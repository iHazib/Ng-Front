# Product administration: daily editor

The current owner-facing workflow is described below. Earlier verification reports concern the previous editor and are retained as historical evidence.


## Daily editor usability revision (current, 2026-10-06)

This revision supersedes the daily editor workflow described in the previous product-admin stage. The storefront remains unchanged. `/admin/products` exposes ordinary product details, optional shade/size options, stock counts and images; `/admin/tools` holds source imports, explicit unmatched-image assignment and import history. The normal editor does not expose evidence, provenance, research, UUIDs or generic review checkboxes. Existing records remain internally preserved.

Migration 008 adds the caller-authorized atomic `save_daily_product` RPC, private save-request receipts and immutable admin-readable `inventory_counts`. Counts use the existing audited movement service for deltas; zero-count reconciliation is independently audited. Revision/count checks, row locks and idempotency prevent partial saves and duplicate adjustments. Removed options are archived. Publication requires actual category/product information, prices, reconciled counts and approved primary images; genuine package/set/SPF issues remain conditional blockers. Optional concerns and enrichment do not block publication. Concern research remains partially complete. No existing product is automatically published by installation.

Private-review originals, explicit approval, signed Cloudinary publishing, primary/order/replacement and referenced-asset cleanup protections are retained. The owner sees one Approve image action that invokes explicit approval then publishing. No service key is added. Existing Auth, membership validation, CSRF and no-store protections remain.

Migration 008 / SQL Editor file 06 is prepared and passed disposable PostgreSQL tests; installation in hosted development Supabase is still pending. See `daily-editor-installation.md` and `admin-usability-live-verification.json`. The API reports the missing update rather than pretending a save succeeded.


## Daily editor usability revision (current, 2026-10-06)

Implemented the simplified daily editor, optional shade/size table with automatic UUID/SKU relationships, stock-count input including zero, Save draft / Publish / Hide actions, plain conditional warnings and publication checklist, optional homepage toggle and clean image gallery. Import/history and explicit unmatched-image assignment are outside the daily editor. Existing research/source/claim records remain internally unchanged. The approved storefront was not edited.

The exact migration 008 SQL Editor package passed a fresh disposable PostgreSQL 16 run, alongside catalog/security/media regression SQL. Five daily-editor assertion groups passed: easy incomplete drafts plus audited zero and idempotency; two-option atomic saves; stale stock/incomplete publication rollback; option archive/history preservation; non-admin save denial. All 121 imported fixture SKUs were accounted for with repeat-import preservation. Native Auth/Storage were doubles, not actual services.

Actual Chrome plus connected development Supabase passed twelve checks in `admin-usability-live-verification.json`: login/access rejection, no-store, CSRF, all 121 SKU identities searchable, normal editor terminology, mobile document overflow and logout. Desktop/mobile screenshots were inspected. The action bar was then made static so it does not cover fields, and header navigation was reduced to ordinary link size. No real-device Safari verification was performed.

Pending: apply `supabase/sql-editor/06_install_daily_product_editor.sql` once to development, then rerun `scripts/verify-admin-usability.mjs --run-development`. Hosted Supabase still lacks the atomic daily-save RPC. Actual browser single-product/two-option saves, stock reconciliation, Publish rejection and option removal are therefore pending, not passed. No synthetic products were created during the pre-install run. The revised image-control UI has not yet been independently exercised against providers; the earlier real media verification remains historical service evidence.

Ten security/media unit tests passed separately (provider transport mocked where stated). Source integrity passed for all 64 original files and 14 CSS blocks. Dependencies/lockfile are unchanged. The earlier synthetic failed-image cleanup guard remains pending until its recorded eligibility. No next-stage storefront integration or real product publication was performed.

## Earlier stage record (historical)

# Product administration

This stage adds `/admin/login` and `/admin/products`. The storefront, approved reference, sample cart and storefront catalog adapter are unchanged. No product-publication button is provided in this stage.

## Security and sessions

