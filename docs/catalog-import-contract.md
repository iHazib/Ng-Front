# Catalog import contract v1.1

This contract preserves the latest supplied workbook and accounts for each source SKU. The later database stage now implements it in versioned Supabase migrations and a server-only access layer; see [database setup](database-setup.md). Only disposable local imports have run. The storefront continues to use isolated visual samples; no admin UI or provider integration is connected.

Version 1.1.0 retains the original mapping and adds `publication_profile`: category-specific essential blockers, optional enrichment and separate review notes. Missing photos do not block draft import/admin search. Optional concerns, genuine secondary media, reviews and extra verified facets do not block publication. Concern research is **partially complete**, not fully assigned. Package-detail questions remain review notes unless they satisfy a category-specific essential identity/label requirement. SQL publication gates enforce required approvals plus actual approved price, reconciled inventory and primary media state.

## Source and outputs

Input: `data/imports/Nook_Glow_Product_Listing_Updated.xlsx`, SHA-256 `6f115be852d12412fd2bfa8697beb298e4700aa9e34c9033e57b001583679101`. This matches the top-level workbook in the original Desktop Web-Assets ZIP. The current contract includes 121 exact SKU records, with 270 source stock units. These are unverified source quantities, not available-to-sell inventory.

The workbook has five sheets. `Product Listings` is the inventory source. `Instructions`, `Catalog Review`, `Search Taxonomy` and the header-only `Listing Copy` are preserved as provenance. They do not execute instructions or approve data. In particular, references to 57 products, no fragrance inventory and website-only Balance SKUs are historical. Do not manufacture BAL-001/BAL-002 records from those notes. Row 125 is the HOME APPLIANCES heading, not a product. Another 417 rows are blank or formula-only templates; all are excluded from inventory, with their original cells retained.

| Artifact | Purpose |
| --- | --- |
| `data/catalog-contract/review.json` | Versioned, explicit per-SKU proposals, source fingerprints, brands/aliases, category tree, product types, typed facets/options, concerns, collections and evidence registry |
| `data/catalog-dry-run/raw-workbook.json` | Every sheet's stored cells, coordinates, Excel type/style, raw lexical value, formula/attributes and cell XML; hashes of every XLSX ZIP member |
| `data/catalog-dry-run/sku-mapping.json` | Authoritative complete per-record raw fields, stable UUIDs, proposals, blockers, package requirements and draft state |
| `data/catalog-dry-run/sku-mapping.csv` | Review view of the same mappings; structured cells use JSON, not comma-list storage |
| `data/catalog-dry-run/import-plan.json` | Stage-draft, stage-update, unchanged or quarantine actions; no execution |
| `data/catalog-dry-run/summary.json` | Counts, source/contract hashes, excluded rows and zero network/database operations |

These contain private cost/source/draft information. Keep them outside `public/`, client imports, browser responses and public logs. Repository access must be appropriate for confidential inventory. The original XLSX is the byte-exact archive for layout, styles, relationships and features; JSON is a lossless source-cell capture, not a promise to recreate Excel's formatting from JSON. Numeric and date serials remain lexical strings with their type/style; null is not zero. Formulas and cached values are separate. The importer does not evaluate Excel formulas, trust cached totals as prices, or follow external workbook links. A formula in stock or selling price quarantines only that row.

## Repeatable local run

Requires Python 3.11+ standard library only. No pip/npm installation, secret, service connection or new backend is required. Use the bundled Python executable on this machine if `python` is not configured.

```powershell
python scripts/catalog_import.py
python scripts/catalog_import.py --previous data/catalog-dry-run/sku-mapping.json --output .local/catalog-repeat
python -m unittest discover -s tests -p test_catalog_import.py -v
```

Use `--source` for a later workbook and keep the old workbook as an immutable source revision. The default dry-run artifacts are reproducibly regenerated, so archive a prior run before comparing an updated source. `--previous` supplies a prior mapping snapshot; it never writes to the prior file. Output under `public/` is rejected. The command does not have an apply flag or database credentials. Unchanged input and contract produce byte-identical outputs, with no run timestamps or random IDs.

The reviewed JSON is maintained directly. It is not a heuristic that automatically reclassifies future inventory. New SKUs become unmapped drafts; changed source fields invalidate the earlier evidence-match status and appear as field-level proposals. A changed review also creates a stage-update plan. Absence from a later file means retain the existing item, not delete, zero stock or unpublish it. An explicit later archive action is separate.

## Identity, families and stock

