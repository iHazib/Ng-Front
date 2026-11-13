# Hosted manual-commerce verification — 2026-10-15

**Passed:** 153 actual check observations using real Chrome, Next.js, hosted Supabase Auth/PostgREST/private Storage and the existing Cloudinary media lifecycle. No mocked transport was used for these runs. Owner confirmed 016's fourteen installation flags. No SQL installer or migration was applied/rerun; 015/016 canonical and installer hashes remain unchanged.

| Area | Actual result |
| --- | --- |
| Bank Transfer, Easypaisa, JazzCash | Real Next checkout and hosted order/payment records; fresh desktop Easypaisa and mobile JazzCash forms plus Bank Transfer form passed. Only synthetic receiving targets were used; no real funds moved. |
| Guest cart/confirmation | Persistence/reload, actual quote, exact server totals, per-order ownership, outsider/order-number denial and confirmation reload passed. |
| Private proofs | Real upload/read-back, same-ID retry, owner/admin reads, cross-order denial, anonymous/non-admin Storage/metadata/RPC denial and public-delivery/publish denial passed. Proofs remained private, with no Cloudinary public identity. |
| Review | Submission stayed Under review; browser Request correction/Reject submission, explicit history acknowledgement, exact partial-receipt sum, under/overpayment flags, duplicate proof/reference flags and retries passed. |
| Authoritative values | Browser overrides of prices, fees, receiving account, status and deadline failed or were ignored; server snapshots stayed authoritative. COD, malformed methods and incomplete/disabled methods were rejected. |
| Stock | Unpaid Confirm/Dispatch denial, concurrent last unit, multi-item rollback, cancellation/expiry exactly once, actual timed bounded extension without renewal, explicit late reacquisition and two concurrent late receipts competing for one unit passed. Both receipts survived shortage; only one allocation succeeded. |
| Transfer uniqueness | Same service/account duplicate references, concurrent verification and same-operation retry credited once; same reference across different services remained independently scoped. |
| Fulfilment | Real browser Verify received → Confirm → Dispatch → Complete passed; dispatch retry did not deduct twice and completion did not deduct again. |
| Cleanup | 14 synthetic orders, zero active reservations; 3 private files removed, two public test images cleaned, two products hidden/six variants archived. Metadata/hash/audit/receipt/order histories retained. |
| Preservation | All 1313 original row hashes across 37 tables passed; second baseline (1367 rows) passed too. Homepage selections preserved. All 64 handoff/import sources and 14 approved CSS blocks remain intact. No application UI, approved assets, dependency or schema changes in this verification turn. |

The first run stopped at a test-helper omission: its audited stock request lacked the required fixture productId. That request failed before changing stock; its cleanup/preservation passed. The helper was corrected and all remaining timed/race cases passed in the targeted hosted run. The raw initial report retains that failure; the aggregate resolves it with the targeted evidence rather than rewriting it as a first-run pass. A configuration probe also refreshed its CSRF token immediately before each request to avoid its own competing session-prefetch; fresh real user-form tests subsequently passed.

## Evidence

- [manual-payments-live-verification.json](manual-payments-live-verification.json)
- [manual-payments-hosted-races.json](manual-payments-hosted-races.json)
- [manual-payments-hosted-security.json](manual-payments-hosted-security.json)
- [manual-payments-hosted-configuration.json](manual-payments-hosted-configuration.json)
- [manual-payments-hosted-fresh-browser.json](manual-payments-hosted-fresh-browser.json)
- [manual-payments-hosted-cleanup.json](manual-payments-hosted-cleanup.json)

The standalone server command npm run commerce:maintenance was executed after browsers closed and test cleanup: expired=0, overdueHolds=0, balanceMismatches=0. Earlier timed tests actually expired native database deadlines; no private timestamp was edited. The isolated test process supplied distinct synthetic visitor IP headers to exercise the existing rate controls; this is not a deployed proxy test.

## Remaining setup and limits

Real checkout stays disabled with zero available methods in the normal application. Enter actual account titles/IBAN/account/wallet details and instructions only in secure server configuration; choose payment/review deadlines, shipping/cities/tax treatment, trusted ingress and hosting. Schedule npm run commerce:maintenance independently (for example once per minute) using server-only credentials; no scheduler has been installed. Decide production proof retention/orphan housekeeping and manual under/over/late-payment resolution/refund policies. See manual-payments-setup.md.

Receipt acknowledgements here are synthetic test entries, not evidence of funds in a real account. No bank/wallet/payment API, gateway, actual transfer/refund, courier, deals/reporting stage or deployment was used. Local SQL/Auth-Storage doubles, unit tests and mocked UI results remain separate historical evidence. Physical devices, non-Chrome engines and production load remain untested. There was no new pixel comparison; unchanged UI/CSS and source checks support preservation, not a new pixel-fidelity claim.
