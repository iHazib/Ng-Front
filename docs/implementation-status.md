## Technical SEO and performance verification (Prompt 17, 9 November 2026)

Implemented environment-gated SEO for the existing approved storefront without changing its design or catalogue content. A single policy (`src/lib/seo/site.ts`) requires `NODE_ENV=production`, `APP_ENV=production`, `SEARCH_INDEXING=approved` and a valid HTTPS `SITE_URL` before any indexing, canonical, Open Graph/sitemap URL or `metadataBase` is emitted. Until then public responses are `noindex, nofollow, noarchive`, `robots.txt` disallows the site and the sitemap is empty.

Added per-page metadata for products, collections, brands, articles, search, cart, checkout, order confirmation, care pages and previews; conditional canonicals; Open Graph/Twitter; Organization, WebSite/SearchAction, Product/AggregateOffer, Article and BreadcrumbList JSON-LD; icon convention; environment-aware robots and a canonical sitemap limited to eligible collections/brands/articles/deals with genuine article `lastmod` only. Filters, sort, search, page 2+, cart/checkout, order access, admin, API and previews are noindex. Added a slug-redirect migration and resolver; unknown routes keep real 404s. Product availability is emitted truthfully (`InStock`/`OutOfStock`); ratings appear only from approved public reviews. The deals loading boundary moved under `deals/[slug]` so unknown deals return a real 404.

Verified: `npm run check` (sources/lint/typecheck/build), `npm run test:seo` (3 policy unit tests + production route checks), `npm run test:production`. Measured production-build staging results in headless Chrome: desktop LCP ~1.07–2.13 s across runs, mobile ~0.68–0.82 s, CLS 0, interaction proxy ~88–120 ms desktop / 24 ms mobile, ~1,889 KB total transfer (~1,016 KB images, ~145 KB scripts, ~14 KB CSS). Reduced-motion hero stayed on slide 0. Full report: [seo-performance.md](seo-performance.md), raw data: [seo-performance-results.json](seo-performance-results.json).

Blocked, not fabricated: no approved production domain (`SITE_URL` absent), no `SEARCH_INDEXING=approved` launch authorization, zero published products/articles/deals in the connected Supabase project, slug-redirect migration not applied to hosted Supabase, production serving still 503 by launch gate, no purpose-made 1200×630 social image, social profile URLs unset, care-page copy still placeholder. Prompt 16 (courier) remains deferred and Prompt 18 was not started. No production deployment was performed.

Review-stage final checks: lint/type/build and production preview checks passed; 16 units, 14 Next/Chrome API-double checks, six applicable homepage tests passed (two intentional skips; one decode timeout passed on unchanged isolated retry). All 64 supplied files and 14 reference CSS blocks remain unchanged. Hosted review verification is still pending migration 011 and the two server settings. See [verification report](reviews-verification.json).

## Current stage: reviews/moderation (7 October 2026)

Implemented customer form, optional private email/images, validation/CSRF/signed sessions, SQL quotas/idempotency, simple protected moderation tabs/history/editing, true review media ownership, Cloudinary approval dispatch, approved-only product display/ratings and freshness invalidation. Exact clean installer SHA-256: `32e40f5f7e2cbec18a3ccd8d81de86bb76f0b2c7f108761f155cf193fbb0cc52`; canonical receipt: `0a3d7c1ad1e67b09f876c3c43ea8c335f23e698d32bbc38eee0a595321975e52`.

Passed locally: exact installer `psql -X -v ON_ERROR_STOP=1 -f` against fresh 001–010, seeded existing-row preservation, repeat-install refusal, full prior database/media/editor/storefront/CMS regressions, review permissions/moderation/media/averages/history/quota SQL assertions and input units. Actual Next/Chrome with explicitly mocked providers passed customer submission, moderation, private upload/readback/preview and desktop/mobile flows; these are not live Supabase/Cloudinary tests.

Pending externally: migration 011 installation/receipt; `SUPABASE_SECRET_KEY` and `REVIEW_SESSION_SECRET` local configuration. Read-only hosted probe returned 404; no hosted fixtures or real records were mutated. Actual hosted browser/RLS/Storage/Cloudinary/delivery/freshness and safe synthetic cleanup still need those prerequisites. Hosting ingress choice remains required before non-development guest submissions.

Older stage reports below are historical. Current review setup: [reviews-setup.md](reviews-setup.md).

# Implementation status

## Content CMS live verification completed — 2026-10-07

Migration010 application confirmed by the user; public content RPC200. **44 actual checks passed**, separately from prior mocked UI tests:25 real Next/Chrome/provider workflow checks,11 Auth/RLS/private Storage checks and8 read-only cleanup checks. Browser article create/edit/publish/hide/delete, Draft/Published/Hidden Save preservation, stale-edit rejection with entered-text retention, invalid published-edit rollback, raw stored HTML sanitation, true article/homepage private upload/approval/publishing, actual Cloudinary decode/metadata, homepage order/themes, public freshness and draft isolation passed.

Both final test articles are hidden/soft-deleted, all3 final images cleaned, associations removed and deleted URLs404. Previous homepage selections restored exactly; all833 baseline rows across17 tables retain original hashes. Prior timed-out/test-image attempts were also cleaned. Audit/history is retained intentionally. No real catalog/content record or supplied asset was changed; no installer rerun. Source integrity64 files/14 CSS blocks and targeted lint passed. Actual desktop/mobile screenshots inspected. Current stage has no remaining live setup blocker; earlier pending010 entries below are historical and superseded. Evidence and limits: [content-live-verification.md](content-live-verification.md).

## Actual Cloudinary development verification — completed

14 live checks passed through the existing service: private reviewed bytes, signed upload, provider/original-byte verification, database metadata/association, duplicate completion, transformed delivery and reference-safe cleanup. Fixed the verification runner's empty-201 parsing and service cleanup's cached-download confirmation; cleanup now checks Storage metadata, private upload cache lifetime is zero, and deleting/deleted private reads are blocked. Seven mock/pure regression tests, TypeScript and targeted lint passed separately. Source checks remain unchanged (64 supplied files, 14 CSS blocks).

Final read-only audit verified all three attempted media assets absent from Cloudinary/private Storage and all associations removed. Four synthetic parent records remain archived with workflow/tombstone/audit history. No real catalog import, migration rerun, UI or storefront change. Evidence: cloudinary-provider-verification.json, cloudinary-provider-recovery.json and cloudinary-final-cleanup.json. Earlier pending Cloudinary configuration statements below are historical; no blocker remains for this requested synthetic provider cycle.

## Media integration service — 2026-10-05

Implemented private review uploads, explicit approval, server-side signed Cloudinary publishing, authoritative metadata plus original-byte validation, stable UUID/environment identities, atomic association/replacement, primary selection/order, idempotent retries/completion, bounded recovery listing and reference-safe cleanup. Added migration 007 and an incremental SQL Editor package; preserved six-migration bootstrap. Shared resolver retains local preview behavior and adds responsive Cloudinary delivery. No admin UI, routes, real SKU import or storefront change. See [setup and limits](media-service.md).

Verification: additive migration applied in a disposable PostgreSQL database; existing 54 assertions and media lifecycle assertions passed. Six Node tests passed with explicitly mocked Cloudinary responses (including tamper rejection, metadata limits and responsive/local resolver behavior). TypeScript and targeted lint passed. Source check confirms 64 files/14 reference CSS blocks unchanged. Actual Cloudinary test is **pending configuration and hosted migration 007**; no Cloudinary account operations were performed. Environment variable names and account instructions are in media-service.md; no secrets requested in chat.

## Actual authenticated Supabase verification — completed 2026-10-05

All 45 hosted checks passed using the configured development project and confirmed admin/non-admin accounts. Verified actual login/token identities, database roles, known-row draft/order isolation, unauthorized write denial, private-schema non-exposure, and known-object Storage read/list/upload/sign denial with positive admin byte comparison. Actual server-only TypeScript access wrappers were executed against Supabase under Node's react-server condition, without adding a Next.js route or changing the storefront. All exact synthetic rows/objects were removed and absence verified; append-only audit/Auth logs remain intentionally. See [results and limits](supabase-authenticated-verification.md).

Source preservation passed again (64 files, 14 CSS blocks). No real catalog import or installer rerun. Future login UI/session pipeline, admin uploads and commerce/import workflows are outside this verification; the direct wrapper test does not claim browser/Next.js request-cycle coverage. This supersedes earlier pending authenticated-access entries below.

## Hosted anonymous access verified — 2026-10-05

User confirmed successful SQL Editor application with six receipts, products RLS=true and catalog-private public=false. Live read-only checks now pass: products HTTP 200 (PGRST205 resolved), Auth health 200, invalid Auth token rejected 403, anonymous is_admin=false, admin-search/orders/import_records/audit_logs denied 401, private Storage listing empty. See supabase-live-access-checks.json. No remote writes, installer reruns or storefront edits occurred. Admin and ordinary-user credentials are absent, so actual signed-in role tests and known-object Storage isolation remain pending. First-admin guide and guarded membership SQL prepared in first-admin-setup.md and sql-editor/04_provision_first_admin.sql.

## SQL Editor application package — 2026-10-05

Prepared `supabase/sql-editor/00_preflight.sql`, atomic `01_install_all_six.sql`, metadata/role `02_verify_installation.sql`, and `03_reload_schema_cache.sql`, with hashes and a repeatable generator. Migration order confirmed. Migration 003 now scopes public-schema policy/audit/index/grant operations to owned objects instead of unrelated tables/functions. Collision, extension-location, existing bucket and Storage-policy checks abort without overwriting data. See [exact application steps and flagged statements](sql-editor-installation.md).

Verification: generated installer plus postflight applied to a new disposable PostgreSQL 16.11 cluster; repeat installation rejected safely; 54 SQL assertions passed, including local 121-row draft import and repeat safety. Auth/Storage were SQL test doubles. Hosted installation and real Auth/PostgREST/Storage tests remain pending user application. No connected-project mutations or storefront changes performed.

Latest read-only Supabase check: user-provided `.env` is Git-ignored; Auth health returned 200, REST root 401, and products endpoint 404/PGRST205. Provider reachability now passes; actual schema availability, login/admin authorization, RLS, Storage and imports remain unverified. No remote mutation occurred. See supabase-integration-verification.md.

## Supabase service verification attempt — 2026-10-05, pending setup

Docker Desktop was started but its engine health check timed out. The CLI is absent; npm registry lookup failed with EACCES. No separate development credentials/configuration are present. Consequently actual Supabase migrations, Auth login/token validation, PostgREST role tests, private Storage and HTTP draft import remain **pending**, not passed. Earlier native PostgreSQL assertions remain valid only for that SQL test environment. No database was reset or connected remotely. Source verification was rerun successfully: 64 supplied files and 14 reference CSS blocks unchanged.

Exact fresh-stack commands, local-only variable names, service test requests and expected outcomes are in [Supabase integration verification](supabase-integration-verification.md). The old reset recommendation was removed. No application or migration changes were needed or made in this attempt.

## Database stage — completed locally 2026-10-05

Six versioned migrations now implement catalog, typed taxonomy/evidence, publication gates, media metadata, inventory/reservations, orders, deals, sales/refunds, shipments, reviews, The Edit, homepage selections and audit logs. Server-only access verifies Supabase Auth and admin membership on each privileged operation; generated table/enum types come from the applied database. See [setup and limitations](database-setup.md) and [verification record](database-verification.json).

Contract v1.1.0 retains all original SKU mappings and introduces category-specific essential requirements, separate optional enrichment and review notes. All 121 SKUs are importable/searchable as drafts without photos. All eight concern groups remain available; concern research is **partially complete**, and absent concerns never block publication. Source quantities and prices are preserved privately; live stock begins unreconciled, and repeat imports cannot reset stock or admin edits.

