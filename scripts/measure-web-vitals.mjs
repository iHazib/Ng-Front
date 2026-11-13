import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { setTimeout as delay } from 'node:timers/promises';
import { chromium } from '@playwright/test';

const username = 'vitals-check';
const password = randomBytes(32).toString('hex');
const port = 3103;
const origin = `http://127.0.0.1:${port}`;
const child = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'start', '--hostname', '127.0.0.1', '--port', String(port)], {
  env: {
    ...process.env,
    NODE_ENV: 'production',
    APP_ENV: 'staging',
    SEARCH_INDEXING: '',
    SITE_URL: 'https://seo-test.example',
    PREVIEW_USERNAME: username,
    PREVIEW_PASSWORD: password,
    NEXT_TELEMETRY_DISABLED: '1',
  },
  stdio: 'ignore',
  windowsHide: true,
});

const init = () => {
  window.__perf = { lcp: 0, lcpElement: null, cls: 0, events: [] };
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      window.__perf.lcp = entry.startTime;
      window.__perf.lcpElement = entry.element ? `${entry.element.tagName.toLowerCase()}.${entry.element.className || ''}` : null;
    }
  }).observe({ type: 'largest-contentful-paint', buffered: true });
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) if (!entry.hadRecentInput) window.__perf.cls += entry.value;
  }).observe({ type: 'layout-shift', buffered: true });
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) if (entry.interactionId) window.__perf.events.push(entry.duration);
  }).observe({ type: 'event', buffered: true, durationThreshold: 16 });
};

async function measure(browser, name, viewport) {
  const context = await browser.newContext({
    httpCredentials: { username, password },
    viewport,
    deviceScaleFactor: viewport.width < 600 ? 3 : 1,
  });
  const page = await context.newPage();
  await page.addInitScript(init);
  const started = Date.now();
  await page.goto(origin + '/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);
  const metrics = await page.evaluate(() => {
    const navigation = performance.getEntriesByType('navigation')[0];
    const resources = performance.getEntriesByType('resource').map((entry) => ({
      name: new URL(entry.name).pathname,
      initiator: entry.initiatorType,
      transfer: entry.transferSize || 0,
      encoded: entry.encodedBodySize || 0,
    }));
    return {
      lcp: Math.round(window.__perf.lcp),
      lcpElement: window.__perf.lcpElement,
      cls: Number(window.__perf.cls.toFixed(4)),
      domContentLoaded: Math.round(navigation.domContentLoadedEventEnd),
      load: Math.round(navigation.loadEventEnd),
      resourceCount: resources.length,
      transferBytes: resources.reduce((sum, item) => sum + item.transfer, 0),
      encodedBytes: resources.reduce((sum, item) => sum + item.encoded, 0),
      images: resources.filter((item) => item.initiator === 'img').sort((a, b) => b.transfer - a.transfer).slice(0, 12),
      imageBytes: resources.filter((item) => item.initiator === 'img').reduce((sum, item) => sum + item.transfer, 0),
      scripts: resources.filter((item) => item.initiator === 'script').reduce((sum, item) => sum + item.transfer, 0),
      styles: resources.filter((item) => item.name.endsWith('.css')).reduce((sum, item) => sum + item.transfer, 0),
    };
  });
  // A meaningful interaction proxy: opening the bag updates client state and a dialog.
  await page.locator('.bag-button').click();
  await page.waitForTimeout(300);
  const inp = await page.evaluate(() => {
    const values = window.__perf.events;
    return values.length ? Math.round(Math.max(...values)) : null;
  });
  await page.keyboard.press('Escape').catch(() => {});
  const result = { name, viewport, elapsedMs: Date.now() - started, ...metrics, interactionDurationMs: inp };
  await context.close();
  return result;
}

async function reducedMotionCheck(browser) {
  const context = await browser.newContext({
    httpCredentials: { username, password },
    viewport: { width: 1440, height: 900 },
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  await page.goto(origin + '/', { waitUntil: 'networkidle' });
  const first = await page.locator('.hero-slide.active').getAttribute('aria-hidden');
  const firstIndex = await page.locator('.hero-slide').evaluateAll((slides) => slides.findIndex((slide) => slide.classList.contains('active')));
  await page.waitForTimeout(9000);
  const secondIndex = await page.locator('.hero-slide').evaluateAll((slides) => slides.findIndex((slide) => slide.classList.contains('active')));
  await context.close();
  return { reducesMotion: first !== null && firstIndex === secondIndex, firstIndex, secondIndex };
}

try {
  let ready = false;
  for (let attempt = 0; attempt < 80; attempt++) {
    if (child.exitCode !== null) throw new Error('Vitals server exited early');
    try {
      if ((await fetch(`${origin}/robots.txt`)).ok) {
        ready = true;
        break;
      }
    } catch {}
    await delay(250);
  }
  if (!ready) throw new Error('Vitals server did not become ready');

  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const results = {
    generatedAt: new Date().toISOString(),
    build: 'next build (production) with APP_ENV=staging, noindex preview',
    desktop: await measure(browser, 'desktop-home', { width: 1440, height: 900 }),
    mobile: await measure(browser, 'mobile-home', { width: 390, height: 844 }),
    reducedMotion: await reducedMotionCheck(browser),
  };
  await browser.close();
  writeFileSync('docs/seo-performance-results.json', `${JSON.stringify(results, null, 2)}\n`);
  console.log(JSON.stringify({
    desktop: { lcp: results.desktop.lcp, cls: results.desktop.cls, interaction: results.desktop.interactionDurationMs, transferKB: Math.round(results.desktop.transferBytes / 1024), scriptsKB: Math.round(results.desktop.scripts / 1024), images: results.desktop.images.slice(0, 5) },
    mobile: { lcp: results.mobile.lcp, cls: results.mobile.cls, interaction: results.mobile.interactionDurationMs, transferKB: Math.round(results.mobile.transferBytes / 1024), scriptsKB: Math.round(results.mobile.scripts / 1024) },
    reducedMotion: results.reducedMotion,
  }, null, 2));
} finally {
  child.kill();
  await new Promise((resolve) => child.once('exit', resolve));
}
