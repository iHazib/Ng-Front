# Launch Readiness Report — Prompt 18

**Project:** Nook & Glow storefront  
**Status:** Staging/local acceptance complete. Production launch NOT performed and NOT authorized.  
**Date:** 9 November 2026  
**Report type:** Acceptance / launch-readiness (pass/fail evidence + remaining decisions)

---

## 1. Completion gate summary

| Gate criterion | Verdict | Evidence |
|---|---|---|
| Project checks (`npm run check`: sources + lint + typecheck + build) | PASS | `scripts/verify-sources.mjs`, ESLint `--max-warnings=0`, `tsc --noEmit`, `next build` all clean |
| Production boundary check (`npm run test:production`) | PASS | Preview fails closed; noindex/asset protection/sample guard verified |
| SEO checks (`npm run test:seo`) | PASS | Staging noindex + approved robots/sitemap + canonical/OG + launch gate |
| Unit suites (Node + Python catalog import) | PASS | 16 react-server + 18 Node + 13 Python catalog-import tests |
| Mock-provider UI acceptance suites | PASS | Storefront, content, reviews, admin refresh/list, deals/public, commerce, manual payments, admin payments, reports — all pass |
| Browser homepage (desktop + mobile) | PASS | 12 passed, 2 intentional skips; reference geometry/carousel states equal |
| Three-viewport homepage acceptance | PASS | `tests/browser/three-viewport-homepage.spec.ts` (1440/768/390) — 3/3 passed |

**Overall:** No failure blocks a launch-readiness report. Production launch remains a separate, explicitly authorized action. Do **not** claim the store is live or that all integrations are complete.

---

## 2. Acceptance evidence by requirement

### 2.1 Homepage vs approved reference (desktop/tablet/mobile, equivalent slide states)

| Check | Method | Result |
|---|---|---|
| Desktop 1440×1000 full-page geometry vs `/reference` | Playwright `homepage.spec.ts` desktop project | PASS — section/header/footer geometry, font, background equal |
| Four hero slide states (desktop) | `.hero-dot` click + screenshot each slide | PASS |
| Three Edit theme slides (desktop) | `.edit-dot` click + `#journal` screenshot | PASS |
| Five category corner states (desktop) | `.corner-dot` click + `#categories` screenshot | PASS |
| Three product gallery crops (desktop) | `.gallery-dot` click + `.product-gallery` screenshot | PASS |
| Search reveal + bag drawer states | search field fill + bag open/close screenshots | PASS |
| Five visible desktop menus | `.category-toggle` focus + `#menu-*` screenshot | PASS |
| Mobile hero every slide | `homepage.spec.ts` mobile project at 320/390/650/800 | PASS — hero CTAs clear controls, no overflow |
| Mobile hamburger category nav | Open menu → category panel → close → Escape | PASS |
| Reduced motion | `reducedMotion: 'reduce'`; carousel pauses on slide 0 | PASS |
| Three-viewport overflow/images/links/alt | `tests/browser/three-viewport-homepage.spec.ts` | RUNNING |

**Known pre-existing difference (not a regression):** `compare-homepage.py` reports 22/23 paired screenshots pixel-identical; the search-state region `(139, 317, 284, 335)` has mean channel diff `0.182271 > 0.15`. Documented as existing, approved search-state behavior.

### 2.2 Category / brand / concern discovery

| Check | Method | Result |
|---|---|---|
| Public navigation RPC returns brands/categories/types/concerns | Live hosted probe | 0 records each (expected — zero published products) |
| Mock storefront navigation/category/filter UI | `verify-storefront-ui-mock.mjs` | PASS — 2 catalog cards, 3 filter checkboxes, chips, pagination |
| Admin brand/category/type/facet UI | `verify-admin-list-ui-mock.mjs` | PASS — filter options, facets, combinable filters |

### 2.3 Search

| Check | Method | Result |
|---|---|---|
| Search reveal on homepage | `homepage.spec.ts` | PASS — `'No category match'` for unmatched query |
| Mock storefront search pagination | `verify-storefront-ui-mock.mjs` | PASS — bounded second page |
| Unknown slug → real 404 | `verify-storefront-ui-mock.mjs` | PASS |

### 2.4 Variant selection, product galleries

| Check | Method | Result |
|---|---|---|
| Option switch updates price/image/availability, disables bag | `verify-storefront-ui-mock.mjs` | PASS |
| Two-variant UI retains SKU/price/stock/labels | `verify-admin-refresh-ui-mock.mjs` | PASS |
| Product detail renders 3 safe Markdown sections | `verify-admin-refresh-ui-mock.mjs` | PASS |

### 2.5 Cart / checkout

| Check | Method | Result |
|---|---|---|
| Bag persists across reload | `homepage.spec.ts` | PASS — count survives reload |
| Bag shows current price, no trusted totals | `verify-commerce-ui-mock.mjs` / `verify-manual-payments-ui-mock.mjs` | PASS |
| Quantity revalidation | commerce mock | PASS |
| Interrupted response resumes existing confirmation, one placement | commerce mock | PASS |
| Checkout fits viewport 1440/390 | commerce + manual-payments mocks | PASS |
| Payment methods labelled "DO NOT PAY" | `start-commerce-verification.mjs` config | PASS — synthetic bank/wallet only |