Verification: six migrations applied in a fresh disposable PostgreSQL 16.11 cluster; 121 accepted, zero quarantined; repeat import unchanged. 54 SQL assertions passed covering anonymous/non-admin/admin permissions, self-promotion denial, private media/orders/source data, eligible publication without concerns, SKU immutability, stock idempotency, shared deal components, insufficient-stock rollback, immutable placed lines, refund limits and Karachi reporting boundaries. The cluster was stopped. Source check passed for 64 original files and 14 CSS blocks. Final lint, TypeScript (`tsc --noEmit -p tsconfig.build.json`) and all 13 Python contract tests passed. No frontend files were changed; no build or browser visual comparison was rerun in this database stage.

Remaining external verification: actual Supabase Auth/PostgREST/Storage services were not run (Docker daemon unavailable; CLI/test credentials unset). SQL Auth/Storage schemas were explicit test doubles. No production migration/import, provider operation, real order/payment/shipment, admin UI/upload or storefront integration occurred. This supersedes older statements below that schema work is pending; historical stage reports remain as records of their completion dates.

## Catalog import contract — completed 2026-10-05

Completed the offline import contract and complete per-SKU mapping for the latest supplied workbook. See [contract and repeat-run commands](catalog-import-contract.md), [verified flags and evidence](catalog-review-findings.md), [all SKU mappings](../data/catalog-dry-run/sku-mapping.json) and [dry-run summary](../data/catalog-dry-run/summary.json).

Implemented behaviour: five-sheet source capture preserves cell values/types/styles/formulas/XML and archive hashes; all 29 named source fields survive per product. Exact SKU identity produces stable separate product/variant UUIDs. All 121 source records remain private draft proposals with their original 270 stock units pending reconciliation. There are 50 normalized brand candidates, 18 factory-pack candidates, distinct category/menu/type mappings, controlled typed facets/options, all eight concern groups and a 21-entry evidence registry. No family is merged, no set stock is expanded into components, no deal is created, and no production filter/concern is activated.

New, changed, unchanged, missing-from-later-source and conflicting records have explicit dry-run actions. Re-import retains IDs, presents source changes without overwriting admin data, and marks changed evidence stale. Duplicate exact SKUs and normalization collisions quarantine only affected records. The later Supabase/admin model, individual publication requirements, source/admin ownership and factory-set versus component-consuming-deal rules are documented; they are not live services or applied migrations.

Verification actually performed:

- Workbook ZIP CRC and source hash verified; project workbook matches the original top-level Web-Assets ZIP copy. Five sheets inspected. 121 unique exact SKUs found; no exact duplicates or normalization collisions. Row 125 heading and 417 blank/formula-template rows excluded with provenance preserved.
- Dry-run generation succeeded with 121 stage-draft operations, zero publication, network or database operations. A repeat using the prior mapping reports 121 unchanged operations. Tests prove byte-identical artifacts for identical inputs and no workbook mutation.
- All 13 Python contract tests passed: complete row/stock reconciliation, stable IDs/reordering, exact duplicate isolation, incoming and previous-key normalization collisions, source-price change/stale review, zero versus missing stock, formula/invalid numbers, new/missing SKUs, absent-source retention, typed facet/concern scope, no automatic families/scent profiles, deterministic output and rejection of public output directories.
- `npm run sources:check` passed: all 64 supplied files remain byte-identical and all 14 reference CSS blocks match. Dependencies, lockfile, asset contract, sample adapter, homepage and `/reference` were not changed. No app build/browser comparison was rerun because this stage changes offline tooling/data/documentation only.
- Official manufacturer research was performed for the relevant ambiguous products and selected concern/variant proposals. The registry distinguishes fetched official pages, official search excerpts, the exact Boots brand-range RUSHOWER listing, and unresolved official searches. No failed retrieval or marketplace listing is represented as manufacturer confirmation.

Remaining blockers are to individual future publication, not this preparation gate: exact physical package identities, shades/generations and sizes; SB-001 price; OPI/AROM and other pack contents; CTP/VS application scope; brand/cutlery details; approved media/copy, expiry/condition and inventory reconciliation. All are listed per SKU. Admin UI, database schema/RLS, authenticated apply services, migrations and production integration remain later stages. No real stock mutation, order, payment, shipment or deployment occurred. Stop here.

## Interior page stage (2026-10-05)

Completed category/product/brand/search/editorial/cart/guest-checkout/customer-care layouts with typed approved samples and a shared preview cart. Category filters, sorting, query pagination, product options, bag quantities/removal and validated guest-checkout review work locally. Fragrances has separate home/personal branches. Unknown identities return HTTP 404. No backend or production catalog work has started.

Design extensions are provisional: existing cream/bronze colours and Georgia/Arial typography, flat product imagery, desktop filter column/mobile drawer, two-column product/checkout layouts that stack on mobile, and article-specific editorial colours. These pages have no separately approved wireframes. The verified homepage, including its requested mobile hero/menu and footer endpoint changes, is preserved.

Verification actually performed:

- `npm run check` passed: all 64 supplied source files byte-identical, 14 reference CSS blocks intact, ESLint, TypeScript and optimized production build. Dependency pins and lockfile unchanged.
- Four new Playwright tests passed in Edge desktop 1440x1000 and mobile 390x844 emulation: 17 routes, metadata, breadcrumbs, responsive overflow, unknown-product 404, query filters/pagination/empty states, supported option, cart persistence/removal, validation/focus and local checkout review without a POST. Both existing desktop/mobile homepage interaction tests also passed with the new article/checkout navigation.
- Representative listing, product, editorial, brand and care screenshots were captured; desktop listing and desktop/mobile checkout layouts were visually inspected. Homepage before/after captures retain identical dimensions at 1440px and 390px. Small image-region pixel differences remain (mean channel difference 0.00549 and 0.02591 on a 0-255 scale); this is not a pixel-identical claim. See [comparison evidence](interior-visual-checks.json).
- `npm run test:production` passed, including authenticated interior pages, protected checkout, no-store/noindex, correct missing-product 404, fail-closed unconfigured preview, asset protection, production sample guard and `/reference` exclusion/404.
- Local development preview restored on port 3000; `/`, `/skincare` and `/reference` each returned 200. The original reference remains development-only and unchanged.

Remaining limits: Edge/Chromium emulation only; no Safari, Firefox or physical-device verification. Loading/retry boundaries are implemented but the error boundary was not fault-injected. Approved product details/usage, genuine secondary images/variants, reviews, policies, shipping/payment configuration and production catalog validation remain external content/business dependencies. No real stock, orders, database imports, migrations, admin integration or deployment was introduced. No implementation blocker remains for this sample-layout stage; stop before production integration.

## Mobile hero and menu update

Final verification: responsive Playwright regression passed at 320/390/650/800px, including category open/back, Escape/focus return, all four hero slides, CTA/control clearance and overflow checks. Desktop reference comparison passed; 24 of 26 paired screenshots are pixel-identical and two have only minor image raster differences below the existing tolerance. ESLint and TypeScript passed after the final tap-versus-hover fix. All 64 supplied source files remain unchanged. No production build/deployment was run for this update; no outstanding implementation blocker remains.

User-authorized mobile changes supersede exact reference matching for the mobile header and hero. The original source and `/reference` remain unchanged. `mobile.css` overrides only the storefront: below 651px, the hero uses the full supplied image plus a compact live heading/CTA area instead of the fixed 680px gap; all four slides retain their order and controls. At 1050px or below, a three-line toggle opens navigation and category panels, with close, outside click, link selection and Escape handling. Desktop styling remains unchanged.

Verified in local Edge at 320, 390, 650 and 800px: hamburger open/category/back/close; all four mobile hero CTAs clear their controls; no horizontal overflow. The 390px render was visually inspected. Desktop 1440px was also checked. Earlier mobile reference screenshot equality is now historical, not a current acceptance criterion. Physical devices and Safari remain untested. No provider decision or credential blocks this change.

## Homepage footer endpoint update

At the user's request, the Design handoff notes section is now excluded from the generated homepage fixture. The homepage ends at the existing footer. The supplied HTML and development-only `/reference` retain the original notes unchanged. No backend or provider work is involved. Earlier full-page screenshot evidence predates this intentional difference; future comparisons capture `.site` through the footer.

Verified in local Edge at 1440×1000 and 390×844: homepage notes absent, document bottom equals footer bottom within two pixels, and reference notes still present. Source checks confirm all 64 supplied files and the 14 reference CSS blocks remain unchanged. No blockers for this edit; a new production build was not needed or run for this fixture-only removal.

## Full approved homepage — completed 2026-10-04

The entire approved page now renders on `/` in React; the Foundation preview notice is gone. Retained existing foundation work: pinned dependencies/lockfile, supplied files, reference CSS/fonts, asset contract, site configuration, preview protection, media boundary and development-only `/reference`. No application reinitialization or backend work was performed.

Completed in this task: all sections and visible reference notes; original header/footer and inline SVGs; four heroes in order; category coverflow; compact three-theme Edit and article dialogs; sample products and crop galleries; concern/brand rails; hover/focus/keyboard/swipe controls; category-only search reveal; policy/social preview dialogs; validated local sample bag, quantities, removal and non-submitting checkout simulation.

Verification actually performed:

- `npm run check` passed: 64 source files byte-identical, 14 reference CSS blocks verified, ESLint without warnings, route type generation/TypeScript, optimized Next.js 16.3.8 build using Node 24.21.0. Dependency pins and lockfile unchanged.
- Browser suite: seven of eight expanded desktop/mobile checks passed together; the remaining mobile motion check passed on a targeted rerun after resetting its starting category slide following autoplay. Earlier six core comparison/interaction/media checks passed together. No application failure remained.
- 47 paired screenshots compared: 44 pixel-identical; three tiny image-region raster differences with maximum mean channel error 0.008098 on the 0–255 scale. Matching section geometry, fonts and backgrounds; no final hydration or browser-console errors. Side-by-side desktop/mobile visual inspection performed. See [visual verification](visual-verification.md) and [numeric comparison evidence](homepage-visual-checks.json).
- `npm run test:production` passed: reference absent from build/routes and authenticated requests return 404; missing preview credentials fail closed; assets require authentication; noindex and production sample guard remain enforced.
- Approved reference route/source, assets, spreadsheet, import inputs and original backups remain intact. No real records, credentials, customer data, admin, provider connection, migrations, payments, shipments or production deployment were introduced.

Remaining limitations: Edge/Chromium and emulated mobile only; Safari, Firefox and physical devices are untested. The approved CSS hides category navigation at 1050px or below and retains the large mobile hero cream area; both are intentionally preserved. Three screenshots have tiny pixel-level image differences, so this is not a universal pixel-perfect claim. No blocker remains for the requested sample homepage. Validated catalog content, real secondary photos, dedicated Bath & Body art, social URLs, policies and provider/business decisions remain launch dependencies. Stop before backend/catalog/admin integration.

## Follow-up foundation audit (2026-10-04)

Reviewed the repeated foundation prompt against the existing implementation. No missing implementation requirements were found. No application, dependency, style, reference, asset, catalog or import-source files were changed in this audit. Only documentation was updated to distinguish existing work from this review.

Already implemented: App Router/TypeScript scaffold and exact version pins/lockfile; scoped reference CSS, tokens, fonts, shared shell and inline SVGs; typed sample adapter and common local-preview/Cloudinary media interface; storefront/admin/server/catalog/config boundaries; environment example, secret ignores, secure preview access and noindex controls; Pakistan site settings with an unset production domain; lint/type/build scripts, Playwright comparison tooling and development-only reference route.

Fresh checks performed during this review:

- `npm run sources:check`: all 64 supplied files unchanged and all 14 scoped CSS blocks match the source extraction.
- `npm run lint`: passed with no warnings.
- Direct `tsc --noEmit -p tsconfig.build.json`: passed, using the existing generated route types without interrupting the running reference route.
- Both `http://localhost:3000/` and `/reference` returned 200. The homepage still identifies itself as Foundation preview.
- The live reference response equals the original approved HTML exactly after its 55 embedded image occurrences are replaced by verified local paths. Its response remains non-indexable.
- Exact dependency pins match the preserved lockfile. The existing production route manifest excludes `/reference`.

