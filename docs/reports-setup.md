# Sales reports, manual refunds and returns — incremental 020

## Installation (development project only)

001–019 remain unchanged and owner-confirmed installed. Do not rerun earlier installers. There is no direct database or management connection configured; HTTP API credentials cannot execute this DDL. Do not share secrets in chat.

1. Open a NEW Supabase SQL Editor query and run `supabase/sql-editor/18_preflight_reports_refunds.sql` using ordinary **Run**. It is read-only and returns metadata flags only. Before installation: prerequisite_019, history_complete and no_client_policies must be true; the other 12 flags false. If any new objects/receipt exist or history_complete is false, stop and inspect; do not combine/install fragments.
2. Open another NEW query. Paste the entire `supabase/sql-editor/18_install_reports_refunds_clean.sql` and run it ONCE using ordinary **Run**, not Run and enable RLS. The complete transaction already sets RLS and grants correctly.
3. Confirm all 15 final flags are true, including receipt_matches, private_rls, private_grants, rpc_security and action_grants. Do not rerun on any unexpected result; share only metadata flags, never credentials/customer data.
4. Apply the separate, tested 021 partial-value extension described below. Then run the pending actual hosted synthetic financial verification. The prepared harness is `npm run verify:reports:development`, after starting `npm run dev:commerce:test` on isolated port 3100. It requires explicit MEDIA_ENVIRONMENT=development, current admin/non-admin test accounts and existing media credentials. It refuses missing reporting RPCs before creating business fixtures. It uses synthetic shipping/accounts only and preserves original records/homepage selections. Do not run it against production. Normal checkout remains disabled.

Exact complete installer SHA-256: `9495f7d52a00ebbc2679e861215475fddef46e85ff91cb356a770398cb6ae515`.
Canonical migration SHA-256: `3a274cb58a5da769a57ee7ab0dfb5877b68bb82adcf92caba1031ca1e4b6b434`.
The exact installer passed `psql -X -v ON_ERROR_STOP=1 -f` on a NEW disposable database with migrations 001–019. File hash matched before/after testing. All 15 final flags, unchanged seeded rows, repeat refusal, 60 SQL assertions and independent-session approval/send races passed. Auth/Storage/provider metadata in that local SQL suite are explicit doubles, not hosted/provider verification.

## Data and permission changes

Adds seven private RLS tables, indexes, append-only history triggers and admin-authorized RPCs. Reconstructs completed sales additively from explicit existing Complete events and their original timestamps. Missing historical completion evidence blocks installation. Future explicit completion records one sale with historical merchandise/shipping amounts; retries cannot duplicate it. No existing order, receipt, deal snapshot, financial record or stock quantity is rewritten/deleted/reset.

The installer replaces only the existing public order/payment wrappers while retaining their signatures, owner and secure grants. It adds actual-receipt-date metadata for newly verified payments and blocks new Confirm/Dispatch while an unsent approved item/shipping refund needs resolution; prior successful retries still remain idempotent. It revokes authenticated INSERT on the old generic public.sales/public.refunds tables so they are not a second financial entry workflow. This is an intentional permission restriction, not a data deletion. No DROP/TRUNCATE/DELETE data statement or RLS bypass is included. Private table privileges are revoked from anon/authenticated/service_role; client access is only through checked SECURITY DEFINER functions with empty search_path and real admin membership.

## Reporting definitions

