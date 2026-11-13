import { test, expect, type Page } from '@playwright/test';
async function open(page: Page, path: string) {
  const response = await page.goto(path);
  await expect(page.locator('.storefront')).toHaveAttribute('data-preview-ready', 'true');
  return response;
}

test('sample page families render with metadata and responsive layouts', async ({ page }, info) => {
  test.setTimeout(180_000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  const paths = ['/skincare','/makeup','/fragrances','/fragrances/home-fragrance','/bath-body','/cutlery','/products/on-the-glow-blush-ruby','/brands','/brands/axis-y','/search','/the-edit','/the-edit/the-art-of-an-everyday-table','/cart','/checkout','/customer-care','/privacy','/contact'];
  for (const path of paths) {
    const response = await open(page, path);
    expect(response?.status()).toBe(200);
    await expect(page.locator('.commerce h1')).toBeVisible();
    await expect(page.locator('meta[name="robots"]')).toHaveAttribute('content', /noindex/);
    await expect(page.getByRole('navigation', { name: 'Breadcrumb' })).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    if (['/skincare','/products/on-the-glow-blush-ruby','/brands','/the-edit','/customer-care'].includes(path)) await page.screenshot({ path: info.outputPath(`${path.replaceAll('/','_')}.png`), fullPage: true, scale: 'css' });
  }
  expect((await open(page, '/products/not-a-product'))?.status()).toBe(404);
  await expect(page.getByRole('heading', { name: 'This corner is not here.' })).toBeVisible();
  expect(errors).toEqual([]);
});

test('URL filters, pagination, variant selection and guest checkout preserve the sample bag', async ({ page }, info) => {
  test.setTimeout(120_000);
  await open(page, '/search');
  await expect(page.locator('.catalog-card')).toHaveCount(2);
  await page.getByRole('link', { name: 'Next →', exact: true }).click();
  await expect(page).toHaveURL(/page=2/);
  await expect(page.locator('.catalog-card').first()).toContainText('On the Glow Blush Ruby');
  await open(page, '/skincare');
  const mobile = info.project.name === 'mobile';
  if (mobile) await page.getByRole('button', { name: 'Filter & sort' }).click();
  await page.locator(`#${mobile ? 'mobile' : 'desktop'}-brand`).selectOption('axis-y');
  await page.getByRole('button', { name: 'Apply filters', exact: true }).click();
  await expect(page).toHaveURL(/brand=axis-y/);
  await expect(page.locator('.catalog-card')).toHaveCount(1);
  await page.getByRole('link', { name: 'Clear all', exact: true }).click();
  await expect(page.locator('.catalog-card')).toHaveCount(2);
  await open(page, '/search?q=not-a-product');
  await expect(page.getByRole('heading', { name: 'Nothing in this edit yet.' })).toBeVisible();
  await open(page, '/products/on-the-glow-blush-ruby');
  await expect(page.getByRole('radio', { name: 'Ruby', exact: true })).toBeChecked();
  await page.getByLabel('Quantity', { exact: true }).fill('2');
  await page.getByRole('button', { name: 'Add to sample bag' }).click();
  await page.getByRole('link', { name: 'View your bag →' }).click();
  await expect(page.locator('.order-summary')).toContainText('Rs 6,998');
  await page.reload();
  await expect(page.getByLabel('Quantity', { exact: true })).toHaveValue('2');
  await page.getByRole('link', { name: 'Continue to checkout', exact: true }).click();
  await page.getByRole('button', { name: 'Review sample checkout' }).click();
  await expect(page.getByLabel('Full name', { exact: true })).toBeFocused();
  await expect(page.getByText('Enter full name.', { exact: true })).toBeVisible();
  for (const [label, value] of [['Full name','Sample Visitor'],['Email','sample@example.test'],['Phone','03000000000'],['Delivery address','Preview only'],['City','Preview']]) await page.getByLabel(label, { exact: true }).fill(value);
  const posts: string[] = [];
  page.on('request', request => { if (request.method() === 'POST') posts.push(request.url()); });
  await page.getByRole('button', { name: 'Review sample checkout' }).click();
  await expect(page.getByRole('heading', { name: 'Your checkout preview is ready.' })).toBeFocused();
  await expect(page.locator('.order-summary')).toContainText('Payable total: not available');
  expect(posts).toEqual([]);
  await page.getByRole('button', { name: 'Edit details' }).click();
  await expect(page.getByLabel('Full name', { exact: true })).toHaveValue('Sample Visitor');
  await open(page, '/cart');
  await page.getByRole('button', { name: 'Remove On the Glow Blush Ruby' }).click();
  await expect(page.getByText('Your sample bag is empty.')).toBeVisible();
});