- **Product**: stable UUID describing a confirmed product family. Initially each SKU gets its own isolated draft product UUID. The UUIDv5 namespace `51299a68-a4ca-51ca-a072-bf0b47152287` and input `product:<exact original SKU>` are frozen for this bootstrap only. Existing IDs supplied by a prior snapshot take precedence. Later admin-created IDs should be generated once and persisted, never derived again after a rename.
- **Sellable variant**: stable UUID, exact unique business SKU, product FK, specific option values, price and inventory. Bootstrap input is `variant:<exact original SKU>`. Original SKU and stock are retained separately for every variant. Product names, row numbers, filenames and normalized SKU spellings are never identity keys.
- **Potential family**: a review suggestion only. Pixi blush, Tarte concealer, Dior oils, Estée Lauder serum sizes, Ciaté blushes and cutlery colours are candidates. No candidates are merged. Confirm manufacturer/model/formula/generation and legitimate shade/size/finish axes first. Preserve variant IDs/SKUs and each stock ledger when approved grouping later moves them under one product. Record source product redirects/audit history; never sum variant stock into a single family quantity.
- **Factory-packed set**: one sellable SKU and its own stock count. Confirm outer barcode/seal and component contents. Contents describe what is in that pack; they do not decrement individually stocked component SKUs. Current workbook sets are `factory_set_candidate` until packaging is verified.
- **Admin-assembled deal**: separate deal identity plus component variant UUID and positive integer quantity. It owns no independent stock balance. Availability is the minimum whole deal quantity supported by components after reservations. A later order transaction must reserve/decrement each component atomically, aggregating shared components across deal/cart lines; reject cycles, missing/inactive components and overselling. Cancellation reverses reservations once. Do not convert a factory set into a deal without an explicit stock/accounting decision. No deals are created by this import.

Source Quantity is a pending inventory snapshot. Re-import must never add it repeatedly, overwrite active stock or erase reservations. A later authorized inventory adjustment compares a dated count with the ledger and writes an idempotent adjustment; import id/source hash/SKU provide a unique operation key. Cost, target, minimum and market price stay distinct decimal PKR fields. Target price is only a selling-price proposal. Minimum/market/cost are not fallback selling prices, advertised discounts or public fields.

## Record-local validation

Exact duplicate SKUs quarantine every affected source row. Different exact SKUs that collide after Unicode NFKC, case normalization and trimming spaces around hyphens also quarantine only that collision set, including collisions with prior identity keys. No first-row-wins, automatic merging or stock addition. Identical names with different SKUs are not duplicates by themselves. Missing SKU rows are retained as quarantined source rows without manufactured identity. Invalid/missing prices or stock can be retained in a draft, but cannot pass publication requirements. Unknown types, facet values/references/scopes and unsupported concern scopes quarantine only affected records. The source schema/header being unreadable is a file-level error.

The normalization proposal for `DANM - 001` and `MAC - 001` is an optional alias, never an automatic SKU change. Normalized uniqueness must also be checked transactionally during future admin edits. SKU renames require an audited alias migration preserving original identifiers and UUIDs.

## Normalized data model for later Supabase implementation

These are logical tables and constraints, not applied migrations:

| Relation | Key fields and invariants |
| --- | --- |
| import_sources / import_rows | UUID, hash, private source object reference, sheet/row, raw field/cell JSON, schema version; immutable revisions |
| products | UUID, draft/published/archived state, brand FK, approved family identity, display copy, slug; optimistic revision |
| variants / sku_aliases | UUID, product FK, exact unique SKU, normalized collision key, source SKU, status; unique alias ownership |
| brands / brand_aliases | UUID or stable import key, display name; normalized alias unique per language; unknown brand stays null until confirmed or explicitly unbranded |
| categories / product_categories | Parent FK without cycles; product links; primary category plus reviewed secondary category membership |
| menu_nodes | Category/collection reference and display position; Fragrances can point to separate Beauty/Personal Fragrance and Home/Home Fragrance branches |
| product_types / category_product_types | Controlled type IDs and allowed category scopes; Makeup Face, Eyes, Lips, Tools/Accessories and Sets are distinct |
| option_axes / option_values / variant_options | Typed axes; controlled values and labels; one value per variant/axis; unique confirmed option combination per family |
| facet_definitions / facet_options / product_facet_values / variant_facet_values | Category-specific enum/reference/integer/decimal-with-unit/boolean value types; exactly one matching typed value column; no schema-wide comma lists |
| evidence / field_reviews | URL or private package-media reference, source type, region/version, reviewed date, bounded factual finding, field/value, approver/time and source revision; distinguish candidate evidence from inventory identity |
| concerns / product_concerns | Controlled concern and claim kind, evidence/approval link; no ingredient-to-claim automation |
| collections / collection_members | Curated memberships, order, schedule and publication state; no implied Best Sellers ranking |
| factory_set_contents | Set variant FK, component description/reference, quantity/size/options; informational only for stock |
| deals / deal_components | Deal UUID, component sellable variant UUID, positive quantity; no independent stock, no recursive deals |
| inventory_ledger / inventory_reservations | Variant FK, signed movements, reason/source idempotency key, lot/expiry; atomic operations and reconciliation |
| product_media / variant_media | Owner FK, ordered approved Cloudinary metadata; pending/confidential media stays in private Supabase Storage |
| catalog_revisions / approvals | Immutable changes, actor, base revision, field ownership, approval/rejection reason and publication revision |

