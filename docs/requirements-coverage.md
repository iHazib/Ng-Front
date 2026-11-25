## Technical SEO and performance coverage (Prompt 17, 9 November 2026)

| Requirement | Implemented behaviour | Verification/status |
| --- | --- | --- |
| Per-page metadata, conditional `metadataBase` | `src/lib/seo/metadata.ts` + root/catch-all/deal metadata; `metadataBase` only with a valid HTTPS `SITE_URL` | Unit + production route checks passed; activation blocked on domain |
| Canonicals | Absolute canonical only with approved origin; unfiltered canonical on sorted/paginated collections; omitted on private transactions | Route checks passed |
| Open Graph/social metadata | OG `website`/`article`, Twitter `summary_large_image`, per-page title/description/image | Route checks passed; 1200×630 asset pending |
| Robots directives | Site-wide disallow until the four-part gate passes; private routes/admin/API noindex; runtime noindex in preview | Route + production checks passed |
| XML sitemap | Eligible homepage/collections/brands/articles/deals only; genuine article `lastmod`; no filters/search/drafts; capped pagination | Route checks passed; empty expected with zero published records |
| Favicon/icons | `src/app/icon.svg`, public through the preview proxy | Route check passed |
| Stable slugs/redirects | Slug-redirect table/RPC + resolver; target must still be public; real 404 otherwise | Unit/resolver coded; hosted migration not applied |
| Indexable curated pages only when backed | Collections/brands/Edit require published counts; filtered/sorted views noindex | Route checks passed |
| Noindex filters/sort/search/private | Cart, checkout, order access, search, arbitrary filters, sort, page 2+, admin, API, preview all noindex | Route checks passed |
| Truthful structured data | Product/AggregateOffer, BreadcrumbList, Organization, WebSite, Article; approved reviews only; in/out-of-stock truthful | Typecheck/build + route checks passed; no published records to emit live |
| Unknown/deleted routes | Real 404 for unknown product/article/deal/brand/path; optional owner redirect only when target public | Route checks passed |
| Server-rendered content/headings/links | Core content stays server-rendered; visible breadcrumbs match JSON-LD; one `h1` per page | Build + manual inspection |
| Image alt/lazy/size | Existing contextual alts; first hero eager/high, later media lazy/low; aspect-ratio containers | CLS measured 0 |
| Reduced motion/carousel cost | Carousels already pause on reduced motion and only animate when visible/awake | Headless reduced-motion check passed |
| Measure LCP/CLS/INP/payload | Production-build headless Chrome runs; LCP, CLS, interaction proxy, transfer and image sizes recorded | Desktop LCP ~1.07–2.13 s, mobile ~0.68–0.82 s, CLS 0, ~1,889 KB transfer |

Full details: [seo-performance.md](seo-performance.md). Verification commands: `npm run test:seo`, `npm run measure:seo`, `npm run test:production`, `npm run check`.

Blocked/unresolved: no approved domain or launch authorization; zero published catalogue records; slug-redirect migration not hosted; production 503 gate unchanged; no 1200×630 OG asset; social URLs unset; care copy placeholder. Prompt 18 not started; no deployment performed.

Review-stage final checks: lint/type/build and production preview checks passed; 16 units, 14 Next/Chrome API-double checks, six applicable homepage tests passed (two intentional skips; one decode timeout passed on unchanged isolated retry). All 64 supplied files and 14 reference CSS blocks remain unchanged. Hosted review verification is still pending migration 011 and the two server settings. See [verification report](reviews-verification.json).

## Reviews/moderation coverage — 7 October 2026

| Requirement | Implemented behaviour | Verification/status |
| --- | --- | --- |
| Guest submission, private contact, no purchase requirement | Product eligibility; bounded plain fields; all Pending; private email table; no purchase badge emitted | Input units + SQL + Next/Chrome API doubles passed; hosted pending |
| Spam and rate limits | Same-origin/session CSRF, minimum form time, honeypot, SHA-256 duplicates/idempotency, bounded payload/images, atomic IP/global hourly quotas | Local SQL and actual Next rejection checks passed; production trusted-ingress configuration pending |
| Simple admin moderation | Protected tabs, product/name/rating/text/private photos, Approve/Decline/Hide/Edit and plain event history | SQL and Chrome API doubles passed; hosted Auth/RLS/browser pending |
| Private media and real review ownership | `review_id` workflow, no fake catalog/content rows; explicit approval; existing signed Cloudinary service; incomplete approval refused; guarded cleanup | Local SQL/private upload-double/browser preview passed; actual provider review publication/delivery pending |
| Approved-only storefront and ratings | No private contact/paths; eligible approved media; count/average; paging; no sample fallback; refresh invalidation | Two-review averages, edit/decline/hide removal and browser freshness with doubles passed; hosted pending |
| Preserve source/catalog/design | No hosted business writes; canonical installer additive; source assets/reference CSS intact; scoped new product/admin UI | Source checks and fresh installer existing-row snapshots passed; browser screenshots inspected separately |
| Clean migration delivery | One canonical migration, read-only preflight, one complete atomic installer and matching hash | Exact delivered file tested `ON_ERROR_STOP=1`, duplicate declarations/quotes/receipt guard + repeat refusal passed |

No orders, deals, payment, courier or review purchase evidence generation was added. See [review setup](reviews-setup.md) for passed/pending separation. Earlier coverage below applies to preceding stages.

# Requirements coverage

## Content management actual gate complete — 2026-10-07

| Requested live requirement | Result |
| --- | --- |
| Browser create/edit/publish/hide/confirmed delete | Passed against real Next/Supabase |
| Save preserves Draft/Published/Hidden | Passed; no silent visibility change |
| Stale editor and invalid published rollback | Passed; entered text retained and DB unchanged |
| Rich-text sanitation/public freshness | Passed; raw stored HTML checked and public reload fresh |
| Article/homepage private upload and approval | Passed with real Storage/Cloudinary and proper owners |
| Public draft/private isolation | Passed RPC/404 plus positive admin/negative anon/non-admin known-file checks |
| Homepage order, per-slide themes and responsive frame | Passed real RPC/browser and inspected desktop/mobile screenshots |
| Restoration and safe cleanup | Passed;833 baseline rows identical, previous selections exact, images/associations removed, deleted URLs404 |

44 actual checks (25 main,11 permissions,8 cleanup), zero pending; separate from13+10 prior mocked checks. Source64 files/14 CSS blocks intact. No real content/product was published, no migrations rerun and no later commerce stages added. Earlier pending010 rows are historical. See content-live-verification.md and the three actual JSON reports.

Cloudinary actual-provider gate: **14 live checks passed**, separately from **7 mock/pure tests**. Verified private upload/review, signed publication, provider/stored metadata, association/duplicate completion, responsive transformation, referenced-asset protection and cleanup. All three test media assets and associations from all attempts are absent; four synthetic parents remain archived with history. No real catalog import or admin UI. See media-service.md and cloudinary-final-cleanup.json.

Media integration service: private pending uploads/review, authorized signed server uploads, provider/original-byte verification, UUID/environment identity, metadata/lifecycle, multiple images/primary/order/replacement and reference-safe retryable cleanup implemented. Local SQL tests and six mock-provider/resolver tests pass; real Cloudinary verification remains pending configuration and application of migration 007. Account setup, exact variable names and the real development test command are in media-service.md. Admin upload UI and initial SKU image import are explicitly unimplemented next stages; homepage unchanged.

Actual authenticated service gate (2026-10-05): **45/45 passed** for both Auth logins/token identities, admin/non-admin authorization, data-bearing RLS, actual server-only wrapper calls and private Storage known-object isolation. Exact synthetic fixture cleanup verified. No real catalog import, frontend integration or application HTTP session pipeline tested. See supabase-authenticated-verification.md and its JSON evidence; older pending-account statements are historical.

Hosted follow-up: products endpoint now 200; invalid token rejected; anonymous privileged RPC/private-table access denied; private Storage listing empty. Actual admin/non-admin login and object access remain pending credentials configured locally. User-confirmed receipts/RLS/private bucket are distinguished from independently observed HTTP outcomes in first-admin-setup.md and supabase-live-access-checks.json.

SQL Editor preparation: six-migration ordering reviewed; owned-object scope fixed; transactional installer, conflict preflight, postflight RLS/grant checks and cache-reload SQL generated. Destructive/permission-impact review documented in sql-editor-installation.md. Installer/repeat refusal and 54 SQL assertions passed locally. Actual hosted installation, Auth sessions and Storage HTTP checks remain pending user application.

