# Exact admin identifier search correction — 2026-10-12

Incremental migration 014 replaces only public.admin_catalog_list. Applied 013 and its installer remain byte-identical. No storefront, assets, dependency or business-row changes are part of this installer. No destructive statements: only CREATE OR REPLACE FUNCTION, explicit existing grants, a new migration receipt and schema-cache notification.

The complete whitespace-trimmed query is normalized using existing sku_collision_key and resolved against indexed variants.sku_key and sku_aliases.collision_key before category/status/facet/attention filters and active-option eligibility. Matching identifiers return only their variant; an excluded or archived option produces zero results rather than fuzzy siblings. Fuzzy name/brand/category/assigned-concern and partial queries run only if there is no exact identifier anywhere in the catalog. Original SKUs and existing normalization/collision guards are unchanged.

sku_aliases is the existing admin-controlled identifier table: accepted rows are business-approved SKU aliases, with no pending approval column. General catalog_search_aliases remain general search terms; this correction does not promote pending terms into identifiers or infer claims.

## Passed: disposable local database

The exact complete 12_install_admin_exact_search_clean.sql was executed via psql -X -v ON_ERROR_STOP=1 -f on a NEW PostgreSQL 16 database with canonical migrations 001–013. Nine final verification flags passed. Every seeded public business-table hash stayed unchanged; the same file hash was verified before/after execution, and a repeat install was refused without business changes. Auth/Storage are local doubles in this test, not actual Supabase services.

Targeted SQL regressions passed: closely spelled long sibling SKU/alias isolation, case/space/tab/newline trimming, spaced SKU normalization without modifying original values, combined category ancestry/brand/type/facets, excluding exact matches without fallback, archived option eligibility, typo/assigned concern search, partial queries, pagination/counts, immutable SKU and cross-owner normalization collisions. Existing admin list/freshness/authorization/reminder and database suites also passed. Sources check confirms 64 supplied files and all 14 reference CSS blocks unchanged. New verification scripts passed lint.

Exact installer SHA-256: `d569fa8fd982d905bc03578740fd5f500646c2c7b58c6d80cba5f748cd57a2fa`.
Canonical migration SHA-256: `3f771bd8309cd0c1de097e93b6aaf76963d7a18c1f26029fb7047ec2c86e53c3`.
Evidence: admin-exact-search-local-verification.json; local folder database-test-522e5c99ac55.

## Actual hosted/browser results

21 checks passed using real Chrome, Next.js, Supabase Auth/PostgREST and synthetic development fixtures: admin/non-admin login, anonymous/private RPC denial, CSRF rejection, uncached responses, synthetic draft create and three-option save through the Next wrapper, ordinary typo search, combined category/brand/type/OR facet filters, preservation and cleanup.

Hosted migration 013 still returns 3 variants for the complete alias and 3 for the normalized spaced SKU in this reproducer. This is an observed pre-fix result, NOT verification that the hosted correction works. No hosted SQL was applied. Direct database connection is not configured; existing Auth keys do not provide SQL Editor privileges. Exact fixed hosted isolation/browser checks remain pending 014 application.

The first runner attempt had an incorrect expectation that a partial UUID-based identifier excluded the third similarly spelled synthetic SKU. It failed that assertion; cleanup and preservation still passed. The corrected general partial-query test combines actual assigned facets, and passed. This was a test expectation correction, not a catalog change. The first sanitized report is retained.

The successful run preserved 1257 pre-existing row hashes across 29 tables, including homepage selections and content/media. Both attempts' synthetic products and all six variants are archived; a separate actual read-only check confirms zero anonymous-visible fixture rows. No media was uploaded or real product published. Private audit/history and inactive synthetic taxonomy remain for traceability.

## Apply once, then complete hosted checks

1. In the connected DEVELOPMENT Supabase SQL Editor, run the entire 12_preflight_admin_exact_search.sql in a new query. Expected BEFORE: prerequisite_013, list_present, authorization_preserved, rpc_grants_preserved, private_rls and no_client_policies true; receipt_014_present, receipt_014_matches and exact_priority_present false. If any 014 flag is already true or prerequisite/security checks fail, inspect state and do not rerun.
2. Run the entire 12_install_admin_exact_search_clean.sql once in a separate new query. All nine final flags must be true. This file includes its own atomic transaction and guard. Do not run earlier installers or edit migration 013.
3. Share only confirmation of final flags. No secrets needed. The prepared scripts/verify-admin-exact-search-development.mjs --run-development then verifies exact original/normalized/alias and spaced SKU isolation, same-size browser row, matching and excluding combined filters, general typos, permissions and safe cleanup through the actual services.

Commerce / Prompt 13 has not started. The hosted exact-priority completion gate remains pending, separately from successful local tests and actual pre-fix reproduction.


## Update: hosted correction verified (2026-10-13)

Supersedes the earlier pending 014 application/fixed hosted verification sections above. Owner confirmed nine flags; no installer was rerun. All 41 actual Next/Chrome/Supabase checks passed, including exact original/normalized/spaced/alias isolation, no fuzzy fallback on excluded filters and ordinary typo search. Existing records/homepage selections stayed unchanged and all synthetic fixtures were safely archived. Details and live-versus-local boundaries: admin-exact-search-hosted-results.md. No commerce started.
