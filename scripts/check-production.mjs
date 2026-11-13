import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';

const manifest = JSON.parse(readFileSync('.next/server/app-paths-manifest.json', 'utf8'));
assert(!Object.keys(manifest).some((key) => key.includes('reference')), 'Reference route shipped in production');
assert(!Object.keys(manifest).some((key) => key.includes('deal-ui-verification')), 'Temporary deal verification harness shipped in production');
const username = 'local-check';
const password = randomBytes(32).toString('hex');
const authorization = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;
const port = 3101;

async function run(environment, checks) {
  const child = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'start', '--hostname', '127.0.0.1', '--port', String(port)], {
    env: { ...process.env, NEXT_TELEMETRY_DISABLED: '1', PREVIEW_USERNAME: '', PREVIEW_PASSWORD: '', ...environment },
    stdio: 'ignore', windowsHide: true,
  });
  try {
    let ready = false;
    for (let attempt = 0; attempt < 80; attempt++) {
      if (child.exitCode !== null) throw new Error('Production test server exited early');
      try { if ((await fetch(`http://127.0.0.1:${port}/robots.txt`)).ok) { ready = true; break; } } catch {}
      await delay(250);
    }
    assert(ready, 'Production test server did not become ready');
    await checks((path, headers = {}) => fetch(`http://127.0.0.1:${port}${path}`, { headers }));
  } finally {
    child.kill();
    await new Promise((resolve) => child.once('exit', resolve));
  }
}

await run({ APP_ENV: 'staging' }, async (get) => {
  assert.equal((await get('/')).status, 503, 'Unconfigured preview must fail closed');
  assert.equal((await get('/assets/hero/makeup.webp')).status, 503);
});
await run({ APP_ENV: 'staging', PREVIEW_USERNAME: username, PREVIEW_PASSWORD: password }, async (get) => {
  assert.equal((await get('/')).status, 401);
  assert.equal((await get('/assets/hero/makeup.webp')).status, 401);
  assert.equal((await get('/', { authorization: 'Basic invalid' })).status, 401);
  const page = await get('/', { authorization });
  assert.equal(page.status, 200);
  assert.match(page.headers.get('x-robots-tag'), /noindex/);
  assert.match(page.headers.get('cache-control'), /no-store/);
  const html = await page.text();
  assert(!html.includes(password));
  assert(!html.includes('Open the approved reference'));
  assert.equal((await get('/reference', { authorization })).status, 404);
  assert.equal((await get('/checkout')).status, 401);
  for (const path of ['/skincare', '/privacy', '/checkout']) {
    const interior = await get(path, { authorization });
    assert.equal(interior.status, 200);
    assert.match(interior.headers.get('x-robots-tag'), /noindex/);
    assert.match(interior.headers.get('cache-control'), /no-store/);
  }
  // Installed Next docs specify 200 for a streamed notFound response; blocking
  // metadata crawlers must receive a real 404, and browsers must see noindex/404 UI.
  assert.equal((await get('/products/missing', { authorization, 'User-Agent': 'Twitterbot/1.0' })).status, 404);
  const missing = await get('/products/missing', { authorization });
  assert([200,404].includes(missing.status));
  assert.match(missing.headers.get('x-robots-tag'), /noindex/);
  assert.match(await missing.text(), /This corner is not here/);
  assert.match(await (await get('/robots.txt')).text(), /Disallow: \//);
});
await run({ APP_ENV: 'production', PREVIEW_USERNAME: username, PREVIEW_PASSWORD: password }, async (get) => {
  assert.equal((await get('/', { authorization })).status, 503, 'Sample data must not publish as production');
});
console.log('Production checks passed: reference absent; preview fails closed; authentication, asset protection, noindex and production sample guard verified.');
