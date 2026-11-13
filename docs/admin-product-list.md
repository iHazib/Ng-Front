# Admin product list update — 2026-10-09

Only the daily product list, its private access layer and derived database infrastructure change. Product editor workflows, business records, publication safeguards, storefront templates/styles and approved assets are preserved.

## Behaviour

- Search uses original SKUs/SKU aliases, names, brand aliases, category ancestry/additional assignments, product types, shade/size labels/options and actual assigned facet/concern values. Token conjunction supports partial words and trigram spelling variations. This is an admin-only index; pending/unapproved assignments can be found in admin but never enter the public projection through this change. Search does not generate suitability or claim assignments.
- The list shows matching SKU rows and shade/size labels, with distinct product and SKU totals. Active options are listed; incomplete removed options do not contaminate active-option warnings. A product whose options are all removed retains a representative history row so the owner can still open it.
- Filters combine visibility, brand, hierarchical category/subcategory, type, category-assigned facets/concerns, attention issues and ignored reminders. Values within a facet use OR, different facets use AND on the same matching option. Main categories include descendants. Page size is 25 (RPC maximum 50); total counts match applied filters. Search is bounded to 160 characters, JSON/filter sizes are validated and database listing has an eight-second statement timeout.
- Required information is labelled “Before publishing”; optional copy and availability are separate. Unreconciled stock is “Not counted”; a reconciled zero is 0 plus “Out of stock”. Reserved quantities are shown separately. Pending photos are distinct from an approved primary image requirement. Optional How to use/Key benefits reminders are omitted for Cutlery, including descendants inheriting that scope. These remain optional everywhere; no publication checks were added or weakened.
- Ignore/Undo/Restore changes only a private dismissal and an audit entry. It never changes product revision, content, status, price or inventory. Dismissals belong to a product issue or affected option issue and its occurrence UUID. Fixing an issue ends that occurrence; a later recurrence creates a new UUID and restores the reminder automatically. “Ignored reminders” filters and per-row controls support recovery. Needs-attention filters intentionally count underlying unresolved issues even if their reminders were ignored; ignoring never bypasses publication blockers.
- Ordinary mutations refresh only the affected product. Infrequent taxonomy changes refresh the derived index set. The existing public search index/functions remain unchanged. No client policies/grants exist on the new private RLS tables. Every public admin RPC checks database membership, every Next read/write validates Auth, mutations reuse CSRF/origin checks, and private responses remain no-store.

## Incremental SQL Editor application

Earlier migrations/installers must not be rerun. No secrets or database password are required in chat.

1. Run the entire **11_preflight_admin_catalog_list.sql** alone in a new DEVELOPMENT SQL Editor query. `prerequisite_012` must be true. Before a new installation, search/issues/dismissals/list/filters/reminder/receipt presence and receipt_matches are false; shared-view/helper presence and refresh_triggers_installed are false; private_rls is null, and no_client_policies is true. Any existing new presence/receipt requires inspection rather than a rerun. A 404 API response alone does not prove rollback/absence.
2. Only after confirmed absence, run the entire **11_install_admin_catalog_list_clean.sql** once in another new query. All final checks should be true. Confirm the receipt hash and refresh the admin. If the RPC still returns PGRST205/PGRST202, inspect schema exposure/grants/cache; reload only the PostgREST schema cache after installed-state verification, not the installer.
3. Return the result flags only, without secrets. Then run the prepared actual development browser runner with the existing local configuration.

The installer creates three private RLS tables, a private assigned-attributes view/indexes, authorized functions and derived-refresh triggers, then inserts one receipt and notifies the schema cache. It executes no DELETE/TRUNCATE/DROP or UPDATE against catalog, stock, media, content or other existing business records. Runtime DELETE/UPDATE statements affect only the new derived/reminder tables during refresh/Restore. No column on an existing table is added or rewritten. Foreign-key cascades apply only to new derived records on an authorized future owner deletion. Receipt and exact-file hashes: admin-list-installer-structure.json.

## Verification