- Business orders are the default. Development/test orders require explicit selection and are reported separately; retained synthetic history cannot silently become business revenue.
- Completed order count, gross merchandise, sales refunds and net merchandise use immutable captured order amounts. Shipping charged/refunded is separate. Receipts and refunds actually sent are cash measures, independent of order placement/dispatch. No profit is inferred from missing historical cost data.
- Asia/Karachi dates convert to inclusive local start/exclusive next-day start in UTC. New completions use actual transition time; historical completions preserve their recorded explicit event timestamps. New receipt verification can record the actual receiving date additively; older original receipt timestamps are preserved. Sent refunds use the actual supplied send date. Reversals are new dated correction events, never historical deletions.
- Refunds for uncompleted/cancelled orders affect cash only. If an uncompleted order is later explicitly Completed, its earlier item/shipping refund is recognized against merchandise/shipping on completion (or later recording), without moving its original cash date. Reversals offset this correctly. Overpayment refunds never reduce merchandise sales.
- A deal contributes its charged merchandise once. Component analysis is an alternative view of exact frozen price attribution; it is not additional revenue. Top sellers show gross completed units/charged amounts before refunds and clearly distinguish deal units from component units.
- Event pages contain 25 rows (RPC upper bound 100). Top analysis is capped at 20; trend shows latest 400 event-bearing buckets, with totals for the entire selected range. CSV includes selected totals, all event rows, top analysis and trend; more than 5,000 events requires narrowing dates, rather than silently truncating. Formula-like text is neutralized and money is exported as integer paisa. Exports omit customer contacts/addresses, account details and transfer references.
- Order refund/return history is bounded to 100 refund requests and 200 return records; the UI explains when review is required at these safety limits. Approved refunds reserve cash/quantity/value; cancelling an unsent request releases its reservation. Requests alone reserve nothing.

## Manual refund/return controls

The owner selects exact sold items or deal components and quantities. Their frozen component attribution, shipping balance and verified overpayment determine the amount server-side; browser totals/current catalog prices are never authoritative. Mixed-cart labels and approval breakdowns include the originating deal, so identical component SKUs in different order lines remain distinguishable. Fractional per-unit paisa are reconciled through exact cumulative allocation; the last refunded quantity receives the remaining paisa.

Only explicit account-history confirmation records Sent, with Bank Transfer/Easypaisa/JazzCash, transfer reference, actual sent date and verified actor. No money moves automatically. References are conservatively unique across each manual payment service; changing an account label cannot bypass duplicate recording. A legitimate same reference in another account under that service requires human review; do not disguise it with an invented reference. No recipient banking information is required or exported. Mistaken ledger entries can be reversed only with explicit history acknowledgement/reason; this does not recover actual money. Originals/audits remain intact.

Returns and refunds remain independent. Received/inspected quantity is capped by frozen dispatched units. Only resale quantity adds audited stock, using existing guarded inventory adjustments. Damaged units add none. Retries/reversals cannot add twice; correcting an erroneous restock removes only available unreserved stock or fails atomically. Pre-dispatch cancellation only releases reservations. Refunding never automatically cancels/reopens an order, and cancellation never sends a refund.

After an overpayment is actually refunded, a separate explicit net-payment/stock review can restore Paid readiness only when net funds equal the original order and item/shipping refunds are resolved. It uses existing atomic late-stock reacquisition when explicitly requested; a cancelled order never reopens. Shortage retains received funds and resolution-required status. This action cannot dispatch automatically.

## Commands / external dependencies

`npm run sql:reports`, `npm run test:reports:unit`, `npm run verify:reports:mock-ui`, `npm run verify:reports:readonly`, `npm run verify:reports:development`.
Fresh exact-file database runner: bundled Python `tooling/test-reports-refunds.py` with PostgreSQL16 binaries. No new npm dependencies or secrets were introduced; the lockfile is preserved. Existing server-only Supabase/Cloudinary/test-account configuration is reused. Real account/shipping/tax/deadline/ingress decisions and independent commerce maintenance scheduling remain required before real checkout. No courier, gateway, technical SEO, deployment or next feature stage.


## Partial-value follow-up 021 (2026-10-20)

020 remains frozen and byte-identical to the file already supplied. Do not replace or rerun it if installed. A final edge-case check required value-only refunds: a cancelled customer who paid only part of the invoice must be able to receive that exact amount back without pretending a shipping refund or requiring a whole item price.

After 020 is installed, run `supabase/sql-editor/19_preflight_partial_refunds.sql` read-only. Before 021: prerequisite_020, private_rls and permissions_preserved true; other four flags false. Then apply the complete `supabase/sql-editor/19_install_partial_refunds_clean.sql` once using ordinary Run. All seven final flags must be true. Existing rows and financial history are unchanged; only two function bodies are replaced while preserving OIDs, owner, grants and RLS. No new tables or direct client privileges.

