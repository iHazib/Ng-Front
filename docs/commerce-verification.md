> Historical 015 implementation notes. The owner now confirms 015 is installed: **do not rerun its installer**. Current payment policy and incremental 016 steps supersede the COD/setup instructions below; see [manual-payments-setup.md](manual-payments-setup.md).

# Commerce verification - 2026-10-13

## Corrected installer: passed locally

Executed the exact complete `13_install_guest_commerce_clean.sql` using `psql -X -v ON_ERROR_STOP=1 -f` against NEW disposable PostgreSQL 16 with migrations 001-014 applied. Final eleven flags passed, all seeded pre-existing public business row hashes were preserved, hash matched before/after execution, and repeat installation was rejected. Auth/Storage/media in this suite are doubles, not hosted provider verification. Evidence folder: `database-test-386f142a7abb`.

Installer SHA-256: `ea1d878b6caa9209cba75885448dd84f5b6c075576266f8d1c51c74d1f176ef0`.
Canonical 015/receipt SHA-256: `b89d4a6a6ae13c27be9d71928c5ea288c26b64691f8be0d867c8070abf5b0ce0`.
Migrations 001-014 were not edited or applied to the hosted project.

Passed SQL checks cover actual minor-unit quote/no cart reservation, stale prices/unavailable multi-item complete rollback, snapshots/private guest ownership, identical/altered retry, stale action rejection, cancellation retries, dispatch/complete single deduction, unchanged historical totals after catalog edits, unpaid confirm/dispatch denial, missing/partial/inactive reservations, missing components, mismatched reserved counters, finite accepted holds, fail-closed expiry, cancellation after a deadline, accepted COD retention, audited stock below reserved rejection, private admin listing, anonymous/non-admin denial, and direct legacy primitive bypass rejection. Two independent PostgreSQL sessions competed for the last unit: exactly one order/reservation committed and the loser rolled back. No hosted orders were created.

## UI/unit/scaffold

Two bounded-input/Pakistan-phone unit tests passed. 14 actual desktop/mobile Chrome UI checks with MOCK catalog/commerce responses passed: current-price notices, quantity revalidation, no cart placement, responsive checkout form, browser submits no trusted totals, interrupted-response recovery with one placement, private confirmation view and separate payment status. This is NOT Supabase order verification.

Production build passed and excludes /reference. Full lint and final TypeScript checks passed; one earlier typecheck raced the production build's temporary reference-file removal and was rerun sequentially. Windows compiler sandbox path resolution required the authorized local runtime; no application source workaround was introduced. A production browser-chunk scan checked 22 JavaScript files and found zero configured secret/test-password values. Dependencies are unchanged; package scripts were added without rewriting the lockfile.

Approved-homepage regression ran with explicit sample-preview content: desktop section geometry/carousel states and mobile hero/hamburger checks passed (2 tests, 2 intentional project skips). Of 23 paired desktop screenshots, 20 were pixel-identical. Remaining small first editorial/home image-transition differences and the EXISTING sample-preview 'Search sample products' link caused the pixel comparison threshold to fail for search (mean channel difference 0.1823). Both search screenshots were visually inspected; this link was not introduced/changed by commerce work. Do not claim complete pixel equality. All 64 original source/import files and 14 reference CSS blocks remained byte-identical. No approved hero/category/concern/brand/footer asset or stylesheet was changed.

## Actual hosted checks: partial, clearly pending

13 actual existing Auth/admin/private-boundary checks and 5 actual read-only new-route/configuration checks passed: normal storefront checkout disabled, anonymous/non-admin orders rejected, isolated development configuration labelled, and CSRF-less checkout rejected. Real commerce_quote returned HTTP 404. Owner confirms migration 015 is NOT installed. These checks do not prove hosted guest orders, reservations or transitions.

Actual hosted last-unit concurrency, multi-item rollback, retries, stale prices, variant visibility, guest ownership, order browser actions, dispatch/completion, native expiry and provider fixture cleanup await corrected 015 installation. Prepared verifier is scripts/verify-commerce-development.mjs; it stops BEFORE mutation when new RPCs are absent. Current live report has no fixtures, orders, media uploads or stock changes. Real catalog/content/homepage selections remain untouched.

## Explicit pause and business setup

Owner requested the corrected safeguard installer then a pause for application. No hosted SQL will be run; no earlier installer rerun or reset. Approved shipping/cities/fees/tax treatment/payment choice, hosting/trusted ingress, scheduling and any transactional email remain decisions. No real payment gateway, sales dashboard, deals, courier API, shipments or deployment were implemented. See commerce-setup.md for exact settings and maintenance command.
