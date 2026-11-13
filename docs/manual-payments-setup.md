> Current hosted state: the owner confirmed 016 installed; **do not rerun any installer**. Actual hosted commerce/manual-payment verification is complete. See [manual-payments-hosted-results.md](manual-payments-hosted-results.md) for results and remaining business/scheduler setup. Preparation-stage pending statements below are historical.

# Manual advance payments — incremental 016

This supersedes the COD/development-hold payment policy in the historical 015 notes. The owner confirms 015 is installed. Its canonical migration and installer have not been changed or rerun in the hosted project.

## Install once in the development project

1. Run `supabase/sql-editor/14_preflight_manual_payments.sql` as a new SQL Editor query. It is read-only and returns no business/account details.
2. Before installation, only `prerequisite_015` and `no_client_policies` should be true; the other twelve flags should be false. If objects or a receipt already exist, inspect the state rather than rerunning.
3. Run the entire `supabase/sql-editor/14_install_manual_payments_clean.sql` in a new query, once. Its transaction requires the exact 015 receipt and refuses existing/partial 016 objects. Do not combine fragments or rerun earlier installers.
4. All fourteen final flags must be true. Reuse the read-only preflight for later checks. If PostgREST still reports an unavailable RPC after successful installation, inspect the schema cache; the installer already issues `NOTIFY pgrst, 'reload schema'`.

The installer drops/replaces three named CHECK constraints, replaces payment/fulfilment guards and moves old implementations to owner-only private backup functions. It does not drop tables, truncate/delete business rows, rewrite existing orders, change catalog content or reconcile stock. Existing COD snapshots remain historical; they cannot be confirmed/dispatched under the new advance-only gate or automatically treated as paid. Any historical such order needs explicit owner resolution; there is no silent conversion.

Exact SHA-256 values are in `manual-payments-installer-manifest.json`. `manual-payments-local-verification.json` records the actual exact file tested with `psql -X -v ON_ERROR_STOP=1 -f` after fresh 001–015 migrations, unchanged pre-existing business rows, repeat refusal and SQL/race tests. The local Auth/Storage schemas and catalog image metadata are test doubles; this is not hosted payment/Storage verification.

## Owner configuration (server only)

Keep `COMMERCE_ENABLED` unset/false until shipping, tax treatment, receiving accounts and deadlines are approved. Configure `COMMERCE_CONFIG_JSON` in secure local/server configuration; never paste account details or credentials into chat or commit them. Restart Next.js after changing settings.

The existing object retains `mode`, a changed `version` whenever options change, `taxTreatment`, and explicit `shipping` rules with `feeMinor` in integer paisa and supported `cities`. No fee/threshold/tax rate is supplied by this stage.

Add mandatory integer `paymentSeconds` (60–604800) and `reviewExtensionSeconds` (0–86400). These are owner decisions, not business defaults. `payment` supports exactly these method IDs:

| ID | Required owner configuration |
| --- | --- |
| `bank-transfer` | `enabled: true`, `label`, `bankName`, `accountTitle`, `destination` (account number or IBAN), `instructions` |
| `easypaisa` | `enabled: true`, `label`, `accountTitle`, `destination` (wallet number), `instructions` |
| `jazzcash` | Same fields as Easypaisa |

Labels, title, destination and bank name are at most 120 characters; instructions at most 500. Missing/disabled/unrecognized methods, including COD, are excluded. If no complete method remains, checkout is unavailable. Receiving details are shown at checkout and snapshotted on each order. Keep a consistent canonical bank name/account identifier when updating configuration: deduplication scopes are hashes of service + canonical bank name + normalized receiving account. Changing a label/account title/instructions does not change scope. If moving from an account number to its equivalent IBAN, receiving-account alias reconciliation needs owner review before changing that identifier; this stage does not infer equivalence between banking identifiers.

Other existing variables: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, server-only `SUPABASE_SECRET_KEY` (legacy service-role fallback supported), `MEDIA_ENVIRONMENT`, `COMMERCE_SESSION_SECRET` (or existing `REVIEW_SESSION_SECRET`, minimum 32 characters), `COMMERCE_TRUSTED_IP_HEADER` on a trusted production ingress. No payment API keys exist. Proof handling does not require Cloudinary credentials.

`npm run dev:commerce:test` starts a separate local port 3100 process with clearly labelled synthetic receiving targets and a synthetic delivery fee, 60-second payment window and 30-second maximum review extension. Those settings are process-only, never written to `.env`, and are not real accounts or business policy. Never transfer money to test targets.

## Behaviour and security

