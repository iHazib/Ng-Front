import { test, expect, type Page } from '@playwright/test';

// Full supplied-image decoding and many reference screenshots exceed the generic
// smoke-test budget on this Windows host. Keep every assertion and allow the work.
test.beforeEach(() => test.setTimeout(180_000));

async function ready(page: Page) {
  if (!page.url().endsWith('/reference')) await expect(page.locator('.storefront')).toHaveAttribute('data-preview-ready', 'true');
  await page.locator('img').evaluateAll(async images => {
    images.forEach(image => { (image as HTMLImageElement).loading = 'eager'; });
    await Promise.all(images.map(image => (image as HTMLImageElement).decode()));
  });
  await expect(page.locator('.brand-card')).toHaveCount(36);
  // Freeze document travel only while comparing settled states on both pages.
  await page.addStyleTag({ content: 'html { scroll-behavior: auto !important; }' });
}
const sections = '.ng-header, main > section, .refined-footer';
async function dimensions(page: Page) {
  return page.locator(sections).evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect(), style = getComputedStyle(element);
    return { width: rect.width, height: rect.height, top: rect.top + scrollY, font: style.fontFamily, background: style.backgroundColor };
  }));
}

test('complete approved page matches section geometry and all carousel states', async ({ page }, info) => {
  test.skip(info.project.name === 'mobile', 'Mobile hero/header intentionally updated by user; covered by responsive mobile checks.');
  test.setTimeout(300_000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  const reference = await page.context().newPage();
  await reference.goto('/reference'); await ready(reference);
  const response = await page.goto('/'); await ready(page);
  expect(response?.headers()['x-robots-tag']).toContain('noindex');
  await expect(page.getByText('Foundation preview', { exact: true })).toHaveCount(0);
  expect(await dimensions(page)).toEqual(await dimensions(reference));
  for (const [name, current] of [['reference', reference], ['react', page]] as const) {
    await current.mouse.move(0, 0);
    // Handoff notes are reference-only; compare the storefront through its footer.
    await current.locator('.site').screenshot({ path: info.outputPath(`${name}-home.png`), animations: 'disabled', scale: 'css' });
    for (let index = 0; index < 4; index++) {
      await current.locator('.hero-dot').nth(index).click();
      await expect(current.locator('.hero-slide.active')).toHaveCount(1);
      await current.locator('.hero-carousel').screenshot({ path: info.outputPath(`${name}-hero-${index}.png`), animations: 'disabled' });
    }
    for (let index = 0; index < 3; index++) {
      await current.locator('.edit-dot').nth(index).click();
      await current.locator('#journal').screenshot({ path: info.outputPath(`${name}-edit-${index}.png`), animations: 'disabled' });
    }
    for (let index = 0; index < 5; index++) {
      await current.locator('.corner-dot').nth(index).click();
      await current.locator('#categories').screenshot({ path: info.outputPath(`${name}-category-${index}.png`), animations: 'disabled' });
    }
    for (let index = 0; index < 3; index++) {
      const gallery = current.locator('.product-gallery').first();
      await gallery.locator('.gallery-dot').nth(index).click();
      await gallery.screenshot({ path: info.outputPath(`${name}-product-${index}.png`), animations: 'disabled' });
    }
    await current.locator('.search-trigger').click();
    await current.locator('.search-field input').fill('skin');
    await current.locator('.ng-header').screenshot({ path: info.outputPath(`${name}-search.png`), animations: 'disabled' });
    await current.keyboard.press('Escape');
    for (const [index, button] of (await current.locator('.category-toggle:visible').all()).entries()) {
      await button.focus();
      const menu = current.locator(`#${await button.getAttribute('aria-controls')}`);
      await menu.screenshot({ path: info.outputPath(`${name}-menu-${index}.png`), animations: 'disabled' });
      await menu.locator('.menu-close').click();
    }
    await current.locator('.quick-bag').first().click();
    await current.locator('.bag-button').click();
    await current.locator('#cart-drawer').screenshot({ path: info.outputPath(`${name}-bag.png`), animations: 'disabled' });
    await current.locator('#cart-close').click();
  }
  expect(errors).toEqual([]);
  await reference.close();
});

test('React menus, sample bag, article dialogs and keyboard controls work', async ({ page }) => {
  await page.goto('/'); await ready(page);
  // The approved CSS hides the category navigation at <=1050px, on both pages.
  for (const button of await page.locator('.category-toggle:visible').all()) {
    await button.focus();
    await expect(button).toHaveAttribute('aria-expanded', 'true');
    const menu = page.locator(`#${await button.getAttribute('aria-controls')}`);
    await expect(menu).toBeVisible();
    await menu.locator('.menu-close').click();
    await expect(menu).toBeHidden();
  }
  await page.locator('.search-trigger').click();
  await page.locator('.search-field input').fill('unmatched');
  await expect(page.locator('#search-results')).toContainText('No category match');
  await page.keyboard.press('Escape');
  await expect(page.locator('#nav-search')).toBeHidden();
  await page.locator('#hero-carousel').focus(); await page.keyboard.press('ArrowRight');
  await expect(page.locator('.hero-slide.active')).toHaveClass(/selected-makeup/);
  await page.locator('#hero-pause').click(); await expect(page.locator('#hero-pause')).toHaveAttribute('aria-pressed', 'true');
  await page.locator('.corner-shell').focus(); await page.keyboard.press('ArrowRight');
  await expect(page.locator('#corner-description')).toHaveText('A little colour. A lot of you.');
  await page.locator('.edit-dot').nth(1).click();
  await expect(page.locator('#journal')).toHaveClass(/is-warm/);
  await page.locator('.edit-slide.active [data-blog]').click();
  await expect(page).toHaveURL(/the-edit\/the-art-of-an-everyday-table/);
  await expect(page.locator('.article-page h1')).toHaveText('The art of an everyday table.');
  await expect(page.locator('.article-prose')).toContainText('Start with texture');
  await page.goto('/'); await ready(page);
  await page.locator('.bag-button').click();
  await expect(page.locator('.empty-bag')).toBeVisible(); await page.locator('#cart-close').click();
  await page.locator('.quick-bag').first().click();
  await page.locator('.text-add').nth(1).click();
  await expect(page.locator('.bag-count')).toHaveText('2');
  await page.reload(); await ready(page);
  await expect(page.locator('.bag-count')).toHaveText('2');
  await page.locator('.bag-button').click();
  await expect(page.locator('#cart-total')).toHaveText('Rs 9,298');
  await page.getByRole('button', { name: 'Increase Dark Spot Correcting Glow Serum quantity', exact: true }).click();
  await expect(page.locator('#cart-total')).toHaveText('Rs 13,097');
  await page.getByRole('button', { name: 'Remove Foaming Cleanser', exact: true }).click();
  await expect(page.locator('#cart-item-count')).toHaveText('2');
  await page.locator('#checkout-open').click();
  await expect(page).toHaveURL(/checkout/);
  await expect(page.locator('.commerce')).toContainText('Payment methods are not configured.');
  await page.goto('/'); await ready(page);
  await page.locator('[data-preview="Instagram"]').click();
  await expect(page.locator('#preview-dialog')).toContainText('official Instagram profile URL');
  await page.keyboard.press('Escape');
  const concerns = page.locator('.concerns-grid');
  await concerns.focus(); await page.keyboard.press('ArrowRight');
  expect(await concerns.evaluate(element => element.scrollLeft)).toBeGreaterThan(0);
});

test('mobile hero fits every slide and hamburger supports category navigation', async ({ page }, info) => {
  test.skip(info.project.name !== 'mobile', 'Responsive mobile verification.');
  for (const width of [320, 390, 650, 800]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto('/'); await ready(page);
    await page.getByRole('button', { name: 'Open menu', exact: true }).click();
    await expect(page.locator('.ng-links')).toBeVisible();
    await page.locator('.category-toggle').first().click();
    await expect(page.locator('#category-menu-0')).toBeVisible();
    await page.locator('#category-menu-0 .menu-close').click();
    await expect(page.locator('.category-toggle').last()).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.locator('.ng-links')).toBeHidden();
    await expect(page.getByRole('button', { name: 'Open menu', exact: true })).toBeFocused();
    if (width <= 650) {
      for (let slide = 0; slide < 4; slide++) {
        await page.locator('.hero-dot').nth(slide).click();
        const button = await page.locator('.hero-slide.active .button').boundingBox();
        const controls = await page.locator('.hero-controls').boundingBox();
        expect(button!.y + button!.height).toBeLessThan(controls!.y);
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
        await page.locator('.hero-carousel').screenshot({ path: info.outputPath(`mobile-${width}-hero-${slide}.png`), scale: 'css' });
      }
    }
  }
});

