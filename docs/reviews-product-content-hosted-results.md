# Hosted reviews and product content verification — 2026-10-08

Migrations 011/012 were confirmed installed by the owner. No installer or migration was executed again. Local presence-only checks passed for SUPABASE_SECRET_KEY and REVIEW_SESSION_SECRET (including its minimum length); Next was restarted before testing. The actual public review RPC returned HTTP 200. Reports contain no credentials.

## Actual hosted results

`reviews-product-content-live-verification.json` records **58 passed checks, zero pending checks**, using real Chrome, Next server routes, Supabase Auth/PostgREST/private Storage and Cloudinary. No intercepted provider responses or database doubles were used. Repeatable runner: `scripts/verify-reviews-product-content-development.mjs --run-development`, using the configured Node runtime.

- Anonymous/non-admin editor/API access was rejected; admin browser login/logout worked. Private responses were no-store and missing-CSRF mutations failed. All 121 original import SKUs remained searchable; no catalog import was run.
- Two customer submissions started pending. A review-owned private image was unreadable anonymously and by the non-admin, but readable by the admin. Explicit browser approval published through Cloudinary; metadata-backed responsive delivery decoded in Chrome. Email stayed private and no unsupported verified-purchase badge appeared.
- Approve, Decline and Hide worked through the real moderation screen. Pending/declined reviews did not affect ratings. Approved ratings of 5 and 1 produced count 2/average 3; hiding the first left count 1/average 1. Editing the remaining approved review returned it to moderation and removed it from public ratings. Reloaded public pages reflected these changes.
- Single-product and two-variant browser saves persisted Product description, How to use and Key benefits exactly. Write/Preview and public rendering supported formatting, escaped raw HTML, rejected unsafe links and did not embed arbitrary images. An unrelated name edit retained all three untouched fields and stock.
- Ordinary Save preserved published and hidden product/option statuses. An invalid published edit showed an actionable checklist and rolled back without changing revision, price, stock or visibility. Only explicit Save draft changed hidden products back to drafts.
- Zero stock was reconciled as an explicit audited count. Variant prices persisted in integer PKR minor units; exact stock edits worked. Removing an option archived it while preserving its SKU and stock history. Mobile product/editor layouts had no document overflow.

## Fix found during actual provider testing

The first live run failed image decoding for a tiny synthetic image: c_limit does not upscale, but responsive width descriptors advertised requested rather than delivered sizes. The shared resolver now bounds fit-image descriptors to the original width; explicit fill crops and local preview assets are unchanged. Actual provider verification was rerun and passed. The failed run and its completed cleanup/preservation checks remain separately recorded in `reviews-product-content-live-first-run.json`.

## Cleanup and preservation

The successful run hid both synthetic products and both reviews, archived their test taxonomy and removed its three uploaded assets through the guarded Storage/Cloudinary cleanup service. Earlier failed-run fixtures were also cleaned. Audited synthetic rows/tombstones are intentionally retained; real business rows were not deleted.

Every one of **923 pre-existing rows across 25 tables** remained identical after the successful run, including catalog content/prices/stock/media, import records, articles, homepage selections and reviews. The earlier failed run separately preserved its 906-row baseline. No real product/article/review was published or approved. Approved source assets and storefront CSS were not changed.

## Separate local checks and limits

Nineteen unit/security tests passed, including explicitly mocked provider verification/cleanup tests. Those are separate from the actual provider results above. Build, source-integrity and homepage browser results are recorded in `admin-refresh-verification.json` and the standing implementation status.

Browser coverage is installed Chrome desktop and mobile emulation, not physical iOS Safari. Hosted abuse quotas were not deliberately exhausted; rate-limit/invalid-input cases have separate local SQL/unit coverage. This was development verification, not a production deployment or load test. Production ingress/hosting and existing business decisions remain outside this stage. No next numbered stage was started.
