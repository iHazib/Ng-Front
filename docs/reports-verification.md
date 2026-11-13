# Reporting/refunds verification — 2026-10-20

## Hosted financial verification completed (2026-10-20)

Supersedes earlier pending-installation/hosted-verification notes. Owner confirmed 020/021 receipts and all 15/seven flags; no installer or hosted SQL was run. Actual Chrome, Next.js, hosted Supabase/Auth/PostgREST, private Storage and Cloudinary checks passed: 91 main, 22 supplemental and 44 independent cleanup/read-back checks. No intercepted provider responses were used in these runs.

Six synthetic orders covered exactly-once completion, separate receipts/shipping/cash, mixed-cart frozen deal attribution, full/partial-value/item/shipping/overpayment refunds, cancelled/uncompleted cash-only refunds, competing approvals and duplicate-reference sends, retry/stale-edit protection, explicit outgoing-history confirmation, independent inspected resale/damaged returns, partial deal components and dispatched limits. Real browser request/approve/send/return controls and desktop/mobile Reports layouts passed. Historical order/report values remained unchanged after synthetic catalog/deal price edits; hidden visibility was preserved. Actual CSV totals/privacy, Pakistan-day filtering and previous-day exclusion passed. Anonymous/non-admin financial RPCs and all seven private financial tables were inaccessible; private financial responses remained no-store.

Cleanup: two products and three deals hidden, options archived, five approved test media/private originals deleted; all six order/financial histories and audit events retained. No active fixture reservations, idle deal pools or approved/requested financial holds remain. Global reconciliation: zero balance mismatches, overdue holds and ended allocations. All 1525 pre-existing rows across 40 tables, homepage selections and pre-existing business/development financial events were preserved. All 64 handoff/import files and 14 reference CSS blocks remain byte-identical. Normal checkout stays disabled; no real funds moved, storefront design changes, courier integration or next stage.

Verification limits: exact 18:59:59/19:00:00 UTC Pakistan-midnight fixtures and hostile formula-like CSV names were tested in disposable PostgreSQL/unit tests, not newly fabricated/backdated hosted financial history. Actual hosted day windows and CSV totals/privacy passed. Bank/wallet outgoing-history acknowledgements were synthetic; no account statements or real transfers were verified. Chrome desktop/mobile emulation is not physical-device, other-engine or production-load evidence. Prior storefront comparison remains 21/23 pixel-identical with the documented existing search-link/full-page differences; no new fidelity claim follows from these financial tests.

Evidence: reports-hosted-live-verification.json, reports-hosted-supplement.json, reports-hosted-cleanup-readonly.json; screenshots under .local/reports-hosted. Local SQL, intercepted UI and unit evidence remains separately labelled in reports-verification.md/json. Receiving-account/shipping/tax/deadline approval, trusted ingress and an independent commerce-maintenance scheduler remain launch setup decisions.

## Passed on actual local PostgreSQL (Auth/Storage are doubles)

- Exact complete 020 on fresh 001–019: 15 flags, unchanged seeded records, 60 assertions, repeated-install refusal, two independent authenticated-session races for approvals and duplicate outgoing transfers, clean inventory reconciliation.
- Exact frozen 020 followed by exact 021 in another fresh database: all prior regressions/races, seven 021 flags, 11 additional partial-value assertions, unchanged financial rows/function OIDs/owners/grants, repeated-install refusal. 020 remained byte-identical to the previously supplied file.
- Rules tested include completed-once sales; placements/receipts/dispatch excluded; frozen deal attribution; partial/full/shipping/overpayment/cancelled refunds; approved cash reservation and release; explicit outgoing confirmation; value/quantity/cash caps; duplicate/stale actions; corrections without deletion; damaged/partial deal returns and no duplicate restock; receipt dates and Pakistan midnight; business/test separation; pre-completion-refund recognition without moving cash dates; admin/non-admin/private grants.

Hashes and exact files: reports-installer-manifest.json, reports-local-verification.json, partial-refunds-installer-manifest.json, partial-refunds-local-verification.json. SQL Editor steps: reports-setup.md. No applied earlier migration was edited or rerun in the connected project.

## Passed with mocked financial API responses

Actual Chrome/Next and real admin login, with explicitly intercepted reporting/refund responses: 14 checks across 1440px desktop and 390px mobile. Reports/cash/alternative component view/CSV navigation, order drill-down, request/approve/send, CSRF headers/idempotency fields, partial-value quantity-zero payloads, damaged return and viewport fit passed. Screenshots under .local/reports-ui were visually inspected. These tests do not prove actual hosted financial writes or money receipt/send.

Five unit tests passed for formula injection/quoting, private-data exclusion, exact integer CSV, very large PKR formatting, precise amount input and component-name formulas. TypeScript, lint, final production build and production preview/auth/noindex/sample/reference-route security checks passed. No package was added; dependency lockfile retained.

## Historical pre-installation hosted read-only checks

Seven checks: anonymous private reports/finance API denial, CSRF-less finance denial, non-admin rejection, admin membership/login, missing schema shows an error rather than sample fallback, normal checkout disabled. New report RPC returns PGRST202/404 at the time of this check. Private receipt installation cannot be inspected through the configured HTTP keys; the owner must confirm SQL Editor flags. No direct database/management connection is configured; no credentials are requested in chat.

## Storefront preservation

Eight homepage/scaffold browser tests passed, with two intentional mobile/desktop skips. Desktop section geometry and carousel states, interactions, sample bag, motion/swipe and mobile hero/hamburger/resolver checks pass. Source verification confirms all 64 original handoff/import files and 14 reference CSS blocks unchanged. Storefront source/styles/assets were not edited.

Of 23 same-state desktop screenshot pairs, 21 are pixel-identical. The existing search-link difference is unchanged (mean channel difference 0.1822712042), and the small full-home difference is 0.0171112606. The pixel threshold still flags the search comparison; it was not waived or called a clean pixel pass. These differences were already recorded before this financial stage. Geometry and responsive checks are separate passing evidence. See reports-homepage-visual-verification.json.

## Remaining setup and limits

No installation or fixture-cleanup step remains pending. Exact midnight boundary fixtures and formula-like CSV names have local SQL/unit evidence; actual hosted day windows, selected CSV totals and privacy have separate passed evidence. No real account statement or money transfer was tested. Receiving accounts, shipping/tax/deadlines, trusted ingress and independent maintenance scheduling still need approved launch configuration. Normal checkout remains disabled. No courier or next stage was started.

Final runtime check: isolated port-3100 synthetic checkout stopped; normal checkout remains disabled and development /reference returns 200. Full lint, targeted harness lint, five money/CSV unit tests and source-integrity checks passed in this continuation. No application source or applied migration change was required.