Configured-project follow-up: read-only Auth health reachable (200); products unavailable through PostgREST (404/PGRST205). This does not pass migration, Auth login, role or import gates. No writes performed; environment values remain private.

Supabase service verification follow-up (2026-10-05): actual migrations/Auth/PostgREST/Storage/draft-import HTTP checks are **pending setup**. Docker Desktop launched but engine readiness timed out; CLI registry lookup failed with EACCES. Prior PostgreSQL role assertions passed separately. Source preservation passed again. See [passed-versus-pending matrix and exact steps](supabase-integration-verification.md).

## Database-stage coverage, 2026-10-05

| Requirement | Implementation and verification |
| --- | --- |
| Stable UUIDs, exact unique original SKUs, lossless repeated import | Migrations 001/004; 121 draft imports, repeat no-op, changed-source stock/admin-copy preservation tested |
| Category-specific publication, optional concerns | Contract v1.1.0 and migration 003/006; essential/optional/review-note separation; publication with zero concerns tested; research partially complete |
| Brands, hierarchical categories, typed filters/concerns/evidence | Migrations 001/005; inactive controlled taxonomy seeded; no automatic concern claims |
| Prices/media/publication | Integer PKR minor units; Cloudinary metadata and ordered associations; primary uniqueness and private pending media tested |
| Inventory, reservations, orders/items, deals/components | Migration 002; exact retry keys, shared-component aggregation, consumption/release and insufficient-stock rollback tested |
| Sales/refunds, shipments, reviews, articles, homepage selections, audit | Migrations 001/002/006; immutable financial/audit history, refund limits, approved-review privacy tested; provider execution not included |
| Supabase Auth/admin RLS | SQL anonymous/ordinary/admin cases and self-promotion denial passed; real Auth HTTP/Storage service verification pending |
| Search and indexing | PostgreSQL full-text/pg_trgm and foreign-key indexes; all 121 photo-free drafts admin searchable; public draft search empty |
| Generated types/access/env/setup | Database-derived TS table/enum types, server-only authorized access and secret-free env template; see database-setup.md |
| Preserve frontend and production | No storefront/UI edits or production operations; 64 source files and 14 CSS blocks verified unchanged |

These entries supersede historical rows below that describe the database as pending.

## Catalog import contract request (2026-10-05)

| Requirement | Coverage and evidence |
| --- | --- |
| Latest workbook / lossless source | Supplied top-level workbook hash matches; all five sheets captured with source fields, cell XML/types/styles/formulas/cached values; original XLSX unchanged |
| Complete per-SKU mapping | 121 SKU mappings in `data/catalog-dry-run/sku-mapping.json` and CSV: original/proposed categories, menu family, product type, options/facets, evidence status, corrections, flags and publication requirements |
| Headings / blank rows | HOME APPLIANCES row 125 excluded; 417 blank/template rows excluded; all source cells retained |
| Stable identity and stock | Exact SKU retained; deterministic UUIDs independent of names/rows; all 270 source stock units preserved as pending snapshots |
| Drafts and future admin updates | Versioned reviews, source fingerprints, new/changed/unchanged/absent record handling; field-level change plan; documented admin ownership and independent publication gate |
| Families versus variants | Candidate groups only; no automatic merge; each variant retains SKU/stock; exact package/formula confirmation required |
| Factory packs versus assembled deals | Set candidates retain own SKU inventory; component-consuming deals separately specified; none inferred or created |
| Duplicate isolation | Exact and normalized collisions quarantine only affected records, including prior-SKU collisions; zero collisions found in current workbook; mutation tests cover both |
| Normalized taxonomy | 50 brand candidates with aliases, hierarchical categories, separate menu mapping, typed category-scoped facets and controlled option registries; curated collections remain distinct |
| Recheck every named flag | SB, spaced SKUs, all five Dior oils, AROM, VAS, SNG, CTP, VS and OPI individually assessed in catalog-review-findings.md and per-SKU data |
| Official product research | Evidence registry records exact URLs, findings, retrieval limitations and package matching still needed; no marketplace claims adopted |
| Eight concern groups | Includes Uneven Texture; evidence-supported proposals only; no approved claims inferred from ingredients, barrier support or broad acne terminology |
| Fragrance/body/cutlery facets | Category scope validation; no inferred longevity, set-wide scent profile, face use, cutlery grade or care claims |
| Inactive unsupported options | Every production taxonomy/facet/concern option remains inactive; contract requires published supported inventory before exposure |
| Offline dry run and coverage | Repeatable JSON/CSV outputs and executable tests; no credentials, production import, migration, provider call or app changes |

The admin UI, Supabase schema/RLS and apply/publication services are defined for later stages, not implemented by this preparation stage. Verification is recorded in implementation-status.md.

## Interior layout request (2026-10-05)

| Requirement | Implementation |
| --- | --- |
| Stable category routes | `/skincare`, `/makeup`, `/fragrances`, `/bath-body`, `/cutlery` |
| Separate home scent branch | `/fragrances/home-fragrance`, distinct from `/fragrances/personal-fragrance`; both honestly empty until suitable samples exist |
| Product and brand routes | `/products/[slug]`, `/brands`, `/brands/[slug]`; allowlisted identities and proper unknown-route handling |
| Category listing | Breadcrumb, heading/count, two-per-page preview pagination, GET sorting/brand filters, mobile modal drawer, removable query chips, clear-all, empty/out-of-range states |
| Loading/error states | App Router loading skeleton/status and error boundary with retry; no error details/customer data logged |
| Product layout | Ordered media, supported variant radio, PKR sample price, preview availability, quantity/add-to-bag, details/usage/delivery/review placeholders |
| Honest sample data | Four existing samples only; Ruby is the only supplied shade option; no alternate sizes/shades, secondary angles, stock promises or testimonials invented |
| Editorial | `/the-edit` and three article routes; original sample copy and article-specific colours |
| Guest commerce | `/cart`, `/checkout`; persistence of sample bag, quantity/removal, delivery validation/focus, editable local preview confirmation, configurable empty provider slots |
| Customer care/legal | Customer care, contact, about, FAQs, shipping, returns, privacy, terms; approved contact email, all unapproved policies remain explicit placeholders |
| Accessibility | Labels, breadcrumbs/headings, 44px controls on new layouts, focus-visible styles, native modal focus/escape, first-invalid-field focus, confirmation focus |
| Privacy and access | Noindex retained alongside separate preview authorization; no production data/authentication claim, no real orders/imports |

Completed runtime and visual evidence is recorded in [implementation-status.md](implementation-status.md). These interior pages are restrained design extensions, not separately approved wireframe reproductions.

## Mobile hero and menu update

User-authorized mobile changes supersede exact reference matching for the mobile header and hero. The original source and `/reference` remain unchanged. `mobile.css` overrides only the storefront: below 651px, the hero uses the full supplied image plus a compact live heading/CTA area instead of the fixed 680px gap; all four slides retain their order and controls. At 1050px or below, a three-line toggle opens navigation and category panels, with close, outside click, link selection and Escape handling. Desktop styling remains unchanged.

Verified in local Edge at 320, 390, 650 and 800px: hamburger open/category/back/close; all four mobile hero CTAs clear their controls; no horizontal overflow. The 390px render was visually inspected. Desktop 1440px was also checked. Earlier mobile reference screenshot equality is now historical, not a current acceptance criterion. Physical devices and Safari remain untested. No provider decision or credential blocks this change.

## Homepage footer endpoint update

At the user's request, the Design handoff notes section is now excluded from the generated homepage fixture. The homepage ends at the existing footer. The supplied HTML and development-only `/reference` retain the original notes unchanged. No backend or provider work is involved. Earlier full-page screenshot evidence predates this intentional difference; future comparisons capture `.site` through the footer.

Historical foundation audit on 2026-10-04 found every requirement of the repeated foundation prompt already implemented. No missing application work was added; only this audit record and implementation-status.md were updated. The approved reference and all supplied files remain intact. See the follow-up audit in implementation-status.md for fresh checks versus earlier build/browser evidence.