The enhanced editor offers an optional exact PKR amount for each order line/component. Blank calculates the selected quantity using the old deterministic allocation. Quantity zero with a positive explicit amount records a value-only refund. A partial amount with a positive quantity is also supported. Quantity entitlement and remaining value are tracked separately; total approved/sent money still cannot exceed verified receipts, original item allocation, shipping or actual overpayment. Sending and restocking remain separate. The editor enables this option only when the database advertises the installed 021 contract.

Both exact installers were executed in a new disposable database: fresh 001–019, exact unchanged 020 with all original regressions/races, then exact 021 with unchanged financial-row snapshots/function ACLs and 11 additional partial-value assertions. Tests cover cancelled partial payments, split amounts without repeated quantities, remaining-value/cash caps, malformed/negative/exponent inputs and sales isolation. Repeated installation refused. This remains local SQL evidence, not hosted finance verification. Browser UI mocks now pass 14 checks including partial values, separately from actual read-only hosted security checks.

021 installer SHA-256: `ca34df2f62ca930458238cf43b76d8c1063de7db9cb270f10b52bd61a60db0db`.
021 canonical SHA-256: `2c620c81ec6821b9f733a8108bfc881a6f4d209a04b9fb0fd9347d235c4fda73`.
Evidence: partial-refunds-local-verification.json and partial-refunds-installer-manifest.json.
The prepared actual development harness requires both 020 and 021. No hosted financial fixtures have been executed yet. `npm run sql:partial-refunds` regenerates only 021; do not regenerate/reapply frozen 020.


## Hosted financial verification completed (2026-10-20)

Supersedes earlier pending-installation/hosted-verification notes. Owner confirmed 020/021 receipts and all 15/seven flags; no installer or hosted SQL was run. Actual Chrome, Next.js, hosted Supabase/Auth/PostgREST, private Storage and Cloudinary checks passed: 91 main, 22 supplemental and 44 independent cleanup/read-back checks. No intercepted provider responses were used in these runs.

Six synthetic orders covered exactly-once completion, separate receipts/shipping/cash, mixed-cart frozen deal attribution, full/partial-value/item/shipping/overpayment refunds, cancelled/uncompleted cash-only refunds, competing approvals and duplicate-reference sends, retry/stale-edit protection, explicit outgoing-history confirmation, independent inspected resale/damaged returns, partial deal components and dispatched limits. Real browser request/approve/send/return controls and desktop/mobile Reports layouts passed. Historical order/report values remained unchanged after synthetic catalog/deal price edits; hidden visibility was preserved. Actual CSV totals/privacy, Pakistan-day filtering and previous-day exclusion passed. Anonymous/non-admin financial RPCs and all seven private financial tables were inaccessible; private financial responses remained no-store.

Cleanup: two products and three deals hidden, options archived, five approved test media/private originals deleted; all six order/financial histories and audit events retained. No active fixture reservations, idle deal pools or approved/requested financial holds remain. Global reconciliation: zero balance mismatches, overdue holds and ended allocations. All 1525 pre-existing rows across 40 tables, homepage selections and pre-existing business/development financial events were preserved. All 64 handoff/import files and 14 reference CSS blocks remain byte-identical. Normal checkout stays disabled; no real funds moved, storefront design changes, courier integration or next stage.

Verification limits: exact 18:59:59/19:00:00 UTC Pakistan-midnight fixtures and hostile formula-like CSV names were tested in disposable PostgreSQL/unit tests, not newly fabricated/backdated hosted financial history. Actual hosted day windows and CSV totals/privacy passed. Bank/wallet outgoing-history acknowledgements were synthetic; no account statements or real transfers were verified. Chrome desktop/mobile emulation is not physical-device, other-engine or production-load evidence. Prior storefront comparison remains 21/23 pixel-identical with the documented existing search-link/full-page differences; no new fidelity claim follows from these financial tests.

Evidence: reports-hosted-live-verification.json, reports-hosted-supplement.json, reports-hosted-cleanup-readonly.json; screenshots under .local/reports-hosted. Local SQL, intercepted UI and unit evidence remains separately labelled in reports-verification.md/json. Receiving-account/shipping/tax/deadline approval, trusted ingress and an independent commerce-maintenance scheduler remain launch setup decisions.
