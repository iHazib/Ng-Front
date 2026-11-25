## Customer reviews â€” implemented, hosted installation pending (7 October 2026)

Customer submission remains inside Next.js, with a narrowly scoped server-only Supabase secret-key gateway. Guest sessions are signed, same-origin/CSRF checked, and rate keys are HMACs of trusted client addresses; SQL enforces atomic quotas and published-product eligibility. Public/non-admin clients cannot call submission/finalization RPCs directly. Admin requests retain the existing verified Auth/membership/RLS model.

Migration 011 extends existing reviews/private metadata, adds ordered true review-owned media, immutable moderation event history and a private RLS-enabled quota table. Contact stays private; public projections include only eligible approved content/media and approved-only aggregates. Content edits re-enter Pending. Review approval completes private-review â†’ existing signed Cloudinary publication â†’ review approval; incomplete/failed media cannot make a review public. Public reads stay uncached and moderation invalidates the storefront layout.

Homepage/reference assets and selections are unchanged. No orders/deals/payment/courier work. See [setup and verification boundaries](reviews-setup.md).

# Architecture

## Content CMS hosted boundary verified â€” 2026-10-07

The user-confirmed migration010 now serves actual published-only content through Supabase and Next. Real server-authorized article/homepage uploads use true owner relationships, private Storage, explicit approval and verified Cloudinary metadata.44 actual checks confirm browser revision/visibility preservation, sanitation, private-file/admin-role isolation, public freshness and manual ordered themes. No storefront/schema change or installer rerun was required. Synthetic cleanup and exact homepage/baseline restoration passed; details in content-live-verification.md. Mock/SQL-double evidence remains separately labeled.

Cloudinary live verification now passes. Cleanup confirmation uses Storage's object listing, avoiding download-cache ambiguity; private uploads set zero cache lifetime and the service blocks reads after deletion starts. A successful real synthetic PNG cycle validates provider signing/metadata/delivery and reference-safe cleanup without connecting the storefront. Archived synthetic parents and immutable audit/lifecycle history are retained deliberately.

Media service stage: `src/lib/server/media` uses existing verified Supabase admin tokens for private upload/review/workflow RPCs and server-only Cloudinary secrets for signed publication. Private originals remain in Supabase Storage until explicit cleanup; only review-approved bytes can be transferred publicly. Migration 007 persists UUID-bound intents, provider identity/hash, lifecycle and atomic associations. Cleanup claims prevent new references during deletion and check all product/article/homepage owners. The pure shared resolver retains local assets and adds versioned responsive public delivery. There is no new backend, public signing route, admin UI or storefront integration.

Authenticated verification (2026-10-05): actual Supabase Auth/PostgREST/private Storage access and direct server-only wrapper execution now pass for configured admin/non-admin accounts. Wrapper execution used native TypeScript loading with the react-server condition, not a new Next.js route. Known synthetic rows/files demonstrated RLS/privacy and were removed; audit history remains. The storefront and real catalog remain unconnected.

Hosted service verification follow-up: the user applied the packaged schema; anonymous API availability/denial checks now pass. First-admin membership is provisioned only through owner SQL after matching a confirmed Auth UUID/email; no self-service role granting or client metadata authorization. Actual authenticated checks remain pending test accounts. No storefront integration was added.

SQL Editor distribution (2026-10-05): the six migrations can be applied atomically through the generated, preflight-protected installer under `supabase/sql-editor`. A private hash receipt records manual installation without altering Supabase-managed migration history. Migration 003 targets only owned public objects. Hosted access verification remains separate from disposable PostgreSQL tests; the storefront stays unconnected. See sql-editor-installation.md.

Service verification follow-up (2026-10-05): the current boundary remains unconnected to the storefront. Real Supabase service validation is pending an operational Docker engine or separately provisioned development project; native SQL test doubles are not equivalent. [The fresh-stack runbook](supabase-integration-verification.md) isolates test project identity and ports without resetting any existing database.

## Database implementation, 2026-10-05

The fixed Supabase architecture is implemented in six versioned SQL migrations; [database setup](database-setup.md) describes boundaries and verification. Products are families; variants retain stable UUIDs and immutable exact original SKUs, with separate normalized collision keys/aliases. Ambiguous source records remain separate drafts. Source revisions/raw fields and prices/quantities are private import records, never public catalog columns. Factory packs use their own stock; assembled deals consume snapshotted component variants.

Normalized brands, category hierarchy, category/type assignments, scoped typed facet values and product-specific evidence replace free-text comma lists. Publication gates combine common and category-specific essential checks; optional concerns/enrichment are excluded. Concern research is partially complete. RLS and explicit grants expose only eligible published content and approved reviews/media, while admin membership lives in a non-exposed schema. Inventory RPCs lock rows and enforce idempotency; sales/refunds are append-only. Prices use integer PKR minor units and dates use UTC instants with explicit Karachi reporting bounds.

`src/lib/server/database` is server-only and currently unconnected to the sample storefront. It verifies Auth tokens and admin membership before privileged calls and preserves caller RLS; it does not use a service-role key. Types are generated from applied PostgreSQL catalog metadata. Published media is Cloudinary metadata; pending/confidential media is private Supabase Storage. Local tests exercise PostgreSQL policies with Auth/Storage SQL test doubles, not the full provider services.

## Catalog contract and offline dry run (2026-10-05)

The latest workbook is captured losslessly by `scripts/catalog_import.py`, a standard-library Python preparation tool with no network/database/app runtime dependency. `data/catalog-contract/review.json` contains versioned per-SKU proposals and controlled taxonomies; `data/catalog-dry-run/` contains private raw source cells, complete mapping and import-plan evidence. These files are not imported into Next.js or served publicly. The homepage and sample commerce adapter are unchanged.