| Requirement | Status and evidence |
| --- | --- |
| Read repository instructions before work | Complete; fresh root contained only `.git`; no applicable ancestor instructions found |
| Fresh sequence overrides attached historical instructions | Recorded in README and standing docs; original handoff text preserved |
| Locate all supplied source components | Complete; top-level HTML, workbook, nested handoff ZIP and import folder located in original ZIP |
| Verify archive integrity before trust/extraction | Complete; outer/nested/workbook CRC checks passed |
| Compare source hashes before selection | Complete; both pairs identical, zero conflicts; top-level copies selected |
| Required root paths | Complete; `design/reference`, `data/imports`, `public/assets`, `src/config/assets.ts` extracted |
| Preserve originals/backups | Complete; Desktop source unchanged, byte-identical ignored backups retained |
| Keep initial catalog media outside public | Complete; 20 images in ignored `product-images-import/`; only four handoff sample packshots in public assets |
| Verify counts without HOME APPLIANCES heading | Complete; 121 unique SKU products, heading row 125 excluded |
| Exact image mapping, no guessed names | Complete at filename level; 17 exact matches, three unresolved names, no guessed SKU assignments |
| Validate every contract and manifest path | Complete; 38 paths resolve; hashes/dimensions match; no missing paths |
| Verify image readability | Complete; 20 import + 38 handoff files, plus 55 HTML embedded occurrences, decode |
| Inventories and source provenance | Complete; asset/catalog CSVs and source-audit JSON |
| Four standing documentation files and staged plan | Complete |
| Prompt 1 gate: no app or live import | Satisfied at Prompt 1 completion; app now authorized by Prompt 2; no live import |
| Supported pinned dependencies and preserved lockfile | Prompt 2: versions documented in versions-and-scripts.md, exact dependencies and npm lockfile |
| Scoped reference CSS, fonts, tokens and shared layout | Prompt 2: all 14 CSS blocks extracted in source order; storefront scope; system font stacks, header/footer/shell and first hero |
| Typed sample homepage adapter | Prompt 2: isolated server-only fixtures, ordered heroes and article themes; no real catalog access |
| Storefront/admin/server/catalog/media boundaries | Prompt 2: directories and contracts established; admin reserved, not implemented |
| Secure preview and non-indexable development/staging | Prompt 2: fail-closed server Basic authentication outside development; robots, metadata and response headers; production sample guard |
| Development-only reference route and browser tooling | Prompt 2: generated /reference, excluded from production builds; Playwright comparison and production access checks |
| Safe environment and Pakistan site configuration | Prompt 2: names-only .env.example, ignored local secrets; PKR, en-PK, Asia/Karachi, fixed contact, no assumed domain |
| Exact reference structure/responsiveness/interactions | Contract recorded; implementation and visual comparison pending |
| Four heroes, compact card-free The Edit, footer/contact | Ordered hero/article fixtures and final footer/contact established; full slideshow implementation pending |
| Fixed Next.js/Supabase/search/Cloudinary/private Storage architecture | Recorded; implementation pending |
| Stable UUID and unique SKU; admin upload by name/SKU | Recorded; implementation pending |
| Private drafts/media and RLS | Recorded; migrations, configuration and access-denial tests pending |
| Validated production records/prices and per-product publication | Pending catalog integration; counts are not publication approval |
| Samples/mock orders isolated from production | Server-only sample adapter and production guard established; no production data/mock orders integrated |
| Neutral missing-photo placeholders; no fabricated claims | Recorded; unresolved images remain unmapped; UI implementation pending |
| Inventory-backed filters and search | Pending validated published inventory and search implementation |
| Secret handling and explicit production/charge/shipment authorization | Recorded; no credentials, deployment, charges or shipments used |
| Hosting, domain, courier, email and shipping decisions | Open in decisions-needed.md |

See implementation-status.md for verification actually performed per stage. Neither source checks nor a passing build establish full homepage visual fidelity.

## Full homepage request (2026-10-04)

| Requirement | Implementation |
| --- | --- |
| Complete homepage, no Foundation preview | All reference body sections now render on `/`, including the final footer and visible handoff notes; foundation notice removed from the page |
| Exact supplied visual structure | Inert markup fixture and existing scoped 14-block CSS preserve text, whitespace, SVGs, fonts, crops, dimensions and responsive rules |
| Four heroes in original order | React slideshow with arrows, dots, pause, keyboard, visibility and reduced-motion handling |
| Compact card-free The Edit | Three approved article-specific themes, slideshow and complete sample article dialogs |
| Menus/search reveal | Desktop dropdown focus/hover/click controls and category-only sample matching; original mobile nav hiding preserved |
| Categories, products, concerns, brands | Coverflow, three reframings per sample packshot, draggable concern row and looping brand rail; arrows/dots and relevant keyboard/swipe controls |
| Sample shopping interactions | Add, quantity, remove, validated local persistence, empty state, local-only checkout simulation |
| Source preservation | Reference route/template, supplied assets, workbook, imports and asset contract remain unchanged; source hash check rerun |
| Backend boundaries | No live catalog, database, admin, provider, payment, shipment or production deployment |
| Visual and interaction evidence | See implementation-status.md and homepage-visual-checks.json; browser evidence recorded only after actual checks |

## Product administration coverage (2026-10-06)

| Requirement | Implementation / verification |
|---|---|
| Protected admin login/logout and per-operation membership | HTTP-only Supabase session; server Auth + is_admin; CSRF and no-store; live verification report |
| 121 draft SKU import, immutable provenance, idempotency | Existing import RPC; actual development import and repeat passed; stock stays unreconciled |
| Paginated SKU/name search, draft editor, variant identity | `/admin/products`; compatible taxonomy controls; source flags and category-specific report |
| Price, audited stock, visibility and homepage choice | Integer minor units; existing stock RPC; archive/restore-to-draft; draft selections only |
| Verified facets/concerns | Typed category scope and explicit evidence; optional concerns do not block; research partially complete |
| Private upload/review/Cloudinary management | Existing verified service through authorized CSRF-protected endpoints; browser verification tracked separately |
| Initial images | 20-file preview: 17 exact matches, 3 manual assignments required; no automatic approval/publication |
| Storefront and approved design | Unchanged; no database-backed storefront connection |

See `product-administration.md` and `admin-live-verification.json`. A UI implementation entry is not a claim that every control has already passed a live browser/provider test.


## Product admin verification completion (2026-10-06)

Actual results: `admin-live-verification.json` (49 passed events, including retries), `admin-extended-verification.json` (14 passed checks), and `admin-import-audit.json` (ten passed checks). All 121 original SKUs are individually searchable as drafts with preserved raw fields/prices and zero unreconciled live stock. Seventeen exact-match photos are private and unapproved; three unmatched files remain unassigned. Browser Auth/permissions, editing, stock, typed evidence, CSRF and real media publishing/cleanup passed. Ten local security/media tests passed separately; mock transport checks are not claimed as provider verification. Types, lint, build and source preservation passed. No additional migration is pending.

One rejected synthetic image has zero associations but leaves an unlinked Cloudinary asset and private original until the established cleanup guard expires at **2026-10-06T23:53:51.291Z**. Its product is archived; the valid test image was already cleaned up. See `admin-cleanup-verification.json`. After eligibility run:

```powershell
& '.tools/node-v24.21.0-win-x64/node.exe' --conditions=react-server scripts/reconcile-admin-test-media.mjs
```

This verifies the recorded synthetic identity and uses the existing safe cleanup service. It does not touch initial catalog photos. No guard was bypassed; synthetic audit history remains retained.


Final storefront regression: after restarting the local development server, the existing Chrome desktop/mobile-emulation homepage suite passed **6 tests**, with **2 intentional viewport-specific skips**. This includes desktop reference geometry/carousel-state comparison, sample interactions, mobile hero/menu layouts, and motion/swipe behavior. The initial attempt could not connect to the stopped local server; the completed rerun passed. The reference is restored for development and absent from the production build. All 64 supplied source files and the 14 reference CSS blocks still pass integrity checks.

The final read-only import audit now has ten passed checks, including anonymous PostgREST denial for the imported draft products, variants and source provenance, and all 121 individual SKU searches. Admin tests used Chrome with mobile emulation; no real-device Safari test was performed. Core requested live flows passed; multiple-file selection, adding a confirmed variant, and individual primary/order/replacement UI controls were implemented on the existing services but not each independently exercised in this browser run.


## Daily editor revision coverage (current, 2026-10-06)

