# Technical SEO and performance verification (Prompt 17)

Date: 9 November 2026. This is a verification and hardening stage for the existing
approved storefront. No storefront design, catalogue content, provider integration
or launch state was changed. Prompt 16 (courier) remains deferred by owner decision.

## 1. What was implemented

### Domain and indexing policy

`src/lib/seo/site.ts` is the single source of truth.

- `SITE_URL` must be an approved `https:` origin without credentials, query or
  fragment. An invalid value fails closed.
- Indexing requires **all** of:
  1. `NODE_ENV=production`
  2. `APP_ENV=production`
  3. `SEARCH_INDEXING=approved`
  4. a valid HTTPS `SITE_URL`
- Until then, every public response is `noindex, nofollow, noarchive`, `robots.txt`
  disallows the whole site, and `/sitemap.xml` returns an empty `<urlset />`.
- No production domain is assumed or invented. `metadataBase`, canonicals, Open
  Graph URLs and sitemap URLs stay absent while `SITE_URL` is unset.

### Metadata and social cards

- Root layout: default title, `%s | Nook & Glow` template, application name,
  description, Open Graph (`website`), Twitter `summary_large_image`, and
  server-rendered `Organization` + `WebSite`/`SearchAction` JSON-LD.
- `src/lib/seo/metadata.ts` centralises per-page metadata: title, description,
  canonical, robots, Open Graph, Twitter and article fields.
- Catch-all metadata covers products, collections, brands, The Edit articles,
  search, cart, checkout, order confirmation, customer-care pages and previews.
- Private/transactional pages (`/cart`, `/checkout`, order confirmation) are
  `noindex, nofollow` and deliberately omit a canonical.
- Arbitrary filters, sorting, search results, pagination beyond page 1 and
  previews are `noindex`. Curated collection/brand/Edit pages are indexable only
  when backed by published records and only on their canonical, unfiltered URL.
- `src/app/icon.svg` supplies the icon convention. The old global
  `X-Robots-Tag` header was removed; `/admin` and `/api` keep explicit noindex
  headers. Preview/staging responses receive a runtime noindex header.

### Canonicals, sitemap and stable URLs

- Canonicals are absolute only when an approved origin exists and are emitted
  for canonical, indexable routes.
- `src/app/sitemap.ts` contains only:
  - the homepage;
  - curated collections with a published product count;
  - brands with a published product count;
  - `/the-edit` and published articles;
  - `/deals` and publicly eligible deals.
- Drafts, deleted records, private routes, filters, sort, search, pagination over
  page 1 and placeholder care pages are excluded.
- `lastModified` is emitted only for articles, the sole public RPC exposing a
  genuine timestamp. Product and deal timestamps are not exposed, so none are
  fabricated.
- `robots.txt` is always public (site-wide disallow while unapproved). After
  approval it allows public routes, disallows admin/API/private paths and points
  at the sitemap.
- A new migration `supabase/migrations/202611090001_seo_slug_redirects.sql`
  adds owner-maintained legacy-slug mappings. The resolver
  `src/lib/server/storefront/redirects.ts` only follows a mapping when the target
  is still publicly eligible; otherwise the route keeps its real 404. The
  migration is **not applied** to hosted Supabase yet.
- Unknown products, articles, deals, brands and paths return real 404s. The deals
  loading boundary was moved under `deals/[slug]` so validation happens before a
  successful stream.

### Structured data

- `Product` + `AggregateOffer` (price currency PKR, low/high price, offer count,
  `InStock`/`OutOfStock`). Single-variant products also expose `sku`.
- Product ratings/reviews appear only from the public approved-review projection.
  No invented review text, ratings or counts are emitted.
- `Article` with headline, description, image, author, publisher, dates, section
  and keywords; only genuine `publishedAt` is used.
- `BreadcrumbList` on product, collection, brand, article, Edit and deal pages,
  matching the visible breadcrumbs.
- `Organization` with name, URL, logo and contact email; `WebSite` with search
  action.
- JSON-LD is server-rendered and `<` is escaped to prevent script injection.

### Rendering, headings, links and images

- Core collection/product/article content remains server-rendered.
- Each page keeps one `<h1>` and consistent breadcrumb/internal links.
- The first hero image is eager with `fetchpriority=high`; later hero slides and
  below-fold media are lazy with `fetchpriority=low`. The header logo is eager.
- Images reserve space via the existing aspect-ratio/grid CSS, keeping CLS at 0
  in measurement.
- Carousels already respect `prefers-reduced-motion`; verified that the hero
  stays on slide 0 with reduced motion.

## 2. Automated verification

`npm run test:seo` runs:

1. `tests/seo-policy.test.mjs` — 3 unit tests for URL validation, the four-part
   indexing gate and canonical construction.