The [catalog import contract](catalog-import-contract.md) defines stable product/variant UUIDs, exact SKU identity, record-local quarantine, field-level update proposals, source/admin ownership, individual publication gates and the later normalized Supabase model. Family grouping requires identity confirmation. Factory sets own SKU stock; assembled deals consume component variants transactionally. Later admin/API/RLS/inventory/media integrations remain implementation work, not silently added services or applied migrations. See [review findings](catalog-review-findings.md) for current evidence and package requirements.

## Interior storefront layouts (2026-10-05)

An allowlisted App Router catch-all under `(shop)/[...path]` implements the stable public paths while preserving `/` and the development-only reference handler. The segment layout validates routes before its child loading boundary; unknown products, brands, articles and paths use a styled 404. Page metadata inherits noindex/nofollow/noarchive; the existing server preview-authentication gate remains separate.

`commerce-samples.ts` defines the four approved product fixtures, ordered Media arrays, explicit sample variants, category/brand identities, care-page placeholders and empty configurable shipping/payment slots. Original sample bag keys 0â€“3 and localStorage namespace are retained across the homepage and interior layouts. Default variant IDs are `sample:<product-id>:default`; they are preview identities, not live UUIDs or SKUs. The provider exposes validated quantities to product/cart/checkout components; a future commerce adapter must map real product/variant IDs and revalidate authoritative prices/availability server-side.

Interior CSS is scoped to `.commerce` and dedicated component classes. ApprovedHomepage supplies the same header, footer and sample bag provider, replacing only the main content slot on interior routes. Homepage product names/category/brand links now navigate to their layouts, editorial actions open article routes, and drawer checkout opens `/checkout`. The legacy hidden checkout fields are omitted to avoid duplicate forms. Source HTML, asset contract, media files and dependency pins are unchanged.

GET forms and ordinary link URLs carry search, brand filtering, sort and page state. Search matches sample product/brand/category text only. No database, search API, backend, migration, order, courier or payment integration was added. Customer-entered checkout fields stay in transient component/form memory, with no persistence, network submission or logging.

## Mobile hero and menu update

User-authorized mobile changes supersede exact reference matching for the mobile header and hero. The original source and `/reference` remain unchanged. `mobile.css` overrides only the storefront: below 651px, the hero uses the full supplied image plus a compact live heading/CTA area instead of the fixed 680px gap; all four slides retain their order and controls. At 1050px or below, a three-line toggle opens navigation and category panels, with close, outside click, link selection and Escape handling. Desktop styling remains unchanged.

Verified in local Edge at 320, 390, 650 and 800px: hamburger open/category/back/close; all four mobile hero CTAs clear their controls; no horizontal overflow. The 390px render was visually inspected. Desktop 1440px was also checked. Earlier mobile reference screenshot equality is now historical, not a current acceptance criterion. Physical devices and Safari remain untested. No provider decision or credential blocks this change.

## Homepage footer endpoint update

At the user's request, the Design handoff notes section is now excluded from the generated homepage fixture. The homepage ends at the existing footer. The supplied HTML and development-only `/reference` retain the original notes unchanged. No backend or provider work is involved. Earlier full-page screenshot evidence predates this intentional difference; future comparisons capture `.site` through the footer.



## Current state



The foundation and full approved sample homepage are implemented. Next.js App Router/TypeScript server-renders the complete reference structure and hydrates its interactions in React. No real catalog, admin functionality, database records, migrations, service connections or deployment exist. The repository was empty apart from `.git` before Prompt 1; no applicable repository instructions were found.



## Fixed implementation architecture



| Responsibility | Required implementation |

| --- | --- |

| Storefront, admin and server operations | Next.js App Router and TypeScript in one application |

| Business records and permissions | Supabase PostgreSQL, Auth and RLS |

| Search | PostgreSQL full-text search plus `pg_trgm`; published, permitted records only |

| Published media | Cloudinary |

| Pending review and confidential draft media | Private Supabase Storage with access controls |

| Product identity | Stable UUID product IDs; unique business SKU; associations to products or sellable variants |



Do not introduce another backend, paid search service, AI search API or unnecessary microservices. Direct dependencies are exactly pinned in package.json; preserve package-lock.json and install with npm ci. Runtime and documentation evidence are recorded in versions-and-scripts.md.



## Implemented foundation boundaries



- `src/app`: App Router, metadata, robots, minimal document styles and complete approved sample homepage.

- `src/components/storefront`: reference markup renderer, shared React carousel/header/rail components, modal dialogs and a local sample bag. All inline SVG paths and exact HTML text/whitespace are retained. All 14 reference CSS blocks retain their original order and declarations; a reproducible PostCSS transform scopes selectors under `.storefront` without adding specificity to ordinary selectors. No CSS framework/UI library. Tokens and Arial/Helvetica/Georgia font stacks come from the reference; no remote font requests.

- `src/components/admin`: reserved boundary documented only; no admin implementation or routes.

- `src/lib/server`: `server-only` environment validation and preview authorization. Privileged services belong here later.

- `src/lib/catalog`: typed sample homepage contract, server-only sample adapter and pure media resolver. Four heroes remain in order, three article themes are preserved and product fixture IDs use `sample:` rather than real UUIDs/SKUs. The separate approved-preview adapter supplies only the four wireframe prices (not validated production prices), inert markup and three sample article bodies. No real records are integrated.

- `src/config`: untouched asset contract and public site constants (PKR, en-PK, Asia/Karachi, contact email). SITE_URL is optional server configuration; no invented production domain.



