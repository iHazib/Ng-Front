import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';

const username = 'seo-check';
const password = randomBytes(32).toString('hex');
const authorization = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;
const port = 3102;
const site = 'https://seo-test.example';

const child = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'start', '--hostname', '127.0.0.1', '--port', String(port)], {
  env: {
    ...process.env,
    NODE_ENV: 'production',
    APP_ENV: 'staging',
    SEARCH_INDEXING: '',
    SITE_URL: site,
    PREVIEW_USERNAME: username,
    PREVIEW_PASSWORD: password,
    NEXT_TELEMETRY_DISABLED: '1',
  },
  stdio: 'ignore',
  windowsHide: true,
});

const get = (path, headers = {}, redirect = 'manual') => fetch(`http://127.0.0.1:${port}${path}`, { headers, redirect });

try {
  let ready = false;
  for (let attempt = 0; attempt < 80; attempt++) {
    if (child.exitCode !== null) throw new Error('SEO test server exited early');
    try {
      const response = await get('/robots.txt');
      if (response.ok) {
        ready = true;
        break;
      }
    } catch {}
    await delay(250);
  }
  assert(ready, 'SEO test server did not become ready');

  const html = async (path, headers = { authorization }) => {
    const response = await get(path, headers);
    return { response, text: await response.text() };
  };

  const robots = await (await get('/robots.txt')).text();
  assert.match(robots, /Disallow: \//);
  assert.doesNotMatch(robots, /Sitemap:/);

  const sitemap = await get('/sitemap.xml', { authorization });
  assert.equal(sitemap.status, 200);
  assert.match(sitemap.headers.get('x-robots-tag') ?? '', /noindex/);
  const sitemapText = await sitemap.text();
  assert.match(sitemapText, /<urlset/);
  assert.doesNotMatch(sitemapText, /<url>/);
  assert.equal((await get('/sitemap.xml')).status, 401, 'Staging sitemap remains behind preview authentication');

  const home = await html('/');
  assert.equal(home.response.status, 200);
  assert.match(home.response.headers.get('x-robots-tag') ?? '', /noindex/);
  assert.match(home.response.headers.get('cache-control') ?? '', /no-store/);
  assert.match(home.text, /<meta name="robots" content="noindex[^"]*"/);
  assert.match(home.text, new RegExp(`<link rel="canonical" href="${site}/?"`));
  assert.match(home.text, /<meta property="og:title"/);
  assert.match(home.text, /<meta property="og:description"/);
  assert.match(home.text, /<meta name="twitter:card" content="summary_large_image"/);
  assert.match(home.text, /"@type":"Organization"/);
  assert.match(home.text, /"@type":"WebSite"/);
  assert.match(home.text, /"@type":"SearchAction"/);

  for (const path of ['/skincare', '/skincare?sort=price-asc', '/skincare?page=2', '/skincare?brand=example', '/search?q=serum', '/cart', '/checkout', '/privacy', '/brands', '/the-edit', '/deals']) {
    const page = await html(path);
    assert.equal(page.response.status, 200, path);
    assert.match(page.text, /<meta name="robots" content="noindex[^"]*"/, path);
  }

  const search = await html('/search?q=serum');
  assert.match(search.text, new RegExp(`<link rel="canonical" href="${site}/search"`));
  const filtered = await html('/skincare?sort=price-asc&page=2');
  assert.match(filtered.text, new RegExp(`<link rel="canonical" href="${site}/skincare"`));
  assert.match(filtered.text, /<meta name="robots" content="noindex[^"]*"/);

  for (const path of ['/products/missing-product', '/the-edit/missing-article', '/deals/missing-deal']) {
    const missing = await get(path, { authorization, 'User-Agent': 'Twitterbot/1.0' });
    assert.equal(missing.status, 404, path);
    assert.match(missing.headers.get('x-robots-tag') ?? '', /noindex/);
    assert.match(await missing.text(), /This corner is not here/);
  }

  const icon = await get('/icon.svg');
  assert.equal(icon.status, 200);
  assert.match(icon.headers.get('content-type') ?? '', /image\/svg\+xml/);

  const reference = await get('/reference');
  assert.equal(reference.status, 404);

  // Approved mode: robots/sitemap are public and indexable, while HTML pages
  // remain behind the production launch gate. This exercises the approved
  // branch without removing that gate.
  const approvedPort = 3105;
  const approvedSite = 'https://seo-approved.example';
  const approvedChild = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'start', '--hostname', '127.0.0.1', '--port', String(approvedPort)], {
    env: {
      ...process.env,
      NODE_ENV: 'production',
      APP_ENV: 'production',
      SEARCH_INDEXING: 'approved',
      SITE_URL: approvedSite,
      PREVIEW_USERNAME: '',
      PREVIEW_PASSWORD: '',
      NEXT_TELEMETRY_DISABLED: '1',
    },
    stdio: 'ignore',
    windowsHide: true,
  });
  const approvedGet = (path) => fetch(`http://127.0.0.1:${approvedPort}${path}`, { redirect: 'manual' });
  try {
    let approvedReady = false;
    for (let attempt = 0; attempt < 80; attempt++) {
      if (approvedChild.exitCode !== null) throw new Error('Approved SEO test server exited early');
      try {
        if ((await approvedGet('/robots.txt')).ok) {
          approvedReady = true;
          break;
        }
      } catch {}
      await delay(250);
    }
    assert(approvedReady, 'Approved SEO test server did not become ready');

    const approvedRobotsResponse = await approvedGet('/robots.txt');
    const approvedRobots = await approvedRobotsResponse.text();
    assert.equal(approvedRobotsResponse.status, 200);
    assert.match(approvedRobots, /^Allow: \/$/m);
    assert.doesNotMatch(approvedRobots, /^Disallow: \/$/m);
    assert.match(approvedRobots, new RegExp(`^Sitemap: ${approvedSite}/sitemap\.xml$`, 'm'));
    assert.match(approvedRobots, /^Disallow: \/admin$/m);

    const approvedSitemap = await approvedGet('/sitemap.xml');
    assert.equal(approvedSitemap.status, 200);
    assert.doesNotMatch(approvedSitemap.headers.get('x-robots-tag') ?? '', /noindex/);
    const approvedSitemapText = await approvedSitemap.text();
    assert.match(approvedSitemapText, /<urlset/);
    assert.match(approvedSitemapText, new RegExp(`<loc>${approvedSite}/</loc>`));

    // The production launch gate intentionally still blocks HTML serving.
    const approvedHome = await approvedGet('/');
    assert.equal(approvedHome.status, 503);
    assert.match(approvedHome.headers.get('x-robots-tag') ?? '', /noindex/);
  } finally {
    approvedChild.kill();
    await new Promise((resolve) => approvedChild.once('exit', resolve));
  }

  console.log('SEO route checks passed: staging noindex, approved robots/sitemap, canonical/OG metadata, private routes, 404s, icons, cache headers and the production launch gate verified.');
} finally {
  child.kill();
  await new Promise((resolve) => child.once('exit', resolve));
}