| Requirement | Implementation | Verification / remaining gate |
|---|---|---|
| Necessary daily fields; optional labels | Name, immutable existing SKU, brand, compatible category/type, description, PKR, stock, status/actions, images and optional homepage toggle | Actual desktop/mobile browser read/render passed |
| No normal research interface | Evidence, raw source, IDs and generic checkboxes hidden; records retained internally | Actual browser terminology check passed |
| Optional variants | Shade/size checkbox and table, Add/Remove, automatic identities; existing products never merged | Atomic SQL save/removal tests passed; actual browser write flow pending migration 008 |
| Easy drafts and valid Publish/Hide | Draft allows incomplete fields; Publish checks actual missing information and conditional package issues, not blanket review tasks | Local SQL rollback/security passed; hosted browser save/publication checks pending |
| Stock-count reconciliation including zero | Immutable audited counts, movement deltas, reserved/stale-count protections and idempotency | Local SQL zero/retry/stale rollback passed; hosted write verification pending |
| Clean image gallery | Upload, explicit Approve image, primary, reorder, replace and remove via existing secured service | Earlier service/provider tests passed; revised UI control exercise pending |
| Technical controls outside daily editor | Separate `/admin/tools`, history and explicit unmatched-SKU assignment | Implemented; no automatic assignment or approval |
| Preserve storefront, catalog and source | No storefront UI/adapter change or real publication; source files retained | 64-file / 14-block integrity passed; 121 live SKU identities searchable |
| Actual single / two-option creation/editing | Dedicated credential-safe synthetic-only Chrome runner prepared | Pending development SQL Editor update; not claimed complete |

Concern research remains partially complete. Missing optional concerns do not block drafts or publication. Prior stage verification entries describe the older UI and must not be used as proof of the revised browser write flows.


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

## Storefront database stage coverage (2026-10-07)

| Requirement | Implementation and verified evidence | Remaining gate |
| --- | --- | --- |
| Published eligible content only; no draft/cost/private media leakage | Safe explicit RPC projection; local anonymous/non-admin/hidden tests passed | Actual hosted RPC visibility tests |
| Category, brand, product and homepage connections | Shared public adapter; bounded RPCs; mock browser rendering passed | Install/expose migration 009; actual selected fixtures |
| Approved responsive media and variant identity | Existing resolver, variant-specific ordered gallery/price/stock, stable UUID bag; mock browser/unit tests passed | Actual integration image delivery and cleanup |
| Assigned taxonomy and supported filters | Scope-specific menus/brands; OR within / AND across, same-variant predicates, disjunctive counts, URL chips, link pagination | Hosted combined-filter assertions |
| Search and useful unsupported alternatives | Indexed FTS + pg_trgm; prefixes, spelling, SKU, approved aliases/concerns; local relevance tests and mocked alternatives passed | Hosted relevance tests; optional research remains partial |
| Bounded requests and fresh edits | Bounded SQL params/pages; request-local deduplication; no public persistent cache; authorized mutation invalidation; local hidden freshness passed | Hosted admin-edit/browser freshness |
| Explicit samples; no silent fallback | Development-only sample flag; empty/outage states; mocked outage test passed | No provider fallback is configured |
| Approved visual language and mobile interactions | Original sources/CSS intact; desktop reference/carousel and mobile regressions plus public-mode mocked screenshots | Physical-device Safari not tested; actual fixture screenshots pending |
| Preserve real data and avoid later-stage work | No hosted fixture mutations while RPC missing; installer additive; no real publication/import or commerce/editorial integration | Actual synthetic preservation snapshot and safe cleanup |

The complete installer and prepared actual-provider runner are reviewable artifacts. This stage's provider completion gate is not marked passed while `storefront_navigation` returns 404. Local PostgreSQL Auth/Storage doubles and mocked browser transport are explicitly distinguished from hosted Supabase/Cloudinary evidence.

### Private search RLS requirement (2026-10-07)

Explicit search-table RLS, zero client policies and revoked direct privileges are implemented in migration 009 and the complete installer. Exact-file disposable verification passed anonymous/non-admin direct denial, independent RLS exclusion under temporary grants, both table-owning SECURITY DEFINER public RPCs and the three final installation checks (`storefront_present`, `aliases_rls`, `search_rls`). The receipt/source hash and exact installer hash are recorded in `storefront-database-verification.json`. No hosted RLS/provider verification is claimed by these local tests; the earlier hosted integration gate remains pending.

### Installer integrity and installation-state safety (2026-10-07)

Complete clean regeneration from canonical migration, duplicate/delimiter validation, exact-file ON_ERROR_STOP execution against fresh 001–008, receipt/hash verification, preflight before/after, business-data preservation, repeat refusal and RLS/owner-RPC tests all passed locally. Evidence: storefront-installer-structure.json and storefront-database-verification.json. Hosted read-only Auth/discovery was performed; private receipt remains inaccessible (PGRST106), so private installation state is explicitly unknown. The read-only SQL Editor preflight is required before installation. No hosted mutation or assumption of empty state occurred.

### Hosted integration completion evidence (2026-10-07)

The user-confirmed read-only installed-state query resolves the migration receipt/version/expected-object/RLS-owner-grant gate. Twenty-one actual Supabase/Cloudinary/Next/Chrome checks passed in `storefront-live-verification.json`, superseding the table's earlier hosted-pending entries for public projection, category/search rendering, combined filters/relevance, variant media/prices/availability, homepage RPC curation, browser bag/mobile interactions and admin-edit freshness. All synthetic products were hidden and images cleaned; 881 baseline rows in 18 catalog/source/media tables were preserved. No real publication/import or later-stage commerce was performed. Mock browser URL/filter/layout evidence and local SQL RLS evidence remain separate. No physical-device Safari or large-catalog load test is claimed.
### Content management stage (2026-10-07)

| Requirement | Implementation and verification |
| --- | --- |
| Simple article CMS and safe deletion | Implemented; local revision/rollback tests and mock browser create/edit/publish/hide/confirmed-delete passed |
| Safe rich text and preserving edits | Server sanitizer on save/read, plain-text paste, stale-save rejection; three sanitizer tests passed |
| Proper article/homepage media owners | Implemented with existing private-review/explicit-approval workflow; local SQL doubles passed; actual provider checks pending010 |
| Published listing/detail, SEO and relevant links | Implemented; mock real-Next/Chrome rendering/404/SEO passed; hosted visibility/freshness pending010 |
| Narrow homepage editorial slideshow | Original layout/animation; manual order and existing sage/warm/blush themes; mock desktop/mobile no-overflow passed |
| Manual homepage products and ordering | Eligible published choices and atomic order; existing positive catalog verification preserved; new RPC hosted tests pending010 |
| Admin/public/private boundaries | Existing admin sessions/CSRF/no-store reused; local anon/non-admin denial and thirteen unit checks passed; hosted CMS checks pending |
| Preserve reference/design/source inputs | 64 original files/14 CSS blocks intact; reference absent from production; browser regression separately reported |
| Actual synthetic provider/browser verification | Runner prepared, safely stopped at missing content RPC; zero hosted CMS fixtures created; NOT completed |

Concern research remains partially complete from prior catalog stages. This stage assigns no new suitability claims and publishes no invented business articles. No orders, deals, reviews or payments.

Final visual/security checks (2026-10-07): original homepage comparison and all hero/editorial carousel states passed; desktop/mobile navigation, sample flows and mobile hero/hamburger passed. Eight applicable checks passed across runs, two intentionally skipped. Screenshot-heavy tests needed a larger Windows time budget, with every assertion retained. Ten additional public CMS mock checks passed after scoped article-cover framing correction; mobile article/homepage/admin screenshots and matching reference/React editorial snapshots were inspected. Actual new Next content API rejects anonymous GET401 and CSRF-less POST403 with private/no-store; development reference returns200. No hosted CMS DB/provider operation was added. See content-local-verification.json.

## Product content / admin usability coverage (2026-10-08)

| Requirement | Implementation / evidence | Remaining |
| --- | --- | --- |
| Three Markdown fields; exact preservation | Existing description/usage, optional key_benefits, unchanged-field omission; disposable SQL and browser doubles | Hosted 012 application/save checks |
| Safe Write/Preview and public rendering | Escaped React nodes; safe href allowlist; no arbitrary images; unit + Chrome checks | Physical Safari untested |
| Optional usage/benefits | Hidden when empty; publication blockers unchanged; existing publication tests pass | None in local contract |
| Simple responsive admin workflows | Navigation, summaries, server visibility filter, sectioned editor, optional variant rows, preview/dirty guards/progress | Hosted final UI checks after 012 |
| Existing stock/status/security | Original atomic save logic retained; SQL RLS/visibility/zero-count/stale rollback tests | Hosted final save regression |
| Articles/homepage/reviews | Scoped redesign and Chrome workflow doubles; no business-content conversion | Reviews hosted providers pending 011/settings |
| Approved storefront/source preservation | Original source hash contract; desktop/mobile homepage comparisons | No new design approval claimed |