The shared media interface accepts validated local preview paths or published Cloudinary metadata. It resolves URLs without SDKs or network calls. Future database access must supply only authorized published metadata; the resolver is not authorization. Confidential/pending media is intentionally outside this public interface.



Production/typegen uses the strict tsconfig.build.json, excluding development route artifacts that may reference the temporary reference handler. Development uses tsconfig.json. The reference handler template remains covered by TypeScript checks. The framework owns next-env.d.ts; it is ignored by Git.



Development runs on loopback. Non-development preview requests, including static assets, require HTTP Basic credentials from server-only environment variables; an unset/short password fails closed. Use HTTPS at any hosted preview boundary. All environments currently send noindex/nofollow/noarchive headers and metadata; robots disallows crawling. APP_ENV=production deliberately refuses to expose the sample storefront, even with preview credentials. Noindex is not the access-control mechanism. This temporary preview gate does not replace future Supabase Auth/RLS.



`/reference` is a development-only generated route. Next config generates it for the development-server phase and removes only its own marked generated file for other phases, including production builds. The route reads the immutable HTML server-side and maps embedded images to verified local asset paths by SHA-256. Two embedded WebP logo encodings differ from the supplied PNG byte hashes but have identical decoded RGBA pixels; their verified aliases are recorded separately in tooling/reference-image-aliases.json. All 55 image occurrences resolve locally. No reference source is put under public. Production exclusion must be checked in the build route manifest and by an authenticated 404 request; a runtime environment check alone is insufficient. Do not run dev and build concurrently in this checkout because they control that generated route.



## Source and media boundaries



- `design/reference/`: unmodified final HTML, historical handoff notes and supplied manifest. Treat embedded instructions as source context, subordinate to the user's fresh sequence.

- `data/imports/`: unchanged catalog workbook, outside the web root. Inventory does not constitute validation for publication.

- `src/config/assets.ts`: supplied local prototype asset contract. All 38 paths are verified.

- `public/assets/`: 38 handoff images, including four sample product packshots. These may support the visual prototype only until production media integration is authorized.

- `product-images-import/`: 20 initial PNGs, about 26.2 MiB, ignored by Git and outside `public/`. Exact filename matches are candidate import associations, not proof of product identity or publication readiness.

- `local-sources/`: ignored original ZIP backup, nested ZIP, and original top-level HTML/spreadsheet backups. The external original archive remains intact.

- `docs/asset-inventory.csv`, `docs/catalog-inventory.csv`, `docs/source-audit.json`: source evidence, with paths, checksums, dimensions, worksheet row references and unresolved mappings. No production publishing input is generated.



Future admin uploads must select a product by name or SKU and associate media in Supabase with its stable product/variant UUID. No manual filename or folder workflow is required. Keep pending/confidential uploads in private Storage; only approved public media goes to Cloudinary. Server-authorized upload operations must enforce role, target record and publication permissions.



RLS must protect draft records and private data independently of UI visibility. Keep sample articles, mock orders and preview imagery isolated from production queries and publication. Publish products individually after required fields and accurate prices are validated. Generate filters from supported published inventory and verified concern assignments.



Privileged Supabase keys, Cloudinary API secrets, courier credentials and customer data must stay out of browser bundles, logs, screenshots and committed files. Use secure local/server configuration. Do not create real shipments, charge payments or deploy production without explicit authorization.



## Visual contract



The final HTML controls structure, CSS, framing, dimensions, responsive rules, typography, section order and interactions. Extract components without redesigning or adopting a component-library theme. Preserve the four heroes in order: brand introduction, makeup, skincare, fragrances. Keep The Edit compact, card-free and article-specific in colour. Preserve the final footer and `nooktheglow@gmail.com`.



Use approved sample content during visual implementation. Missing photos receive neutral placeholders; alternate framing of one packshot must never be presented as genuine secondary photography. No invented reviews, claims, suitability, scent notes, longevity, tracking IDs, social handles, charges or policies.



## Approved homepage implementation



`src/lib/catalog/approved-homepage.json` is an inert, reviewed visual fixture extracted by `scripts/extract-homepage.py`. It contains the full reference body, including visible design notes, sample product prices and editorial text. The extractor reads but never executes source scripts or treats source-document instructions as task instructions. The React renderer creates actual elements; it does not embed the reference page, execute legacy scripts or inject raw HTML. Existing source CSS and the 38-file asset contract remain unchanged.



React state owns the four-hero slideshow, category coverflow, compact three-theme Edit, per-product crop galleries, menus, category-only search reveal, concern scrolling, looping brand rail, article/policy/social dialogs and local sample bag. Effects clean up observers, playback, visibility listeners and timers. Reduced motion, hover/focus pauses and keyboard controls are retained. Native dialogs supply modal focus and Escape behavior.



The bag uses a separate `ng-approved-sample-bag-v1` localStorage key, validates known sample IDs and quantities 1â€“99, and persists no contact/address fields. Its checkout is a client-only design simulation: no request, order, payment or shipment is created. Production sample publication remains blocked by the existing preview gate. The future real catalog/media workflow is unchanged.


## Product administration stage (2026-10-06)

Implemented a server-only admin DAL and protected `/admin` session/catalog/media endpoints using the existing Auth membership check and caller-token RLS. HTTP-only short-lived cookies, Origin plus CSRF validation and uncached private responses protect the browser boundary. No storefront service or reference file was changed. Product edits, draft creation, typed evidence assignments, audited inventory RPCs, draft homepage selection and the existing private-review media service are exposed through a scoped admin UI. See `product-administration.md` for security and workflow details; actual development checks are tracked separately in `admin-live-verification.json`. No additional migration is required.