- Placement reserves atomically and starts Awaiting payment. The original payment deadline and actual stock-hold deadline are displayed with Pakistan time and seconds. Cart operations do not reserve stock.
- A transaction reference is required; claimed amount and a private PNG/JPEG/WebP proof are optional. Customer access requires the existing signed HttpOnly guest session and per-order ownership token. It works on later visits in that browser for the session's 30-day lifetime; order numbers/UUIDs alone grant no access. Cross-device recovery is not implemented.
- Uploads use UUID media/workflow owners linked to the order, never fake products/articles. Bytes are bounded to 5 MiB, fully decoded, single-frame checked and re-encoded to PNG with metadata stripped. SHA-256 of normalized bytes flags identical images, including metadata-only copies; there is no OCR, fraud verdict or perceptual-image matching. Storage bytes are read back and verified before completion. Retry the same upload identity and bytes after interruption; up to five proof uploads and ten submissions per order limit storage abuse.
- Proofs always remain pending/private in `catalog-private`. SQL prevents publishing them through Cloudinary, changing ownership or associating them with public content. Guest/admin image routes authorize every read and return no-store/nosniff responses. Public URLs and reusable public signed delivery URLs are not generated.
- A completed submission changes payment to Under review, never Paid. Only the first submission before the original deadline may extend stock, bounded by both first-submission time plus the configured extension and the original deadline plus that extension. Later uploads, resubmissions and correction requests cannot renew it. Uploading without submitting does not extend it at all.
- The admin queue is Awaiting payment / Proof submitted / Needs attention / Paid, with bounded server pagination and fulfilment/date/search filters. Verify received requires actual receiving-account history acknowledgement, amount and reference. Request correction keeps history; Reject submission explicitly releases/cancels an unpaid order.
- Immutable receipt and action records preserve actor, verification time, amounts, references and review messages. Amount mismatch, reused references in the same receiving account/service and identical images are review flags. Unique `(account_scope, normalized_reference)` plus transactional locking prevents crediting one transfer twice, including races. Reference normalization is conservative NFKC/uppercase with whitespace and hyphens removed; collisions fail closed for review, never automatic duplicate credit.
- Partial/overpayment receipts remain accurately recorded as Needs attention. Multiple distinct partial receipts can sum to the exact order total; only that total becomes Paid. There is no automatic refund/overpayment resolution.
- A full late receipt is recorded even when stock cannot be allocated. Explicitly select the stock reallocation checkbox to try again atomically. A shortage rolls back every stock change while retaining the receipt as Payment received—resolution required. Retrying its reference does not credit funds again. Intentionally cancelled orders are never silently reopened.
- Confirm/Dispatch require Paid plus complete accepted allocation. Dispatch consumes once; Complete does not deduct again. Cancellation after receipt preserves payment history and flags resolution; no refund is claimed or issued.

## Expiry scheduling and cleanup

Use the existing `npm run commerce:maintenance` server job, for example every minute in the eventual hosting scheduler. It needs the server URL/key configuration and runs independently of browsers. Scheduling/hosting is still a business/provider dependency; no hosted scheduler was created. The job releases expired temporary holds exactly once and checks reservation counters. Accepted paid allocations do not expire. Missed scheduling delays release until the task runs; uploads cannot change an expired deadline.

Synthetic SQL fixtures run inside rolled-back transactions or an isolated disposable cluster that is stopped after testing. No hosted fixtures were created while 016 was unavailable. When hosted tests run after installation, hide/archive only their uniquely marked products, cancel active synthetic orders, clean their public test packshots through the existing service, and retain private order/payment/audit history. Never delete real orders, receipts or referenced proofs to make a test report appear clean. Payment-proof retention and orphan-file housekeeping after failed intents need an owner-approved retention policy; no automatic deletion of financial evidence is scheduled.

## Verification boundaries

- Local: exact incremental SQL file, fourteen final checks, preserved seeded legacy orders/catalog/inventory, repeat refusal, payment lifecycle/permissions/proof ownership and two-session late-stock/reference races.
- Unit: disabled/unconfigured methods, no COD, receiving-service scopes, deadline bounds, full image decode, metadata stripping and malformed/oversized/SVG rejection.
- Browser with explicit mocks: desktop/mobile cart/checkout/deadlines/submission and admin review controls. These are UI checks, not provider payment results.
- Actual hosted read-only: real admin/non-admin Auth, Next authorization/CSRF/no-store, ownership-before-upload and installed 015 quote. Evidence: `manual-payments-live-readonly-verification.json`.
- Pending after owner installs 016: actual hosted manual order/proof Storage round trip, moderation actions, private delivery, receipt/reference deduplication, expiry/reacquisition races and cleanup. No funds, real orders, payment APIs or hosted SQL were used in this implementation turn.

Sharp 0.35.5 is pinned directly (the already-installed image codec) and the lockfile is preserved. Its untrusted-input pixel/decoder limits and output APIs were checked against official documentation: https://sharp.pixelplumbing.com/api-constructor/ and https://sharp.pixelplumbing.com/api-output/ . Homepage/reference CSS and approved assets were not edited. Historical pixel-comparison limitations in `commerce-verification.md` still apply; a successful build is not a claim of pixel-perfect fidelity.

An intentionally incomplete JSON template is provided in `manual-payment-config.example.json`. Blank/null fields must be replaced with approved settings in secure server configuration, and chosen complete methods explicitly enabled. Do not enable checkout with the unfilled template. The current `verify:commerce:development` script now delegates to the gated 016 manual-payment runner; the old COD harness is historical. The prepared hosted runner refuses to create fixtures while the new admin RPC is unavailable. Extended hosted race/correction/duplicate-proof cases remain explicitly pending and must not be inferred from the local suite.