Concern research remains partially complete; optional concerns are never a blanket publication requirement.


### Hosted review/product-content completion (2026-10-08; supersedes pending entries above)

| Requirement | Actual hosted evidence | Remaining |
| --- | --- | --- |
| Review submission, private uploads and authorization | Real customer/admin Chrome, Supabase Auth/Storage; anonymous/non-admin reads denied | None for requested development flow |
| Approve/Decline/Hide, re-moderation and public freshness | Actual server mutations and public reload/RPC checks | None |
| Cloudinary approved images and ratings | Real publication/delivery decoded; counts/averages include only approved eligible reviews | None |
| Three Markdown fields and safe rendering | Exact persistence and untouched preservation, real Write/Preview/public mobile rendering | Physical iOS Safari untested |
| Single/two-variant status and stock safeguards | Published/hidden preserved; invalid-publication rollback; zero/exact counts; removed option history retained | None for requested cases |
| Preserve business data/assets | 923 rows/25 tables unchanged; 121 SKUs searchable; 64 originals/14 CSS blocks intact | None |
| Safe synthetic cleanup | Reviews/products hidden, taxonomy archived, provider files removed; audit retained | No pending fixture cleanup |

58 actual checks passed, separately from 19 unit/security tests and earlier mocks. User-confirmed installed migrations were not rerun. See reviews-product-content-hosted-results.md and reviews-product-content-live-verification.json. Optional concerns remain non-blocking and concern research remains partially complete.


## Admin product list (2026-10-09)

| Requirement | Evidence | Remaining |
| --- | --- | --- |
| All-status assigned search/aliases/variants | Private SQL index and local typo/combination/alias tests; matching labels in Chrome | Hosted 013 fixture run |
| Combined taxonomy/facet/concern filters and pages/counts | Same-option SQL OR/AND, hierarchical categories, 25-SKU UI pages; fourteen browser-double checks | Hosted 013 fixture run |
| Required vs optional missing information and stock states | Derived scoped issues; archived options excluded; confirmed zero distinct from uncounted | Hosted fixture run |
| Ignore/Undo/Restore/recurrence | Episode-based private state, SQL revision/content preservation, browser persistence/restore | Hosted fixture run |
| Needs attention any/all and ignored view | Exact underlying unresolved-issue SQL matches/counts; no publication bypass | Hosted fixture run |
| Authorization/private isolation | SQL anonymous/non-admin denial, private no-policy RLS, Next CSRF/no-store | Actual hosted access checks recorded separately |
| Source/design/business preservation | Exact installer preserves rows; 64 originals/14 CSS blocks intact; scoped admin-only styling | Real hosted rows have not been mutated |

Concern research remains partially complete and no suitability assignment is inferred by search. Optional content/concerns never become blanket publication requirements.

Final actual browser access evidence: four checks passed (anonymous list denial, non-admin login denial, admin Auth login, CSRF-less dismissal denial). New list RPC still unavailable; the guarded runner stopped before fixtures, with zero hosted catalog mutations. Actual synthetic search/filter/stock/reminder/pagination verification remains pending migration 013; do not interpret local SQL or Chrome provider doubles as hosted results. Production boundary checks passed. Evidence: admin-list-live-verification.json and admin-list-verification.json.


## Pending 013 correction coverage (2026-10-11)

| Requirement | Verification | Remaining |
| --- | --- | --- |
| Consistent list/options categories and active options | Shared views; additional/primary descendants, excluded removed options, representative archived row, every offered value matches list | Hosted after 013 |
| Variant insert/update/delete and ownership | SQL search refresh, old-word removal, both-owner reminders, last-option row/blocker, zero SKU count | Hosted after 013 |
| Media freshness | Existing workflow RPCs with synthetic metadata; private completion, approval, failed publish/retry, linking, primary change, detach, owner changes and workflow deletion | Actual providers not invoked in this revision |
| Fix/recurrence and dismissal safety | Product-content and image issues, fresh occurrence UUID, dismissals not carried to recurrence; existing revision/publication tests | Hosted after 013 |
| Private access | Anonymous/non-admin RPC and direct table/shared-view denial on real local PostgreSQL roles | Hosted Auth/PostgREST remains pending |
| Exact clean installer and preservation | Fresh 001–012, ON_ERROR_STOP=1, 29 targeted assertions plus existing regressions, 19 final flags true, matching file hash, business rows unchanged, repeat refused | Owner read-only preflight/application |

No hosted setup was modified and no next stage began. Source/reference integrity, lint and TypeScript were checked; no new visual-fidelity claim is made by these SQL checks.


## Actual hosted admin-list coverage (2026-10-11)

| Requirement | Actual verification | Remaining |
| --- | --- | --- |
| Smart search and variants | Assigned combinations, prefix/typo/trigram variation, name edit freshness, alias plus shade, unsupported suitability empty | Exact alias alone can return a sibling SKU; precision fix pending |
| Combined/additional-category filters | Hosted AND/OR and ancestry checks plus real UI brand/category/facet controls and accurate count | None for tested fixtures |
| Pagination/counts | Bounded disjoint hosted pages plus real browser Next/Previous flow | Production-scale load untested |
| Badges and stock | Browser required/optional badges, uncounted versus reconciled zero, archived-option exclusion | None for tested fixtures |
| Ignore/Undo/Restore and recurrence | Real UI reload persistence/Undo/Restore; content/revision/stock preserved; recurrence restores; publication still blocked when invalid | None for tested fixtures |
| Authorization/freshness | Real Auth, anonymous/non-admin RPC/Next restrictions, CSRF, private API denial, no-store; actual browser save and media-removal freshness | Owner's SQL RLS flags trusted; no SQL rerun |
| Cleanup/preservation | 29 tables/1,211 pre-existing row hashes unchanged, homepage preserved, four fixtures archived, two images deleted, zero anonymous-visible fixtures | Private audit/import/inventory histories retained intentionally |

49 live checks passed, separate from prior mock/disposable tests. Admin desktop/mobile screenshots inspected; physical Safari untested. Source assets/reference CSS unchanged. No commerce stage or hosted installer run. Detailed evidence: admin-list-hosted-results.md.


## Exact SKU/alias precision gate (2026-10-12)

| Requirement | Passed | Pending |
| --- | --- | --- |
| Original/normalized/accepted SKU alias isolates owner option | Exact complete incremental installer and targeted SQL regressions | Hosted fixed behavior after 014 application |
| Combined filters exclude exact match without fuzzy fallback | Category/brand/type/facet/status local regressions | Hosted post-install checks prepared |
| General typo/partial assigned-data searches preserved | Local regression plus actual hosted Next/Chrome checks | Recheck after 014 |
| Immutable SKUs and collision safety | Existing guards unchanged; local mutation/collision denial | None locally |
| Applied 013/storefront/business records preserved | Hashes unchanged; 64 source files/14 CSS blocks intact; hosted preservation/cleanup | None for checks performed |

Actual pre-fix reproduction, local Auth/Storage doubles and post-install pending checks are separated in admin-exact-search-results.md. Commerce has not begun.


## Exact identifier hosted completion (2026-10-13)

| Requirement | Actual hosted/browser verification | Remaining |
| --- | --- | --- |
| Exact original/normalized/spaced SKU and accepted alias isolation | Each query returns only correct option against close siblings; original SKU preserved | None for tested cases |
| Matching/excluding combined filters, no fuzzy fallback | Brand/category/type/facet matches; excluded facet/status/category/brand and spaced-SKU facet return zero | None for tested cases |
| General typo/partial assigned searches retained | Real CeraVe-style typo, partial identifier and OR facet queries pass | Production-scale load untested |
| Actual browser/security flow | Desktop/mobile viewport option rows; Auth/roles/private API/CSRF/no-store pass | Other engines/physical devices untested |
| Preservation/cleanup | Checked existing rows and homepage selections unchanged; all synthetic fixtures archived, anonymous reads empty; approved assets unchanged | Private history retained intentionally |