2. `scripts/verify-seo.mjs` — starts a production build with
   `APP_ENV=staging`, a test-only `https://seo-test.example` and preview auth,
   then asserts:
   - robots disallow-all and no sitemap reference while unapproved;
   - sitemap is empty, noindex and remains behind preview auth;
   - home noindex header, `Cache-Control: no-store`, robots meta, canonical,
     Open Graph, Twitter, Organization, WebSite and SearchAction;
   - collection, filtered, sorted, paginated, search, cart, checkout, privacy,
     brands, Edit and deals routes are noindex;
   - canonical stays unfiltered on sorted/paginated collections;
   - unknown product/article/deal slugs return 404 with noindex;
   - `/icon.svg` is public and served as SVG;
   - `/reference` is absent from production.
   - **approved mode** (`APP_ENV=production`, `SEARCH_INDEXING=approved`, real
     test `SITE_URL`): robots allows the site, disallows admin/API/private paths
     and points at the sitemap; the sitemap is public, not noindex, and contains
     the homepage; HTML still returns the 503 launch gate with noindex.

Result: all checks passed.

`npm run test:production` also passed after the changes (reference absent, preview
fails closed, authentication/asset/noindex/production sample guard verified).

`npm run check` (sources, lint, typecheck, build) passed.

### Freshness and draft privacy

- Public catalogue/article/deal reads use the published-only RPCs with
  `cache: 'no-store'`; there is no cross-request catalogue cache to invalidate
  after an admin edit.
- `robots.txt` and `sitemap.xml` are force-dynamic, so a newly published or
  unpublished record is reflected on the next request rather than a stale build.
- Preview responses are `Cache-Control: private, no-store`.
- Drafts, deleted records and private routes are never queried by the public
  projections and are never emitted in metadata, JSON-LD or the sitemap.
- The route checks confirm unknown/deleted and private paths return 404/noindex
  instead of leaking draft names.

## 3. Measured performance

Environment: production `next build`, `APP_ENV=staging`, local `next start`,
headless Chrome 1.63 via Playwright, preview authentication enabled. This is a
local production build, not production hosting or field data.

| Metric | Desktop 1440×900 | Mobile 390×844 |
| --- | --- | --- |
| LCP | ~1.07–2.13 s across repeated runs | ~0.68–0.82 s |
| CLS | 0 | 0 |
| Interaction proxy (event duration) | ~88–120 ms | 24 ms |
| Requests | 20 | 20 |
| Total transfer | ~1,889 KB | ~1,889 KB |
| Images | ~1,016 KB | ~1,016 KB |
| Scripts | ~145 KB | ~145 KB |
| CSS | ~14 KB | ~14 KB |
| Reduced motion | hero stayed on slide 0 | — |

Raw evidence: [`docs/seo-performance-results.json`](seo-performance-results.json).

The LCP element is `img.hero-photo`. Desktop LCP varied noticeably between local
runs (about 1.1 s to 2.1 s); mobile was consistently under 0.72 s. CLS stayed 0
and the interaction proxy stayed well under the 200 ms "good" INP threshold.
INP here is an interaction proxy (bag click), not field INP.

## 4. Concrete performance findings

- **Images dominate the payload (~1,016 KB of ~1,889 KB).** The four hero images
  are ~162–243 KB each, plus product and category imagery. The next improvement
  is compressing/resizing hero and product assets and serving responsive variants;
  this is an asset-pipeline change, not a markup fix.
- **CSS is small (~14 KB transferred).** An earlier measurement misattributed
  `<link rel=preload>` entries to styles; the script now counts only `.css`.
- **Scripts are ~145 KB transferred**, acceptable for the current interactive
  bag/carousel behaviour.
- **CLS is 0** because media containers reserve aspect ratio.
- **Below-fold media is lazily loaded** and non-first hero slides are low
  priority; the first hero is eagerly fetched and high priority.

## 5. Unresolved decisions and blockers

1. **No approved production domain.** `SITE_URL` is absent, so `metadataBase`,
   canonicals, Open Graph URLs, sitemap URLs and indexing cannot activate.
2. **No explicit launch approval.** `SEARCH_INDEXING=approved` is intentionally
   unset. Preview/staging stays noindex.
3. **No published catalogue content.** The connected Supabase project has zero
   published products, articles and deals, so the approved-mode sitemap would
   currently contain only the homepage. This is correct, not a defect.
4. **Slug-redirect migration not installed.** Hosted HTTP credentials cannot apply
   DDL and no `SUPABASE_DB_URL` is available. Until applied, legacy slugs return
   404; the resolver returns null safely.
5. **Production serving remains gated.** `APP_ENV=production` still returns 503
   until launch configuration is authorized. That gate was not changed.
6. **No approved 1200×630 social image.** The current Open Graph fallback is
   `/assets/hero/brand-introduction.webp` (1672×941), used only when a domain
   exists. A purpose-made 1200×630 asset is recommended before launch.
7. **Social profile URLs are unset** in `src/config/site.ts`, so `sameAs` is not
   emitted.
8. **Customer-care copy is still placeholder content.** Those pages are noindex
   but followable; they must not be indexed until real policy copy is approved.
9. **`.env` contains an unused `NEXT_PUBLIC_SUPABASE_SECRET_KEY`.** It is gitignored
   but should be removed/renamed to avoid a future leak.

No production deployment was performed. Prompt 18 has not been started.