test('motion preferences, pause, swipe and brand scrolling work', async ({ page }) => {
  await page.clock.install();
  await page.goto('/'); await ready(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.mouse.move(0, 0);
  await page.clock.runFor(100);
  await page.clock.fastForward(7700);
  await expect(page.locator('.hero-slide.active')).toHaveClass(/selected-makeup/);
  await page.locator('#hero-pause').click();
  await page.locator('#hero-pause').blur();
  await page.mouse.move(0, 0);
  await page.clock.fastForward(16000);
  await expect(page.locator('.hero-slide.active')).toHaveClass(/selected-makeup/);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.locator('.corner-dot').first().click();
  const shell = page.locator('.corner-shell');
  await shell.dispatchEvent('pointerdown', { clientX: 280, clientY: 200, button: 0, pointerId: 1 });
  await shell.dispatchEvent('pointerup', { clientX: 100, clientY: 205, button: 0, pointerId: 1 });
  await expect(page.locator('#corner-description')).toHaveText('A little colour. A lot of you.');
  const rail = page.locator('.brand-viewport');
  const before = await rail.evaluate(element => element.scrollLeft);
  await page.locator('.brand-controls button').last().click();
  expect(await rail.evaluate(element => element.scrollLeft)).toBeGreaterThan(before);
});