The successful build, running production-access checks and four Edge desktop/mobile browser checks below were performed in the preceding completion run, not rerun in this documentation-only review. Their implementation is unchanged. Browser limitations remain as recorded in visual-verification.md. The Foundation preview is not the completed homepage, and no real catalog, Supabase, Cloudinary connection or admin functionality has been integrated.

## Prompt 2: completed application foundation

Completed the minimal Next.js App Router/TypeScript scaffold without changing supplied files. The completion gate passes. Stop here; do not proceed to the full visual stage automatically.

- Exact pinned dependencies, lockfile, runtime version files and documented scripts. See [versions and official sources](versions-and-scripts.md).
- Scoped extraction of all 14 reference CSS blocks, design tokens and original system font stacks. No UI library or CSS framework.
- Shared reference-derived header/footer/shell and first approved hero frame. Navigation/shopping remain explicitly unavailable; this is not the completed homepage.
- Typed, server-only sample adapter retains all four heroes in order and all three article themes. No real catalog, prices or orders integrated.
- Public media interface supports local preview assets and published Cloudinary metadata without a service connection.
- Server-only configuration and preview access, names-only .env.example, optional domain, PKR/en-PK/Asia-Karachi/contact constants.
- Fail-closed authentication for staging/production-mode previews, including assets. All pages are non-indexable. APP_ENV=production blocks sample publication.
- Development-only /reference resolves embedded image bytes to local contract paths. Production configuration removes its generated route before compilation.
- Playwright desktop/mobile comparison tooling and production security/exclusion checks.

No Supabase/Cloudinary credentials, DB records, admin functionality, migrations, payments, shipments or deployment were introduced.

### Prompt 2 verification performed (2026-10-04)

| Check | Actual result |
| --- | --- |
| `npm run check` | Passed: source preservation, scoped CSS drift check, lint with zero warnings, strict TypeScript and production build |
| Source preservation | All 64 original handoff/import files remain byte-identical, including design, workbook, public assets and assets.ts |
| Dependencies | Direct pins agree with package-lock.json; Next 16.3.8, React 19.3.0, Node 24.21.0, npm 11.19.0; no invalid top-level dependencies |
| Production route exclusion | Build manifest has no reference route; authenticated GET /reference returns 404 |
| Running production checks | Passed: unset preview credentials return 503; missing/invalid authentication returns 401; protected asset requests denied; valid authentication returns 200 with no-store/noindex |
| Production sample guard | APP_ENV=production returns 503 even with valid preview credentials |
| Robots and secrets | Robots disallows crawling; HTML/headers are non-indexable; generated test password absent from HTML; local secret/tool/import paths ignored by Git |
| Playwright | Four checks passed in Edge 154.0.4258.53 at desktop 1440×1000 and mobile 390×844 emulation; no page JavaScript errors |
| Visual foundation comparison | Header/hero/footer dimensions, fonts and background colours matched; screenshots inspected; all reference images loaded locally |
| Dev-to-typecheck lifecycle | Passed after browser suite: fresh production types exclude stale temporary /reference development types; strict errors are not suppressed |
| Dependency audit | Production dependencies: zero vulnerabilities. Development lint chain: four high entries from one unpatched braces advisory; documented follow-up |

Browser limits and screenshot locations are in [visual verification](visual-verification.md). Only foundation components have been compared, not the full homepage. Firefox, WebKit/Safari, physical devices and hosted previews remain untested. Shared staging needs secure preview credentials plus HTTPS. No external service setup blocks this local stage.

Next dev generated AGENTS.md/CLAUDE.md; retained. The installed Next TypeScript and route-handler guides were consulted for the reference route/type lifecycle. next-env.d.ts remains framework-managed and Git-ignored.

## Prompt 1: completed source preparation

This stage was completed before Prompt 2. Historical “Prompt 2” directions in the handoff do not authorize work; the user's fresh sequence does.

Implemented preparation:

- Extracted the handoff at the repository root, retaining its original files.
- Selected the supplied top-level final HTML and latest workbook for the required reference/import paths after verifying equality with the nested copies.
- Preserved the original Desktop archive and local backups. Kept all 20 initial product image files outside `public/` and Git-ignored; no full catalog media was copied into `public/assets`.
- Created asset and catalog inventories, a machine-readable audit and a repeatable audit/preparation script.
- Recorded architecture, coverage, staged plan, provisional assets and launch decisions.

## Verification performed

| Check | Actual result |
| --- | --- |
| Outer and nested ZIP CRC validation | Passed for every entry |
| Workbook ZIP CRC and read-only parsing | Passed; five worksheets |
| Top-level vs nested HTML | Identical SHA-256: `ba602df03432268d81568d817b9296d3c2bc0c8c52506d2ca98995a6e0d955dc` |
| Top-level vs nested spreadsheet | Identical SHA-256: `6f115be852d12412fd2bfa8697beb298e4700aa9e34c9033e57b001583679101` |
| Catalog products | 121 rows with unique SKUs; no duplicate SKUs |
| Non-product heading | `Product Listings!B125`, HOME APPLIANCES, excluded |
| Initial product images | 20 PNGs decoded; 17 exact SKU filenames; three unresolved name-based files |
| Exact initial image coverage | 17 of 121 SKUs; 104 have no exact filename match in this import folder |
| Handoff contract/manifest | 38 unique paths each; identical sets; all resolve; all SHA-256 and dimensions match |
| Handoff image decoding | All 38 passed Pillow verification and full pixel decoding |
| HTML embedded images | All 55 base64 image occurrences decoded |
| Extracted images vs source | All 58 extracted image files match archive hashes and decode |
| Original source preservation | Original archive re-read unchanged; local backups byte-identical |
| Source conflicts | None; no path renames or substitutions required |

Workbook row count is not product count: the principal sheet has formatting through row 540. Products were counted from populated SKU/name records, allowing the two existing spaced SKUs. `DANM - 001` (row 109) and `MAC - 001` (row 122) are preserved, not silently normalized. Other worksheets are Instructions, Listing Copy, Catalog Review and Search Taxonomy; they are not additional product tables.

Detailed evidence: [source audit](source-audit.json), [asset inventory](asset-inventory.csv), [catalog inventory](catalog-inventory.csv). The audit reads the workbook without saving or recalculating it. Prices, stock, copy, claims and publication readiness have not yet been validated. Exact filenames are not a visual identity audit.

At Prompt 1 completion, no build, application tests or browser fidelity comparison was performed because no app existed then. Image integrity was not a claim of visual fidelity. No migrations were prepared or run; no live records were imported. Prompt 2 results are recorded separately above.

## Proposed fresh sequence

These are planning stages only. Each requires the user's next prompt; do not execute subsequent stages automatically.

1. **Source preparation — complete.** Required paths, source equality, integrity, inventories and this plan.
2. **Application foundation — complete.** Next.js App Router/TypeScript, pinned versions, reference styles, boundaries, preview controls and comparison tooling. Verification recorded above.
3. **Visual storefront — complete.** Full approved sample page and React interactions implemented and compared at desktop/mobile sizes; checks and limitations are recorded above.
4. **Data model and permissions — implemented and verified in development (see database verification reports).** Original stage scope: prepare Supabase schema and migrations for stable UUIDs, unique SKUs, variants, catalog, media, publication, users and orders. Add PostgreSQL search and RLS tests, including draft/private access denial. Apply only in an authorized environment.
5. **Product admin and media workflow — implemented; one synthetic timed-cleanup follow-up remains.** See the current product administration report below. Original stage scope: implement authenticated catalog editing, product/SKU selection, private review uploads, approved Cloudinary publishing and record associations. Verify role and media access controls.
6. **Catalog integration — pending.** Validate records, prices, stock, mappings and claims; reconcile spaced SKUs and unmatched media; publish individually. Replace visual samples with validated records and inventory-backed search/filter options. Keep previews isolated.
7. **Commerce and launch readiness — pending.** Implement approved order/payment/shipping rules and providers, test without real charges/shipments, resolve policy/content/hosting decisions and perform production readiness review. Production deployment remains explicitly gated by user instruction.

## Remaining blockers

No blockers remain for the completed source-preparation and application-foundation gates. Later work depends on the next stage prompt, SKU/media review, validated catalog content and the provider/business decisions in [decisions needed](decisions-needed.md). The development-only lint advisory remains an upstream follow-up. Missing provider credentials do not block independent implementation, local checks or migration preparation.

To repeat this source audit, run `scripts/audit_sources.py` with the original ZIP path using Python with Pillow and openpyxl. The script refuses source/hash conflicts and preserves byte-identical existing content; it does not initialize an app or touch a database. Its runtime libraries are bundled tooling, not application dependencies.

## Product administration stage (2026-10-06)

Implemented `/admin/login` and `/admin/products`: server-validated sessions, per-operation membership/RLS, CSRF and no-store protection; product creation/editing, compatible taxonomy, variants, typed evidence-backed filters/concerns, PKR prices, audited stock adjustments, archive/restore-to-draft, draft homepage selections and private-review media management. Storefront components/adapters and source design files remain unchanged. No new migration or dependency was needed; the lockfile is preserved.

Actual development evidence: `admin-live-verification.json` records 49 passed events (including upload/approval retries with a valid replacement fixture), and `admin-extended-verification.json` records 14 passed checks. These cover real browser login/logout, anonymous/non-admin rejection, a valid non-admin token rejected at API/media routes, cross-origin and missing-CSRF rejection, browser creation/editing, PKR persistence, stale-edit rejection, audited stock changes/retries, insufficient-stock rejection, typed evidence assignment, visibility and draft homepage selections. A valid synthetic PNG passed browser private upload/preview/approval, real Cloudinary publishing and safe removal/cleanup. Admin desktop/mobile screenshots were inspected and mobile document overflow checked.

`admin-import-audit.json` contains ten passed read-only checks across all 121 stable identities and exact original SKUs. All raw values, source quantities and target prices are preserved; all imported products/variants are drafts and individually searchable. Source stock totals 270 units; all imported live balances remain zero/unreconciled. Repeat import returned unchanged and preserved the inspected product/price/provenance/stock snapshot. Seventeen exact-match initial images are private and unapproved; the three unmatched files remain unassigned.

Separately, 10 local security/media regression tests passed (three pure security tests and seven media tests, including mock provider transport). Full ESLint, TypeScript, build and production preview/reference protection checks passed. Source verification passed: 64 supplied files byte-identical and 14 reference CSS blocks preserved. These checks are not a claim that compilation proves visual fidelity.

Pending cleanup: the first synthetic PNG decoded in Chrome but failed strict integrity/byte verification during publication. Its product is archived and it has zero media associations, but an unlinked Cloudinary asset and private original await the existing 24-hour guard until **2026-10-06 23:53:51 UTC**. See `admin-cleanup-verification.json`; run `scripts/reconcile-admin-test-media.mjs` with `--conditions=react-server` after eligibility. No guard was bypassed. The valid replacement image was safely deleted; synthetic product/evidence/movement/import/audit history is retained.

No real product was published, no imported stock was reconciled, and no storefront database connection or blog/review/deal/order administration was introduced. The existing stock RPC supports nonzero audited adjustments; zero-count reconciliation requires a later audited schema operation.


Final storefront regression: after restarting the local development server, the existing Chrome desktop/mobile-emulation homepage suite passed **6 tests**, with **2 intentional viewport-specific skips**. This includes desktop reference geometry/carousel-state comparison, sample interactions, mobile hero/menu layouts, and motion/swipe behavior. The initial attempt could not connect to the stopped local server; the completed rerun passed. The reference is restored for development and absent from the production build. All 64 supplied source files and the 14 reference CSS blocks still pass integrity checks.