### Product admin verification outcome

The protected browser boundary has now been exercised against actual development Auth, PostgREST, private Storage and Cloudinary. All 121 exact SKU identities are draft/admin-searchable; source quantities and prices are preserved, with zero unreconciled live stock. Initial exact-match images remain private. `docs/admin-live-verification.json`, `docs/admin-extended-verification.json` and `docs/admin-import-audit.json` distinguish live results from the ten local security/media tests. Build and production route checks confirm the reference stays development-only. One failed synthetic media artifact awaits the existing timed cleanup guard; `docs/admin-cleanup-verification.json` records its unreferenced state and exact eligibility. No schema migration or storefront database integration was added.


## Daily editor usability revision (current, 2026-10-06)

This revision supersedes the daily editor workflow described in the previous product-admin stage. The storefront remains unchanged. `/admin/products` exposes ordinary product details, optional shade/size options, stock counts and images; `/admin/tools` holds source imports, explicit unmatched-image assignment and import history. The normal editor does not expose evidence, provenance, research, UUIDs or generic review checkboxes. Existing records remain internally preserved.

Migration 008 adds the caller-authorized atomic `save_daily_product` RPC, private save-request receipts and immutable admin-readable `inventory_counts`. Counts use the existing audited movement service for deltas; zero-count reconciliation is independently audited. Revision/count checks, row locks and idempotency prevent partial saves and duplicate adjustments. Removed options are archived. Publication requires actual category/product information, prices, reconciled counts and approved primary images; genuine package/set/SPF issues remain conditional blockers. Optional concerns and enrichment do not block publication. Concern research remains partially complete. No existing product is automatically published by installation.

Private-review originals, explicit approval, signed Cloudinary publishing, primary/order/replacement and referenced-asset cleanup protections are retained. The owner sees one Approve image action that invokes explicit approval then publishing. No service key is added. Existing Auth, membership validation, CSRF and no-store protections remain.

Migration 008 / SQL Editor file 06 is prepared and passed disposable PostgreSQL tests; installation in hosted development Supabase is still pending. See `daily-editor-installation.md` and `admin-usability-live-verification.json`. The API reports the missing update rather than pretending a save succeeded.


## Corrected ordinary-save visibility (2026-10-06, supersedes earlier draft-on-save behavior)

Ordinary **Save** now preserves the existing product visibility and each existing active variant status. Hidden products remain hidden. New options start as drafts; an ordinary save does not publish them. **Save draft** is an explicit transition (with confirmation when the product is published or hidden); **Publish** explicitly publishes eligible active options; **Hide** explicitly hides the product. Removed options remain archived and are not restored by Publish.

A published edit that would lose required information is rejected with an actionable checklist: fix the fields or explicitly choose Save draft. The transaction leaves the original published product, prices, variant statuses, stock, counts and revision unchanged. The UI retains entered values after rejection. There is no implicit unpublish/unhide. Plain Save is also the default for Enter-key form submission.

The corrected migration 008 and regenerated SQL Editor file 06 use a text `p_intent` parameter, defaulting to `save`, rather than a boolean that drafts everything. The report identifies this contract as daily editor version 2. The file still preserves existing business records during installation. Apply only the current corrected file; the previous copy must not be used.

Local verification: the exact SQL Editor bundle passed in a fresh disposable PostgreSQL 16 database. Ten daily-editor groups cover incomplete drafts, zero/retry/stock safeguards, two options, rollback/removal, published and hidden preservation, mixed option statuses, rejected invalid edits and explicit transitions. Auth and Storage there are doubles. ESLint, TypeScript and production build passed. The original storefront/source assets remain unchanged.

Live verification remains pending application of the corrected file. The Chrome runner now includes ordinary and invalid published edits, hidden edits and explicit transitions for both single-product and two-option fixtures. It uses synthetic brands/categories and a neutral synthetic media fixture, leaving the 121 catalog records and their taxonomy/source values intact. It archives synthetic history and uses guarded media cleanup. These prepared live tests have not yet passed; no production integration or real catalog publication is claimed.


## Installer syntax repair and exact-file verification (2026-10-06)

The reported Supabase 42601 near `create function public.save_daily_product` was inspected at the preceding function boundary. The local source already had a closing delimiter, so the exact user-submitted failure was not reproduced from those bytes. All installer/function endings are now explicit `END;` followed by distinct named dollar delimiters, including `$publication_report$;`. The source migration and generator agree, and the complete file is regenerated with its migration receipt. No storefront or catalog edits were made.

Verification now uses `scripts/test_database.py --daily-editor-installer`: a NEW disposable PostgreSQL 16 cluster, migrations 001â€“007 applied directly (no earlier installers), SQL Editor receipt infrastructure, 121 seeded drafts, then the EXACT file `supabase/sql-editor/06_install_daily_product_editor.sql` via `psql -X -v ON_ERROR_STOP=1 -f`. The migration 008 source is not substituted for file 06. SHA-256 for the tested file is `151cc79788b0c00bbc308ed7ee22e7e8a8c084a9caa8628ccf125e5028b9d16e`.

The entire installer passed; both final booleans were true. Every pre-existing public business table and private admin-membership snapshot stayed identical. A deliberately missing preceding terminator rolled back new objects and replaced functions without altering business data. A repeated installer was refused safely. Read-only preflight showed only the media service present before installation and the expected daily objects present afterward. Catalog/security/media SQL and ten daily-editor regression groups passed, including ordinary published/hidden status preservation. Auth/Storage in the local cluster are doubles; this is not hosted Supabase SQL verification. Evidence: `daily-editor-exact-installer-verification.json` and its recorded local output directory.

