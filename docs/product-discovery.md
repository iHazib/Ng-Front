# Product discovery: concerns, category features and recommendations

Implemented 2026-11-25. This is separate incremental 024 after owner-confirmed 023. No hosted SQL, product assignments or publication have been performed. Not pushed/deployed yet.

## Approach and audit

The actual hosted read-only audit found all eight approved skincare concerns already present but inactive. Existing category facets were also inactive, and the daily editor displayed assignments without a practical way to create them. This implementation reuses the normalized facet/concern/evidence tables, existing authorized Save, PostgreSQL search and current storefront components. No new backend, paid/AI search, packages or comma-separated attributes.

| Category | Optional fields |
|---|---|
| Skincare | Dryness, Oiliness, Dark Spots, Uneven Texture, Acne and Blemishes, Sensitive Skin, Dullness, Fine lines; skin type, area, size, named ingredients, applicable SPF, piece count |
| Makeup | Shade, format, finish, coverage, skin type, area, material, piece count, size, occasion |
| Personal fragrance | Concentration, scent family, multiple notes, marketed audience, size, piece count, occasion, season |
| Home fragrance | Home format, scent family, notes, size, piece count, occasion, season; no perfume concentration |
| Bath & Body | Format, body-care focus, area, size, named ingredients, applicable SPF, occasion |
| Hair Care | Hair type, hair/scalp concern, format, area, size, named ingredients |
| Cutlery | Material, finish/colour, piece count, care, occasion |

New values are optional vocabulary, not claims about products. They remain inactive until an owner-confirmed assignment. No real product has been automatically classified or given concerns/notes. Concern research remains partially complete. Ingredient presence does not establish treatment or suitability. Acne-prone suitability is not acne treatment, nor barrier support sensitive-skin suitability. Concentration does not imply longevity. Occasion/season are explicitly store curation. Multi-fragrance sets cannot receive one scent profile; a single-profile set needs explicit confirmation that all included items share it. These optional assignment checks do not restore the boxed-set publication gates removed by 023.

## Daily workflow

The optional Discovery filters section follows the chosen category/subcategory. Skincare shows the eight concern checkboxes. Add filter creates a simple row: field, typed value, and either all options or a particular shade/size. Multiple rows support multiple notes/materials. Reference fields accept a specific named value, one at a time. Existing assignments have Remove and pending removals have Undo. No technical IDs or research essays are required.

For additions, confirm the selections against the product label or official page. An official-page selection requires its HTTPS link. Internal approved verification records are generated automatically, preserving verification without exposing it in normal editing. Occasion/season confirmation explicitly means owner curation.

Selections join the SAME existing Save transaction as product details: admin Auth/membership, CSRF, stale revision protection, inventory lock order and idempotency remain. Invalid selections roll back everything. Untouched assignments, source data and internal evidence remain; removals are explicit/audited. Stock/content/visibility are not rewritten by discovery changes. Optional filters never become blanket saving/publication requirements. The UI/server check the installed capability before accepting discovery data; basic saves still work without 024.

## Public discovery and relevance

Only approved assignments backed by approved records and eligible published inventory appear publicly. Inherited category scope is shared by validation, RLS helpers and public projections. Archived/draft variant-only attributes do not leak. Public filter counts and OR-within/AND-between semantics remain in PostgreSQL. Labels and assigned values are indexed in public/admin search; EDP/EDT/EDC are vocabulary aliases. Admin search covers all visibility states; public search remains isolated from drafts, evidence and private content.

Supported values fill the existing navigation columns: skincare concerns/skin type; fragrance audience/family/notes/concentration/occasion; makeup finish/coverage; body features; cutlery attributes/occasion. Unsupported longevity is not invented. Homepage concern cards become linked only when published inventory supports that concern. Hair Care retains its branch under Bath & Body and its scoped listing filters. The public navigation tag expires after authorized saves.

