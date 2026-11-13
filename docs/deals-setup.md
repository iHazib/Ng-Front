# Assembled deals — incremental 017

Migrations 001–016 are retained unchanged. Factory-pack SKUs remain ordinary catalog products. Deals are separate UUID owners with exact variant components; no catalog families or physical counts are copied or rewritten.

## Apply once in the development project

1. Run **`supabase/sql-editor/15_preflight_deals.sql`** in a new SQL Editor query. It is read-only. Before installation, only `prerequisite_016` and `no_client_policies` should be true; the other thirteen flags should be false. If objects/receipt already exist, inspect state instead of rerunning.
2. Open the complete **`supabase/sql-editor/15_install_deals_clean.sql`** in a new query and run the entire file once. Do not combine fragments or rerun previous installers. The file starts a transaction, checks canonical 016, installs 017, writes one hash receipt, reloads PostgREST's cache, commits and returns the same fifteen checks. All fifteen should then be true.
3. Share only those result flags. No keys, account details or customer data are needed in chat. The private receipt cannot be inspected via a browser publishable key.

`docs/deals-installer-manifest.json` records the exact installer SHA-256 and canonical migration SHA-256. The receipt stores the canonical migration hash; it is deliberately different from the complete installer hash. `docs/deals-local-verification.json` identifies the exact file tested with `psql -X -v ON_ERROR_STOP=1 -f` on a fresh 001–016 database.

Installation adds tables/columns/indexes and replaces guarded functions. It drops/recreates two media ownership CHECK constraints and one media SELECT policy, preserving existing owner rules and adding deals. It revokes generic authenticated deal/component writes in favour of authorized RPCs. It performs no business-row deletion/reset. DELETE statements inside runtime functions release unused pool rows or replace the components of the explicitly edited deal; they do not execute during installation. Historical orders/components/receipts/audits are retained.

## Owner workflow

Use **Admin → Deals**. Save a title/unique slug as a draft, search for exact product options/SKUs, select quantities and enter a total PKR price. Repeated SKUs aggregate automatically. Draft/ineligible components may be prepared privately; publication requires eligible published component options, a positive price and approved deal media. Images upload under the deal's own UUID, stay in private Storage for review, then publish through the existing server-verified Cloudinary service only after explicit approval. Replacement keeps the old image until completion; primary/order/alt controls and retries reuse the existing service. Pending/failed uploads are separately removable with existing safety windows.

Ordinary Save preserves Published/Hidden status. Invalid published changes fail with a checklist/message and roll back. Save draft, Publish and Hide are explicit visibility actions. Dates are entered/displayed in Pakistan time and stored as UTC instants. Empty start/end dates are allowed. Homepage selections are manual, ordered together with products through the existing Homepage screen (up to twelve). Selecting a deal cannot overwrite an occupied product position. Hero/category/concern/brand assets and section/card styling are unchanged.

Public routes are `/deals` (24 per page with real pagination links) and `/deals/[slug]`. Only published, currently active deals with eligible components and approved media appear. Inactive/hidden/unknown detail routes return 404. No sample data is substituted on provider failure. Savings appear only when the actual current standalone component total exceeds the deal total. Checkout revalidates current deal revision/price/stock on the server.

## Shared stock and allocation rules

Available deal units are `min(floor((general available component stock + this deal's idle pool) / aggregated required component quantity))`. Individual products and other deals cannot spend this deal's idle pool. Physical `on_hand` is never deducted for a set-aside or cart addition.

Set-asides use the existing balance `reserved` counter plus private, audited pool rows. An explicit deal save replaces the **unused** pool with the requested number of deal units, in addition to stock already held by orders. Every save advances a pool generation. Insufficient stock rolls back the entire save. No allocation takes order-reserved stock; physical counts below all order/pool reservations are rejected by the existing stock adjustment safeguards.

Placement transfers that deal's relevant pool units into one aggregate reservation per order/variant. The pool decreases before the aggregate reservation increases, avoiding double counting. Mixed carts aggregate individual options and every deal component across all lines. A transaction gate serializes inventory critical sections for this small store, with ascending UUID row locks. No additional service is introduced.

Cancellation/expiry returns **only the originally transferred portion** to the same unchanged, open deal generation. Units taken from general availability return to general availability. If the deal was saved/changed, hidden, ended or became ineligible, all released order units return to general stock. Returning a portion is idempotent. Hiding/ending releases only unused allocation; accepted orders retain their own reservations.

Late payment receipt remains independent of stock. Explicit admin reacquisition may reclaim that order's own returned, unchanged-generation pool units, plus available general stock. It does not steal another deal's allocation. Shortage rolls back the complete reacquisition while retaining the receiving-account receipt as “Payment received—resolution required”. No automatic refund or fulfilment occurs.

Orders snapshot deal title/price and exact component SKU/product/option names, quantities and standalone prices. Deterministic largest-remainder price attribution allocates every paisa of the deal line to its components for later partial-refund reporting. Runtime allocation assertions compare immutable private snapshots with public order components, reservations, counters and dispatch movements. Later deal composition/price/visibility edits cannot change the historical charge or dispatch quantity. Dispatch consumes once; Complete never deducts again.

## Maintenance and configuration

Run `npm run commerce:maintenance` through an independent secure scheduler **every minute** after 017 installation. It processes bounded batches of ended/ineligible idle deal allocations and unpaid order deadlines, then checks reconciliation/backlog counters and exits nonzero on mismatches/backlog. It uses the existing server-only `NEXT_PUBLIC_SUPABASE_URL` plus `SUPABASE_SECRET_KEY` (legacy `SUPABASE_SERVICE_ROLE_KEY` fallback). Do not expose those server credentials in cron URLs, browser code or logs. No scheduler has been deployed by this task; choose the host/scheduler later.

No new provider/environment secret is required. Existing Cloudinary environment separation and Supabase private Storage/Auth configuration are reused. Real checkout remains disabled until owner-approved receiving accounts, shipping/cities/tax treatment, deadlines and ingress/scheduler configuration are complete. Only Bank Transfer, Easypaisa and JazzCash are supported; no COD/gateway/API was introduced.

## Verification boundary

Read `deals-local-verification.json`, `deals-ui-verification.json` and `deals-live-readonly-verification.json` separately. PostgreSQL is real in the disposable test, while Supabase Auth/Storage/provider metadata are explicit doubles there. Chrome/Next UI tests use real admin Auth but intercept synthetic deal/media/cart responses. The temporary component harness is removed and never included in production.

Full hosted synthetic deal CRUD/media/checkout/payment/concurrency tests remain pending 017 application and receipt verification. No hosted deal/product/order fixtures or uploads were created in this stage. After installation, test the live flows with synthetic fixtures, release all pools/reservations, remove only their private/public files, archive their catalog/deals and retain order/payment/allocation audit history. Preserve baseline business hashes and homepage selections. The previous 016 hosted results remain historical evidence, not proof of new 017 behaviour.


## Hosted verification completed (2026-10-18)

Supersedes installation-pending notes: owner confirms 017–019 installed; actual hosted/browser deal/media/stock/payment tests and guarded cleanup pass. Do not rerun installers. See deals-hosted-results.md/json. Real checkout and external scheduler remain unconfigured; prior business decisions above still apply.
