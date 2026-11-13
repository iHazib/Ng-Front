import assert from 'node:assert/strict';
import test from 'node:test';
import { canonicalUrl, indexingApproved, siteUrl } from '../src/lib/seo/site.ts';

const original = { ...process.env };
function restore() {
  for (const key of ['NODE_ENV', 'APP_ENV', 'SITE_URL', 'SEARCH_INDEXING']) {
    if (original[key] === undefined) delete process.env[key];
    else process.env[key] = original[key];
  }
}

test('siteUrl requires HTTPS and rejects credentials, query and fragment', () => {
  assert.equal(siteUrl(undefined), undefined);
  assert.equal(siteUrl(''), undefined);
  assert.equal(siteUrl('https://nook.example').origin, 'https://nook.example');
  for (const value of ['http://nook.example', 'https://user:pass@nook.example', 'https://nook.example?x=1', 'https://nook.example#top']) {
    assert.throws(() => siteUrl(value), /SITE_URL/);
  }
});

test('indexing needs production, explicit approval and a real HTTPS site URL', () => {
  try {
    process.env.NODE_ENV = 'production';
    process.env.APP_ENV = 'production';
    process.env.SITE_URL = 'https://nook.example';
    delete process.env.SEARCH_INDEXING;
    assert.equal(indexingApproved(), false);

    process.env.SEARCH_INDEXING = 'approved';
    assert.equal(indexingApproved(), true);

    process.env.APP_ENV = 'staging';
    assert.equal(indexingApproved(), false);

    process.env.APP_ENV = 'production';
    process.env.SITE_URL = 'http://nook.example';
    assert.equal(indexingApproved(), false);

    delete process.env.SITE_URL;
    assert.equal(indexingApproved(), false);
  } finally {
    restore();
  }
});

test('canonical URLs are absolute, origin-only and path-based', () => {
  try {
    process.env.SITE_URL = 'https://nook.example';
    assert.equal(canonicalUrl('/products/example'), 'https://nook.example/products/example');
    assert.equal(canonicalUrl('products/example'), undefined);
    assert.equal(canonicalUrl('//other.example/path'), undefined);
    assert.equal(canonicalUrl('/skincare?sort=price-asc'), undefined);
    assert.equal(canonicalUrl('/skincare#top'), undefined);
    delete process.env.SITE_URL;
    assert.equal(canonicalUrl('/'), undefined);
  } finally {
    restore();
  }
});