The final read-only import audit now has ten passed checks, including anonymous PostgREST denial for the imported draft products, variants and source provenance, and all 121 individual SKU searches. Admin tests used Chrome with mobile emulation; no real-device Safari test was performed. Core requested live flows passed; multiple-file selection, adding a confirmed variant, and individual primary/order/replacement UI controls were implemented on the existing services but not each independently exercised in this browser run.


## Daily editor usability revision (current, 2026-10-06)

Implemented the simplified daily editor, optional shade/size table with automatic UUID/SKU relationships, stock-count input including zero, Save draft / Publish / Hide actions, plain conditional warnings and publication checklist, optional homepage toggle and clean image gallery. Import/history and explicit unmatched-image assignment are outside the daily editor. Existing research/source/claim records remain internally unchanged. The approved storefront was not edited.

The exact migration 008 SQL Editor package passed a fresh disposable PostgreSQL 16 run, alongside catalog/security/media regression SQL. Five daily-editor assertion groups passed: easy incomplete drafts plus audited zero and idempotency; two-option atomic saves; stale stock/incomplete publication rollback; option archive/history preservation; non-admin save denial. All 121 imported fixture SKUs were accounted for with repeat-import preservation. Native Auth/Storage were doubles, not actual services.

Actual Chrome plus connected development Supabase passed twelve checks in `admin-usability-live-verification.json`: login/access rejection, no-store, CSRF, all 121 SKU identities searchable, normal editor terminology, mobile document overflow and logout. Desktop/mobile screenshots were inspected. The action bar was then made static so it does not cover fields, and header navigation was reduced to ordinary link size. No real-device Safari verification was performed.

Pending: apply `supabase/sql-editor/06_install_daily_product_editor.sql` once to development, then rerun `scripts/verify-admin-usability.mjs --run-development`. Hosted Supabase still lacks the atomic daily-save RPC. Actual browser single-product/two-option saves, stock reconciliation, Publish rejection and option removal are therefore pending, not passed. No synthetic products were created during the pre-install run. The revised image-control UI has not yet been independently exercised against providers; the earlier real media verification remains historical service evidence.

Ten security/media unit tests passed separately (provider transport mocked where stated). Source integrity passed for all 64 original files and 14 CSS blocks. Dependencies/lockfile are unchanged. The earlier synthetic failed-image cleanup guard remains pending until its recorded eligibility. No next-stage storefront integration or real product publication was performed.


Final revision checks: ESLint, TypeScript and production build passed; `/reference` is absent from the production route manifest and restored in development. The existing homepage Chrome regression passed six tests with two intentional viewport-specific skips, including desktop reference geometry/carousel states, interactions and mobile hero/menu behavior. Final admin screenshots were inspected after the action-bar correction. The final actual admin run passed twelve checks, including the separate import-history page and omission of import controls from the daily product page. Live save and two-option flows remain pending SQL Editor file 06; these results do not mark the revision complete.


## Corrected ordinary-save visibility (2026-10-06, supersedes earlier draft-on-save behavior)

Ordinary **Save** now preserves the existing product visibility and each existing active variant status. Hidden products remain hidden. New options start as drafts; an ordinary save does not publish them. **Save draft** is an explicit transition (with confirmation when the product is published or hidden); **Publish** explicitly publishes eligible active options; **Hide** explicitly hides the product. Removed options remain archived and are not restored by Publish.

A published edit that would lose required information is rejected with an actionable checklist: fix the fields or explicitly choose Save draft. The transaction leaves the original published product, prices, variant statuses, stock, counts and revision unchanged. The UI retains entered values after rejection. There is no implicit unpublish/unhide. Plain Save is also the default for Enter-key form submission.

The corrected migration 008 and regenerated SQL Editor file 06 use a text `p_intent` parameter, defaulting to `save`, rather than a boolean that drafts everything. The report identifies this contract as daily editor version 2. The file still preserves existing business records during installation. Apply only the current corrected file; the previous copy must not be used.

Local verification: the exact SQL Editor bundle passed in a fresh disposable PostgreSQL 16 database. Ten daily-editor groups cover incomplete drafts, zero/retry/stock safeguards, two options, rollback/removal, published and hidden preservation, mixed option statuses, rejected invalid edits and explicit transitions. Auth and Storage there are doubles. ESLint, TypeScript and production build passed. The original storefront/source assets remain unchanged.

Live verification remains pending application of the corrected file. The Chrome runner now includes ordinary and invalid published edits, hidden edits and explicit transitions for both single-product and two-option fixtures. It uses synthetic brands/categories and a neutral synthetic media fixture, leaving the 121 catalog records and their taxonomy/source values intact. It archives synthetic history and uses guarded media cleanup. These prepared live tests have not yet passed; no production integration or real catalog publication is claimed.


## Installer syntax repair and exact-file verification (2026-10-06)

The reported Supabase 42601 near `create function public.save_daily_product` was inspected at the preceding function boundary. The local source already had a closing delimiter, so the exact user-submitted failure was not reproduced from those bytes. All installer/function endings are now explicit `END;` followed by distinct named dollar delimiters, including `$publication_report$;`. The source migration and generator agree, and the complete file is regenerated with its migration receipt. No storefront or catalog edits were made.

Verification now uses `scripts/test_database.py --daily-editor-installer`: a NEW disposable PostgreSQL 16 cluster, migrations 001–007 applied directly (no earlier installers), SQL Editor receipt infrastructure, 121 seeded drafts, then the EXACT file `supabase/sql-editor/06_install_daily_product_editor.sql` via `psql -X -v ON_ERROR_STOP=1 -f`. The migration 008 source is not substituted for file 06. SHA-256 for the tested file is `151cc79788b0c00bbc308ed7ee22e7e8a8c084a9caa8628ccf125e5028b9d16e`.

The entire installer passed; both final booleans were true. Every pre-existing public business table and private admin-membership snapshot stayed identical. A deliberately missing preceding terminator rolled back new objects and replaced functions without altering business data. A repeated installer was refused safely. Read-only preflight showed only the media service present before installation and the expected daily objects present afterward. Catalog/security/media SQL and ten daily-editor regression groups passed, including ordinary published/hidden status preservation. Auth/Storage in the local cluster are doubles; this is not hosted Supabase SQL verification. Evidence: `daily-editor-exact-installer-verification.json` and its recorded local output directory.

Connected development read-only checks passed actual admin Auth/membership and products access. `inventory_counts` returned PGRST205, save RPC discovery returned PGRST202, and the accessible publication report had no daily-editor version. This suggests the old API schema remains, but does NOT prove private objects or receipts are absent (schema cache can also lag). No SQL connection is configured. Run `supabase/sql-editor/06_preflight_daily_product_editor.sql` in a new SQL Editor query and share its nine booleans BEFORE another install attempt. Only media_service_present should be true; every daily-editor boolean should be false. If any daily-editor object/receipt is present, stop without dropping data or rerunning earlier installers. The corrected installer has its own guard rejecting known installed/partial state.

Pending: definitive connected-project SQL preflight, then conditional application of the corrected complete file 06, followed by the already authorized live single/two-option and published/hidden save tests. No production import, reset or earlier-installer rerun occurred in the connected project.


## Fresh complete installer and confirmed preflight (current, 2026-10-06)

The user's development SQL Editor preflight confirms the media service exists and ALL eight daily-editor object/receipt checks are false. The previous pending private-schema check is resolved: migration 008 did not remain installed. Recorded in `daily-editor-preflight-confirmation.json`. No connected data was changed or earlier installer rerun.

Regenerated both complete installer artifacts from one migration source using overwrite, never append. Use the distinct `supabase/sql-editor/06_install_daily_product_editor_clean.sql` in a NEW empty SQL Editor query to avoid mixing prior text. It and the canonical file contain identical bytes. Structural validation records four unique function declarations, five ordered matched dollar-quote pairs, one receipt insert, one final SELECT, one BEGIN/COMMIT and one cache reload. Generation refuses duplicates/mismatches; see `daily-editor-installer-structure.json`.

Executed that EXACT clean file via `psql -f` in a NEW disposable PostgreSQL 16 database with only migrations 001–007 applied directly, no earlier installers, and 121 seeded drafts. Installation, final booleans, all pre-existing business-table snapshots, rollback simulation, repeated-install refusal, preflight states and catalog/security/media/ten daily-editor regression groups passed. The cluster was stopped. SHA-256: `ff2d5f584b5572a3c08b82e20251e842f38ca68715a72c335297063ba566ee11`. Evidence: `daily-editor-exact-installer-verification.json`, local run `database-test-df18db4e913f`. Local Auth/Storage are doubles; this is not a claim of hosted Supabase installation or live write verification.

Passed also: generator ESLint and 64-source-file / 14-reference-CSS integrity. Ordinary Save still preserves product/variant visibility, including hidden state; explicit Draft/Publish/Hide and invalid-edit rollback behavior are retained. The storefront and connected catalog remain intact. Pending only: apply the complete clean installer once to development (both final checks true), then run the authorized live single-product/two-option and published/hidden preservation tests. Do not append patches or rerun prior installers.

## Daily editor: completed live development verification (2026-10-06)

This supersedes the earlier pending installation/browser-test entries. The user applied the clean installer and reported both final SQL checks true. No installer was rerun. The actual connected development project exposed daily editor version 2 and accepted the authorized browser operations.

Actual Chrome + Next.js server + Supabase Auth/PostgREST/Storage + Cloudinary verification passed 32 checks. Single-product and two-option creation/editing, PKR minor-unit prices, stock counts, explicit publication, ordinary published/hidden status preservation, rejected invalid published edits with unchanged revision/variant prices/status, explicit Draft transitions and option removal preserving SKU/history all passed. Anonymous and non-admin rejection, CSRF rejection, uncached private responses, admin login/logout and all 121 original SKU searches passed. Synthetic neutral images followed private upload, explicit approval and Cloudinary association; both were detached and safely cleaned. No real product was published or imported.

A supplemental actual browser test passed three checks: a hidden synthetic product counted from five to zero stayed hidden, exactly one audited 5-to-0 reconciliation was created, and saving unchanged zero created no additional count. Evidence: admin-usability-live-verification.json and admin-zero-stock-live-verification.json. These are actual provider/browser results, separate from earlier disposable PostgreSQL tests with Auth/Storage doubles.

Initial attempts exposed accessible-label instability for selects and a populated description textarea. Explicit admin field labels were added; controls now wait for initial reference/catalog loading. Failed synthetic attempts were hidden and their temporary taxonomy archived. Their audit history remains. The successful run verified unchanged hashes for all 821 pre-existing rows across 18 catalog/source/stock/media tables, including existing fixtures, before its synthetic-only supplemental stock change. Original catalog records and image associations were preserved; both successful fixtures and their taxonomy are hidden/archived and their test images cleaned.

Verification also passed ESLint, TypeScript and original-source integrity (64 supplied files and 14 reference CSS blocks). Existing homepage Chrome regressions passed six tests with two intentional viewport-specific skips, covering desktop reference geometry/carousel states and mobile hero/menu/interactions. Mobile admin screenshots were inspected and no document overflow occurred. Storefront code/design, source assets and migration files were unchanged during this verification.

Limitations: browser checks used installed Chrome with mobile emulation, not physical-device Safari. This run did not repeat a production build, deploy, import the catalog or test real customer commerce. No requested live editor check remains pending. Future production setup and other business/provider decisions remain outside this completed stage.

## Public storefront integration (2026-10-07; hosted verification pending)

Implemented published-only homepage selections, category/brand/product pages, live taxonomy navigation, supported typed filters with URL selections and counts, deterministic pagination/sorting, full-text/trigram search, variant-aware prices/media/availability, public bag restoration and admin-edit freshness boundaries. The default is Supabase; explicit local sample preview remains isolated. The approved CSS/reference source, four ordered heroes, menu framing, compact The Edit slideshow and footer are preserved. The Edit content is a neutral placeholder in live mode because blog integration is outside this stage.