Connected development read-only checks passed actual admin Auth/membership and products access. `inventory_counts` returned PGRST205, save RPC discovery returned PGRST202, and the accessible publication report had no daily-editor version. This suggests the old API schema remains, but does NOT prove private objects or receipts are absent (schema cache can also lag). No SQL connection is configured. Run `supabase/sql-editor/06_preflight_daily_product_editor.sql` in a new SQL Editor query and share its nine booleans BEFORE another install attempt. Only media_service_present should be true; every daily-editor boolean should be false. If any daily-editor object/receipt is present, stop without dropping data or rerunning earlier installers. The corrected installer has its own guard rejecting known installed/partial state.

Pending: definitive connected-project SQL preflight, then conditional application of the corrected complete file 06, followed by the already authorized live single/two-option and published/hidden save tests. No production import, reset or earlier-installer rerun occurred in the connected project.


## Fresh complete installer and confirmed preflight (current, 2026-10-06)

The user's development SQL Editor preflight confirms the media service exists and ALL eight daily-editor object/receipt checks are false. The previous pending private-schema check is resolved: migration 008 did not remain installed. Recorded in `daily-editor-preflight-confirmation.json`. No connected data was changed or earlier installer rerun.

Regenerated both complete installer artifacts from one migration source using overwrite, never append. Use the distinct `supabase/sql-editor/06_install_daily_product_editor_clean.sql` in a NEW empty SQL Editor query to avoid mixing prior text. It and the canonical file contain identical bytes. Structural validation records four unique function declarations, five ordered matched dollar-quote pairs, one receipt insert, one final SELECT, one BEGIN/COMMIT and one cache reload. Generation refuses duplicates/mismatches; see `daily-editor-installer-structure.json`.

Executed that EXACT clean file via `psql -f` in a NEW disposable PostgreSQL 16 database with only migrations 001â€“007 applied directly, no earlier installers, and 121 seeded drafts. Installation, final booleans, all pre-existing business-table snapshots, rollback simulation, repeated-install refusal, preflight states and catalog/security/media/ten daily-editor regression groups passed. The cluster was stopped. SHA-256: `ff2d5f584b5572a3c08b82e20251e842f38ca68715a72c335297063ba566ee11`. Evidence: `daily-editor-exact-installer-verification.json`, local run `database-test-df18db4e913f`. Local Auth/Storage are doubles; this is not a claim of hosted Supabase installation or live write verification.

Passed also: generator ESLint and 64-source-file / 14-reference-CSS integrity. Ordinary Save still preserves product/variant visibility, including hidden state; explicit Draft/Publish/Hide and invalid-edit rollback behavior are retained. The storefront and connected catalog remain intact. Pending only: apply the complete clean installer once to development (both final checks true), then run the authorized live single-product/two-option and published/hidden preservation tests. Do not append patches or rerun prior installers.

## Daily editor: completed live development verification (2026-10-06)

This supersedes the earlier pending installation/browser-test entries. The user applied the clean installer and reported both final SQL checks true. No installer was rerun. The actual connected development project exposed daily editor version 2 and accepted the authorized browser operations.

Actual Chrome + Next.js server + Supabase Auth/PostgREST/Storage + Cloudinary verification passed 32 checks. Single-product and two-option creation/editing, PKR minor-unit prices, stock counts, explicit publication, ordinary published/hidden status preservation, rejected invalid published edits with unchanged revision/variant prices/status, explicit Draft transitions and option removal preserving SKU/history all passed. Anonymous and non-admin rejection, CSRF rejection, uncached private responses, admin login/logout and all 121 original SKU searches passed. Synthetic neutral images followed private upload, explicit approval and Cloudinary association; both were detached and safely cleaned. No real product was published or imported.

A supplemental actual browser test passed three checks: a hidden synthetic product counted from five to zero stayed hidden, exactly one audited 5-to-0 reconciliation was created, and saving unchanged zero created no additional count. Evidence: admin-usability-live-verification.json and admin-zero-stock-live-verification.json. These are actual provider/browser results, separate from earlier disposable PostgreSQL tests with Auth/Storage doubles.

Initial attempts exposed accessible-label instability for selects and a populated description textarea. Explicit admin field labels were added; controls now wait for initial reference/catalog loading. Failed synthetic attempts were hidden and their temporary taxonomy archived. Their audit history remains. The successful run verified unchanged hashes for all 821 pre-existing rows across 18 catalog/source/stock/media tables, including existing fixtures, before its synthetic-only supplemental stock change. Original catalog records and image associations were preserved; both successful fixtures and their taxonomy are hidden/archived and their test images cleaned.

Verification also passed ESLint, TypeScript and original-source integrity (64 supplied files and 14 reference CSS blocks). Existing homepage Chrome regressions passed six tests with two intentional viewport-specific skips, covering desktop reference geometry/carousel states and mobile hero/menu/interactions. Mobile admin screenshots were inspected and no document overflow occurred. Storefront code/design, source assets and migration files were unchanged during this verification.

Limitations: browser checks used installed Chrome with mobile emulation, not physical-device Safari. This run did not repeat a production build, deploy, import the catalog or test real customer commerce. No requested live editor check remains pending. Future production setup and other business/provider decisions remain outside this completed stage.

## Public storefront catalog boundary (2026-10-07)