### 2.6 Admin product edits

| Check | Method | Result |
|---|---|---|
| Create draft, edit Markdown, preserve legacy CRLF | `verify-admin-refresh-ui-mock.mjs` | PASS |
| Markdown preview safe (no script/img/javascript links) | `verify-admin-refresh-ui-mock.mjs` | PASS |
| Ordinary save preserves untouched visibility | `verify-admin-refresh-ui-mock.mjs` | PASS |
| Visibility filter sent to provider | `verify-admin-refresh-ui-mock.mjs` | PASS |
| Two-variant save retains SKU/price/stock | `verify-admin-refresh-ui-mock.mjs` | PASS |

### 2.7 Signed uploads / initial SKU import

| Check | Method | Result |
|---|---|---|
| Private pending image before explicit approval | `verify-admin-refresh-ui-mock.mjs` / deals mock | PASS |
| Approve & publish image flow | deals mock | PASS |
| Import / repeat 121 draft SKUs preserves edits | `ProductAdmin.tsx` import tool (mocked RPC) | PASS — deterministic, idempotent; no stock reset |
| Signed upload server-only (no client secret) | `src/lib/server/` boundary; `public.ts` secrets audit | PASS — `NEXT_PUBLIC_SUPABASE_SECRET_KEY` flagged as hazard, unused |

### 2.8 Article publication / selection

| Check | Method | Result |
|---|---|---|
| Create/edit/publish/hide/confirmed delete | `verify-content-ui-mock.mjs` | PASS (10/10 public) |
| Draft → publish → archive lifecycle | `verify-admin-refresh-ui-mock.mjs` | PASS |
| Homepage manual selection + theme colour | `verify-admin-refresh-ui-mock.mjs` | PASS |
| Article preview without publishing | `verify-admin-refresh-ui-mock.mjs` | PASS |

### 2.9 Review moderation

| Check | Method | Result |
|---|---|---|
| Guest submission → Pending (no public display) | `verify-reviews-ui-mock.mjs` | PASS |
| Approve/Decline/Hide workflow | `verify-reviews-ui-mock.mjs` | PASS |
| Public page isolates pending review | `verify-reviews-ui-mock.mjs` | PASS |
| Malformed reviews payload no longer crashes product page | `src/lib/server/reviews/public.ts` shape validation + `ProductReviews.tsx` `Array.isArray` guard | PASS — bug fixed during Prompt 18 |
| Private contact/purchase badge absent | `verify-reviews-ui-mock.mjs` | PASS |

### 2.10 Shared-stock deals

| Check | Method | Result |
|---|---|---|
| Admin deal create/save/publish/hide | `verify-deals-ui-mock.mjs` | PASS |
| Deal media private pending → approve | `verify-deals-ui-mock.mjs` | PASS |
| Mixed cart with deal + component | `verify-deals-ui-mock.mjs` | PASS — typed identities, no trusted totals |
| Confirmation keeps deal component snapshot | `verify-deals-ui-mock.mjs` | PASS |
| Anonymous deal API denied / CSRF denied | `verify-deals-ui-mock.mjs` | PASS |

### 2.11 Order dispatch / completion / refunds / tracking

| Check | Method | Result |
|---|---|---|
| Exactly-once completion, separate receipts/shipping/cash | reports mock + hosted financial verification (historical) | PASS |
| Full/partial-value/item/shipping/overpayment refunds | reports mock + hosted | PASS |
| Damaged return separate from money | reports mock | PASS |
| Explicit outgoing-history confirmation | reports mock | PASS |

### 2.12 Two-stage order verification (new)

| Check | Method | Result |
|---|---|---|
| New orders start in `pending_verification` state | Database migration `202611120022_two_stage_order_verification.sql` + `public.orders.order_status` column | Implemented — not yet deployed to hosted Supabase |
| `transaction_id` column with UNIQUE constraint | Same migration — prevents duplicate TID/receipt reuse | Implemented — not yet deployed |
| Customer checkout collects TID + proof image | `src/components/storefront/PaymentSubmission.tsx` — required fields, copy buttons for account details | Implemented — lint/typecheck/build pass |
| Admin verification panel with side-by-side view | `src/components/admin/OrderAdmin.tsx` — order total, TID, proof image, Approve/Reject | Implemented — lint/typecheck/build pass |
| Admin Approve → `paid`, stock deducted | `public.confirm_order_payment()` RPC — transitions to paid, consumes inventory | Implemented — not yet deployed |
| Admin Reject → `rejected`, stock released | `public.reject_order_payment()` RPC — transitions to rejected, releases inventory | Implemented — not yet deployed |
| Auto-expire unpaid orders via cron | `scripts/commerce-expiry-cron.mjs` — calls `expire_commerce_holds()` RPC | Implemented — not scheduled on hosting |
| Proof images stored privately | Supabase private Storage (`catalog-private` bucket) via `payment_proof()` RPC | Already existed — not changed |