Passed: exact `supabase/sql-editor/07_install_public_storefront.sql` execution in a fresh disposable PostgreSQL 16.11 database with migrations 001–008. SHA-256: `352286668d0b1a4eb012faf57da27de8f4276fe1e93323de9b6ec0c289812c3c`. Local catalog/search/filter/visibility, same-variant matching, aliases, hidden freshness and anonymous/non-admin permission assertions passed, alongside existing catalog/security/media/daily-editor regressions. Auth and Storage were doubles, not hosted services. Evidence: `storefront-database-verification.json`.

Passed separately: 12 checks using actual Next.js/Chrome with mocked catalog RPCs and neutral intercepted images, covering public layout, URL filters, link pagination, option-specific price/image/stock, bag restoration, unsupported-search alternatives, database-outage handling, actual unknown-product 404 and mobile drawer focus/overflow. Evidence: `storefront-mock-ui-verification.json`. Desktop/mobile screenshots were captured; category/product mobile screenshots were inspected. These are NOT Supabase or Cloudinary provider checks.

ESLint, TypeScript production compilation, production build, ten security/media unit tests and source integrity passed. All 64 supplied source/import assets and 14 reference CSS blocks remain byte-identical; dependency versions/lockfile were preserved. Production route output excludes `/reference`; its original development route is restored. Final sample-mode browser visual regression results are recorded below after completion.

Pending actual integration gate: the configured development Supabase returned HTTP 404 for `storefront_navigation` on the latest reachable probe. No synthetic storefront fixtures or real catalog mutations occurred. Apply installer 07 once in a NEW empty development SQL Editor query; both final booleans must be true. If already installed, inspect schema exposure/cache and reload only the cache, rather than rerunning. No database connection URL exists in local configuration, so the current Auth/publishable credentials cannot apply schema SQL. See `storefront-setup.md`. The prepared actual development runner will verify synthetic published/draft visibility, combined filters/search, variant images/prices/availability, real Cloudinary delivery, browser flow, admin-edit freshness and preservation/cleanup once the RPC is available. Those provider checks are pending, not passed. No production publication, catalog import, payment, order, blog or review integration was performed.

Final browser regression (2026-10-07): eight checks passed with two intentional viewport-specific skips in installed Chrome, using an explicitly configured isolated sample-preview server. Desktop section geometry matched `/reference`, all four hero/three editorial/five category/gallery states were captured, and mobile hero/hamburger, bag/menu keyboard interactions, motion/swipe/brand scrolling and responsive media resolver checks passed. Earlier commerce layout regressions passed separately. Mobile is Chrome emulation, not physical Safari. No build alone is used as visual-fidelity evidence.

### RLS-hardened complete storefront installer (2026-10-07; supersedes earlier installer hash)

Added explicit RLS to `app_private.storefront_search` without client policies; retained client privilege revocations and owner SECURITY DEFINER RPC access. Regenerated the entire SQL Editor installer from migration 009, including updated source receipt hash and a third final check `search_rls`. The exact complete file executed via psql -f in NEW disposable PostgreSQL 16.11 with migrations 001–008. All three final checks returned true. Anonymous/non-admin direct access denial, independent no-policy RLS row exclusion under temporary test grants, both public owner RPCs, and existing catalog/search/filter/security/media/daily-editor regressions passed. Temporary grants were rolled back; the disposable cluster stopped.

Exact installer SHA-256: `aca261aa38d25b713a866c23f0dcb1fb3b531cc114644b9ad7aa44728845cce0`; migration receipt/source SHA-256: `f7d321de75bb11b75d6540eef0a5de4d69ddf6f44c6d0f9e4c45dce8594a6588`. Evidence: `storefront-database-verification.json`, local run `database-test-5a69884fc289`. Generator lint and source integrity passed (64 original files, 14 reference CSS blocks). No frontend, real catalog, earlier migration or connected database was changed. Auth/Storage remain local test doubles; hosted integration is still pending installation/exposure of migration 009. The latest complete installer requires THREE true final checks, replacing earlier two-check instructions.

### Fresh clean installer after reported mixed SQL text (2026-10-07; supersedes earlier installer artifacts)

Read-only hosted checks were performed FIRST: actual admin Auth/membership passed; anonymous/admin navigation RPC and anonymous catalog RPC returned PGRST202, aliases table discovery PGRST205. The private search and receipt API requests returned PGRST106 because app_private is not exposed. No direct database connection is configured. Therefore private objects/receipt state remains UNKNOWN; missing API endpoints do not prove rollback. No hosted SQL, cache reload, fixture operation or install was attempted. Evidence: `storefront-hosted-preflight.json`. The user must run the complete read-only `07_preflight_public_storefront.sql` in development SQL Editor and return its result before any installation recommendation.

The reported mixed submitted SQL was not reproduced in the current canonical local source (one brands entry, receipt and final SELECT were present). To prevent stale query/attachment mixing, both complete installer files were regenerated by OVERWRITE from that canonical migration, with explicit structural validation and a distinct `07_install_public_storefront_clean.sql` artifact. There are six unique functions, eight matched delimiter pairs, one navigation brands key, one receipt insert/VALUES, one final SELECT and one BEGIN/COMMIT. Guards now refuse any known storefront object, refresh trigger or receipt, not only the old two-object test. No manual combining is required.

Executed the EXACT clean file using `psql -X -v ON_ERROR_STOP=1 -f` in a NEW disposable PostgreSQL 16.11 database containing migrations 001–008, no earlier installers. Before/after read-only preflight, receipt/source hash matching, all three final booleans, unchanged pre-existing business-table snapshots and safe repeat-install refusal passed. Catalog/search/filter/RLS/media/daily-editor regressions passed; anonymous/non-admin direct search denial and independent no-policy RLS exclusion passed while both owner SECURITY DEFINER RPCs worked. The cluster stopped. Local Auth/Storage are doubles, not hosted services.

Exact delivered clean file SHA-256: `99e5b4c5340b24f7465c3fc34dce1d01f893c7636718e4ca2e958e65d2d74f4a`. Canonical migration receipt/source hash remains `f7d321de75bb11b75d6540eef0a5de4d69ddf6f44c6d0f9e4c45dce8594a6588`. Evidence: `storefront-database-verification.json`, `storefront-installer-structure.json`, local run `database-test-a7a1d6ca2aa4`. Hash equality was checked before and after execution; clean/canonical installer bytes match. Generator/read-only-check lint and original-file integrity passed. No frontend/assets, real catalog or existing hosted database was changed. Hosted installation-state confirmation and integration remain pending.

### Confirmed installed-state query and hosted readiness (2026-10-07)

The three installer final booleans were postflight checks, not the complete preflight. Added ONE read-only `07_verify_installed_storefront.sql` query covering receipt 009/version/source hash, all expected relations/functions/indexes/enabled refresh triggers, both RLS tables, zero private search policies, revoked client search privileges and matching SECURITY DEFINER owners/public execution grants. That exact query passed against the fresh disposable 001–008 + exact clean installer database; evidence run `database-test-f628f7dab43d`. The installer bytes/hash were not changed or rerun on hosted Supabase.

The user subsequently confirmed this full installed-state SQL Editor verification passed, including canonical receipt/hash and no missing objects. Recorded in `storefront-installed-confirmation.json`. Read-only actual provider probes now pass HTTP 200 for both anonymous public RPCs, admin navigation/aliases discovery and Auth/membership. The private schema remains intentionally inaccessible through the API. The local Next public wrapper also returns HTTP 200 with private/no-store after restarting the development process with network permission. Existing sources/frontend were not edited. This supersedes the prior missing-RPC installation blocker; actual synthetic browser/provider checks are now in progress and final results follow below.

### Completed actual hosted storefront verification (2026-10-07)

This supersedes the prior pending hosted integration entries. Installed-state verification was confirmed by the user's read-only SQL Editor query: receipt 009/source hash matches, all expected objects exist, and RLS/owner/grants pass. No installer, migration, schema-cache notification or existing-database reset was run against hosted Supabase.

The actual development verification passed TWENTY-ONE checks using installed Chrome, the running Next.js server, real Supabase Auth/PostgREST/private Storage and real Cloudinary. Three synthetic products (two published solely for verification, one draft) and three neutral 1-pixel test images were created through authorized admin/media services. Passed: anonymous published/draft separation; explicit public payload allowlist even for admin-token reads; combined brand/type/approved synthetic concern search; spelling/prefix and original SKU queries; unsupported claim exclusion; OR-within/AND-across filters; no cross-variant facet matches; bounded sorting/pagination; distinct variant price/image/availability; actual responsive Cloudinary delivery; curated homepage RPC selections; actual search rendering; browser option/out-of-stock behavior; bag restoration; mobile drawer/no document overflow; immediate admin price freshness via direct anonymous RPC and the Next server wrapper; hidden-product disappearance; and complete baseline preservation.

Cleanup passed with no pending items: all THREE synthetic products hidden, THREE test images detached and safely cleaned, synthetic brand/category archived and synthetic concerns/facets deactivated. Synthetic audit/history records remain deliberately intact. All 881 pre-existing rows across 18 catalog/source/stock/media tables matched their original hashes. No real catalog product was imported, edited or published. Evidence: `storefront-live-verification.json`; actual screenshots `.local/storefront-verification/live-desktop.png` and `live-mobile.png` were inspected. Original supplied files/CSS remain intact; the storefront/design code was not edited during verification.

The local server initially lacked outbound network permission and returned a catalog-wrapper 503 despite direct provider HTTP 200. Restarting that development process with approved network access resolved it; the wrapper now returns HTTP 200 and private/no-store. This was a local execution configuration issue, not a schema reinstall or silent sample fallback.

Limits: installed Chrome desktop and mobile emulation, not physical-device Safari. Test images are explicitly neutral synthetic provider assets, not real product angles. Combined-filter/relevance assertions used actual PostgREST RPCs; browser visual/interactions and earlier mock URL/filter regressions are separately recorded. Large-inventory performance/load testing was not performed; real merchandising/publication remains owner-controlled. No requested hosted integration check remains blocked. No payments, orders, blog/review integration or deployment was added.
### Content CMS: implementation ready, hosted verification pending (2026-10-07)

Implemented simple article list/search/pagination, Create/Edit, rich text, cover/inline images with alt text, optional author/category/tags/SEO, Save/Draft/Publish/Hide, confirmed soft deletion and safe revision checks. Published article index/detail, SEO defaults and published product/category links are connected. Homepage provides manual article/product ordering, sage/warm/blush slide themes and optional selection-owned images; original other artwork is preserved. No fake product owns content uploads.

The exact complete installer 08 passed `psql -X -v ON_ERROR_STOP=1 -f` against fresh disposable PostgreSQL 16.11 with migrations 001-009, followed by catalog/security/media/daily-editor/storefront/content regressions. Local Auth/Storage and provider completion metadata are test doubles. Draft/hidden isolation, anonymous/non-admin denial, stale/invalid-edit rollback, true media owners, cover associations and slide themes passed. Evidence: content-database-verification.json, database-test-78c245718e84. Installer SHA-256 ff891628343b3429a0fc9c9f82b55beb8fba2c5b280d2af3b43aeec8d277dae7; canonical receipt hash fc887ea5842eaa16a3980a71c0960a6246cc9b5a4c99a2c90245dd22c2df7bc2.

Lint, production build and thirteen security/sanitizer/media unit tests passed; production excludes /reference. All 64 supplied files and 14 reference CSS blocks remain intact. Thirteen explicitly mocked Chrome checks passed: published pages/404/SEO/sanitization, desktop/mobile slideshow and article rendering, draft/edit/publish/hide/confirmed-delete controls and manual homepage theme selection. These are not hosted provider results. Evidence: content-ui-mock-verification.json and local screenshots. Homepage original-reference regression is recorded separately; build success alone is not visual verification.

