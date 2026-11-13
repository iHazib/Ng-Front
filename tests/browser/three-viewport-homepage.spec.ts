import { test, expect, type Page } from '@playwright/test';

test.beforeEach(() => test.setTimeout(180_000));

const VIEWPORTS = [
  { name: 'desktop', width: 1440, height: 1000 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'mobile', width: 390, height: 844 },
] as const;

async function ready(page: Page) {
  await expect(page.locator('.storefront')).toHaveAttribute('data-preview-ready', 'true');
  await page.locator('img').evaluateAll(async images => {
    images.forEach(image => { (image as HTMLImageElement).loading = 'eager'; });
    await Promise.all(images.map(image => (image as HTMLImageElement).decode()));
  });
  await page.addStyleTag({ content: 'html { scroll-behavior: auto !important; }' });
}

async function checkDocumentOverflow(page: Page, viewportName: string) {
  const overflow = await page.evaluate(() => {
    const problems: string[] = [];
    if (document.documentElement.scrollWidth > window.innerWidth + 2) {
      problems.push(`documentElement scroll=${document.documentElement.scrollWidth} client=${window.innerWidth}`);
    }
    if (document.body.scrollWidth > window.innerWidth + 2) {
      problems.push(`body scroll=${document.body.scrollWidth} client=${window.innerWidth}`);
    }
    return problems;
  });
  expect(overflow, `${viewportName}: document horizontal overflow`).toEqual([]);
}

async function checkBrokenImages(page: Page, viewportName: string) {
  const broken = await page.evaluate(() => {
    const problems: string[] = [];
    for (const img of Array.from(document.querySelectorAll('img'))) {
      if (img.complete && img.naturalWidth === 0) {
        problems.push(`decoded image failed: ${img.src} alt="${img.alt}"`);
      }
      if (!img.complete) {
        problems.push(`image not complete: ${img.src} alt="${img.alt}"`);
      }
    }
    return problems;
  });
  expect(broken, `${viewportName}: broken images`).toEqual([]);
}

async function checkAltText(page: Page, viewportName: string) {
  const missing = await page.evaluate(() => {
    const problems: string[] = [];
    for (const img of Array.from(document.querySelectorAll('img'))) {
      const alt = img.getAttribute('alt');
      if (alt === null) problems.push(`img without alt: ${img.src}`);
    }
    return problems;
  });
  expect(missing, `${viewportName}: missing alt text`).toEqual([]);
}

async function checkBrokenLinks(page: Page, viewportName: string) {
  const broken = await page.evaluate(async () => {
    const problems: string[] = [];
    const links = Array.from(document.querySelectorAll('a[href]')).map(a => (a as HTMLAnchorElement).href);
    for (const href of links) {
      if (!href.startsWith('http://127.0.0.1:') && !href.startsWith('/')) continue;
      try {
        const res = await fetch(href, { method: 'HEAD', redirect: 'error' });
        if (res.status >= 400) problems.push(`broken link ${href}: ${res.status}`);
      } catch {
        try {
          const res = await fetch(href, { redirect: 'error' });
          if (res.status >= 400) problems.push(`broken link ${href}: ${res.status}`);
        } catch { problems.push(`unreachable link ${href}`); }
      }
    }
    return problems;
  });
  expect(broken, `${viewportName}: broken links`).toEqual([]);
}

async function checkFocusTrap(page: Page) {
  await page.keyboard.press('Tab');
  const focused = await page.evaluate(() => document.activeElement?.tagName ?? 'body');
  expect(focused).not.toBe('body');
}

async function checkReducedMotion(page: Page) {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const carousel = page.locator('.hero-carousel');
  if (await carousel.count() > 0) {
    await expect(carousel).toBeVisible();
  }
  await page.emulateMedia({ reducedMotion: 'no-preference' });
}

for (const vp of VIEWPORTS) {
  test(`homepage acceptance at ${vp.name} (${vp.width}x${vp.height})`, async ({ page }) => {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    const errors: string[] = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });

    const response = await page.goto('/');
    expect(response?.status()).toBe(200);
    await ready(page);

    await checkDocumentOverflow(page, vp.name);
    await checkBrokenImages(page, vp.name);
    await checkAltText(page, vp.name);
    await checkBrokenLinks(page, vp.name);
    await checkFocusTrap(page);
    await checkReducedMotion(page);

    // Carousel equivalent slide states across viewports.
    const dots = page.locator('.hero-dot');
    const count = await dots.count();
    for (let i = 0; i < count; i++) {
      await dots.nth(i).click();
      await expect(page.locator('.hero-slide.active')).toHaveCount(1);
    }

    // Focus stays within focusable carousel controls.
    await page.locator('.hero-carousel').focus();
    await page.keyboard.press('ArrowRight');
    await expect(page.locator('.hero-slide.active')).toHaveCount(1);

    expect(errors).toEqual([]);
  });
}