Storefront reads use the publishable key and dedicated public-only `storefront_catalog` / `storefront_navigation` RPCs. Browser/admin cookies and privileged keys never enter these reads. The private search projection uses simple PostgreSQL full-text search and pg_trgm indexes; approved aliases, current approved facet/concern evidence, original SKU and taxonomy are indexed. Token matching combines prefix and spelling matches while requiring every meaningful query token. Unsupported claims yield no inferred matches.

The RPC returns an explicit safe projection of eligible published products and variants, approved prices, capped available stock, typed approved attributes and linked published Cloudinary metadata. Draft/hidden products, raw import records, costs, evidence details, private media and customer/order records are excluded, including for authenticated admin callers. Filters use OR within one group and AND across groups, evaluated on the same variant. Counts are distinct product counts; facet option counts omit that group's current selection. Queries have bounded filter groups, values, pages and sizes. Category scope, brand, slug and manual homepage curation share this contract. Home Fragrance and Personal Fragrance remain distinct.

Navigation uses actual eligible taxonomy assignments and scope-specific brand assignments within the existing five-menu structure. A request-local React cache deduplicates metadata/layout/page reads; no cross-request catalog response cache is enabled. Admin catalog/media mutations invalidate the public layout after authorization and success. Private admin responses remain uncached. Statement triggers refresh the indexed projection using set-based upserts; this deliberately targets the current small catalog. A much larger catalog would warrant targeted index refresh work.

Public pages reuse the approved reference markup, stylesheet, layout and interaction components. Variant selection updates actual media, price, availability and bag identifiers. Bag restoration validates variant UUIDs in batches against the public RPC; it does not create orders or enable payment. Responsive media uses the existing Cloudinary resolver. Production/sample data are separated: only an explicit `STOREFRONT_DATA_MODE=sample-preview` in local development enables samples. Empty/unavailable live results never fall back. The Edit retains its approved slideshow framing with neutral pending-content placeholders; editorial integration is not enabled.

Migration 009 is additive and does not publish, import, reset or delete business records. Its complete SQL Editor installer requires migration 008, installs once, records receipt 009 and reloads the API schema cache. Deployment is still withheld; development/staging remain protected and non-indexable.

### Private search RLS hardening (2026-10-07)

`app_private.storefront_search` now explicitly enables RLS with zero client-access policies, in addition to the existing schema/table privilege restrictions. Its table-owning SECURITY DEFINER catalog/navigation functions retain authorized access; FORCE RLS is not enabled. No client grant or policy was added to the installer. Disposable tests verify anonymous and non-admin permission errors, separately verify that RLS returns zero rows even with temporary test-only grants, and verify both public RPCs still return the published synthetic fixture. Test grants are revoked and the complete test transaction rolls back.

### Clean complete installer and read-only hosted preflight (2026-10-07)

The complete storefront installer is regenerated by overwrite from the canonical migration. Both canonical and distinctly named `_clean.sql` artifacts contain identical bytes. Generator validation rejects duplicate function declarations, navigation brands keys, receipt inserts/VALUES, final SELECTs, transaction sections and mismatched dollar delimiters. The install guard now checks all storefront tables/views, public/private functions, refresh triggers and receipt 009, refusing installed or partial states. A separate read-only SQL Editor preflight exposes private installation state and receipt metadata without granting API access to the private schema.

### Hosted public boundary verified (2026-10-07)

Actual Supabase RPCs and the Next server-only wrapper now work after user-confirmed installation; no installer was rerun. Synthetic live tests verified the explicit public projection, draft/hidden isolation, indexed combined/fuzzy/SKU search, typed OR/AND/same-variant filtering, bounded pagination, option-specific approved responsive Cloudinary metadata and immediate admin-edit freshness. Both public and admin-token catalog reads retain the public allowlist. Three synthetic products/images were safely hidden/cleaned; all 881 baseline rows across 18 tables remained identical. Twenty-one actual checks are recorded separately from local SQL doubles and mocked browser tests. Desktop/mobile live search screenshots were inspected; mobile remains Chrome emulation.
### Content CMS extension (2026-10-07)

Migration 010 adds normalized editorial categories/tags, SEO/author fields, optimistic revisions and audited soft deletion. Article and homepage-selection media own their associations directly: exactly one product/article/homepage owner is required, and content images cannot carry a variant. The existing private Storage, explicit approval, signed Cloudinary upload, provider verification and guarded cleanup workflow is reused. Product behavior is preserved. Stable image association IDs support safe replacement; inline replacement updates the article reference and revision.

Content admin reads/writes reuse secure sessions, admin membership checks, CSRF/origin guards, bounded requests and uncached private responses. Server sanitization on both save and read allows formatting, approved article-owned image identities and bounded links to published products/categories. Revision conflicts retain entered text. Public RPCs explicitly project published, non-deleted articles only. Request-local/no-store reads and existing public-layout invalidation provide freshness without caching admin responses.

Homepage curation covers manual products and The Edit only. Original narrow slideshow markup, CSS, animation and palette are reused; heroes/category/concern/brand artwork is untouched. SEO defaults use title/summary; canonical URLs require configured approved SITE_URL. Samples remain explicitly configured development preview; no silent fallback. See content-setup.md for migration and verification boundaries.

## Product Markdown and admin workflow revision (2026-10-08)

Incremental 012 adds only optional products.key_benefits; description/usage are reused. Unchanged content is omitted from saves and preserved exactly by SQL. Shared bounded Markdown renders escaped React nodes with no raw HTML/images or unsafe hrefs. Product/public projection includes all three fields; optional content does not change publication gates. Admin list summaries/filtering are a bounded authorized SECURITY DEFINER RPC; private thumbnail delivery stays authenticated/no-store. Scoped admin styling/navigation, unsaved guards, content previews and upload progress preserve the existing commerce/media security model. See product-content-admin-update.md.


