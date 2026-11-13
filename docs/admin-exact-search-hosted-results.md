# Exact identifier search: actual hosted verification

2026-10-13. Completed after owner confirmed all nine migration 014 final flags. Supersedes earlier pending-installation and pre-fix reproduction notes. No installer or migration was run or edited.

## Actual live results

All 41 checks passed through real Chrome, local Next.js and the connected development Supabase Auth/PostgREST services. No mocks were used in this run.

- Full original Small and closely spelled Large sibling SKUs each isolated their own option.
- Case-normalized and whitespace-trimmed original SKUs and accepted SKU aliases isolated exactly one option.
- Original spaced SKU, normalized hyphen spacing and expanded separator spacing isolated the Spaced option. Stored original SKU remained unchanged.
- Alias plus matching brand/category/product type/facet filters returned one option. Excluding facet, visibility, category or brand returned zero, including a facet supported by the sibling; there was no fuzzy fallback.
- Excluding filters on an original spaced SKU also returned zero.
- Actual desktop browser searches for alias, original Large SKU and normalized spaced SKU showed one correct option row. Alias search also passed at a 390x844 mobile viewport (desktop 1440x1000).
- Ordinary CeraVe-style typo/name search still returned actual assigned matches. General partial identifiers and combinable OR facet filters retained expected results.
- Actual admin login succeeded; non-admin login and anonymous/non-admin RPC/private-schema access were denied. CSRF-less mutation was rejected and private responses stayed uncached.
- Synthetic product creation and three-option saving used the authorized Next wrapper. Fixtures remained drafts throughout testing; none was published.

## Preservation and cleanup

Every checked pre-existing record hash across 29 catalog/content/media tables and 1275 rows stayed unchanged, including homepage selections. The new synthetic product and its three options are archived; its synthetic brand/category are archived and its facet inactive. A separate actual read-only check also confirmed the two earlier reproducer fixtures remain archived: 3 products and 9 variants in total, zero anonymous-visible products or variants. Private audit history and archived identities remain for traceability. No images were uploaded or changed.

All 64 supplied source/import files remain byte-identical and all 14 reference CSS blocks are unchanged. Applied migration 013, canonical 014 and installer hashes still match their prior verified values. No storefront, approved assets, dependencies or lockfile were changed. Only verification scripts and documentation were updated; targeted script lint passed. The local Next server remains running on port 3000.

## Live versus local and limitations

Historical 2026-10-12 local tests executed the exact complete 014 installer against fresh migrations 001-013 with ON_ERROR_STOP=1, using Auth/Storage doubles. Those tests are recorded separately in admin-exact-search-local-verification.json and were not rerun here. This report records actual hosted/browser results, not those local doubles.

No functional exact-search check remains pending. Owner-reported installation flags establish receipt/RLS metadata; no private SQL receipt was read through the API. Other browser engines, physical mobile devices and production-scale load were not tested. An initial sandbox-only local server startup failed on Windows path canonicalization; authorized local startup resolved it before the fixture run, with no app change.

Evidence: admin-exact-search-live-verification.json, admin-exact-search-cleanup-verification.json and admin-exact-search-hosted-results.json. Earlier pre-installation reproduction is retained in admin-exact-search-live-preinstallation-20261012.json. Commerce has not started.
