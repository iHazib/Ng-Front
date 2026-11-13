/** Explicitly authorized development fixture test; never imports the real catalog. */
import { readFile, writeFile } from 'node:fs/promises';
import { parseEnv } from 'node:util';
import { randomUUID } from 'node:crypto';
import { registerHooks } from 'node:module';

// Execute the actual TypeScript source with Node's type stripping. Resolve its
// extensionless TS imports; server-only uses its real react-server export.
registerHooks({ resolve(specifier, context, next) {
  try { return next(specifier, context); }
  catch (error) {
    if (specifier.startsWith('.') && context.parentURL?.includes('/src/lib/server/database/')) return next(`${specifier}.ts`, context);
    throw error;
  }
} });
for (const file of ['.env', '.env.local']) {
  try { Object.assign(process.env, parseEnv(await readFile(file, 'utf8'))); }
  catch (error) { if (error.code !== 'ENOENT') throw new Error('Local configuration could not be read.'); }
}
const needed = ['NEXT_PUBLIC_SUPABASE_URL', 'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY', 'TEST_ADMIN_EMAIL', 'TEST_ADMIN_PASSWORD', 'TEST_USER_EMAIL', 'TEST_USER_PASSWORD'];
if (needed.some(name => !process.env[name])) throw new Error('Required local configuration is missing; values omitted.');
const endpoint = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL);
if (endpoint.protocol !== 'https:' || endpoint.username || endpoint.password) throw new Error('Invalid project URL.');
const checks = [];
const run = randomUUID();
const product = randomUUID(), variant = randomUUID(), order = randomUUID(), deniedProduct = randomUUID();
const prefix = `verification/${run}`;
const objects = [`${prefix}/private.txt`, `${prefix}/nonadmin.txt`, `${prefix}/anonymous.txt`];
const bytes = `Synthetic private verification fixture ${run}`;
let adminToken, userToken;
let fixturesStarted = false;
function check(name, ok, status) {
  checks.push({ check: name, result: ok ? 'passed' : 'failed', ...(status === undefined ? {} : { http_status: status }) });
  console.log(`${ok ? 'PASS' : 'FAIL'}: ${name}${status === undefined ? '' : ` (HTTP ${status})`}`);
}
function requireCheck(name, ok, status) { check(name, ok, status); if (!ok) throw new Error('Verification prerequisite failed.'); }
async function request(path, token, method = 'GET', body, extra = {}) {
  const response = await fetch(`${endpoint.origin}${path}`, {
    method, headers: { apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }), ...extra },
    body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
    signal: AbortSignal.timeout(20000), cache: 'no-store', redirect: 'error',
  });
  const raw = await response.text();
  let data; try { data = JSON.parse(raw); } catch { data = raw; }
  return { status: response.status, ok: response.ok, data };
}
async function deniedWrapper(name, action) {
  try { await action(); check(name, false); }
  catch (error) { check(name, error.message === 'Administrator access required.' || /^Database request failed \((401|403)\)\.$/.test(error.message)); }
}
try {
  const client = await import('../src/lib/server/database/client.ts');
  const catalog = await import('../src/lib/server/database/catalog.ts');
  for (const [role, env] of [['admin', 'TEST_ADMIN'], ['non-admin', 'TEST_USER']]) {
    const login = await request('/auth/v1/token?grant_type=password', undefined, 'POST', { email: process.env[`${env}_EMAIL`], password: process.env[`${env}_PASSWORD`] });
    requireCheck(`${role} actual password login`, login.status === 200 && !!login.data.access_token, login.status);
    const token = login.data.access_token;
    if (role === 'admin') adminToken = token; else userToken = token;
    const user = await request('/auth/v1/user', token);
    requireCheck(`${role} Auth server validates token identity`, user.status === 200 && user.data.id === login.data.user.id, user.status);
    const membership = await request('/rest/v1/rpc/is_admin', token, 'POST', {});
    requireCheck(`${role} database membership`, membership.status === 200 && membership.data === (role === 'admin'), membership.status);
  }
  const authorized = await client.authorizeAdmin(adminToken);
  check('actual server-only authorizeAdmin accepts admin', !!authorized.userId);
  await deniedWrapper('actual server-only authorizeAdmin denies non-admin', () => client.authorizeAdmin(userToken));
  await deniedWrapper('actual server-only authorizeAdmin rejects invalid token', () => client.authorizeAdmin('invalid-verification-token'));
  fixturesStarted = true;
  let result = await request('/rest/v1/products', adminToken, 'POST', { id: product, name: `Synthetic verification ${run}` });
  requireCheck('admin creates synthetic draft', result.ok, result.status);
  result = await request('/rest/v1/variants', adminToken, 'POST', { id: variant, product_id: product, original_sku: `VERIFY-${run}` });
  requireCheck('admin creates synthetic variant', result.ok, result.status);
  result = await request('/rest/v1/orders', adminToken, 'POST', { id: order });
  requireCheck('admin creates synthetic empty draft order', result.ok, result.status);
  const rows = await catalog.searchAdminCatalog(adminToken, `VERIFY-${run}`);
  check('actual searchAdminCatalog finds photo-free synthetic draft', rows.length === 1 && rows[0].product_id === product);
  const productRows = await catalog.getAdminProduct(adminToken, product);
  check('actual getAdminProduct reads synthetic draft', productRows.length === 1 && productRows[0].id === product);
  const publication = await catalog.getPublicationReport(adminToken, product);
  check('actual publication wrapper reports draft blockers', publication.essential_blockers.length > 0 && publication.concern_research === 'partially_complete');
  const publicRows = await client.searchPublishedCatalog(`Synthetic verification ${run}`);
  check('actual public-search wrapper hides known draft', !publicRows.some(row => row.product_id === product));
  await deniedWrapper('actual catalog wrapper denies non-admin', () => catalog.getAdminProduct(userToken, product));
  for (const [role, token] of [['anonymous', undefined], ['non-admin', userToken]]) {
    for (const [table, id] of [['products', product], ['variants', variant], ['orders', order]]) {
      result = await request(`/rest/v1/${table}?id=eq.${id}&select=id`, token);
      check(`${role} cannot read known synthetic ${table}`, result.status === 200 && Array.isArray(result.data) && result.data.length === 0 || [401,403].includes(result.status), result.status);
    }
    result = await request('/rest/v1/rpc/admin_search_catalog', token, 'POST', { p_query: `VERIFY-${run}` });
    check(`${role} cannot call admin search RPC`, [401,403].includes(result.status), result.status);
  }
  result = await request('/rest/v1/products', userToken, 'POST', { id: deniedProduct, name: `Denied synthetic ${run}` });
  check('non-admin draft creation denied', [401,403].includes(result.status), result.status);
  result = await request(`/rest/v1/products?id=eq.${product}`, userToken, 'PATCH', { name: 'Unauthorized synthetic edit' });
  const intact = await catalog.getAdminProduct(adminToken, product);
  check('non-admin cannot modify known draft', (result.ok || [401,403].includes(result.status)) && intact[0]?.name === `Synthetic verification ${run}`, result.status);
  result = await request('/rest/v1/admin_members?select=user_id', userToken, 'GET', undefined, { 'Accept-Profile': 'app_private' });
  check('private membership schema not exposed', [401,403,406].includes(result.status), result.status);
  result = await request(`/storage/v1/object/catalog-private/${objects[0]}`, adminToken, 'POST', bytes, { 'Content-Type': 'text/plain', 'x-upsert': 'false' });
  requireCheck('admin uploads known private file', result.ok, result.status);
  result = await request(`/storage/v1/object/authenticated/catalog-private/${objects[0]}`, adminToken);
  requireCheck('admin downloads identical private bytes', result.ok && result.data === bytes, result.status);
  for (const [role, token, file] of [['anonymous', undefined, objects[2]], ['non-admin', userToken, objects[1]]]) {
    result = await request(`/storage/v1/object/authenticated/catalog-private/${objects[0]}`, token);
    check(`${role} cannot download known private file`, [400,401,403,404].includes(result.status), result.status);
    result = await request('/storage/v1/object/list/catalog-private', token, 'POST', { prefix, limit: 100 });
    check(`${role} cannot list known private file`, [401,403].includes(result.status) || result.status === 200 && Array.isArray(result.data) && result.data.length === 0, result.status);
    result = await request(`/storage/v1/object/sign/catalog-private/${objects[0]}`, token, 'POST', { expiresIn: 60 });
    check(`${role} cannot sign private download URL`, [400,401,403,404].includes(result.status), result.status);
    result = await request(`/storage/v1/object/catalog-private/${file}`, token, 'POST', bytes, { 'Content-Type': 'text/plain', 'x-upsert': 'false' });
    check(`${role} cannot upload private file`, [400,401,403].includes(result.status), result.status);
  }
  result = await request(`/storage/v1/object/public/catalog-private/${objects[0]}`);
  check('public download route cannot expose known private file', [400,401,403,404].includes(result.status), result.status);
} catch {
  check('verification completed without unexpected error', false);
  // Never print caught fetch/provider errors: they may embed endpoint or payload.
} finally {
  if (adminToken && fixturesStarted) {
    try {
      const removed = await request('/storage/v1/object/catalog-private', adminToken, 'DELETE', { prefixes: objects });
      check('synthetic Storage cleanup request', removed.ok, removed.status);
      const remaining = await request('/storage/v1/object/list/catalog-private', adminToken, 'POST', { prefix, limit: 100 });
      check('synthetic Storage prefix is empty after cleanup', remaining.ok && Array.isArray(remaining.data) && remaining.data.length === 0, remaining.status);
      for (const [table, id] of [['variants', variant], ['products', product], ['products', deniedProduct], ['orders', order]]) {
        const removedRow = await request(`/rest/v1/${table}?id=eq.${id}`, adminToken, 'DELETE');
        const read = await request(`/rest/v1/${table}?id=eq.${id}&select=id`, adminToken);
        check(`synthetic ${table} cleanup ${id === deniedProduct ? 'denied-attempt' : 'fixture'}`, removedRow.ok && read.ok && Array.isArray(read.data) && read.data.length === 0);
      }
    } catch { check('fixture cleanup completed', false); }
  }
  await writeFile('docs/supabase-authenticated-verification.json', JSON.stringify({
    checks, fixture_run_id: run, real_catalog_imported: false, storefront_modified: false,
    wrapper_runtime: 'Actual TypeScript source, Node 24 type stripping, react-server condition; no Next.js HTTP route added.',
    retained_records: 'Append-only audit events and provider Auth logs from synthetic verification remain by design.',
  }, null, 2) + '\n');
}
if (checks.some(item => item.result === 'failed')) process.exitCode = 1;