- **Disposable actual PostgreSQL, Auth/Storage doubles:** exact complete installer executed with `psql -X -v ON_ERROR_STOP=1 -f` against fresh migrations 001–012, preserved all existing public rows, matched the supplied file hash and refused repeat installation. Existing catalog/security/media/review/daily-editor regressions passed; local 121-SKU import/repeat preserved stock/copy. New search/aliases/typos/variant matching, same-option OR/AND filters, any/all issue filters, counts/pagination, stock distinctions, Ignore/Restore/fix/recurrence, revision preservation and anonymous/non-admin RPC/direct-access denial passed. See admin-list-database-verification.json. This is not hosted Auth/Storage verification.
- **Actual Next/Chrome with local provider doubles:** 14 checks passed for list pagination/counts, matching options, stock labels, collapsed filters, ignore/undo/persist/restore, combined filter payloads, assigned facets, responsive layout and CSRF denial. Desktop/mobile screenshots were captured and inspected. See admin-list-mock-ui-verification.json. These are not hosted catalog results.
- **Actual hosted read-only:** admin Auth login passed; new admin-list RPC returned HTTP 404. No hosted catalog fixtures or real record changes were made by that probe. Actual fixture tests await the installed-state confirmation for 013; see admin-list-hosted-preflight.json and admin-list-live-verification.json for current access checks.

Repeatable commands using the configured Node/Python runtimes:

```
node scripts/prepare-admin-list-sql.mjs
python scripts/test_database.py --admin-list-installer
node scripts/verify-admin-list-ui-mock.mjs
node scripts/check-admin-list-setup.mjs
node scripts/verify-admin-list-development.mjs --run-development
```

The prepared actual runner stops before catalog mutations if 013 is unavailable. When available it uses only synthetic draft/published/hidden products, assigned attributes, aliases and a neutral approved image; tests actual browser/API search/reminders and snapshot preservation, then hides fixtures, archives synthetic taxonomy and safely removes uploaded media. Audit/history tombstones are intentionally retained. Real records and homepage selections are never published/edited by the runner. Browser coverage is Chrome desktop/mobile emulation, not physical Safari. No next commerce stage is started.

## Corrected installer review — 2026-10-11

The generated installer now uses shared category membership (including additional assignments/ancestors) and the identical eligible option set in both list and filter options. Removed options do not supply filters when active options exist. An all-archived product retains one history option; an optionless product retains an editable product row, a missing-option blocker and zero SKU count. Admin types/display accept a null variant/SKU without inventing an identity.

OLD-owner lookup now also handles set_variant_id. Media presence remains stable during publishing/failure/retry when an actual private photo exists. Upload completion, approval, linking/primary selection, detach, owner changes and workflow deletion refresh derived reminders/thumbnails. Ignored issues start a fresh nonignored occurrence after being fixed and recurring.

29 targeted SQL assertions passed in supabase/tests/admin-list-freshness.sql, in addition to existing local catalog/security/media/content/review/editor/search/reminder tests. The exact complete installer passed ON_ERROR_STOP=1 on fresh 001–012; all 19 final verification flags were true. Public business-row snapshots remained identical; repeat installation was refused. Both added shared views deny anonymous/non-admin direct access. Auth/Storage/Cloudinary metadata are doubles; no hosted SQL or provider calls occurred in this revision.

Canonical migration SHA-256: de9272e1f837c654aa613e84fbabc8e1e12fc6248475764573a6a153d46e51b0.
Exact tested installer SHA-256: c570fff73caf5395271f6e5cde9bce658cb7e5359c13e301684cb23be2584310.
See admin-list-database-verification.json; local evidence database-test-0cc53f2d96da. Use the complete corrected installer, not an earlier copied version. Hosted 013 application and live fixtures remain pending; the storefront and previous migrations remain unchanged.

## Actual hosted verification completed — 2026-10-11

49 real Next/Chrome/Supabase checks passed; main and supplemental evidence are in admin-list-hosted-results.md. Search/filter/reminder/freshness/security flows and browser controls were exercised with synthetic records only. Four fixtures are archived and both test media deleted; existing rows/homepage selections and original assets were preserved. No mocks or hosted installers were used in this run. Exact long SKU aliases can still return a close sibling through trigram matching; this precision limitation is recorded separately and was not counted as a passing exact-isolation test. Mobile is Chrome emulation, not physical Safari. No commerce stage started.