Supabase password login runs on the Next.js server. Only accounts whose verified Auth user has active database admin membership receive a session. The access token is held in a host-only, HTTP-only, SameSite=Strict cookie scoped to `/admin`, with a maximum one-hour lifetime and no stored refresh token. HTTPS Secure cookies are required outside `next dev`; expiry requires signing in again. Every protected page/read/write validates Auth and database membership. Removing membership immediately removes panel access. Logout clears the cookies and asks Supabase to revoke the local Auth session; already-issued JWTs remain subject to Supabase token expiry semantics.

Every mutation, including login, requires a random HTTP-only CSRF cookie plus its matching request header and an Origin matching the actual Host header. Forwarded host headers are not trusted. GET never changes catalog data. Private pages/APIs/media use `private, no-store`; API errors omit provider payloads and credentials. Public API keys are not admin authorization, and no service-role key is used. No user metadata can assign membership.

Supabase Auth applies its configured authentication rate limits. Production hosting, reverse proxy configuration and any shared edge rate limiting remain deployment decisions. Do not expose the development server publicly.

## Product workflows

- Search original SKU/name with 50-row pagination. Open each product for immutable identity, preserved source values, unresolved flags, publication blockers and optional enrichment.
- Create a distinct draft SKU through the existing transactional import RPC, explicitly marked `admin-entry-v1` provenance. Existing exact SKUs and normalization collisions cannot create duplicate identities. Confirm a product family before adding legitimate shade/size variants; existing unresolved families are never merged.
- Edit category/subcategory, compatible product type, brand, description/usage, identity review, variant labels/options and integer-minor-unit PKR prices. Product details use revision checks to reject stale edits. Original source SKUs and source values remain immutable.
- Add category-specific typed facets and skincare concerns with explicit official/package evidence review. Optional concerns never block publication; concern research remains partially complete. Review checkboxes record individual publication requirements; they do not publish products.
- Hide archives a product; unhide returns it to draft. Homepage selections stay draft and do not replace the sample storefront content. Position conflicts must be resolved explicitly, not silently overwritten.
- Stock is adjusted only through `adjust_inventory`, with an explicit signed delta, reason and idempotency UUID. Workbook quantities are provenance, not initial live stock. Existing schema rejects zero-delta movements; a zero-count reconciliation needs a separately designed audited operation, not a fabricated movement.

## Media workflows

Upload files by selected SKU/product, with alt text and optional replacement target. Multiple PNG/JPEG/WebP files are accepted (10 MiB each). The existing service stores private originals, verifies bytes, records explicit review approval, uploads with a server-only Cloudinary signature, validates provider metadata and links the image. Images can be primary, reordered, replaced or detached. Cleanup is separate and refuses referenced assets. Publishing an image does not publish its product.

Initial import previews exact filenames against immutable original SKUs. The 17 exact matches can be staged/retried using deterministic per-variant/content UUIDs. Three unmatched name-based files remain unassigned until an administrator confirms a target SKU. Initial staging does not approve or publish images. Future uploads do not use repository filenames or folders.

## Configuration and verification

Use existing secure local configuration: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `MEDIA_ENVIRONMENT=development`. Existing `APP_ENV` / preview configuration still applies. No new secret is required. Never paste credentials into chat. The development project must already have migrations 001–007 (including `05_install_media_service.sql`); this stage does not rerun the installer or require another migration.

Live verifier: `.tools/node-v24.21.0-win-x64/node.exe scripts/verify-admin-development.mjs --run-development`. Requires Chrome and local `TEST_ADMIN_EMAIL`, `TEST_ADMIN_PASSWORD`, `TEST_USER_EMAIL`, `TEST_USER_PASSWORD`. It performs authorized draft imports and image staging, creates a synthetic product/media fixture, exercises browser flows and archives/cleans up that fixture. It never prints credentials or stores Playwright traces. Inspect `docs/admin-live-verification.json` before retrying an interrupted run; historical synthetic metadata is retained for audit.

Live checks and their current status are recorded in `docs/admin-live-verification.json`. Static checks and any remaining limitations are separately recorded in the implementation status. Do not interpret compilation as visual or provider verification.


## Product admin verification completion (2026-10-06)