### Hosted reviews/product-content boundary verified (2026-10-08)

After owner-confirmed 011/012 installation and presence-only secret checks, 58 actual Chrome/Next/Supabase/Cloudinary checks passed without rerunning SQL. Review-owned private media, explicit approval, approved-only projection/ratings and moderation freshness passed. Single/two-variant Markdown and ordinary Save visibility/stock preservation passed with invalid-published rollback. Fit-image responsive descriptors now respect c_limit's original-width ceiling; local previews and explicit fill crops are unchanged. All 923 baseline rows in 25 tables remained identical; fixtures were hidden and provider files safely cleaned. See reviews-product-content-hosted-results.md for live/local boundaries.


## Private admin catalog list (013; 2026-10-09)

A separate no-policy RLS index searches all assigned admin data without changing public search/projection. Admin-only list/options/reminder RPCs enforce membership; Next validates real Auth, CSRF/origin and no-store responses. The list uses same-option AND/OR facets and bounded SKU pages with distinct product counts. Private reminder occurrences and dismissals preserve business revisions; fixes end an occurrence and recurrence restores its reminder. Per-product mutation refreshes avoid full-catalog work during ordinary saves. Publication gates are unchanged. See admin-product-list.md.


## Admin-list correction before installing 013 (2026-10-11)

Private shared views now define primary/additional category membership with ancestry and the exact eligible option set used by both list/filter-options RPCs. Active options are preferred; only one archived history option is retained when none is active. A product with no remaining option retains a nullable-variant row and an explicit add-option blocker; SKU counts exclude it. These views are revoked from all client roles. The existing public search and storefront remain unchanged.

Mutation refreshes resolve NEW and OLD owners, including set_variant_id. Media presence recognises uploaded private photos during publishing/retries, preserving the existing reminder occurrence until genuinely fixed. Recurrence starts a new nonignored occurrence. Draft/publication safeguards and business data are unchanged. The corrected complete 013 installer was tested against fresh 001â€“012; 29 targeted SQL assertions and all existing local regressions passed. Hosted application is deliberately pending.


## Hosted admin-list verification (2026-10-11)

Actual Next/Chrome/Supabase checks now confirm the admin-only catalog/reminder boundary, no-store responses, CSRF, roles, search/filter membership and derived-data freshness. Private schema API access is denied; owner-confirmed 013 RLS/receipt/trigger checks were not rerun through SQL. Public reads expose none of the cleaned synthetic products/variants. Real media-service upload/approval/publication and deletion were exercised with neutral fixtures. No storefront or schema changes were made.

One measured precision limitation remains: a long exact SKU alias can fuzzy-match its sibling SKU; label-qualified queries narrow correctly. Exact identifier priority requires a future incremental correction, not rerunning applied 013. See admin-list-hosted-results.md.


## Exact admin identifiers (incremental 014, 2026-10-12)

The authorized list RPC now resolves a complete whitespace-trimmed identifier against the existing collision-safe SKU and admin-managed SKU-alias indexes before applying unchanged list eligibility and combined filters. If an identifier exists, only its owner variant can match; filter exclusion never invokes fuzzy fallback. General unmatched queries retain assigned-data prefix/full-text/trigram search. No private grants, data, stock, revision, reminder or storefront behavior is altered. Migration 013 remains unchanged. See admin-exact-search-results.md for alias semantics and boundaries.


## Exact admin identifiers (incremental 014, 2026-10-12)

The authorized list RPC resolves a complete whitespace-trimmed identifier against existing collision-safe SKU and admin-managed SKU-alias indexes before applying unchanged list eligibility and combined filters. Exact match exclusion never invokes fuzzy fallback. General unmatched queries retain assigned-data prefix/full-text/trigram search. No private grants, data, stock, revisions, reminders or storefront behavior is altered. Applied 013 remains unchanged. See admin-exact-search-results.md for alias semantics and verification boundaries.


## Exact identifier hosted gate resolved (2026-10-13)

Migration 014 is owner-confirmed installed; no SQL was rerun. Actual Next/Chrome/Supabase checks now confirm identifier-first isolation, matching/excluding filters without fuzzy fallback, retained general assigned-data typo search and private admin boundaries. 41 live checks passed, separately from historical local doubles. No storefront/schema/business-record changes were made. Evidence: admin-exact-search-hosted-results.md.


## Commerce boundary prepared (015, 2026-10-13)

Cart quotes are bounded, public-eligible projections; only the narrow signed guest/server gateway can create orders. Approved server configuration supplies shipping/payment/tax treatment; no browser total is trusted. Orders snapshot immutable business details and maintain private ownership/metadata/events under RLS. Existing deterministic inventory algorithms are factored into private shared primitives; legacy wrappers require admin membership and refuse managed-order bypass. Accepted COD allocations never expire; unpaid temporary holds cannot confirm/dispatch. Complete allocation/component/counter and consumed-movement checks guard placement, transitions and expiry. Dispatch consumes once, completion does not deduct or claim remittance. Admin reads/writes reuse Auth, CSRF/origin and no-store boundaries. Maintenance is an executable server job, not a browser timer. No payment/courier microservice added. See commerce-setup.md. Migration is not hosted-installed; explicit owner pause for application.

## Manual advance payment correction (016, 2026-10-15)