Actual hosted content RPC currently returns404. No CMS fixtures or real articles/products were published, no earlier installer rerun. Applying migration010 via development SQL Editor remains necessary; actual new-owner private upload/approval/Cloudinary delivery, hosted draft isolation, browser curation/freshness and safe cleanup are pending. Existing local keys cannot apply SQL. This stage is not claimed fully live-verified. Orders/deals/reviews/payments remain out of scope.

Final visual/security checks (2026-10-07): original homepage comparison and all hero/editorial carousel states passed; desktop/mobile navigation, sample flows and mobile hero/hamburger passed. Eight applicable checks passed across runs, two intentionally skipped. Screenshot-heavy tests needed a larger Windows time budget, with every assertion retained. Ten additional public CMS mock checks passed after scoped article-cover framing correction; mobile article/homepage/admin screenshots and matching reference/React editorial snapshots were inspected. Actual new Next content API rejects anonymous GET401 and CSRF-less POST403 with private/no-store; development reference returns200. No hosted CMS DB/provider operation was added. See content-local-verification.json.

## Latest revision: product content / admin usability (2026-10-08)

Implemented the three Markdown editors and conditional storefront sections, spacious responsive admin navigation/workflows, product summaries/filtering, simple variant rows, unsaved feedback, private upload progress and product/article previews. Previous migrations and source assets are preserved. Prepared incremental 012 with read-only preflight and one exact complete installer. Disposable SQL and local Chrome/provider-double evidence are separate; see product-content-admin-update.md and product-markdown-database-verification.json. Hosted review verification remains pending: RPC HTTP 404, SUPABASE_SECRET_KEY and REVIEW_SESSION_SECRET absent. The new admin list/save contract awaits 012 application; it fails explicitly rather than dropping fields on an old RPC. No hosted mutation or next stage was performed.


## Hosted reviews and product-content verification completed (2026-10-08)

This supersedes the earlier missing-011/012/settings blockers. The owner confirmed both installed receipts/preflight checks. SUPABASE_SECRET_KEY and REVIEW_SESSION_SECRET presence/minimum length were checked privately and Next restarted; actual review RPC returned 200. No installer was rerun. All 58 actual hosted/browser checks passed: customer pending submissions/private images, admin approval/decline/hide, approved Cloudinary delivery, approved-only rating calculations, re-moderation after edits, immediate public freshness, single/two-variant Markdown saving/previews/public sanitation, published/hidden Save preservation, invalid-published rollback, zero-count/exact stock reconciliation and secure login/logout/CSRF/no-store boundaries. All 121 real SKUs remained searchable.

Actual first-run testing found a small-image responsive descriptor bug; the shared resolver now advertises delivered fit widths. Real provider retest passed. Synthetic products/reviews/taxonomy were hidden/archived and uploaded Storage/Cloudinary files safely removed; audit tombstones remain. Every one of 923 pre-existing rows in 25 tables remained identical, including homepage selections and content. Failed-run cleanup also completed and preserved its baseline. No real content was published/approved, no catalog import, schema change or next numbered stage occurred. Details: reviews-product-content-hosted-results.md; sanitized actual report: reviews-product-content-live-verification.json.

Separate verification: 19 unit/security tests passed, ESLint/typecheck/production build passed, and all 64 original source files plus 14 CSS blocks remain byte-identical. Production excludes /reference. Final homepage/browser boundary results are recorded in admin-refresh-verification.json. Mobile is Chrome emulation; physical iOS Safari and production load testing remain unperformed. Hosted quotas were not deliberately exhausted; existing local SQL/unit tests cover those failure cases.

Final regression completion: six homepage checks and two scaffold checks passed across desktop/mobile with two intentional viewport skips. One mobile interaction readiness wait exceeded five seconds during concurrent compilation; its identical test passed on the warmed server. The full desktop/reference section geometry and all carousel states passed, as did mobile hero/hamburger and interactions. Production preview/auth/noindex/reference-exclusion checks passed. The isolated sample server was stopped and regular Supabase-mode development Next restored on port 3000. Final probes: homepage 200, development reference 200, anonymous protected admin redirect 307.


## Admin product list update (2026-10-09; hosted migration pending)

Implemented smart assigned-data/alias/partial/trigram search, matching shade/size rows, combinable private catalog/facet/concern filters, bounded pagination with accurate counts, category-aware optional reminders, uncounted/zero stock distinctions, persisted per-product/option Ignore/Undo/Restore and recurrence reset. Needs-attention any/all checks unresolved data even if reminders are ignored. Publication rules, stock/edit services, storefront and earlier migrations are unchanged.

Exact incremental 013 installer passed ON_ERROR_STOP=1 against fresh 001–012, preserved existing business rows, matched its artifact hash and refused repeat. Local catalog/security/media/review/daily-editor regressions plus new search/filter/reminder/permission assertions passed; Auth/Storage are doubles. Fourteen actual Next/Chrome checks using local provider doubles passed; desktop/mobile screenshots were inspected. Lint, TypeScript/production build and all 64 original handoff/import files/14 CSS blocks passed preservation checks. See admin-list-database-verification.json, admin-list-mock-ui-verification.json and admin-product-list.md.

Actual hosted admin Auth login passed; new RPC returned 404, so 013 installed-state/receipt confirmation is required before actual synthetic hosted search/filter/reminder tests. No earlier installer or connected real record was changed. A read-only preflight, one complete tested installer and guarded actual development runner are supplied. This pending hosted gate is separate from successful local/mock tests. No next commerce stage was started.

Final actual browser access evidence: four checks passed (anonymous list denial, non-admin login denial, admin Auth login, CSRF-less dismissal denial). New list RPC still unavailable; the guarded runner stopped before fixtures, with zero hosted catalog mutations. Actual synthetic search/filter/stock/reminder/pagination verification remains pending migration 013; do not interpret local SQL or Chrome provider doubles as hosted results. Production boundary checks passed. Evidence: admin-list-live-verification.json and admin-list-verification.json.

Final source production build and repeated 14-check desktop/mobile provider-double workflow passed after category ancestry, stale-reminder message and page-clamping refinements. The exact tested installer hash remains unchanged. Regular development Next was restored on port 3000. No hosted synthetic fixture was created while 013 was unavailable.


## Corrected pending 013 installer verified (2026-10-11)

This supersedes the previous admin-list installer artifact. The filter-options/list mismatch is fixed through shared category/eligible-option views. Variant insert/update/delete, both owners after ownership changes, deleting/moving the last variant, archived-option exclusion/restoration, media upload/review/publish/failure/retry/detach/ownership changes and issue fix/recurrence passed 29 targeted SQL assertions. Products without options remain editable with an actionable blocker and accurate SKU totals.

The exact complete 11_install_admin_catalog_list_clean.sql ran with psql -X -v ON_ERROR_STOP=1 -f against a new disposable PostgreSQL database with migrations 001–012. All 19 postflight flags were true; before/after public business-row hashes were identical; repeated installation was rejected. Tested file SHA-256: c570fff73caf5395271f6e5cde9bce658cb7e5359c13e301684cb23be2584310. Canonical receipt hash: de9272e1f837c654aa613e84fbabc8e1e12fc6248475764573a6a153d46e51b0. Evidence: admin-list-database-verification.json and local database-test-0cc53f2d96da.

Auth/Storage/provider metadata in this SQL suite are doubles, not hosted/provider verification. No hosted SQL, API mutations or real records were touched; earlier migrations were not changed. Storefront/reference/assets are preserved. Source preservation, lint and typecheck were checked separately. Browser/provider-double results from 2026-10-09 remain historical; they were not rerun for this SQL correction. Hosted 013 application and synthetic integration verification remain pending. No commerce stage started.


## Pending actual hosted admin-list run completed (2026-10-11)

Supersedes the earlier migration-unavailable/hosted-pending notes. Owner confirmed all 19 installed flags; actual Auth and RPC availability passed. 49 live checks passed across the main browser/fixture run and supplemental read-only UI/API run. Smart assigned-data search, spelling variation, variants, combined/additional-category filters, pages/counts, badges, stock distinctions, Ignore/Undo/Restore, recurrence, browser-edit freshness and authorization were verified against real Next/Supabase. Desktop/mobile screenshots were inspected. No mocks were used for this run; earlier mock/local results remain separate.

All pre-existing hashes across 29 tables/1,211 rows passed preservation, including homepage selections. All four synthetic products are archived; both test media are deleted; anonymous reads expose none. Histories/tombstones remain private. Source preservation and targeted harness lint passed. The app remains available on port 3000; storefront code/assets were unchanged. No SQL installers were rerun or hosted SQL applied, and no commerce stage began.

Observed remaining limitation: exact long SKU aliases also return a closely spelled sibling via trigram matching; exact identifier priority needs a future incremental fix. Alias plus option label works. Physical Safari/production-load verification was not performed. Evidence and exact live-versus-mock boundaries: admin-list-hosted-results.md/json and admin-list-live-*.json.


## Exact identifier correction prepared (2026-10-12)

Incremental 014 and one clean installer/read-only preflight are ready. Exact file tested on fresh 001–013 using ON_ERROR_STOP=1: nine flags, unchanged business snapshots, repeat refusal, exact/normalized/spaced/alias isolation, combined filters/no fallback and prior regressions passed. Sources and targeted lint passed. 21 actual hosted/browser checks passed; hosted 013 reproduces alias/spaced identifier siblings, so fixed hosted isolation remains pending owner application of 014. Both synthetic runs and six variants were archived, real records/homepage/assets preserved. No storefront/dependency change, real publication, hosted SQL or commerce. Details: admin-exact-search-results.md.


## Exact SKU/alias hosted verification complete (2026-10-13)

Supersedes 014 installation-pending notes. All 41 actual Chrome/Next/Supabase checks passed: original/sibling SKU, normalized/spaced identifiers, aliases, matching/excluding filters, no fuzzy fallback, ordinary typos, desktop/mobile row isolation, real Auth/authorization/CSRF/no-store, draft fixture saves and safe cleanup. 1275 pre-existing row hashes across 29 tables remained unchanged, including homepage selections. Separate read-only cleanup confirms three historical/current synthetic products and nine variants archived, anonymous reads empty. Sources/reference CSS and migration/installer hashes unchanged; targeted lint passed. Historical local tests remain separate, not rerun. No installers, real publication, storefront edits or commerce. Physical devices/other engines and production load untested. See admin-exact-search-hosted-results.md.


## Commerce implementation prepared; pause for corrected 015 application (2026-10-13)

Real cart revalidation/persistence, guest form/private confirmation, server snapshots/totals, reservation lifecycle, admin orders/search/date/status/details/actions and maintenance runner are implemented. Corrected unpaid-payment/dispatch and reservation-completeness safeguards passed exact-file ON_ERROR_STOP=1 testing on fresh 001-014: eleven flags, unchanged seeded rows, repeat refusal, atomic lifecycle/corruption checks and two-session last-unit race. Source and dependency assets unchanged; unit/mocked UI/lint/type/build checks passed, separately from actual provider checks. Homepage geometry/mobile checks pass; 20/23 pixel pairs identical, with existing search-link and tiny transition differences reported honestly. Hosted 015 is owner-confirmed absent; actual commerce/order/expiry tests remain pending. No hosted fixtures or SQL, real publication, payments/courier calls or deployment. Owner explicitly requested a pause after delivering the corrected installer/hash. Details: commerce-verification.md; installer hash ea1d878b6caa9209cba75885448dd84f5b6c075576266f8d1c51c74d1f176ef0.

## Manual payment correction prepared (016, 2026-10-15)

