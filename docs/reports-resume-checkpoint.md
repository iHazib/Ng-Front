# Current owner-confirmed gate (2026-10-20)

020 (15 flags) and 021 (seven flags), including receipts/security, are confirmed installed by the owner. Do not rerun or regenerate installers. Actual hosted financial verification and independent cleanup are passed; consult reports-hosted-live-verification.json, reports-hosted-supplement.json and reports-hosted-cleanup-readonly.json. Six synthetic order/financial histories remain intentionally retained, without stock/financial holds or public fixtures. Older pending-installation notes below are historical. Normal checkout remains disabled.

# Current resume gate — 2026-10-20

020 and the separate partial-value extension 021 are prepared and exact-file tested. 020 remains unchanged at SHA-256 9495f7d52a00ebbc2679e861215475fddef46e85ff91cb356a770398cb6ae515. Do not rerun it if installed. Owner must confirm 15 flags for 020 and seven for 021 before actual hosted financial fixtures. Read reports-setup.md and current verification evidence. The live harness is prepared, not executed. Earlier checkpoint text below is historical.

# Resume status — 2026-10-20

020 is now prepared and exact-file tested; the paused draft blocker was removed only by clean regeneration. Read docs/reports-setup.md and the current reports verification evidence before acting. Owner application/receipt confirmation and actual hosted financial fixtures are still pending; do not rerun 001–019 or claim hosted financial completion. The guarded live harness is now prepared, but not executed.

The original 2026-10-18 checkpoint is retained below as historical context, not current instructions to block the tested installer.

# Paused: sales reporting, refunds and returns (2026-10-18)

User asked to do this later and resume from here. Do not restart the stage or rerun 001–019.

## Current state

001–019 are owner-confirmed installed. The previous hosted deals stage is complete; docs/deals-hosted-results.md and JSON remain the passed evidence. No hosted financial-stage SQL, refunds, returns, transfers or business fixtures were executed. Real checkout remains disabled. This stage is unfinished and NOT ready for installation.

Work in progress: canonical 202610180020_reports_refunds_returns.sql; generator scripts/prepare-reports-sql.mjs; private completed-sales/refund/return/receipt-date ledgers and secured RPCs; Reports page/API; order-level OrderFinance panel/API; Reports navigation; actual receipt-date input; admin-only styles. Frontend storefront files/assets remain unchanged. No new dependencies.

Canonical 020 has evolved beyond the last generated installer. The SQL Editor installer is deliberately blocked and marked unverified; do not give/apply it until regenerated and its exact bytes tested. No hosted installer was run.

## Verification so far (not completion)

- Three CSV/PKR unit tests passed: formula injection, exact integer export, privacy and large-paisa formatting.
- First full lint passed BEFORE later source edits; rerun after finishing.
- Typecheck initially hit Windows sandbox canonicalization restrictions. Escalated retry generated Next types, then identified BigInt literal target errors. These were changed to BigInt constructors; not yet rechecked.
- Fresh disposable 001–019 installer runs passed installation/postflight/preservation checks for earlier draft SQL, then stopped on fixture requirements: first missing expectedDealRevision (fixed), then overpayment correctly not permitting fulfilment (test adjusted to verify extra funds after completion). Final canonical source/installer and regressions have NOT passed together.
- Initial mocked Reports browser run passed first metric check then timed out during component-view transition; changes were being made concurrently. It needs a stable rerun and inspection. No hosted financial flow verified. Test report records failure, not a pass.
- No final build, fresh full tests, concurrency checks or new storefront regressions yet.

## Resume next

1. Read AGENTS.md and installed Next docs. Inspect latest canonical SQL, source and generated artifacts without overwriting correct work.
2. Review newly added explicit net-payment/stock resolution action and wrapper safeguards. Confirm helper declarations/types and action allowlists agree. Check dispatch idempotency when an approved refund is created after an earlier successful dispatch.
3. Regenerate one clean complete 020 installer and read-only preflight using the generator, removing the intentional draft blocker only through regeneration. Run exact file with ON_ERROR_STOP=1 in fresh 001–019; test current canonical hash equals receipt and delivered installer hash. Earlier installers remain untouched.
4. Finish SQL regressions, including independent concurrent approvals/sends, full remaining refund, return-without-refund, damaged returns, reversals, receipt dates, pre-completion-refund recognition at later completion, actual Pakistan boundaries and business-vs-development reporting isolation. Fixture helpers/tests: supabase/tests/reports-fixtures.sql, reports-refunds.sql; runner tooling/test-reports-refunds.py creates only fresh local clusters and stops them in finally.
5. Recheck lint/type/build, CSV tests, stable desktop/mobile mocked UI with screenshots, approved storefront source/regressions. Distinguish all mocks/local doubles from hosted results.
6. Update four standing docs, provide tested incremental preflight/installer and exact hash for owner application. Configured HTTP API credentials cannot perform DDL; no direct database/management connection is configured. Do not request secrets in chat or claim hosted finance tests until 020 is owner-confirmed installed.
7. Then actual hosted synthetic orders/payments/deals/refund/return/report/browser/concurrency checks, preserving baseline rows/stock/homepage/assets and keeping financial/audit history. Prepare a guarded dedicated live harness; it is not implemented yet.

## Accounting choices implemented; review before finalizing

Sales only on Complete, once; historical Complete events backfilled additively with original timestamps. Refund requests vs approved reservations vs Sent are separate. Refunds use exact frozen component entitlements; approved/sent quantities consume entitlement; integer remainder is allocated on subsequent quantity approvals. Shipping/verified overpayments are separate. Actual outgoing-history acknowledgement required; references conservatively unique per manual payment service (account labels cannot bypass deduplication).

Refund/return mistakes append reversals; no history deletes. Physical resale returns are separate from refunds and use audited inventory adjustments. Cancellation never adds physical stock. A refund before completion is cash-only; if subsequently completed, a distinct sales-recognition event occurs on completion (or later recording), preserving the refund's original cash date. This derived recognition/reversal logic still needs targeted regression testing.

Business reports default to approved/business orders. Development/test orders require explicit selection, preserving historical synthetic isolation. New actual receipt dates are separate immutable metadata; original payment receipts remain untouched; old receipts use their recorded receipt timestamp. Aggregate money strings preserve integer precision through JSON/CSV; PKR formatting uses BigInt without changing the TS target.

An explicit payment-balance review action is drafted for overpayment refunds: no automatic Paid/fulfilment; checks net funds and approved item/shipping refunds, uses atomic stock reacquisition if explicitly requested, never reopens cancelled orders. This is the latest unverified code and needs careful review.