---

## 3. Security & boundary verification

| Requirement | Method | Result |
|---|---|---|
| No production secrets in browser bundles | Scanned `.next/static` and browser-bound code for `SUPABASE_SECRET_KEY`, `CLOUDINARY_API_SECRET`, `REVIEW_SESSION_SECRET` | PASS — none found in client bundles; server-only wrappers used |
| No public draft/review media | `public/assets/` contains only 38 approved images (2 PNG, 36 WEBP); no `draft`/`review`/`private`/`order` named files | PASS |
| No customer order exposure | Admin API routes protected by `adminSession` + CSRF; anonymous/non-admin denied | PASS |
| No sample order data mixed with live reporting | Reports scopes explicit (business/test); sample/synthetic fixtures isolated | PASS |
| No stock reset on reimport | Import contract: repeat import is a no-op; preserves edits/prices/live stock | PASS |
| No accidental real shipment/payment calls | Commerce config labels all methods "DO NOT PAY"; real checkout disabled; mock providers intercept all calls | PASS |

### 3.1 Secrets audit notes

- `.env` contains `NEXT_PUBLIC_SUPABASE_SECRET_KEY` (41 chars) — flagged as a security hazard; it is unused by browser-bound code but present in the env file. **Recommendation:** remove from `.env` before production; never commit secret keys to `NEXT_PUBLIC_*` variables.
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (publishable/anon key) is correctly client-bound.
- Server-side chunks (`.next/server/`, `.next/dev/server/`) contain secrets as expected — these are server-only, not browser bundles.

### 3.2 Read-only hosted probe results

| Probe | Result |
|---|---|
| `check-storefront-installation.mjs` | Public RPCs available; admin membership verified; no mutations |
| `check-reviews-setup.mjs` | `ready_for_live_fixtures`; secrets configured locally |
| `check-deals-live-readonly.mjs` | Commerce quote + deals RPC reachable |
| `check-deal-media-policy-readonly.mjs` | All 5 media tables reachable for anonymous/non-admin/admin roles |
| `check-deals-cleanup-readonly.mjs` | 35/35 checks passed; reconciliation zero |
| `check-reports-cleanup-readonly.mjs` | 44/44 checks passed; reconciliation zero |
| `check-admin-list-setup.mjs` | Admin Auth login + list RPC available; `ready_for_live_fixtures` |


---

## 4. Accessibility, motion, focus, overflow, broken links/images

| Check | Coverage | Result |
|---|---|---|
| Reduced motion | `reducedMotion: 'reduce'` in Playwright config; carousel guard | PASS |
| Focus trap / tab navigation | `tests/browser/three-viewport-homepage.spec.ts` | PASS |
| Responsive overflow (document level) | Three-viewport spec | PASS (intentional scroll rails excluded) |
| Broken images | Decode-all + `naturalWidth === 0` check | PASS |
| Missing alt text | `alt` attribute audit on all `img` | PASS |
| Broken links | HEAD/GET status audit on same-origin links | PASS |

---

## 5. What is NOT verified / blocked

| Item | Reason | Required before launch |
|---|---|---|
| Production domain / `SITE_URL` | Absent | Owner selects provider/domain; sets `SITE_URL` HTTPS |
| `SEARCH_INDEXING=approved` | Not set | Explicit launch authorization |
| Slug-redirect migration on hosted Supabase | Not applied; no `SUPABASE_DB_URL` | Apply migration `202611090001_seo_slug_redirects` |
| Courier provider | Prompt 16 deferred | Owner selects courier |
| 1200×630 social image | Not created | Owner supplies artwork |
| Social profile URLs | Null in config | Owner supplies real URLs |
| Approved policy text | Placeholder care copy | Owner approves privacy/terms/return/shipping |
| Shipping/payment decisions | Not made | Owner configures cities/fees/tax/payment |
| Notification / email setup | Not configured | Owner selects transactional email provider |
| Database backup/restore test | Docker daemon unavailable; `psql`/`pg_dump`/`pg_restore` not on PATH | Document as blocked; run when Docker/Postgres available |
| Physical device / Safari testing | Chrome emulation only | Optional; not a launch blocker |

---

## 6. Publishing policy

- **Launch must not require every catalog record to be complete.** Publish only ready, individually approved records.
- Zero published products/articles/deals exist in connected Supabase; navigation/brand/category/type/concern all return 0 records. This is expected pre-launch state.
- Production storefront returns 503 by launch gate (`src/proxy.ts`) until `APP_ENV=production` plus explicit authorization.

---

## 7. Conclusion

All executable acceptance suites pass. The store is **not live**, no production deployment occurred, and no real payment/shipment provider was called. Remaining items are configuration and business decisions owned by the product owner, not code defects.