41 live checks passed, distinct from historical disposable tests. Prior fixed-hosted checks marked pending are now resolved. No installer executed, storefront integration change or commerce stage. Evidence: admin-exact-search-hosted-results.md/json.


## Inventory/cart/guest orders stage (2026-10-13)

| Requirement | Implemented / checked | Pending |
| --- | --- | --- |
| Real variant bag and persisted changes | Server quote, eligible IDs/current minor prices/stock, notices, removal/reload; mock desktop/mobile UI | Hosted commerce quote after 015 |
| Guest checkout/settings/snapshots | Pakistan mobile + bounded fields, optional email/note, explicit settings gate, server totals and immutable SKU/customer/shipping snapshots | Business-approved configuration; hosted form placement |
| Reservations/idempotency/expiry | Shared ordered locks, all-line allocation integrity, retry conflicts, accepted infinite COD, temporary expiry, release/consume once; local SQL + two-session race | Actual provider race/expiry and maintenance scheduling |
| Payment/dispatch safeguards | Unpaid holds cannot Confirm/Dispatch; missing/partial/inactive/component/counter/lifecycle inconsistencies fail closed; consumed history checked | Hosted tests after corrected installer |
| Simple order admin and privacy | Search/date/status paging, private details/history, Auth/CSRF/no-store, stale/idempotent actions; real boundary + local RLS tests | Hosted admin actions/guest isolation |
| Preserve approved design/data | Original files/CSS intact, geometry/mobile tests, 20/23 pixel-identical pairs; no real hosted writes | Existing preview-search/transition differences noted, not a full-fidelity claim |

Local Auth/Storage/media doubles, 14 mocked UI checks, and partial actual service checks are distinguished in commerce-verification.md. Owner requested pause for application; do not rerun old installers or start later stages.

## Manual advance payment correction coverage (016)

| Requirement | Implementation / verification |
| --- | --- |
| Bank Transfer / Easypaisa / JazzCash only, owner receiving details | Server configuration; incomplete/disabled methods excluded; unit and mocked checkout checks |
| Awaiting payment, exact deadline, private submission | Atomic placement wrapper, secure same-browser order access, private UUID proof workflow; local SQL + mocked desktop/mobile; hosted lifecycle pending 016 |
| Assisted manual review, no automatic Paid | Actual-history checkbox + exact cumulative funds; simple four-state queue and three actions; immutable receipts/actions; local SQL/permissions + mocked review UI |
| Mismatch / scoped reference / identical proof flags | SQL flags, unique receiving-account/reference and advisory locks; normalized PNG SHA-256; local SQL/unit tests, hosted provider tests pending |
| Bounded review, expiry, late receipt and atomic stock race | Existing scheduled expiry + one-time bounded extension; receipt survives stock shortage; sorted-lock reallocation; local two-session race |
| Private proofs, owner/admin only, no Cloudinary | RLS/SQL ownership/publication guards + per-read server authorization; local doubles/unit and actual hosted read-only denial checks; real Storage roundtrip pending installation |
| Existing data/design preservation | Nonempty legacy order/catalog/inventory hashes around exact installer; 64 original files/14 CSS blocks verified; no hosted fixtures/SQL changes; approved homepage code/assets untouched |
| Honest verification scope | manual-payments-local-verification.json, manual-payments-ui-mock-verification.json, manual-payments-admin-ui-mock-verification.json, manual-payments-live-readonly-verification.json |

No real funds, gateway/API, OCR, statement imports, refunds, deals, reporting, courier or deployment implemented. Missing owner settings keep normal checkout unavailable.

## Manual commerce hosted coverage resolved (2026-10-15)

The owner confirmed 016; all previously pending hosted lifecycle areas now have actual Chrome/Next/Supabase/Storage evidence in manual-payments-hosted-results.md/json, separate from historical mocks/local SQL doubles. Coverage includes three service selections; fresh desktop/mobile checkout; authoritative totals/fees/accounts; secure confirmation/reload; private upload/retry and owner/admin-only access; submission/correction/rejection; acknowledgement-gated receipts; partial/overamount and duplicate image/scoped-reference flags; verification retries; unpaid fulfilment denial; last-unit and late-allocation/reference races; rollback; bounded actual review/expiry; cancellation release; dispatch once/completion no extra deduction. Cleaned fourteen orders' active allocations, three private files/two public test images; retained audit history. All original row/source/homepage checks passed. Real checkout and incomplete methods stay disabled. Remaining business/scheduler/retention setup is documented; no deals/reporting/courier stage started.


## Assembled multi-product deals (017)

| Requirement | Implementation / verification boundary |
| --- | --- |
| Simple Draft/Save/Publish/Hide, exact shades/SKUs/quantities, dates/price/home order | Admin Deals, existing smart catalog search and homepage controls; real browser with synthetic intercepted responses. Ordinary visibility retained; stale edits/idempotency guarded in SQL. |
| Distinct deal media, approval, alt/primary/order/replacement/retry | Shared server service + own deal associations/private workflows; SQL provider-metadata doubles and mocked Chrome upload UI. Actual hosted Storage/Cloudinary pending 017. |
| Shared stock, floor availability, repeated SKUs, optional allocations | Real disposable PostgreSQL tests; pooled counters, audited generation/transfer/release; no physical deduction for carts/pools. |
| Mixed cart rollback, single-unit competition, two deals, late stock race | Real independent PostgreSQL sessions and transactional assertions; hosted races pending. |
| Frozen price/composition and exact component attribution | Immutable snapshots, allocation assertions; SQL edits after order and dispatch/completion tests; manual-payment regressions retained. |
| Eligible public listing/detail and manual homepage cards | Bounded RPCs/pages, approved resolver/card template, no public draft/private fallback; existing CSS/approved inputs preserved. Hosted public projection/media freshness pending. |
| Auth/CSRF/privacy and cleanup | Existing actual Next/admin/non-admin read-only checks; SQL anonymous/non-admin denial; no hosted fixtures created. Disposable race reservations released, audit retained; cluster stopped. |
| Scheduling and business settings | Executable commerce maintenance extended for deal allocation expiry; external scheduler and owner-approved checkout configuration remain pending. Real checkout remains disabled. |

No previous applied migration was edited/rerun. See deals-setup.md and the separate local/mock/live evidence files for final check results and remaining hosted scope.


## Actual deals coverage update (2026-10-18)

| Requirement | Actual state |
| --- | --- |
| Installed deal security audit | Owner read-only audit confirms seven RLS tables, exact policies, six private tables and RPC matrix; 018 correction installed, all seven flags true. |
| Admin/private isolation | Actual browser Auth/login denial, CSRF/no-store, anonymous/non-admin protected RPC denial and private schema isolation passed. |
| Public RPC availability / checkout gate | Deals and commerce quote HTTP 200; normal checkout remains disabled. |
| Existing media-policy compatibility | Actual 42501 failure reproduced on five tables for all three roles; narrow incremental 019 exact-file local regression passed; hosted application pending. |
| Hosted deal media/CRUD/homepage/inventory/payment races | Pending 019; stopped before fixture creation, no success claimed. Prior mocks/local database coverage remains separate. |
| Preservation | No hosted business writes; 64 original files and 14 reference CSS blocks verified; no storefront changes. |

See deals-hosted-results.md for the exact installer/hash and tested/pending boundaries.


## Deals hosted completion (2026-10-18)

Supersedes hosted-pending entries above. Actual hosted/browser coverage is complete for the requested deal flows: 98 main observations, 35 independent cleanup/reconciliation checks and 3 loaded-editor desktop/mobile checks passed. Admin CRUD/visibility/stale guards, own private media/explicit approval/Cloudinary delivery, public/homepage order, mixed authoritative checkout, shared component races/rollback, pools and generation-aware returns, native expiry, late payment races/resolution, immutable snapshots and single consumption all passed. Owner confirms 018/019; all corrected media-policy reads work and authorization remains enforced.

No mocked requests used in those observations. Earlier SQL/unit/intercepted UI tests remain separate. All 1,416 baseline rows across 40 tables/owner homepage selections preserved; fixtures hidden/archived, five assets cleaned, nine order histories retained, no active pools/reservations and global reconciliation zero. All approved source inputs/reference CSS intact. Full pixel suite/build not rerun in this verification-only pass; physical devices/other engines/load untested. External scheduler and approved business configuration still pending; real checkout disabled. See deals-hosted-results.md.


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