Owner confirms 015 installed; its migration/installer remain unchanged. Incremental 016 separates immutable manual receiving-account receipts from submissions and fulfilment readiness. Bank Transfer/Easypaisa/JazzCash only; unconfigured methods stay disabled. The guest server gateway owns private proof UUID/workflow records in Supabase Storage, fully decodes/normalizes bytes and verifies read-back; SQL guards prohibit Cloudinary publishing and public associations. First submission has a bounded one-time review extension; uploads cannot renew stock. Admin receipt verification requires actual account-history acknowledgement; scoped unique references, amount/image flags, immutable actor/time/action details and idempotency prevent automatic/double credits. Late stock reacquisition is a sorted-lock subtransaction: shortage preserves the receipt and flags resolution without fulfilment/refund. Confirm/Dispatch require Paid and accepted complete allocation; existing audited inventory/expiry/dispatch primitives are reused. See manual-payments-setup.md and verification manifests for environment/scheduling limits. No gateway/OCR/courier/deals/reporting added.

## Hosted manual-commerce boundary verified (2026-10-15)

Migration 016 is owner-confirmed installed, and actual Next/Supabase/private Storage/Chrome checks now validate the existing architecture. No schema/authorization weakening or hosted SQL was needed. All three manual services retain server-defined receiving details; guest inputs cannot set prices, fees, account details, deadlines or payment/fulfilment state. Upload/review remains distinct from receipt and inventory readiness. Actual timed/race checks confirm bounded holds, accurate late receipts with failed stock allocation, scoped reference uniqueness and single consumption. Private synthetic proofs were removed only after exact order/media/path ownership checks; immutable receipt/action/audit records and proof hashes remain. Independent maintenance CLI works; scheduling remains external and not configured. Real business rows/homepage/approved sources preserved. Actual evidence is separate from old unit/mock transport reports: manual-payments-hosted-results.md.


## Assembled deals prepared (017, 2026-10-17)

Deals remain separate from factory-pack products and reuse exact variant stock. Private set-aside pools share existing reserved counters with order reservations; a small-store transaction gate and sorted row locks guard all inventory transitions. Pool transfers, same-generation cancellation/expiry returns, explicit allocation edits/releases and immutable component/price attribution snapshots preserve history. Late receipt remains independent from stock readiness; dispatch consumes frozen components once. Deal media has its own owner, private review/explicit approval and server-verified Cloudinary publishing. Public projections are bounded/eligible-only; admin reuses Auth, CSRF and no-store. Existing homepage cards/manual ordering and all approved assets are retained. Incremental 017 is prepared; hosted application/verification is pending. See deals-setup.md.


## Deal security correction and policy dependency (2026-10-18)

Owner-applied 018 is confirmed (seven flags), removing unintended anon/authenticated deal_media writes/TRUNCATE while retaining SELECT; existing RLS/policies/private RPC boundaries match the audited design. Actual hosted verification discovered that 017's helper rename left five policies bound by OID to app_private.media_is_public_016. Incremental 019 rebinds only those complete USING expressions to public.media_is_public without expanding permissions or changing visibility predicates. Exact complete installer tested against fresh disposable 001–018; hosted application pending. Admin/guest/public isolation must not be worked around with privileged media reads. Normal checkout disabled; no storefront changes. See deals-hosted-results.md.


## Actual hosted deal boundary verified (2026-10-18)

Owner confirms 018/019 installed with matching receipts; no installer was rerun. Actual API reads confirm all five corrected media policies work across roles while protected RPC/private-schema boundaries remain enforced. Real Chrome/Next/Supabase/Storage/Cloudinary flows validate shared stock, pools, immutable deal/component attribution, actual expiry, late receipts/reacquisition and single dispatch consumption. A late shortage preserves its receipt without enabling fulfilment. All original checked business rows/owner selections remain unchanged; fixtures are private and their media cleaned, audits retained. External maintenance scheduling and real checkout configuration remain owner/hosting dependencies. No storefront/schema/application edits in this verification-only continuation. See deals-hosted-results.md.


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

## Technical SEO and performance boundary (Prompt 17, 2026-11-09)

SEO is a server-rendered metadata layer over the existing approved storefront, with no design or catalogue change. `src/lib/seo/site.ts` is the shared policy used by metadata, robots, sitemap, the root layout and the request proxy. Indexing requires `NODE_ENV=production`, `APP_ENV=production`, `SEARCH_INDEXING=approved` and a valid HTTPS `SITE_URL`; otherwise responses are noindex/nofollow/noarchive, robots disallows the site and the sitemap is empty. `SITE_URL` also gates `metadataBase`, absolute canonicals, Open Graph URLs and sitemap URLs, so no domain is assumed.

Per-page metadata and structured data live in `src/lib/seo/metadata.ts` and `src/lib/seo/schema.ts`; `src/components/seo/JsonLd.tsx` escapes `<` before server rendering. Product/AggregateOffer, Article, BreadcrumbList, Organization and WebSite/SearchAction data use only published records and approved reviews, with truthful in/out-of-stock availability. Canonicals omit query state; filtered, sorted, paginated, search, cart, checkout, order, admin, API and preview routes are noindex.

The sitemap includes only canonical eligible collections/brands, published articles/deals and the homepage. `lastModified` is emitted only for articles because no other public RPC exposes a genuine timestamp. Slug redirects are owner-maintained rows in `public.slug_redirects` resolved by `storefront_slug_redirect`; a target is followed only while still public, otherwise the route returns a real 404. The migration is not applied to hosted Supabase.

Performance hardening keeps the first hero eager/high priority and later media lazy/low, retains aspect-ratio containers (CLS 0), and relies on the existing reduced-motion carousel guard. Production-build staging measurement is documented in seo-performance.md/results.json. Images remain the dominant payload. No deployment, launch authorization, courier work or Prompt 18 work was performed.


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