Current review data has 50 normalized brand candidates. For example Cera Ve → CeraVe and Victoria Secret → Victoria’s Secret are lexical proposals; they do not establish authenticity. Blank cutlery/AROM brands must not become Nook & Glow without confirmation. Facet option registries use referenced values, not parsed comma lists. Empty registries remain extensible through authorized admin.

## Taxonomy and claim controls

Hair Care > Dry Shampoo is a proposed new branch for SNG-002. It does not redesign the verified sample homepage in this stage. Home Fragrance remains separate from personal perfume. Source main category Home is retained for AROM-001 even though navigation sits under Fragrances. Ambiguous CTP-001/VS-001/OPI-001 mappings are explicit review destinations, not approved product-use assertions.

All eight approved visual concern groups exist: Dryness, Oiliness, Dark Spots, Uneven Texture, Acne and Blemishes, Sensitive Skin, Dullness, Fine lines. Their production activation is currently false. Source concern strings are preserved verbatim, not imported as approved memberships. Additional discovery concepts such as post-acne marks, visible pores and barrier support remain separate controlled terms. Search aliases aid discovery; they are not claim equivalences.

Only exact product-level evidence may support a concern proposal. Manufacturer-page findings still require the stocked formula/market to match and an approval record. Ingredient presence, a product name, “all skin types”, a generic brand page or an unrelated reformulation is insufficient. Blemish-prone suitability is not acne treatment. Post-acne marks are not active acne. Barrier support is not sensitive-skin suitability. AXI-002 has a sensitive-skin candidate because its product page explicitly addresses it, not because its name says barrier. No concerns are currently approved or published.

Fragrance notes, family, concentration, size and marketed audience are optional typed facts requiring evidence for the exact edition. Longevity is not derived from concentration. Mixed fragrance sets have component-level information only; no single scent profile is assigned. AROM-001 does not get peony notes from its name. Cutlery colour is a finish-colour proposal, not solid gold/steel grade, piece count or dishwasher-safe evidence. Bath & Body facets distinguish application area and wash/scrub/lotion/serum formats, with no facial suitability inferred. Missing product photos use neutral placeholders until reviewed; no fabricated angles.

Production filter options must be a query over approved values attached to supported published sellable inventory, not the complete option registry or prototype menu. Unsupported options stay inactive and can be added later through admin without a schema change. No catalog taxonomies or draft records are wired to public search in this stage.

## Incremental admin and publication contract

Future authorized admin must save incomplete drafts at any time, upload/reorder media by product name/SKU, edit individual fields/options, review evidence and preview proposed changes. Re-import is a three-way review of previous source, incoming source and current admin value. Retain admin-owned edits; offer source changes with conflict reasons. Null incoming values never silently erase approved fields. Explicit clearing is an audited action. Never auto-publish because a workbook cell says Listing Ready.

Publication is per product/variant, not an all-catalog gate: confirmed identity, unique SKU, approved taxonomy/type and variant identity, explicit PKR selling price, stock reconciliation, approved primary photo, accurate required description/usage or explicit not-applicable status, relevant pack/expiry/condition checks and a recorded publication approval. Unsupported optional concerns/facets can remain absent; missing reviews and genuine secondary photos are not requirements to fabricate content. One ambiguous Dior SKU cannot block an unrelated complete product. A family can expose only its individually approved variants.

Supabase Auth roles and RLS must enforce draft, evidence, cost and customer-data privacy later; noindex is not authorization. Server-only Next.js services validate every admin mutation and state transition; only a safe published DTO reaches storefront/search. Published media goes to Cloudinary; review/confidential draft media stays private. The dry run grants no approval and applies no migrations. All 121 current rows are intentionally drafts because final identity/media/content/publication approvals are absent. The contract supports later completion; the catalog is never treated as finished.
