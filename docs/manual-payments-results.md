> Current hosted state: the owner confirmed 016 installed; **do not rerun any installer**. Actual hosted commerce/manual-payment verification is complete. See [manual-payments-hosted-results.md](manual-payments-hosted-results.md) for results and remaining business/scheduler setup. Preparation-stage pending statements below are historical.

# Manual-payment correction results — 2026-10-15

Implemented: advance-only Bank Transfer/Easypaisa/JazzCash configuration, private proof ownership/storage routes, bounded submission review, simple admin queue/actions, immutable manual receiving-account receipts/audits, scoped reference and normalized-image duplication flags, partial/overpayment handling, atomic late allocation and payment-gated fulfilment. No applied migration, real business record, homepage selection or approved asset was changed. No payment APIs, OCR, statements, refunds, courier/deals/reporting/deployment.

## Passed locally

- Exact complete 016 installer executed with psql -X -v ON_ERROR_STOP=1 -f after fresh migrations 001–015. Fourteen final flags true; all pre-existing public/private business table hashes preserved, including a nonempty legacy order/catalog/inventory fixture; repeat installation refused. Evidence: database-test-70ff19191edf.
- SQL lifecycle, full/partial/overpayment receipts, duplicate operations/references, correction/rejection, bounded holds/expiry, ownership/authorization/private Storage policy doubles, public proof publishing/association rejection, and stock consumption assertions passed.
- Two independent PostgreSQL sessions competed for late stock: one allocation, both receipts retained. Concurrent duplicate-reference attempts credited one transfer only. Auth/Storage tables and catalog media metadata in this suite are doubles, not actual hosted services.
- Five commerce/payment configuration/input/image tests and ten existing admin/media security tests passed (provider media unit transport is mocked).
- 18 Chrome desktop/mobile cart/checkout/payment-submission checks and 14 admin-review checks passed with explicitly mocked order/payment data. Admin review used the real authorized shell; no hosted orders were created.
- Source integrity: 64 original files byte-identical, 14 approved CSS blocks intact. Lint, type generation/check, production build and production preview/reference/noindex/sample guards passed. No new pixel-fidelity claim is made; historical differences remain documented in commerce-verification.md.
- 22 production browser JS files contained no configured secret/password values. Generated public TypeScript definitions include payment media ownership. Lockfile preserved, Sharp pinned at 0.35.5.

## Passed against actual hosted services

- anonymous payment/order API denied
- anonymous admin proof denied
- real non-admin Auth login rejected from admin
- real admin Auth and server membership validated
- admin payment CSRF guard
- admin payment response no-store
- only synthetic manual methods in isolated dev settings
- customer submission CSRF guard
- private upload checks order ownership before image/storage access
- installed 015 public quote works

These 10 checks used real Chrome, Next.js and configured hosted Supabase Auth/PostgREST. They were read-only for business records. The new admin payment RPC returns unavailable (Next HTTP 503); 015 quote is available. No hosted SQL or synthetic catalog/order/proof fixtures were created in this turn.

## Pending

Owner application/confirmation of incremental 016, followed by actual synthetic manual checkout, private Storage upload/read-back/delivery, approve/correct/reject, reference/image/amount flags, expiry/late-race and cleanup verification. The prepared gated live runner is not evidence of those passes; extended cases remain explicitly listed in it. All real receiving-account details, deadlines, shipping/tax decisions and scheduler/retention setup remain owner/provider configuration. No genuine transfer receipt was claimed.

Run the read-only preflight first; then the one complete installer once if the preflight is clean. Before: only prerequisite_015 and no_client_policies true. After: all fourteen true. Do not rerun earlier installers. Full instructions and limitations: manual-payments-setup.md.

Exact installer SHA-256: 38bd7630686a04e8e3a225b370021686328d7031038aa10ba4d32d621cdfe644

Canonical migration SHA-256: d0e29a69895ac34b808371c40c126235f7b7d019ee77874b218b3a65cbfdb612

Applied 015 SHA-256 remains: b89d4a6a6ae13c27be9d71928c5ea288c26b64691f8be0d867c8070abf5b0ce0
