import { test, expect } from '@playwright/test';

test('media resolver rejects private or unsafe paths and uses a shared public interface', async () => {
  const { resolveMedia } = await import('../../src/lib/catalog/media');
  expect(resolveMedia({ source: { kind: 'local-preview', path: '/assets/hero/makeup.webp' }, alt: 'Sample' }).src).toBe('/assets/hero/makeup.webp');
  expect(() => resolveMedia({ source: { kind: 'local-preview', path: '/assets/../private.png' }, alt: '' })).toThrow();
  const publicImage=resolveMedia({ source: { kind: 'cloudinary', cloudName: 'test-cloud', publicId: 'products/sample', version: 1, format: 'webp', publication: 'published', width: 100, height: 200 }, alt: 'Sample' });
  expect(publicImage.src).toBe('https://res.cloudinary.com/test-cloud/image/upload/c_limit,w_100,f_auto,q_auto/v1/products/sample.webp');
  expect(publicImage.srcSet).toContain('100w');
  expect(publicImage.srcSet).not.toContain('320w');
});
