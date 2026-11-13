> Historical 015 implementation notes. The owner now confirms 015 is installed: **do not rerun its installer**. Current payment policy and incremental 016 steps supersede the COD/setup instructions below; see [manual-payments-setup.md](manual-payments-setup.md).

# Commerce setup and lifecycle

The stage is implemented locally. Migration 015 is NOT installed in the connected development project, as owner-confirmed on 2026-10-13. The owner requested corrected payment/dispatch and reservation-completeness safeguards, exact-file testing, then a pause for application. No hosted SQL or hosted commerce fixtures have been run. Do not rerun migrations/installers 001-014.

## Application

1. Open a NEW development SQL Editor query and run the complete `supabase/sql-editor/13_preflight_guest_commerce.sql`. Before installation prerequisite_014 and no_client_policies must be true; the other nine flags false. The updated transitions_and_safeguards_present flag verifies both the transition RPC and new allocation/payment safeguards. Any partial presence/receipt means stop and inspect.
2. Open a separate new query and apply ONLY the whole corrected `13_install_guest_commerce_clean.sql` once. It includes its own transaction, guard and receipt. All eleven final flags must be true.
3. Confirm those results before hosted fixture verification. No credentials in chat. This run is explicitly paused for that application.

The installer is additive to records: private commerce metadata/events/rate tables and functions, shared inventory primitives, validated wrappers. It revokes generic authenticated writes to orders/order_items; authorized RPCs perform order changes. No DROP/TRUNCATE or business-row DELETE/UPDATE is executed during installation. Legacy rows are neither reset nor promoted into the managed checkout lifecycle. The existing Auth/RLS/admin-CSRF boundary remains intact.

## Server configuration

- `SUPABASE_SECRET_KEY` (existing secret key) or legacy `SUPABASE_SERVICE_ROLE_KEY`: server-only narrow guest/maintenance gateway, never NEXT_PUBLIC_. Admin actions continue to use verified Auth tokens and membership checks.
- `COMMERCE_SESSION_SECRET`: optional independent 32+ character signing secret; otherwise the configured REVIEW_SESSION_SECRET is reused under a separate commerce HMAC namespace. Rotating changes guest confirmation/session access.
- `COMMERCE_ENABLED`: leave unset/false until explicitly approved settings are ready.
- `COMMERCE_CONFIG_JSON`: structured server configuration below. Blank means checkout unavailable, not a sample fallback.
- `COMMERCE_TRUSTED_IP_HEADER`: cf-connecting-ip or x-vercel-forwarded-for only after trusted ingress strips spoofed headers. Falls back to the existing reviewed review-header setting. Local development has a loopback bucket; nonlocal checkout remains unavailable without trusted IP protection.

Configuration requires mode (`development` or `approved`), version, taxTreatment, shipping[] and payment[]. Shipping options contain unique id, label, nonnegative integer feeMinor, and explicit cities[] (an explicitly approved '*' means all cities). Case-insensitive exact city rules are enforced server-side. There are no invented thresholds or rates. Tax treatment must be explicitly included-in-prices or not-applicable for approved settings; separate tax calculation is not implemented. An approved configuration currently supports COD only when the owner selects it (id='cod', allocation='accepted'). Other real payment methods need their later approved integration; no gateway or manual paid override exists here.

For a clearly isolated development test, `npm run dev:commerce:test` starts port 3100 using .next-public-verification and process-only test configuration: Test City, test shipping 12,345 minor units, a labelled development COD option and a labelled temporary hold. These are synthetic test settings, never business shipping/payment choices. It does not write .env or enable the normal port-3000 store. Keep synthetic fixtures out of real catalog publication; the verifier explicitly publishes only its own neutral fixture and hides/cleans it afterwards.

## Reservations and fulfilment

- Cart quote validates published eligible variant identities, current PKR prices and stock, but never reserves.
- Placement checks customer inputs/configuration, locks product/variant/price rows, snapshots names/original SKUs/options/prices/shipping/customer details and reserves all items atomically in consistent variant order. Failed placement rolls back all order/items/allocations.
- Stable request UUID plus signed session ownership and exact request hash prevents duplicate/altered retries. A lost response can resume the existing private confirmation in the same browser. Only the UUID is stored as an attempt key; customer details are not persisted by this new retry mechanism.
- COD accepted allocations have infinite reservation deadlines; they are not abandoned-checkout holds. Temporary development payment holds last 20 minutes and stay unpaid.
- Unpaid payment holds cannot Confirm or Dispatch. COD due-on-delivery orders may proceed; Complete never claims payment or courier remittance. No payment verification/Mark paid control is fabricated.
- Confirm, Dispatch, Complete and Cancel are audited, idempotent and revision checked. Dispatch consumes once; Complete checks consumed ledger consistency but deducts nothing. Cancel before dispatch releases once, including after a temporary deadline. Cancellation/expiry cannot release twice. Dispatch/completion do not invent courier tracking/shipment rows.
- Allocation guards verify every immutable order line and component, exactly one correctly sized/state reservation per expected variant, counted balances matching all active allocations, accepted infinite deadlines, and consumed movement history. Missing/partial/inactive/extra reservations, missing components or mismatched counters fail closed. No automatic repair guesses stock.
- Expiry validates the complete allocation before release. Integrity failures roll back the batch and require an authorized investigation rather than silently repairing real stock.
- Guest confirmation uses HttpOnly SameSite signed ownership, with no bearer token in a URL or browser bundle. Order number/UUID alone grants no customer data. Cookie lifetime is 30 days; lost/expired ownership requires customer care, with no invented email recovery promise.

## Executable maintenance and scheduling

Run `npm run commerce:maintenance` from a secure server environment with the existing Supabase server configuration. It invokes expire_commerce_holds in batches of 100 (maximum 1,000/run), then reports aggregate balance mismatches/overdue holds. Repeated and overlapping runs are safe: row locks/SKIP LOCKED and terminal states prevent duplicate releases. Nonzero mismatch/backlog or provider failure exits nonzero. It never repairs counters automatically or depends on an open browser. Output contains aggregate counts only, no customer details.

Schedule this command every minute using the eventual host's scheduler (or Windows Task Scheduler locally); use an absolute Node executable/script path and this project as the working directory. For a secure Linux/server cron job, the schedule is `* * * * *`, command `<absolute-node> <absolute-project>/scripts/commerce-maintenance.mjs`, with server secrets injected by the selected host's secret configuration. Never put credentials in the command line, committed files or public HTTP endpoints. Hosting/scheduler selection is still a business setup decision; no task has been deployed or scheduled automatically.

Production/public checkout remains unavailable until approved shipping/city/tax treatment/payment choices, secure ingress/session configuration and hosting are ready. The existing production preview gate remains in place; deployment is not part of this stage.

## Verification boundaries

See commerce-verification.md and the JSON reports. Local PostgreSQL Auth/Storage/media doubles are distinct from actual Supabase service checks. After installation the prepared `npm run verify:commerce:development` uses actual Chrome, Next and Supabase, creates only synthetic fixtures and snapshots existing records before/after. Native expiry testing waits for the real 20-minute hold deadline; it does not alter private timestamps. Before testing the global expiry task it checks for unrelated overdue orders and stops safely rather than touching them. Synthetic orders/history are retained as cancelled/expired/completed evidence; products are hidden and test media cleaned up. No real stock, content or homepage selection may be changed.

Current explicit pause: provide the corrected file and hash; wait for owner application. No deals, sales dashboard, real payments, courier API or deployment implemented.