Similar products stay in the same category/scope and exclude self, duplicates, unavailable/imageless options. Within the bounded 24-candidate pool, rank actual type, shared assigned concerns/skin type/scent attributes/occasion and other relevant features, then brand/price proximity. Up to four results stream without blocking the main product. This is deterministic related-product discovery, not personalized medical suitability advice. No sample fallback.

## SQL Editor installation

1. Run `supabase/sql-editor/21_preflight_product_discovery.sql` read-only. Before application: prerequisite_023, public_security_preserved and helper_private true; five capability/receipt flags false.
2. Apply only `supabase/sql-editor/21_install_product_discovery_clean.sql` once using ordinary Run. All EIGHT final flags must be true. Do not rerun 023 or earlier installers.
3. Deploy the frontend/service changes, then reload the editor. Products still need explicit owner Publish.

The installer is atomic and repeat-refusing. It adds inactive vocabulary/private helpers, hooks the current private daily-save implementation behind the unchanged public inventory-locking wrapper, extends scoped navigation, and refreshes derived search/reminder projections. It does not assign claims, publish products, reset stock or rewrite business content. Existing assignment triggers gain SECURITY DEFINER plus explicit require_admin so inherited-scope lookup remains private. Public mutation grants/RLS and current eligibility are preserved. Installer SHA-256 and canonical receipt: product-discovery-installer-manifest.json.

## Verification and remaining work

- Hosted work: actual read-only taxonomy inventory only, in product-discovery-taxonomy-audit.json. No real assignments or synthetic hosted products created.
- Exact complete installer: fresh disposable PostgreSQL with all 24 existing migration files (001–023 plus SEO), `psql -X -v ON_ERROR_STOP=1 -f`, all eight final flags, 37 assertions, existing business rows preserved, repeat refused. Tests cover seven scopes, inherited subcategory, public/admin EDP and combined filters, explicit confirmation, wrong scope/value/variant rejection, retries/stale edits, public/draft isolation, stock preservation, removal freshness and single-profile/multi-profile set rules. Auth/Storage are doubles. Evidence: product-discovery-local-verification.json.
- Six real Chrome/Next admin checks with local Auth/database doubles: eight concerns, atomic Save payload, persisted attributes, mobile fit, fragrance scope and concentration/custom note entry. Screenshots visually inspected under .local/product-discovery. Evidence: product-discovery-browser-mock.json.
- Twenty-three Chrome/Next storefront mock checks passed, including concern/skin-type/occasion navigation links, filters, disclosures, variants and recommendations. Four recommendation units passed. Final production build, TypeScript and lint passed.

Pending: owner applies 024, frontend is deployed, then actual hosted synthetic assignment/save/search/navigation/cache-freshness verification. No bulk manufacturer research/claim assignment was performed: existing real products need owner-confirmed selections, so public filters may remain sparse initially. No courier/payment/order/stock/import work or next stage. No secrets requested.


## 024 owner-confirmed installed — 2026-11-25

Owner supplied expected before/after results: all eight final installation checks true, including receipt/security. Do not rerun 024 or earlier installers. Actual hosted Auth/PostgREST read-only verification then passed 11 checks: admin/non-admin membership; installed discovery capability; 023 boxed gate still removed; anonymous/non-admin private report denial; eight concern definitions; new category vocabulary; public navigation facets contract; helper unavailable as a public RPC; zero Synthetic matches in admin. No SQL installer, hosted product write or synthetic product was created. Evidence: product-discovery-hosted-readonly.json.

Full hosted Save/removal/search/navigation freshness tests remain pending. The user asked to avoid leftover synthetic products; the current API can archive but cannot fully delete audit-linked product-save fixtures without owner SQL. Therefore persistent fixtures were deliberately not created. The 37 disposable-database assertions, six admin/browser mock checks and 23 storefront mock checks remain separately labelled evidence, not hosted write verification. Frontend changes are still local/unpushed; deployment remains required.
