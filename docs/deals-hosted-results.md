# Actual hosted deals verification — complete, 2026-10-18

## Result

All 98 main live check observations passed using real Chrome, Next.js, hosted Supabase Auth/PostgREST/PostgreSQL/private Storage and Cloudinary. Independent cleanup/reconciliation passed 35 checks; a separate browser pass confirmed the fully loaded editor at desktop and mobile widths (3 checks). No mocked requests were used. No installer/hosted SQL was executed or earlier migration rerun by the agent.

The owner confirmed incremental 018 and 019 installed with matching receipts. 018 removes unintended anon/authenticated deal_media privileges while preserving SELECT; 019 corrects five stale policy helper OIDs introduced by 017. Owner metadata confirms seven RLS tables, intended policies, isolated private tables and RPC permissions. Actual post-019 anonymous/non-admin/admin reads of all five affected tables now return HTTP 200; visibility is still policy-filtered. Protected RPCs and direct media writes remain denied to unauthorized callers.

## Actual hosted coverage

| Area | Verified behaviour |
| --- | --- |
| Authorization | Actual admin login/membership, non-admin browser rejection, unauthenticated API rejection, CSRF denial, private no-store responses; anonymous/non-admin protected RPC denial and private schema isolation. Direct deal_media writes are denied even to admin JWTs, requiring the approved workflow. |
| Daily admin | Browser Create, exact SKU/options, Save draft, Publish and Hide; ordinary Save preserves Published/Hidden; stale and invalid published edits rejected without mutation. Repeated component SKUs aggregate quantities. Factory-pack products remain separate. |
| Media | Real private Storage upload with deal ownership and no fake product; unauthorized reads and pending public metadata denied; admin preview, explicit approval, Cloudinary publication and responsive delivery passed. Duplicate completion creates one association. |
| Public/homepage | Draft/hidden/ended isolation; eligible active deals only; manual homepage selections and changed ordering reflected publicly without replacing owner rows. Existing card template/four heroes/footer render. |
| Stock and mixed cart | Individual-versus-deal and two-deals last-unit races have one winner; mixed overlapping components and unavailable lines roll back completely; browser price override rejected. Repeated SKUs and quantities greater than one reserve exact units. Bag reload persists without reserving stock. |
| Set-aside pools | Individual/other-deal availability reduced, no physical deduction; order transfer avoids double counting; cancellation/expiry returns only own unchanged-generation pool units. Hide releases unused pool while preserving existing order allocations; cancellation after hide returns general stock. Ended pools expire exactly once. |
| Checkout/payment/snapshots | Actual browser mixed checkout, private guest confirmation, reference submission staying Under review, unpaid fulfilment denial, explicit admin verification and Confirm/Dispatch/Complete. All three configured synthetic manual services exercised. Later deal edit/hide leaves historical title/price/components/totals unchanged; dispatch consumes old quantities once, retry/Complete do not deduct again. |
| Actual deadlines/late receipts | Native temporary deadlines were allowed to expire, without editing private timestamps. Executable expiry RPC releases once; late payment reacquires own returned pool, verification retry retains one receipt. Concurrent late-paid deals retain both receipts but allocate one last shared unit; the other requires resolution and cannot fulfil. |

The initial mobile-editor screenshot captured the list before its asynchronous editor load. The harness now explicitly waits for the Deal title field. A separate read-only actual browser follow-up verified the loaded editor at 390px and 1440px; screenshots were inspected. Public mobile deal detail and approved image loading were verified at 390px. Synthetic fixture images are intentionally neutral one-pixel images; they are not product photography. Desktop order and mobile editor/detail screenshots remain ignored under .local/deals-hosted.

## Preservation and cleanup

All 1,416 original row hashes across 40 checked business tables remained unchanged, including existing catalog/stock, orders/payment records, content/media and homepage selections. Only synthetic fixtures were created: two separate product families/four variants, three assembled deals, nine successful orders and five media assets. Products/deals are hidden, variants archived, fixture homepage selections retired, taxonomy archived, private originals removed and media cleanup completed through the existing provider service. Audit, allocation, order, receipt and stock-movement history is retained; no business history was hard-deleted.

Independent read-back confirms no active fixture reservations, zero reserved fixture counters, empty fixture deal pools, no public fixture products/deals, deleted media and actual Storage not-found responses. Global reconciliation is clean: balanceMismatches=0, overdueHolds=0, endedDealAllocations=0. All nine order histories remain with no active holds. All 64 original handoff/import inputs and 14 reference CSS blocks passed preservation checks. Targeted harness lint passed. No storefront code, approved design/assets, real record, owner selection or local secret configuration was changed.

## Local/mocked tests and remaining limits

Earlier disposable SQL tests, exact-file 017/018/019 installer checks, units and intercepted UI tests are historical separate evidence, not counted in the actual hosted observations above. They were not rerun as hosted tests. This pass made no application/schema change and did not rerun build or the full pixel-diff suite; previous recorded homepage pixel differences are not claimed fixed. Current desktop/mobile browser views were inspected, not inferred from a build.

Normal port-3000 checkout remains disabled. The isolated port-3100 test instance used process-only, clearly labelled synthetic shipping/accounts and no actual money. No receiving-account history, gateway, payment API or real transfer was used. Before real checkout: owner-approved receiving accounts/instructions and stable identifiers; shipping/cities/fees/tax treatment; payment/review deadlines; human payment-resolution/proof-retention policy; hosting/trusted ingress and an external every-minute `npm run commerce:maintenance` schedule are still needed. The maintenance functions were actually exercised, but an external scheduler is not installed. Physical devices, other browser engines and production-load behaviour were not tested.

No reporting, refunds, courier API, deployment or next feature stage was started. Raw actual evidence: deals-hosted-live-verification.json, deals-hosted-cleanup-readonly.json, deals-hosted-editor-layout.json, deal-media-policy-hosted-readonly.json and deals-hosted-security-audit.json.