This supersedes the historical pause/015-absent statement above: owner confirms 015 installed. No applied migration or hosted SQL was rerun. Incremental 016 implements advance-only manual payment configuration, private proof submission, simple admin queue/actions, explicit funds verification, scoped reference deduplication, identical-image/amount flags, bounded deadlines and atomic late stock reacquisition. Existing storefront layout/assets are preserved. Exact installer, SQL lifecycle/races, unit and mocked browser evidence are separate from actual hosted read-only Auth/security checks. Full hosted manual lifecycle and private Storage verification remain pending owner application of 016; no hosted synthetic records were created. See manual-payments-setup.md and manual-payments-*-verification.json for exact results and installer hashes. No next stage started.

## Actual hosted manual-payment verification complete (2026-10-15)

Supersedes 016 installation/lifecycle-pending statements. Owner confirmed all fourteen final flags; no installer or hosted SQL was run. Real Chrome/Next/Supabase/private Storage flows passed for Bank Transfer/Easypaisa/JazzCash: guest ownership/reload, private proof upload/read-back/access, review actions, explicit receipts/mismatch/dedup/idempotency, server-authoritative checkout values, unpaid fulfilment denial, atomic last-unit/late-payment races, bounded actual deadlines/expiry/release and dispatch/completion consumption. Initial fixture stock-helper omission was corrected and targeted hosted cases passed; raw evidence retained. 153 passed live check observations across the runs are separate from historical mocks/local doubles.

All 1,313 original hashes across 37 tables remained unchanged; a second 1,367-row baseline also passed, including homepage selections. Fourteen synthetic orders have no active reservations; three private proofs and two public test images are cleaned; two products/six variants are hidden/archived and audit/payment/order/hash history retained. Independent maintenance CLI returned zero expired/overdue/mismatched counters after cleanup. Source integrity (64 originals/14 CSS blocks) and lint passed. Normal checkout remains disabled; production receiving accounts, shipping/tax/deadlines, trusted ingress and an external expiry schedule/retention policy remain configuration dependencies. No real funds, new application/schema/UI changes, next stage or deployment. See manual-payments-hosted-results.md/json.


## Assembled deals implemented; incremental 017 application pending (2026-10-17)

Admin deal editing, exact option selection, total PKR pricing, dates, stock set-asides, private-review media controls and manual homepage ordering are implemented. Public listing/detail and mixed product/deal bag/checkout reuse the approved design and manual advance-payment workflow. Runtime snapshots protect charges and dispatch quantities from later edits. The new complete installer/read-only preflight are separate from unchanged 001–016. Verification evidence and exact hash are in deals-local-verification.json and deals-installer-manifest.json; Chrome/Next mocked deal UI and actual read-only Auth/RPC checks are recorded separately in deals-ui-verification.json and deals-live-readonly-verification.json. New hosted deal RPC is currently unavailable (PGRST202); full actual hosted deal lifecycle/Storage/Cloudinary tests await owner application. No hosted business mutations or automatic publication, new payment methods, reports/refunds/courier/deployment were performed. See deals-setup.md for stock return semantics, installation and external scheduling.

Final checks: lint/typecheck/build/production security and 17 unit checks passed. Exact complete 017 installer passed fresh 001–016 ON_ERROR_STOP=1, seeded-row preservation, fifteen flags, repeat refusal, lifecycle/permission/media doubles and independent-session races. Chrome recorded 24 mocked admin/cart checks, 14 mocked public SSR checks and 11 actual read-only observations. Existing homepage suite: six passed/two intended skips; 21 of 23 desktop pairs pixel-identical. The comparison threshold still flags the existing sample-search link; the small full-home difference is recorded, not waived. All 64 source inputs/14 CSS blocks verified. Full evidence and hosted pending scope: deals-verification.json.


## Deals hosted verification paused on a discovered policy dependency (2026-10-18)

Supersedes 017/018 installation-pending notes: owner confirms both installed; security audit matches after 018. Actual Chrome/Auth/Next authorization/CSRF/no-store and protected RPC/private schema checks passed; public deals/quote HTTP 200 and normal checkout disabled. Before fixture creation, five existing media-related RLS policies failed with permission denied for the helper moved by 017. Read-only checks reproduced all five failures across anonymous/non-admin/admin. No hosted business mutations or uploads occurred. Clean incremental 019 is prepared and exact-file tested with ON_ERROR_STOP=1 on fresh 001–018, including data/policy/grant/RLS preservation, draft isolation and repeat refusal; application is pending owner SQL Editor action. Lifecycle/media/race tests remain pending, not passed. Harness lint/source checks passed; all 64 inputs/14 reference CSS blocks intact. No storefront edits, earlier installer reruns or next stage. See deals-hosted-results.md and media-policy-dispatch-local-verification.json.


## Actual hosted assembled-deal verification complete (2026-10-18)

Supersedes prior 017/018/019 application and hosted-pending statements. Owner confirmed all correction flags; no installer/hosted SQL rerun. All 98 main actual Chrome/Next/Supabase/Storage/Cloudinary observations, 35 independent cleanup checks and 3 loaded-editor layout checks passed. Coverage includes admin/media approval, draft/hidden/public/homepage freshness, mixed carts, last-unit/shared-stock races, pool transfer/return/release/expiry, frozen order composition, manual late payments/reacquisition and receipt-without-stock resolution, dispatch/retry/Complete once. No mocked requests were used. The loaded mobile editor and public mobile detail screenshots were inspected; the harness waits for async editor load.

All 1,416 baseline row hashes across 40 tables and owner homepage selections are unchanged. Two synthetic products/four variants and three deals are hidden/archived; nine order histories retained without active holds, five media files cleaned/private originals not found, pools/counters zero. Global balance/overdue/ended-pool reconciliation is zero. Source verification and targeted harness lint passed. Normal checkout disabled; approved receiving/shipping/tax/deadline/retention/ingress settings and external scheduler remain pending. No storefront changes, next stage or deployment. See deals-hosted-results.md/json for actual-versus-historical local/mock boundaries and limitations.


## Reporting/refunds stage paused by user (2026-10-18)

Work is saved but unfinished; no hosted 020 SQL or financial fixtures were run. The generated installer is deliberately blocked as an unverified draft and must not be applied. Final tests/installer regeneration and hosted verification remain pending. Do not rerun 001–019. Resume from docs/reports-resume-checkpoint.md; it records exact files, passed/failed/pending checks and next actions. Real checkout remains disabled; prior hosted deals results are unchanged.


## Reporting/refunds implementation prepared (2026-10-20)

Supersedes the paused/unverified 020 notes. Reports, private completed-sale/receipt/refund/return ledgers, exact component entitlements, explicit manual Sent confirmation, independent inspected stock returns, audited reversals and balance/stock resolution are implemented. Business/test reporting scopes are explicit. New wrapper guards preserve ordinary order idempotency and existing history. No real money movement or hosted financial writes occurred.

The exact complete 020 installer passed fresh 001–019 ON_ERROR_STOP=1 with all 15 flags, unchanged seeded rows, repeat refusal, 60 SQL assertions and independent approval/duplicate-transfer races. Five CSV/PKR tests and desktop/mobile mocked UI passed separately; these are not hosted finance verification. Build/TypeScript and production preview/reference security checks passed. Actual hosted read-only Auth/CSRF/privacy checks pass; reporting RPC returns PGRST202, so owner application and full synthetic hosted verification remain pending. See reports-setup.md for exact installer/hash, flags, definitions, limits and commands. Do not rerun 001–019. Normal checkout remains disabled; no next stage.


## Partial-value refund follow-up prepared (021, 2026-10-20)

Frozen 020 is unchanged. Separate 021 extends the same private workflow for cancelled partial payments and optional per-item/component monetary amounts, including value-only refunds with quantity zero. Cash, item value and quantity entitlements remain independently bounded; no shipping/overpayment classification is fabricated. The editor advertises these inputs only with the installed contract. Exact fresh 001–019 + exact 020 + exact 021 testing preserved all existing financial rows/function OIDs/grants and passed original races plus 11 extra assertions; seven 021 flags true, repeat refused. Desktop/mobile mocked UI covers partial values. Both installed receipts and actual hosted financial verification remain pending. Do not rerun 020 or earlier installers if already installed. See reports-setup.md for exact files/hashes and expected preflight flags.


## Final local reporting-stage checks (2026-10-20)

020 and 021 are exact-file tested and ready; hosted installation/financial verification remain pending, not completed. Current evidence: 60 original SQL assertions plus independent approval/send races, 11 partial-value assertions, 14 intercepted Chrome UI checks, five precise-money/CSV tests, lint/type/final build and production security pass. Eight homepage/scaffold browser checks pass with two intended skips; 21/23 desktop screenshot pairs are identical, while the existing search-link pixel threshold remains flagged and a small full-page difference is reported honestly. All 64 original inputs/14 reference CSS blocks intact. Seven real hosted read-only Auth/API checks pass; new RPC was PGRST202 before owner installation. No hosted financial writes or actual money, no source storefront changes, no next stage. Full setup/hashes/definitions: reports-setup.md; passed-versus-pending evidence: reports-verification.md/json.


## Hosted financial verification completed (2026-10-20)

Supersedes earlier pending-installation/hosted-verification notes. Owner confirmed 020/021 receipts and all 15/seven flags; no installer or hosted SQL was run. Actual Chrome, Next.js, hosted Supabase/Auth/PostgREST, private Storage and Cloudinary checks passed: 91 main, 22 supplemental and 44 independent cleanup/read-back checks. No intercepted provider responses were used in these runs.

Six synthetic orders covered exactly-once completion, separate receipts/shipping/cash, mixed-cart frozen deal attribution, full/partial-value/item/shipping/overpayment refunds, cancelled/uncompleted cash-only refunds, competing approvals and duplicate-reference sends, retry/stale-edit protection, explicit outgoing-history confirmation, independent inspected resale/damaged returns, partial deal components and dispatched limits. Real browser request/approve/send/return controls and desktop/mobile Reports layouts passed. Historical order/report values remained unchanged after synthetic catalog/deal price edits; hidden visibility was preserved. Actual CSV totals/privacy, Pakistan-day filtering and previous-day exclusion passed. Anonymous/non-admin financial RPCs and all seven private financial tables were inaccessible; private financial responses remained no-store.

Cleanup: two products and three deals hidden, options archived, five approved test media/private originals deleted; all six order/financial histories and audit events retained. No active fixture reservations, idle deal pools or approved/requested financial holds remain. Global reconciliation: zero balance mismatches, overdue holds and ended allocations. All 1525 pre-existing rows across 40 tables, homepage selections and pre-existing business/development financial events were preserved. All 64 handoff/import files and 14 reference CSS blocks remain byte-identical. Normal checkout stays disabled; no real funds moved, storefront design changes, courier integration or next stage.

Verification limits: exact 18:59:59/19:00:00 UTC Pakistan-midnight fixtures and hostile formula-like CSV names were tested in disposable PostgreSQL/unit tests, not newly fabricated/backdated hosted financial history. Actual hosted day windows and CSV totals/privacy passed. Bank/wallet outgoing-history acknowledgements were synthetic; no account statements or real transfers were verified. Chrome desktop/mobile emulation is not physical-device, other-engine or production-load evidence. Prior storefront comparison remains 21/23 pixel-identical with the documented existing search-link/full-page differences; no new fidelity claim follows from these financial tests.

Evidence: reports-hosted-live-verification.json, reports-hosted-supplement.json, reports-hosted-cleanup-readonly.json; screenshots under .local/reports-hosted. Local SQL, intercepted UI and unit evidence remains separately labelled in reports-verification.md/json. Receiving-account/shipping/tax/deadline approval, trusted ingress and an independent commerce-maintenance scheduler remain launch setup decisions.


## Category filters and navigation responsiveness — 2026-11-23

Implemented a scoped filter sidebar and mobile modal drawer: expandable groups, compact native checkboxes, inventory counts, selected-count indicator, sort/reset/apply controls, rounded chips, keyboard focus return and reduced-motion support. Fixed the broad input rule that styled checkboxes as full-width inputs. Existing filter URL/query and eligibility semantics remain intact.