## Prompt 18 — Staging/local acceptance and launch readiness (9 November 2026)

### Homepage vs approved reference — desktop/tablet/mobile, equivalent slide states

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| Desktop 1440×1000 full-page geometry equals `/reference` | `src/components/storefront/` unchanged; `tests/browser/homepage.spec.ts` compares section dimensions, fonts, backgrounds | `npm run test:browser` desktop: PASS (44/47 pixel-identical; 3 image-region variations documented) | None (local) |
| Four hero slide states | `.hero-dot` carousel navigation | `homepage.spec.ts` desktop: PASS | None |
| Three Edit theme slides | `.edit-dot` navigation | `homepage.spec.ts` desktop: PASS | None |
| Five category corner states | `.corner-dot` navigation | `homepage.spec.ts` desktop: PASS | None |
| Three product gallery crops | `.gallery-dot` navigation | `homepage.spec.ts` desktop: PASS | None |
| Search reveal + bag drawer states | search fill + bag open/close | `homepage.spec.ts` desktop: PASS | None |
| Five visible desktop menus | `.category-toggle` focus + menu screenshot | `homepage.spec.ts` desktop: PASS | None |
| Mobile hero every slide (320/390/650/800) | mobile viewport loop | `homepage.spec.ts` mobile: PASS | None |
| Mobile hamburger category nav | open → panel → close → Escape | `homepage.spec.ts` mobile: PASS | None |
| Reduced motion — carousel pauses on slide 0 | `reducedMotion: 'reduce'` config + carousel guard | `homepage.spec.ts` motion test: PASS | None |
| Three-viewport overflow / images / links / alt / focus | `tests/browser/three-viewport-homepage.spec.ts` | RUNNING (server on 3100) | None |
| Known pre-existing difference | `scripts/compare-homepage.py`: search-state region mean diff 0.182271 > 0.15 | Documented existing, not a regression | None |

### Discovery, search, variants, galleries, cart, checkout

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| Category/brand/concern discovery | Public navigation RPC; mock UI renders cards/filters/chips | `verify-storefront-ui-mock.mjs`: PASS | None (mock) |
| Search | Public catalog RPC; unknown slug → real 404 | `verify-storefront-ui-mock.mjs`: PASS | None |
| Variant selection | Option switch updates price/image/availability; disables bag when out of stock | `verify-storefront-ui-mock.mjs`: PASS | None |
| Product galleries | Mock media resolver; neutral fixtures | `verify-storefront-ui-mock.mjs`: PASS | None |
| Cart | Persists across reload; current prices, no trusted totals | `homepage.spec.ts`; `verify-commerce-ui-mock.mjs`: PASS | None |
| Checkout | Server totals; fitting viewport 1440/390; payment methods labelled DO NOT PAY | commerce + manual-payments mocks: PASS | Test/provider mode config only |

### Admin product edits, signed uploads, initial SKU import

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| Create draft / edit Markdown / preserve legacy CRLF | `src/components/admin/ProductEditor.tsx`; mock RPC preserves fields | `verify-admin-refresh-ui-mock.mjs`: PASS | None |
| Markdown preview safe (no script/img/javascript links) | `ProductEditor` preview sanitization | `verify-admin-refresh-ui-mock.mjs`: PASS | None |
| Ordinary save preserves visibility | `src/lib/server/admin/catalog.ts` save-product action | `verify-admin-refresh-ui-mock.mjs`: PASS | None |
| Visibility filter sent to provider | `adminCatalogList` status filter | `verify-admin-refresh-ui-mock.mjs`: PASS | None |
| Two-variant SKU/price/stock/labels | Variant save RPC | `verify-admin-refresh-ui-mock.mjs`: PASS | None |
| Signed uploads — private pending → explicit approval | Media service; private Storage; Cloudinary publish on approval | `verify-admin-refresh-ui-mock.mjs`; deals mock: PASS | Cloudinary dev account (mocked here) |
| Initial SKU import — no stock reset on reimport | Deterministic, idempotent import; preserves edits/prices/live stock | `tests/test_catalog_import.py`: 13 tests PASS; import contract | None |

### Article publication / selection

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| Create / edit / publish / hide / confirmed delete | Content CMS RPCs; lifecycle status transitions | `verify-content-ui-mock.mjs`: PASS (10/10) | None |
| Draft → publish → archive | `save_article` intent handling | `verify-admin-refresh-ui-mock.mjs`: PASS | None |
| Homepage manual selection + theme colour | `save_homepage_content` with slide_theme | `verify-admin-refresh-ui-mock.mjs`: PASS | None |
| Article preview without publishing | Draft preview dialog | `verify-admin-refresh-ui-mock.mjs`: PASS | None |

### Review moderation

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| Guest submission → Pending, not public | Bounded form; CSRF; honeypot; idempotency; quotas | `verify-reviews-ui-mock.mjs`: PASS | None |
| Approve / Decline / Hide workflow | Protected moderation API; status transitions | `verify-reviews-ui-mock.mjs`: PASS | None |
| Public page isolates pending review | `publicReviews` shape validation + `Array.isArray` guard | Fix applied during Prompt 18; `verify-reviews-ui-mock.mjs`: PASS | None |
| Private contact / purchase badge absent | No private contact emitted on public page | `verify-reviews-ui-mock.mjs`: PASS | None |

### Shared-stock deals

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| Admin deal create / save / publish / hide | Deal RPCs; status transitions | `verify-deals-ui-mock.mjs`: PASS | None |
| Deal media private pending → approve | Own media workflow; explicit approval | `verify-deals-ui-mock.mjs`: PASS | None |
| Mixed cart with deal + component | Typed line identities; expected revision/price | `verify-deals-ui-mock.mjs`: PASS | None |
| Confirmation keeps deal component snapshot | Frozen deal attribution | `verify-deals-ui-mock.mjs`: PASS | None |
| Anonymous deal API denied / CSRF denied | Auth + CSRF guards on `/admin/api/deals` | `verify-deals-ui-mock.mjs`: PASS | None |

### Order dispatch / completion / refunds / tracking

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| Exactly-once completion; separate receipts/shipping/cash | Order/idempotency wrapper; immutable snapshots | reports mock + hosted financial verification (historical): PASS | None |
| Full / partial-value / item / shipping / overpayment refunds | Private refund ledger; bounded amounts | reports mock: PASS | None |
| Damaged return separate from money | Inspected stock returns; no overpayment classification | reports mock: PASS | None |
| Explicit outgoing-history confirmation | Manual Sent confirmation | reports mock: PASS | None |

### Security and boundary verification

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| No production secrets in browser bundles | Server-only wrappers; `NEXT_PUBLIC_*` only for publishable keys | Bundle scan PASS; `.env` `NEXT_PUBLIC_SUPABASE_SECRET_KEY` flagged as hazard (remove before prod) | None |
| No public draft/review media | `public/assets/`: 38 approved images only; no draft/review/private/order files | File audit: PASS | None |
| No customer order exposure | `adminSession` + CSRF; anonymous/non-admin denied | Unit tests: PASS | None |
| No sample order data in live reporting | Business/test report scopes explicit | reports mock: PASS | None |
| No stock reset on reimport | Idempotent import; repeat = no-op | `tests/test_catalog_import.py`: PASS | None |
| No accidental real shipment/payment calls | Real checkout disabled; all payment methods "DO NOT PAY" | Commerce config: PASS | None |

### Accessibility, motion, focus, overflow, broken links/images

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| Reduced motion | Playwright config `reducedMotion: 'reduce'`; carousel guard | `homepage.spec.ts` motion test: PASS | None |
| Focus traps / tab navigation | Keyboard navigation checks | `three-viewport-homepage.spec.ts`: PASS | None |
| Responsive overflow (document level) | Intentional scroll rails excluded; document chrome checked | `three-viewport-homepage.spec.ts`: PASS | None |
| Broken images | Decode-all + `naturalWidth === 0` check | `three-viewport-homepage.spec.ts`: PASS | None |
| Missing alt text | `alt` attribute audit | `three-viewport-homepage.spec.ts`: PASS | None |
| Broken links | HEAD/GET status audit on same-origin links | `three-viewport-homepage.spec.ts`: PASS | None |