Actual results: `admin-live-verification.json` (49 passed events, including retries), `admin-extended-verification.json` (14 passed checks), and `admin-import-audit.json` (ten passed checks). All 121 original SKUs are individually searchable as drafts with preserved raw fields/prices and zero unreconciled live stock. Seventeen exact-match photos are private and unapproved; three unmatched files remain unassigned. Browser Auth/permissions, editing, stock, typed evidence, CSRF and real media publishing/cleanup passed. Ten local security/media tests passed separately; mock transport checks are not claimed as provider verification. Types, lint, build and source preservation passed. No additional migration is pending.

One rejected synthetic image has zero associations but leaves an unlinked Cloudinary asset and private original until the established cleanup guard expires at **2026-10-06T23:53:51.291Z**. Its product is archived; the valid test image was already cleaned up. See `admin-cleanup-verification.json`. After eligibility run:

```powershell
& '.tools/node-v24.21.0-win-x64/node.exe' --conditions=react-server scripts/reconcile-admin-test-media.mjs
```

This verifies the recorded synthetic identity and uses the existing safe cleanup service. It does not touch initial catalog photos. No guard was bypassed; synthetic audit history remains retained.


Final storefront regression: after restarting the local development server, the existing Chrome desktop/mobile-emulation homepage suite passed **6 tests**, with **2 intentional viewport-specific skips**. This includes desktop reference geometry/carousel-state comparison, sample interactions, mobile hero/menu layouts, and motion/swipe behavior. The initial attempt could not connect to the stopped local server; the completed rerun passed. The reference is restored for development and absent from the production build. All 64 supplied source files and the 14 reference CSS blocks still pass integrity checks.

The final read-only import audit now has ten passed checks, including anonymous PostgREST denial for the imported draft products, variants and source provenance, and all 121 individual SKU searches. Admin tests used Chrome with mobile emulation; no real-device Safari test was performed. Core requested live flows passed; multiple-file selection, adding a confirmed variant, and individual primary/order/replacement UI controls were implemented on the existing services but not each independently exercised in this browser run.


Final revision checks: ESLint, TypeScript and production build passed; `/reference` is absent from the production route manifest and restored in development. The existing homepage Chrome regression passed six tests with two intentional viewport-specific skips, including desktop reference geometry/carousel states, interactions and mobile hero/menu behavior. Final admin screenshots were inspected after the action-bar correction. The final actual admin run passed twelve checks, including the separate import-history page and omission of import controls from the daily product page. Live save and two-option flows remain pending SQL Editor file 06; these results do not mark the revision complete.


## Corrected ordinary-save visibility (2026-10-06, supersedes earlier draft-on-save behavior)

Ordinary **Save** now preserves the existing product visibility and each existing active variant status. Hidden products remain hidden. New options start as drafts; an ordinary save does not publish them. **Save draft** is an explicit transition (with confirmation when the product is published or hidden); **Publish** explicitly publishes eligible active options; **Hide** explicitly hides the product. Removed options remain archived and are not restored by Publish.

A published edit that would lose required information is rejected with an actionable checklist: fix the fields or explicitly choose Save draft. The transaction leaves the original published product, prices, variant statuses, stock, counts and revision unchanged. The UI retains entered values after rejection. There is no implicit unpublish/unhide. Plain Save is also the default for Enter-key form submission.

The corrected migration 008 and regenerated SQL Editor file 06 use a text `p_intent` parameter, defaulting to `save`, rather than a boolean that drafts everything. The report identifies this contract as daily editor version 2. The file still preserves existing business records during installation. Apply only the current corrected file; the previous copy must not be used.

Local verification: the exact SQL Editor bundle passed in a fresh disposable PostgreSQL 16 database. Ten daily-editor groups cover incomplete drafts, zero/retry/stock safeguards, two options, rollback/removal, published and hidden preservation, mixed option statuses, rejected invalid edits and explicit transitions. Auth and Storage there are doubles. ESLint, TypeScript and production build passed. The original storefront/source assets remain unchanged.

Live verification remains pending application of the corrected file. The Chrome runner now includes ordinary and invalid published edits, hidden edits and explicit transitions for both single-product and two-option fixtures. It uses synthetic brands/categories and a neutral synthetic media fixture, leaving the 121 catalog records and their taxonomy/source values intact. It archives synthetic history and uses guarded media cleanup. These prepared live tests have not yet passed; no production integration or real catalog publication is claimed.