Storefront markup internal anchors now use Next Link; filter/search forms use Next Form client navigation. Category metadata avoids an unnecessary unfiltered query on filtered pages and reuses identical query arguments on unfiltered pages. Only anonymous shared navigation uses a 60-second tagged server cache, expired immediately by existing authorized public invalidation. Product prices, visibility, inventory, checkout and private reads remain uncached. No backend, schema, packages or production data changed.

Read-only deployed baseline (nookandglow-three.vercel.app): category headers 1010–2040ms, complete HTML 1375–2705ms; product headers 1031–1039ms, complete HTML 1290–1782ms from this client connection. Network/cold-start/database contributions are not separately instrumented; Vercel bom1 response-edge identifier does not establish function/database co-location. Recommend checking Vercel function region against Supabase region, then measuring after deployment. No claimed deployed speedup: changes are local and not deployed.

Verification: TypeScript and lint passed; 14 actual Chrome/Next checks with synthetic RPC/image responses passed, including no document reload on filter submission, URL chips, pagination, variants, missing/error handling, compact mobile checkboxes, focus restoration and no overflow/runtime errors. Desktop/mobile screenshots visually inspected. See storefront-mock-ui-verification.json and storefront-response-baseline.json. Provider data was not mutated. Existing homepage structure/assets preserved.


## Optional boxed-set contents — 2026-11-23

Owner requested removing boxed-set confirmation as a publication requirement for AXI-004 and future products. A read-only hosted admin check confirmed AXI-004 (The Mini Glow Set) is draft, sellable_kind=unconfirmed_set, with set_contents_missing as its only essential blocker and no specific issues. No hosted product or publication state was changed.

Incremental 023 removes boxed contents gates from publication_blockers, variant public eligibility and admin reminder generation, plus the boxed-pack-only import confirmation flag. Other identity/scope/claim issues, required price/category/description/stock and approved-media safeguards remain. Original classifications, factory contents, exact SKUs, content, stock, orders and audit history are retained. Existing derived boxed reminders become inactive; dismissals/history are retained. No automatic publication or product reclassification.

The exact complete SQL Editor file 20_install_optional_boxed_sets_clean.sql passed psql -X -v ON_ERROR_STOP=1 -f against a fresh disposable PostgreSQL database with all 23 existing migration files (001–022 plus the additional SEO migration). All seven final flags true; business-row snapshots and function OIDs/owners/ACLs/settings preserved. Local fixtures demonstrated daily Publish for unconfirmed_set, public eligibility for factory_set without contents, removed reminders and repeat-install refusal. Supabase Auth/Storage were local test doubles, not hosted verification. Evidence: boxed-set-local-verification.json and boxed-set-installer-manifest.json.

Pending owner SQL Editor application: run 20_preflight_optional_boxed_sets.sql read-only, then only the complete 20_install_optional_boxed_sets_clean.sql once using ordinary Run. Before: prerequisites_present/admin_write_grants_preserved true and five correction/receipt flags false. After: all seven true. Do not rerun older installers. Refresh AXI-004 and choose Publish explicitly afterward. Existing HTTP configuration cannot apply DDL; no passwords/keys requested in chat. No Git push/deployment performed for this follow-up.


## Collapsible product information — 2026-11-25

Replaced long product-copy panels with shared native details/summary disclosures for Product description (initially open), How to use, Key benefits and Delivery information (initially closed). Each row toggles independently, including keyboard interaction before JavaScript hydration. Optional empty/whitespace-only copy is omitted. Published and explicit sample product pages use the same component; no product copy is rewritten. Existing Markdown sanitation, product metadata, reviews, pricing, inventory and admin data remain unchanged. Styling uses cream/ink/bronze, fine dividers, compact uppercase labels and inline SVG chevrons; responsive spacing and reduced-motion rules are scoped to product disclosures.

Verification: production build, lint and TypeScript passed; 19 Chrome/Next browser checks with explicit synthetic catalog/image responses passed, including expanded/collapsed defaults, keyboard How to use, independent benefit expansion, mobile collapse/no overflow and missing optional sections. Desktop/mobile screenshots visually inspected under .local/storefront-verification/product-disclosures-*.png. These are browser UI checks, not new hosted provider verification. No database mutation, auto-publication or deployment.

Owner separately confirmed 023 installation: all seven flags true. Do not rerun its installer. The product-disclosure change requires no migration.


## Accordion test cleanup check — 2026-11-25

Before GitHub push, actual hosted admin membership was verified; product-name search for synthetic, registered earlier reporting/deal fixture IDs and admin Synthetic search all returned zero matches. Current accordion UI tests use an isolated mock RPC server and do not create hosted products. No deletion or business-data write was necessary. Evidence: product-disclosures-cleanup-check.json. Migration 023 is owner-confirmed installed and is included only as source/history; it is not rerun.


## Similar products — 2026-11-25

Product pages now stream an optional Similar products section between product details and reviews using existing catalog cards, approved images, brand, actual PKR price and product links. Desktop has four columns; mobile has two. One bounded anonymous existing storefront_catalog query fetches at most 24 same-category/scope candidates; ranking prefers actual matching type, brand and price proximity, takes up to four, excludes the current product/duplicates, and shows only variants with available stock and media. The shown variant and minimum price come from those eligible available options. Home Fragrance and personal fragrance never cross scopes. No inferred concerns, personalised claims, fabricated sales ranks, sample fallback or new provider.

The server component is inside Suspense and does not gate the main product rendering on its extra query. Empty or failed recommendations omit the section. Product copy, admin, checkout, prices, stock, homepage and database remain unchanged. No schema/dependency changes. Candidate ranking is bounded to the first 24 returned category products, not a full-catalog similarity model. Explicit local sample-preview pages retain their existing behavior; published storefront pages use actual catalog results only.

Verification: production build, lint and TypeScript passed; three recommendation unit tests passed (self/duplicate/scope/category/stock/image exclusion; ranking/cap; available option price and immutability). All 22 real Chrome/Next browser checks with explicit synthetic catalog/image responses passed, including related-product links, mobile fit and no unrelated empty-category fallback. A separate actual hosted anonymous read-only query passed category/scope membership: two candidates, one other available product. No hosted writes or synthetic products created. Evidence: storefront-mock-ui-verification.json and recommendations-hosted-readonly.json. Changes not pushed or deployed yet.


## Category discovery editor — 2026-11-25

Optional category-scoped concern/features now join the normal authorized, revision-checked/idempotent Save transaction. Reuses existing normalized taxonomy/evidence/search with a simple owner confirmation and internally generated records. All eight skincare concern groups, scoped fragrance family/notes/concentration, occasion/season and makeup/body/hair/cutlery fields are available. No real claims assigned/published automatically; optional discovery does not block ordinary publication. The actual hosted read-only audit found the existing concerns/facets inactive.

Separate incremental 024 adds inactive vocabulary, private save support, inherited-scope validation/RLS/projections, supported navigation fields and searchable labels/EDP vocabulary. Recommendations rank shared assigned attributes within the same category/scope. Existing 023 remains owner-confirmed installed, unchanged; do not rerun it.

Verification: exact installer passed fresh 001–023 plus SEO using ON_ERROR_STOP=1: all eight flags and 37 SQL assertions, existing business rows preserved, repeat refused. Six Chrome/Next admin checks with provider doubles and 23 storefront mock checks passed; four recommendation unit tests, final production build, TypeScript and lint passed. Hosted assignment/freshness verification is pending owner SQL application and frontend deployment; no synthetic hosted products created. Full matrix, semantics, exact SQL steps and limitations: docs/product-discovery.md. Evidence: product-discovery-local-verification.json, product-discovery-browser-mock.json, product-discovery-taxonomy-audit.json and product-discovery-installer-manifest.json. Not pushed/deployed.


## 024 owner-confirmed installed — 2026-11-25

Owner supplied expected before/after results: all eight final installation checks true, including receipt/security. Do not rerun 024 or earlier installers. Actual hosted Auth/PostgREST read-only verification then passed 11 checks: admin/non-admin membership; installed discovery capability; 023 boxed gate still removed; anonymous/non-admin private report denial; eight concern definitions; new category vocabulary; public navigation facets contract; helper unavailable as a public RPC; zero Synthetic matches in admin. No SQL installer, hosted product write or synthetic product was created. Evidence: product-discovery-hosted-readonly.json.

Full hosted Save/removal/search/navigation freshness tests remain pending. The user asked to avoid leftover synthetic products; the current API can archive but cannot fully delete audit-linked product-save fixtures without owner SQL. Therefore persistent fixtures were deliberately not created. The 37 disposable-database assertions, six admin/browser mock checks and 23 storefront mock checks remain separately labelled evidence, not hosted write verification. Frontend changes are still local/unpushed; deployment remains required.


## Visible pre-existing category fields — 2026-11-25

Fixed the reported daily-editor visibility gap: skincare showed concern checkboxes immediately, but fragrance/body feature fields were only created after Add filter. A browser regression reproduced the missing Concentration heading before the fix. Hosted read-only checks confirmed the actual metadata was present (personal fragrance: nine families/eight notes/five concentrations; body format, care focus and other scoped values present), so no taxonomy migration or new assignments were needed.

Discovery now displays all scoped fields by name as optional controls immediately, ordered sensibly per category, with existing selections, per-field Add another, explicit Remove/Undo, custom named values and option ownership. Blank template controls are excluded from the saved payload. Changing category resets staged discovery values; saved assignments remain intact and are shown as not applicable where appropriate. Newly saved custom labels are read through the existing facet_values relationship, so they show without reloading the reference dictionary.

Verification: 12 real Chrome/Next checks with local Auth/catalog doubles passed, including fragrance/body field visibility without Add filter, saved values, empty optional omission, immediate custom-note labels and mobile fit. Screenshots under .local/product-discovery inspected. Production build, lint and TypeScript passed. Actual hosted read-only facet_values(label) join returned HTTP 200; no hosted mutation or synthetic product created. Applied 024 unchanged; no SQL rerun required. This correction is local, not pushed/deployed yet. Public navigation/filter choices continue to require assigned eligible published inventory rather than showing unassigned vocabulary.


## AXI-003 discovery persistence diagnosis — 2026-11-25

Owner reported added filters absent from public navigation/category filters and identified AXI-003. Actual hosted read-only inspection found 121 products, four public products and ZERO product_facets/product_concerns rows. AXI-003’s deployed editor also returned zero assignments. This establishes that no persisted selections were available for public discovery; it is not evidence of a stale public cache. The deployed editor had the correct named fields/capability and produced a discovery payload when confirmed. Its Save request was intercepted BEFORE reaching the server; a subsequent read verified unchanged revision/assignments. No actual suitability was assigned. Evidence: discovery-visibility-diagnosis.json and deployed-discovery-editor-diagnosis.json.

The observed editor gap was reproduced in a browser: an unconfirmed selection could be submitted; the backend correctly rejected it, while an existing Published badge remained and the error was only at the top. The owner’s exact previous request/confirmation state is unknown, so that historical cause is not asserted. Fix: form-associated required confirmation with inline error/focus, Save failures repeated beside the action buttons, and post-save assignment verification before reporting success. The verifier reuses the existing detail read—no extra database call—and checks approved concern/facet values, target variant, custom labels, numeric values and explicit removals. HTTP 200 alone is no longer sufficient to report filters saved. It does not alter the database’s approval/claim requirements.

Verification: 14 real Chrome/Next editor checks with faithful isolated provider doubles passed, including rejection before network submission, successful confirmed Save and a deliberately dropped-assignment response producing a visible failure. Five persistence-verifier unit tests passed; TypeScript/lint and production build passed. No hosted product write, SQL installer, synthetic hosted product, taxonomy change, automatic claim or publication occurred. Existing 024 remains installed and unchanged; no migration rerun is needed. Current correction is local/unpushed. After deployment the owner must reselect actual verified values and Save, since there are no prior stored assignments to recover. Hosted persistence of AXI-003 was deliberately not tested with invented values.