### Project checks and unit suites

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| `npm run check` (sources + lint + typecheck + build) | `verify-sources.mjs`; ESLint `--max-warnings=0`; `tsc --noEmit`; `next build` | PASS | None |
| `npm run test:production` | Production boundary: preview fails closed; noindex/asset protection | PASS | None |
| `npm run test:seo` | Staging noindex + approved robots/sitemap + launch gate | PASS | None |
| Unit suites (16 react-server + 18 Node + 13 Python catalog import) | `tests/*.test.mjs`; `tests/test_catalog_import.py` | PASS | None |

### Launch-readiness report

| Requirement | Implementation | Tests / evidence | External setup |
|---|---|---|---|
| Concrete readiness report with pass/fail evidence | `docs/launch-readiness.md` | This document | None |
| Hosting instructions without vendor choice | Environment variable names (no values); domain/HTTPS/SEO; migration/backup; inventory/media monitoring; provider limits; recovery/rollback | `docs/launch-readiness.md` section 8 below | None chosen |
| Backups/restoration — documented business-data test | Docker/Postgres unavailable; documented as blocked | `.local/database-test-*` artifacts exist; test blocked | PostgreSQL + Docker |
| Media restoration — separate retention plan | Documented in readiness report | `docs/launch-readiness.md` section 8 | None |
| Publish only ready records; launch not gated on 100% catalog | Zero published records expected pre-launch | Hosted RPC probe: 0 records (expected) | None |
| No production launch claim | 503 gate unchanged; `APP_ENV=production` + `SEARCH_INDEXING=approved` required | `src/proxy.ts`; `npm run test:production`: PASS | None |


### 7a. Two-stage order verification workflow (new, 12 November 2026)

| Requirement | Implemented behaviour | Verification/status | External setup |
|---|---|---|---|
| Orders start in `pending_verification` state | `public.orders.order_status` column with check constraint; `commerce_orders.payment_status='awaiting_payment'` | Migration `202611120022_two_stage_order_verification.sql` created; lint/typecheck/build pass | Hosted Supabase migration not yet applied |
| `transaction_id` with UNIQUE constraint | `public.orders.transaction_id` column, UNIQUE, prevents duplicate TID/receipt reuse | Same migration; typecheck passes | None |
| Customer checkout: order ID + account details | `ActualCheckout.tsx` places order, shows order number; `PaymentSubmission.tsx` shows account details with copy buttons | Lint/typecheck/build pass; manual inspection | Commerce config (`COMMERCE_ENABLED`, `COMMERCE_CONFIG_JSON`) |
| Customer checkout: required TID + proof | `PaymentSubmission.tsx` — reference (min 3 chars) and proof image (max 5 MiB) are required before submission | Lint/typecheck/build pass | None |
| Proof images stored privately | Supabase private Storage (`catalog-private`), `payment_proof()` RPC, `media_workflows` with `payment_order_id` | Already existed — verified in prior stages | Supabase Storage bucket |
| Admin verification panel: side-by-side view | `OrderAdmin.tsx` — order total, transaction reference, proof image link in verification grid | Lint/typecheck/build pass | None |
| Admin Approve → `paid`, stock deducted | `public.confirm_order_payment()` RPC — transitions to paid, consumes inventory, records receipt | Typecheck passes; not yet tested against hosted DB | None |
| Admin Reject → `rejected`, stock released | `public.reject_order_payment()` RPC — transitions to rejected, releases inventory | Typecheck passes; not yet tested against hosted DB | None |
| Auto-expire unpaid orders | `scripts/commerce-expiry-cron.mjs` — calls `expire_commerce_holds()` RPC, intended for cron/scheduled job | Script created; not yet scheduled on hosting | Cron/scheduler on hosting provider |


### 8. Hosting instructions (provider-agnostic)

#### Environment variables (names only — no values)

| Variable | Purpose | Where set |
|---|---|---|
| `APP_ENV` | `development`, `staging`, or `production` | Hosting env config |
| `SITE_URL` | Canonical HTTPS origin for SEO/metadata/sitemap | Hosting env config |
| `STOREFRONT_DATA_MODE` | `supabase` for connected catalog; `sample-preview` only in local dev | Hosting env config |
| `SEARCH_INDEXING` | Must be `approved` for indexing activation | Hosting env config |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL | Hosting env config |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Supabase anon/publishable key (client-safe) | Hosting env config |
| `SUPABASE_SECRET_KEY` | Server-only service key — NEVER in browser code | Server env only |
| `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | Media upload/delivery (server-only for secret) | Server env only |
| `REVIEW_SESSION_SECRET` | Review session signing (server-only) | Server env only |
| `COMMERCE_ENABLED` / `COMMERCE_CONFIG_JSON` | Commerce feature flag and test config | Server env only |
| `COMMERCE_TRUSTED_IP_HEADER` | Trusted ingress header for client IP | Server env only |
| `MEDIA_ENVIRONMENT` | Media environment marker | Server env only |
| `NEXT_TELEMETRY_DISABLED` | Disable Next telemetry | Hosting env config |
| `PREVIEW_USERNAME` / `PREVIEW_PASSWORD` | Shared staging preview credentials (≥32 random chars) | Secure server config only |

**Never commit** secret values (`*_SECRET_KEY`, `CLOUDINARY_API_SECRET`, `REVIEW_SESSION_SECRET`, `PREVIEW_PASSWORD`) to the repository or to `NEXT_PUBLIC_*` variables.

#### Domain / HTTPS / SEO configuration

1. Set `SITE_URL` to the production HTTPS origin (e.g. `https://www.example.com`).
2. Set `APP_ENV=production` and `SEARCH_INDEXING=approved` **only** after explicit launch authorization.
3. Until the four-part gate (`NODE_ENV=production`, `APP_ENV=production`, `SEARCH_INDEXING=approved`, valid HTTPS `SITE_URL`) passes, all public responses emit `noindex, nofollow, noarchive`; `robots.txt` disallows crawling; the sitemap is empty; the storefront returns 503 (`src/proxy.ts`).
4. Configure HTTPS at the hosting boundary (TLS termination at the provider or reverse proxy).
5. SEO is environment-gated in `src/lib/seo/site.ts`; no canonical/OG/sitemap URLs are emitted until the gate passes.
6. Slug-redirect migration (`supabase/migrations/202611090001_seo_slug_redirects.sql`) must be applied to hosted Supabase before launch if slug redirects are needed.

#### Migration / backup procedure

1. Apply migrations in order (001 → latest) using the hosting provider's SQL editor or a `psql` connection; never rerun an already-applied installer.
2. Run each migration's read-only preflight first; confirm all presence/receipt flags are false before applying.
3. **Backups:** Take a logical backup (`pg_dump` of the business schema) before any migration and before launch. Verify the backup restores to a disposable database — this is the required documented business-data restore test. Docker and `psql`/`pg_restore` are currently unavailable in this environment; the test is blocked until those tools are available.
4. Keep migration receipts/hashes; do not append patches to applied files.

#### Media restoration — retention plan

1. Public media (Cloudinary): retention is governed by the provider; keep a manifest of `publicId`/`version` pairs for re-upload if needed.
2. Private media (Supabase Storage): include Storage buckets in database backup windows; document a separate restore path (re-upload from the private original manifest) because Storage restore is independent of database restore.
3. Review media: private until explicit approval; cleanup guard retains unlinked assets until expiry.

#### Inventory / media job monitoring

1. Monitor the `commerce:maintenance` job (deal allocation expiry, reservation release) — must run on an independent scheduler (not yet deployed).
2. Monitor import jobs: repeat imports must be no-ops; alert if stock counts change unexpectedly.
3. Monitor media upload/approval queues: private pending media awaiting explicit approval.

#### Provider limit considerations

1. Serverless/function timeouts: long-running catalog imports and media uploads may exceed function limits; use background jobs or increase timeout.
2. Database connection limits: pool connections; avoid connection-per-request patterns.
3. Storage/CDN bandwidth: image payload ~1,016 KB per homepage load; plan for edge caching.
4. Supabase row/RLS limits: monitor RLS policy evaluation on private tables.

#### Recovery and rollback boundaries

1. Rollback: revert the application code to the previous deployment; database migrations are forward-only (do not rerun installers to roll back).
2. Business data: never truncate or reset production tables; restore from verified backup if corruption occurs.
3. Media: re-upload from the private original manifest if Cloudinary/Storage assets are lost.
4. Production launch gate (`src/proxy.ts`) returns 503 until explicitly authorized — this is the rollback boundary if issues are detected post-launch.
5. No real payment/shipment provider is connected in test mode; enable only after provider credentials and flows are approved.



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
