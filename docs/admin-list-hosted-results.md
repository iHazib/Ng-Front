# Actual hosted admin-list verification — 2026-10-11

Migration 013's 19 installed-state flags were confirmed by the owner; the actual hosted admin Auth and list RPC returned success. No installer or hosted SQL was run in this stage. The existing Next.js app ran on port 3000 against the configured development Supabase/Cloudinary accounts.

49 actual checks passed: 42 in the synthetic-fixture run and seven supplemental read-only browser/API checks. This is separate from earlier disposable PostgreSQL/Auth/Storage doubles and browser mocks; no provider mocks were used for these results.

Verified all-status smart name/brand/type/assigned-concern search, prefix and trigram spelling variation, SKU alias plus option matching, same-option OR/AND facets, combined category/brand/type/facet filters, additional category ancestry, category assignment removal freshness, bounded pagination/counts, required/optional badges, archived-option exclusion, uncounted/confirmed-zero stock, Ignore/Undo/Restore and reload persistence. Ignoring preserved product revision/content/stock and did not bypass publication. Fix/recurrence restored the reminder. An actual product-name edit through the browser immediately refreshed search.

Real browser checks covered admin login, non-admin rejection, anonymous Next denial, CSRF-less mutation rejection, uncached private responses, hosted anonymous/non-admin RPC denial and inaccessible private API schema. Desktop/mobile fixture screenshots were captured and inspected. Supplemental browser controls combined brand, additional category and assigned facet; pagination advanced a bounded server page. Unsupported suitability did not produce matches.

A neutral synthetic PNG went through the actual private upload/explicit approval/Cloudinary publishing service. Synthetic publication and hiding worked; removing the image restored its missing-image reminder. The verification did not publish any real product, modify homepage selections or import catalog data.

## Known limitation

The exact synthetic SKU alias alone returns both Small and Large sibling SKUs because their long shared identifier prefix passes the trigram threshold. Alias plus shade/size narrows correctly. This is an observed precision limitation, not a passed exact-identifier isolation check. It requires exact SKU/alias priority ahead of fuzzy matching in a future incremental database correction. Applied 013 was not edited or rerun. Search does not infer suitability.

## Preservation and cleanup

The final fixture run preserved every pre-existing row hash across 29 business tables (1,211 rows, including prior archived test history). This includes catalog, stock/prices, source/import records, media, homepage selections and existing content. Earlier attempts also passed their preservation snapshots. All 64 original handoff/import files and 14 reference CSS blocks remained byte-identical. Storefront code/styles and approved assets were not changed.

Four synthetic products created during this turn are archived; synthetic taxonomy is archived/inactive. Both neutral test images are deleted via the media service. A final actual read-only provider check confirms zero anonymous-visible synthetic products. Audit, inventory, import histories and archived fixture identities are retained safely rather than purged. One batch-payload mismatch and one reminder-panel selector in the verification harness were corrected during retries; these were test setup issues, and their fixtures were cleaned too.

Evidence: admin-list-live-verification.json, admin-list-live-readonly-verification.json, admin-list-live-cleanup-verification.json and admin-list-hosted-results.json. Screenshots: .local/admin-list-live/desktop.png and mobile.png. Chrome mobile emulation was used; physical iOS Safari and production-scale load were not tested. No credentials were displayed. No commerce stage began.
