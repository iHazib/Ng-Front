## Technical SEO and launch decisions (Prompt 17, 9 November 2026)

SEO is implemented but deliberately dormant. Activating it is a launch decision, not an engineering default:

1. **Approve the production domain.** Set `SITE_URL` to the final HTTPS origin (no path, query, credentials or fragment). This is the only value that enables `metadataBase`, absolute canonicals, Open Graph URLs and sitemap URLs. Do not guess or reuse a test domain.
2. **Approve indexing explicitly.** Set `SEARCH_INDEXING=approved` and run with `NODE_ENV=production` and `APP_ENV=production`. Until all four conditions hold, the site, robots and sitemap stay noindex. Preview/staging must never receive these values.
3. **Authorize launch serving.** The existing `APP_ENV=production` 503 gate is unchanged and must be removed only as part of an approved launch, together with the preview-auth decision for public traffic.
4. **Apply the slug-redirect migration.** `202611090001_seo_slug_redirects.sql` is not installed on hosted Supabase (HTTP credentials cannot apply DDL; no `SUPABASE_DB_URL`). Apply it through the approved installer/owner workflow before relying on legacy redirects. Until then old slugs return 404, not a guessed target.
5. **Approve a 1200×630 social image.** The current OG fallback is the 1672×941 brand hero. A purpose-made social card is recommended before launch.
6. **Provide social profiles (optional).** `src/config/site.ts` has `instagram`/`facebook` as `null`; `sameAs` is intentionally omitted until real URLs are approved.
7. **Approve customer-care/policy copy.** Care pages are currently preview placeholders and are noindex but followable. They must not be indexed until shipping, returns, privacy and contact copy is approved. No fabricated policy text was published.
8. **Publish real catalogue/editorial records.** The connected Supabase project has zero published products, articles and deals, so the approved-mode sitemap would contain only the homepage. Publish via the existing admin workflow before expecting a populated sitemap.
9. **Remove the unused secret name.** `.env` still contains `NEXT_PUBLIC_SUPABASE_SECRET_KEY`, which is unused and misleadingly public-prefixed. Delete or rename it; never expose a Supabase secret key to the client.
10. **Decide asset compression.** Images are ~1,016 KB of the ~1,889 KB transfer. Approve a resizing/compression pass for hero, category and product assets (and responsive delivery) if further payload reduction is required.

Prompt 16 (courier) remains deferred because no provider is selected. Prompt 18 was not started. No production deployment or launch claim was made.

## Review-stage setup and decisions (7 October 2026)

- Apply ONLY migration 011's tested clean installer after its read-only preflight. Do not rerun 001–010. Hosted installation/receipt and real review verification remain pending.
- Configure a development backend Supabase secret key (`SUPABASE_SECRET_KEY`) and a locally generated `REVIEW_SESSION_SECRET` in ignored server configuration. No secrets in chat. Public key cannot authorize the private guest upload gateway; project key-management access is required.
- Hosting remains undecided. Before non-development guest submissions, validate trusted ingress/client-IP handling; only explicit Cloudflare/Vercel stripped headers are currently supported. No arbitrary forwarded header is trusted.
- Current abuse defaults: five reviews/address bucket/hour and 100 submissions/hour globally; consider business volume and distributed-abuse controls at launch. No paid or AI spam service introduced.
- Review private contact has no invented retention policy or transactional email promise. Decide an approved retention/privacy policy before public launch; optional email is never displayed publicly.
- No verified-purchase badge is shown in this stage. Future orders integration must supply matching order evidence before such a label can be introduced.

All earlier launch decisions and approved assets remain in force. Details: [reviews-setup.md](reviews-setup.md).

# Decisions needed

## Content CMS development gate resolved — 2026-10-07

Migration010 is already applied and its final checks confirmed. Do NOT rerun installer08 or any earlier installer. Actual provider/browser verification completed with44 passed checks and no pending items; prior homepage selections restored and real records/assets preserved. Earlier migration010 requests below are historical, superseded by content-live-verification.md.

Real articles, authors, approved text/images/alt/SEO and manual merchandising remain owner decisions; no synthetic article survives in the public CMS. Soft-deleted synthetic/audit history remains intentionally private. Chrome mobile emulation was tested, physical Safari/load testing was not. Existing production domain/hosting/shipping/courier/payment/email/social/policy/photo decisions persist. No orders/deals/review moderation/payments were started.

Cloudinary development credentials and migration 007 are now configured/applied by the user, and the actual synthetic provider verification passed. No configuration blocker remains for this stage. Admin upload UI, initial SKU image import and production media/environment decisions remain later work. Keep credentials local/server-only. Archived synthetic verification parents and audit/tombstone history remain intentionally; active test files and associations have been cleaned up.

Media-stage setup: select a separate Cloudinary development product environment with Dynamic folders; configure CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET and MEDIA_ENVIRONMENT=development privately; apply only `05_install_media_service.sql` to the development Supabase project. Real Cloudinary upload/association/delivery/cleanup verification is pending those steps. No unsigned preset or service-role Supabase key is needed. Choose explicit human review before public media publication; confidential draft images stay private. See media-service.md. No UI/import/deployment authorization is inferred.

Authenticated service verification is now complete (45 checks, 2026-10-05); the first admin and ordinary test account are configured. Earlier requests to create these accounts are historical. Local test-password entries may be removed after verification. Future login UI/session handling, real catalog imports, media upload workflow and commerce remain separately scoped work; no production operation is authorized by these checks.

Current next step: create the first confirmed Auth account and provision its private membership using first-admin-setup.md. Create an unprivileged test user separately and store test login credentials only in ignored local configuration. The earlier products/schema-cache blocker is resolved (HTTP 200); remaining checks are authenticated roles and known-object Storage isolation, not another installer run.

SQL Editor next step: apply the prepared files only to the intended development project using [sql-editor-installation.md](sql-editor-installation.md). If preflight finds existing objects or Storage policies, preserve them and review the conflict instead of deleting/resetting anything. Real admin/non-admin Auth verification requires two synthetic confirmed users and local-only test credentials; no secrets in chat. Reconcile private installation receipts with CLI migration history before any later CLI push.

User has now supplied a Git-ignored project URL/publishable-key configuration. Read-only provider reachability works, but products are absent from PostgREST's schema cache. Applying migrations requires an owner-controlled SQL execution path and confirmed non-production target; current public credentials cannot perform schema administration. No additional secrets should be supplied in chat.

Immediate service-verification dependency (2026-10-05): finish Docker Desktop engine startup on Windows, or provision a separate development Supabase project. Do not use/reset an existing database. [The runbook](supabase-integration-verification.md) lists exact commands and environment names; credentials belong in local configuration, never chat. Actual provider checks remain pending; the storefront stays unchanged.

## Database-stage follow-up, 2026-10-05

Six migrations and local SQL tests now exist; earlier statements below that migrations are absent are historical. Select an authorized Supabase test project/region or start a fresh local Docker stack, configure its URL/publishable key securely, create verified Auth administrators through owner-controlled membership provisioning, and verify Auth/PostgREST/Storage end to end. No production application is authorized by this stage. See database-setup.md.

Per-SKU physical identities, source price gaps, stock reconciliation, approved primary media/copy and category-specific label/safety/specification checks remain individual publication decisions. Photos are not needed for draft import/admin search. Secondary photos, reviews and concerns are optional enrichment; concern research is partially complete. Real variant grouping requires identity confirmation. Reservation expiry scheduling, payment/order lifecycle and provider reconciliation remain future commerce work. All prior hosting/domain/courier/shipping/email/legal decisions remain open.

## Catalog evidence and publication decisions (2026-10-05)

The import-contract stage does not need credentials or a provider decision. All 121 source records can be retained as private drafts. Each record lists its own completion requirements, so unresolved records do not hold back unrelated products later.

Review [the catalog findings](catalog-review-findings.md) and `data/catalog-dry-run/sku-mapping.json`: approve SB-001's missing selling price; retain spaced SKU identities unless an explicit alias migration is chosen; confirm every Dior shade/code and generation (030 unresolved); confirm CTP-001 formula/body-face scope, VS-001 full identity/net unit, OPI-001 contents, VAS-001 regional size/variant, AROM brand/components, cutlery specifications and proposed Hair Care placement. Brand-page research cannot identify the physical stock by itself.

Confirm pack contents and stock units before choosing factory-set versus assembled-deal treatment. Confirm family identities before grouping. Approve product copy, accurate prices, stock reconciliation, photo associations and relevant condition/expiry information individually. No concerns or production filter options are approved by the dry run. Review proposed normalized brand labels and new category navigation when supported products are published; the sample homepage remains unchanged.

## Interior layout choices awaiting design review (2026-10-05)

No separate wireframes were supplied for these pages. Provisional choices: cream backgrounds, Georgia display headings and Arial body text, bronze rules, flat image-led listing cards, a desktop filter column/mobile dialog, two-column product and checkout compositions, and one-column mobile layouts. The Edit index uses wide alternating sample-colour article rows, not a generic card theme. The existing header/footer and mobile hero are preserved.

Two products per listing page demonstrate real pagination with the four approved samples; this is a preview setting, not the final production page size. Filter choices derive only from the sample collection being displayed. Concern assignments are not asserted; incoming prototype concern links explain that mapping is pending. Brand pages without sample products and both fragrance branches intentionally show empty states.

No verified alternate sizes/shades or genuine secondary photographs were supplied. Product layouts support ordered media and variant options, but only the existing packshot/default option (Ruby for the Pixi sample) is exposed. Do not fabricate extra variants to fill the layout. Details, usage, shipping timelines/charges, reviews and policies require approved content. Shipping/payment slots are empty; review checkout never implies a payable total or order creation. Provider, domain and production publication decisions remain open.

## Mobile hero and menu update

User-authorized mobile changes supersede exact reference matching for the mobile header and hero. The original source and `/reference` remain unchanged. `mobile.css` overrides only the storefront: below 651px, the hero uses the full supplied image plus a compact live heading/CTA area instead of the fixed 680px gap; all four slides retain their order and controls. At 1050px or below, a three-line toggle opens navigation and category panels, with close, outside click, link selection and Escape handling. Desktop styling remains unchanged.

Verified in local Edge at 320, 390, 650 and 800px: hamburger open/category/back/close; all four mobile hero CTAs clear their controls; no horizontal overflow. The 390px render was visually inspected. Desktop 1440px was also checked. Earlier mobile reference screenshot equality is now historical, not a current acceptance criterion. Physical devices and Safari remain untested. No provider decision or credential blocks this change.

## Homepage footer endpoint update

At the user's request, the Design handoff notes section is now excluded from the generated homepage fixture. The homepage ends at the existing footer. The supplied HTML and development-only `/reference` retain the original notes unchanged. No backend or provider work is involved. Earlier full-page screenshot evidence predates this intentional difference; future comparisons capture `.site` through the footer.

No business decision blocks the source-preparation or application-foundation stages. Resolve the following before the relevant production stage.

## Catalog and assets

| Item | Current evidence / required resolution |
| --- | --- |
| Three name-based imports | `Balance - Hyaluronic Deep Moisturising Serum.png`, `Balance - Vitamin C Brightening Serum.png`, `Boots - Skincare set.png` remain in `product-images-import/skincare/`. Confirm actual catalog/variant associations; do not infer SKUs from similar names. |
| SKU formatting | Preserve `DANM - 001` and `MAC - 001`. Agree canonical formatting during catalog validation before enforcing business identifier uniqueness; retain provenance if normalized. |
| Missing exact import coverage | 104 SKUs have no exact filename match in the 20-file folder; list in source-audit.json. This does not assert all 104 lack any potentially relevant sample media. Use neutral placeholders until associations/photos are validated. |
| Four handoff product samples | Local visual samples only. Verify exact brand, product and variant before linking to real SKUs, prices or stock. |
| Bath & Body category | Reuses skincare artwork; same SHA-256 confirmed in manifest. Preview placeholder, not evidence of a Bath & Body product. Dedicated approved artwork remains pending. |
| Secondary product photos | No genuine secondary photos supplied in handoff galleries. Reframing one packshot is not another product angle. Obtain genuine additional images or use honest single-image behaviour/placeholders. |
| Editorial content | Three sample articles/images; not validated advice or production editorial. Keep article-specific colours and compact slideshow while using samples during visual work. Approve replacement copy before production publication. |
| Concern taxonomy | Supplied workbook assignments can be provisional name matches. Validate supporting evidence before enabling filters or publishing suitability/efficacy claims. |
| Prices, stock and required fields | Validate accuracy and completeness individually. Workbook target/minimum/market prices are source fields, not automatic authority to publish every value. No invented reviews, claims, scent notes or longevity. |
| Brand links | Twelve visual prototype logos are supplied; production options/links must reflect supported published inventory. |

## Business decisions

- Hosting provider and production domain.
- Shipping coverage, charges, rules, delivery commitments and courier provider.
- Payment methods/provider and operational order flow; no real charges or shipments without explicit instruction.
- Transactional email provider, sender identity and delivery configuration. Preserve public contact `nooktheglow@gmail.com`.
- Approved return/refund, privacy, terms and other policy text. Do not invent policy promises or shipping charges.
- Approved Instagram/Facebook and other social URLs. They remain unset; no guessed handles.
- Final launch content/media approval and production deployment authorization.

## External setup required later

- Shared staging preview: supply PREVIEW_USERNAME and a unique random PREVIEW_PASSWORD of at least 32 characters in secure server configuration, with HTTPS at the hosting boundary. Local loopback development needs neither. Do not share or commit these credentials. The reference route is available only in development.

- Supabase project and chosen region; project URL/client publishable configuration; securely provisioned server credentials; Auth redirect settings and admin role assignments. Prepare/apply schema, full-text search/`pg_trgm`, RLS and private Storage bucket policies in the authorized environment. No migrations exist yet.
- Cloudinary account/cloud and secure server API configuration; approve media publishing/access settings. Public-only content may go there; pending/confidential media stays in private Supabase Storage.
- Hosting environment/server secrets and domain/DNS configuration after provider selection.
- Courier, payment and transactional email accounts/credentials only when providers and flows are approved. Do not place secrets in committed files or browser code.

These dependencies do not prevent independent implementation, local tests or migration preparation. They prevent claims of live integration or production readiness until configured and verified.

## Tooling dependency follow-up

The current Next lint plugin has an unpatched development-only braces denial-of-service advisory (GHSA-vfj7-8cjw-p6xm). Runtime dependency audit is clean. Recheck upstream before expanding CI/deployment tooling; no forced downgrade or unreviewed override has been applied. Details are in versions-and-scripts.md.

## Reference behavior retained in the visual stage

- The approved CSS hides the category navigation at viewport widths of 1050px or below; it supplies no alternate mobile category menu. The React page preserves this rule. Any change needs a later design decision. Category cards and the Discover search reveal still provide category access.
- Visible design handoff notes below the footer are retained because this request asks to reproduce the entire approved reference page. They are preview content, not customer policy or production instructions. Remove them during a separately authorized production-content stage.
- Sample gallery frames reuse the same supplied packshot. No new product angles or claims were fabricated. Sample prices and category/scent/concern options remain fixtures, pending validated published inventory.
- Social URLs and policy pages remain preview dialogs; official URLs, policies, shipping charges and provider choices are still unset.

## Product administration decisions (2026-10-06)

- All imported stock remains source provenance until an administrator explicitly reconciles it with a reason. The existing stock RPC requires a nonzero adjustment; an audited zero-count reconciliation operation remains a follow-up schema decision.
- Seventeen exact SKU photos are eligible for private staging, not automatic approval. Confirm the three unmatched package identities before manual assignment. Missing genuine secondary photos and reused Bath & Body art remain unchanged launch decisions.
- Review each product independently before a later publication workflow. Optional concerns remain optional; their research is partially complete. No product was automatically published.
- Admin session expiry deliberately requires fresh login (no browser refresh-token persistence). Production HTTPS/proxy and shared rate-limiting settings belong to deployment setup; current development verification does not certify a production host.
- Blog/review/order/deal administration and storefront database integration are outside this stage.


## Product admin verification completion (2026-10-06)

Actual results: `admin-live-verification.json` (49 passed events, including retries), `admin-extended-verification.json` (14 passed checks), and `admin-import-audit.json` (ten passed checks). All 121 original SKUs are individually searchable as drafts with preserved raw fields/prices and zero unreconciled live stock. Seventeen exact-match photos are private and unapproved; three unmatched files remain unassigned. Browser Auth/permissions, editing, stock, typed evidence, CSRF and real media publishing/cleanup passed. Ten local security/media tests passed separately; mock transport checks are not claimed as provider verification. Types, lint, build and source preservation passed. No additional migration is pending.

One rejected synthetic image has zero associations but leaves an unlinked Cloudinary asset and private original until the established cleanup guard expires at **2026-10-06T23:53:51.291Z**. Its product is archived; the valid test image was already cleaned up. See `admin-cleanup-verification.json`. After eligibility run:

```powershell
& '.tools/node-v24.21.0-win-x64/node.exe' --conditions=react-server scripts/reconcile-admin-test-media.mjs
```

This verifies the recorded synthetic identity and uses the existing safe cleanup service. It does not touch initial catalog photos. No guard was bypassed; synthetic audit history remains retained.


## Daily editor revision setup (current, 2026-10-06)

Apply `supabase/sql-editor/06_install_daily_product_editor.sql` once to the existing development project and confirm its two postflight booleans. This is a required database setup action, not a new business decision. Existing publishable credentials cannot apply schema SQL; no password/key is requested in chat. Installation preserves existing business rows. Do not rerun the earlier installer or reset any database. See `daily-editor-installation.md` for exact steps.

Live browser single/two-option editing, counted stock and publication checks remain pending that update. Genuine unresolved package identities, set contents, shade/code conflicts and sunscreen labels still require the actual package details for the affected products. Ordinary product fields do not require new research findings. Optional concern assignments are not a publication gate, and concern research is partially complete.

Production domain/hosting, shipping/payment providers and charges, policies, approved editorial content, genuine secondary photos, social URLs and prior launch decisions remain unchanged. Source stock must still be deliberately counted; no imported quantity is treated as live stock. No real catalog products were published by this revision.


## Corrected ordinary-save visibility (2026-10-06, supersedes earlier draft-on-save behavior)

Ordinary **Save** now preserves the existing product visibility and each existing active variant status. Hidden products remain hidden. New options start as drafts; an ordinary save does not publish them. **Save draft** is an explicit transition (with confirmation when the product is published or hidden); **Publish** explicitly publishes eligible active options; **Hide** explicitly hides the product. Removed options remain archived and are not restored by Publish.

A published edit that would lose required information is rejected with an actionable checklist: fix the fields or explicitly choose Save draft. The transaction leaves the original published product, prices, variant statuses, stock, counts and revision unchanged. The UI retains entered values after rejection. There is no implicit unpublish/unhide. Plain Save is also the default for Enter-key form submission.

The corrected migration 008 and regenerated SQL Editor file 06 use a text `p_intent` parameter, defaulting to `save`, rather than a boolean that drafts everything. The report identifies this contract as daily editor version 2. The file still preserves existing business records during installation. Apply only the current corrected file; the previous copy must not be used.

Local verification: the exact SQL Editor bundle passed in a fresh disposable PostgreSQL 16 database. Ten daily-editor groups cover incomplete drafts, zero/retry/stock safeguards, two options, rollback/removal, published and hidden preservation, mixed option statuses, rejected invalid edits and explicit transitions. Auth and Storage there are doubles. ESLint, TypeScript and production build passed. The original storefront/source assets remain unchanged.

Live verification remains pending application of the corrected file. The Chrome runner now includes ordinary and invalid published edits, hidden edits and explicit transitions for both single-product and two-option fixtures. It uses synthetic brands/categories and a neutral synthetic media fixture, leaving the 121 catalog records and their taxonomy/source values intact. It archives synthetic history and uses guarded media cleanup. These prepared live tests have not yet passed; no production integration or real catalog publication is claimed.


## Installer syntax repair and exact-file verification (2026-10-06)

The reported Supabase 42601 near `create function public.save_daily_product` was inspected at the preceding function boundary. The local source already had a closing delimiter, so the exact user-submitted failure was not reproduced from those bytes. All installer/function endings are now explicit `END;` followed by distinct named dollar delimiters, including `$publication_report$;`. The source migration and generator agree, and the complete file is regenerated with its migration receipt. No storefront or catalog edits were made.

Verification now uses `scripts/test_database.py --daily-editor-installer`: a NEW disposable PostgreSQL 16 cluster, migrations 001–007 applied directly (no earlier installers), SQL Editor receipt infrastructure, 121 seeded drafts, then the EXACT file `supabase/sql-editor/06_install_daily_product_editor.sql` via `psql -X -v ON_ERROR_STOP=1 -f`. The migration 008 source is not substituted for file 06. SHA-256 for the tested file is `151cc79788b0c00bbc308ed7ee22e7e8a8c084a9caa8628ccf125e5028b9d16e`.

The entire installer passed; both final booleans were true. Every pre-existing public business table and private admin-membership snapshot stayed identical. A deliberately missing preceding terminator rolled back new objects and replaced functions without altering business data. A repeated installer was refused safely. Read-only preflight showed only the media service present before installation and the expected daily objects present afterward. Catalog/security/media SQL and ten daily-editor regression groups passed, including ordinary published/hidden status preservation. Auth/Storage in the local cluster are doubles; this is not hosted Supabase SQL verification. Evidence: `daily-editor-exact-installer-verification.json` and its recorded local output directory.

Connected development read-only checks passed actual admin Auth/membership and products access. `inventory_counts` returned PGRST205, save RPC discovery returned PGRST202, and the accessible publication report had no daily-editor version. This suggests the old API schema remains, but does NOT prove private objects or receipts are absent (schema cache can also lag). No SQL connection is configured. Run `supabase/sql-editor/06_preflight_daily_product_editor.sql` in a new SQL Editor query and share its nine booleans BEFORE another install attempt. Only media_service_present should be true; every daily-editor boolean should be false. If any daily-editor object/receipt is present, stop without dropping data or rerunning earlier installers. The corrected installer has its own guard rejecting known installed/partial state.

Pending: definitive connected-project SQL preflight, then conditional application of the corrected complete file 06, followed by the already authorized live single/two-option and published/hidden save tests. No production import, reset or earlier-installer rerun occurred in the connected project.


## Fresh complete installer and confirmed preflight (current, 2026-10-06)

The user's development SQL Editor preflight confirms the media service exists and ALL eight daily-editor object/receipt checks are false. The previous pending private-schema check is resolved: migration 008 did not remain installed. Recorded in `daily-editor-preflight-confirmation.json`. No connected data was changed or earlier installer rerun.

Regenerated both complete installer artifacts from one migration source using overwrite, never append. Use the distinct `supabase/sql-editor/06_install_daily_product_editor_clean.sql` in a NEW empty SQL Editor query to avoid mixing prior text. It and the canonical file contain identical bytes. Structural validation records four unique function declarations, five ordered matched dollar-quote pairs, one receipt insert, one final SELECT, one BEGIN/COMMIT and one cache reload. Generation refuses duplicates/mismatches; see `daily-editor-installer-structure.json`.

Executed that EXACT clean file via `psql -f` in a NEW disposable PostgreSQL 16 database with only migrations 001–007 applied directly, no earlier installers, and 121 seeded drafts. Installation, final booleans, all pre-existing business-table snapshots, rollback simulation, repeated-install refusal, preflight states and catalog/security/media/ten daily-editor regression groups passed. The cluster was stopped. SHA-256: `ff2d5f584b5572a3c08b82e20251e842f38ca68715a72c335297063ba566ee11`. Evidence: `daily-editor-exact-installer-verification.json`, local run `database-test-df18db4e913f`. Local Auth/Storage are doubles; this is not a claim of hosted Supabase installation or live write verification.

Passed also: generator ESLint and 64-source-file / 14-reference-CSS integrity. Ordinary Save still preserves product/variant visibility, including hidden state; explicit Draft/Publish/Hide and invalid-edit rollback behavior are retained. The storefront and connected catalog remain intact. Pending only: apply the complete clean installer once to development (both final checks true), then run the authorized live single-product/two-option and published/hidden preservation tests. Do not append patches or rerun prior installers.

## Daily editor: completed live development verification (2026-10-06)

This supersedes the earlier pending installation/browser-test entries. The user applied the clean installer and reported both final SQL checks true. No installer was rerun. The actual connected development project exposed daily editor version 2 and accepted the authorized browser operations.

Actual Chrome + Next.js server + Supabase Auth/PostgREST/Storage + Cloudinary verification passed 32 checks. Single-product and two-option creation/editing, PKR minor-unit prices, stock counts, explicit publication, ordinary published/hidden status preservation, rejected invalid published edits with unchanged revision/variant prices/status, explicit Draft transitions and option removal preserving SKU/history all passed. Anonymous and non-admin rejection, CSRF rejection, uncached private responses, admin login/logout and all 121 original SKU searches passed. Synthetic neutral images followed private upload, explicit approval and Cloudinary association; both were detached and safely cleaned. No real product was published or imported.

A supplemental actual browser test passed three checks: a hidden synthetic product counted from five to zero stayed hidden, exactly one audited 5-to-0 reconciliation was created, and saving unchanged zero created no additional count. Evidence: admin-usability-live-verification.json and admin-zero-stock-live-verification.json. These are actual provider/browser results, separate from earlier disposable PostgreSQL tests with Auth/Storage doubles.

Initial attempts exposed accessible-label instability for selects and a populated description textarea. Explicit admin field labels were added; controls now wait for initial reference/catalog loading. Failed synthetic attempts were hidden and their temporary taxonomy archived. Their audit history remains. The successful run verified unchanged hashes for all 821 pre-existing rows across 18 catalog/source/stock/media tables, including existing fixtures, before its synthetic-only supplemental stock change. Original catalog records and image associations were preserved; both successful fixtures and their taxonomy are hidden/archived and their test images cleaned.

Verification also passed ESLint, TypeScript and original-source integrity (64 supplied files and 14 reference CSS blocks). Existing homepage Chrome regressions passed six tests with two intentional viewport-specific skips, covering desktop reference geometry/carousel states and mobile hero/menu/interactions. Mobile admin screenshots were inspected and no document overflow occurred. Storefront code/design, source assets and migration files were unchanged during this verification.

Limitations: browser checks used installed Chrome with mobile emulation, not physical-device Safari. This run did not repeat a production build, deploy, import the catalog or test real customer commerce. No requested live editor check remains pending. Future production setup and other business/provider decisions remain outside this completed stage.

## Public catalog integration setup and launch decisions (2026-10-07)

- Apply the complete `supabase/sql-editor/07_install_public_storefront.sql` ONCE in a NEW empty query in the connected development project already containing migration 008. Final `storefront_present` and `aliases_rls` must both be true. The exact tested SHA-256 is `352286668d0b1a4eb012faf57da27de8f4276fe1e93323de9b6ec0c289812c3c`. No earlier installer, production project or database reset is required. If installed but undiscoverable, check the public API schema/grants and reload the PostgREST schema cache. Current RPC probe returns 404; no synthetic catalog fixtures were created.
- Actual hosted catalog visibility, search/filter/variant/media delivery and admin-edit freshness verification awaits that RPC. Existing local environment names suffice: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, existing test-admin settings and server-only Cloudinary configuration; no secrets should be shared in chat. See `storefront-setup.md`.
- Real products remain owner-controlled drafts until individually eligible and explicitly published. Optional concern enrichment does not block basic publication; concern research remains partially complete and only defensible approved assignments enter public search/filters.
- Hero/category/concern artwork remains approved provisional visual artwork. Bath & Body reuse, missing genuine secondary photos and unset social URLs remain earlier launch decisions. Public product galleries use approved associated photos only; no fabricated alternate angles.
- Live The Edit keeps the approved card-free slideshow layout with neutral pending-content placeholders. Actual articles, blogs and reviews are a later stage. No sample articles silently become live posts.
- Hosting/domain, shipping rules, courier, transactional email and payment decisions remain unset; no stock promises, shipping charges or payment methods were invented. Production publishing remains disabled in this implementation stage.

### Updated migration 009 application artifact (2026-10-07)

Use the RLS-hardened complete installer 07 with SHA-256 `aca261aa38d25b713a866c23f0dcb1fb3b531cc114644b9ad7aa44728845cce0`, superseding the earlier hash. In a NEW empty development SQL Editor query, run it once only if migration 009 has not been installed. Expect all THREE final checks true: `storefront_present`, `aliases_rls`, `search_rls`. The source receipt hash is `f7d321de75bb11b75d6540eef0a5de4d69ddf6f44c6d0f9e4c45dce8594a6588`. No private search client policies/grants are required or allowed. Do not rerun prior installers or an already installed complete file. Hosted integration remains pending; this revision changed no connected data or storefront design.

### Required hosted-state confirmation before clean installer (2026-10-07)

The latest read-only hosted probe confirms admin membership but cannot read the private receipt through PostgREST (PGRST106); missing public RPC/table responses do not establish rollback. Run `supabase/sql-editor/07_preflight_public_storefront.sql` alone in a NEW development SQL Editor query and share the result row, with no secrets. If ANY storefront object/function/trigger or receipt exists, stop and inspect; do not install, drop objects or rerun earlier installers. Only after definitive absence is confirmed may the complete `07_install_public_storefront_clean.sql` be installed once in another empty query. Its tested hash is `99e5b4c5340b24f7465c3fc34dce1d01f893c7636718e4ca2e958e65d2d74f4a`, superseding earlier installer hashes. Canonical and clean files are byte-identical. All three final checks must be true. Hosted state remains pending; no connected records were changed.

### Hosted installation and integration gates resolved (2026-10-07)

The user confirmed the SINGLE read-only installed-state query passed receipt/version/canonical hash, expected objects, RLS/owner/grants. Installer 07 must NOT be rerun. Both public RPCs now return 200; twenty-one actual synthetic development integration checks passed with safe cleanup and all 881 baseline rows preserved. These results supersede prior missing-RPC/receipt-confirmation blockers. Local development server outbound network access was enabled for provider reads; no schema or storefront change was needed.

The real catalog remains owner-controlled and was not automatically published. Production hosting/domain, shipping/payment/courier/email, final genuine product photographs, partially completed concern research, approved editorial content and social/policy URLs remain their existing launch decisions. Browser coverage is Chrome desktop/mobile emulation; physical Safari and large-scale load testing remain unperformed, not failed checks. No further installer application is required for this completed development verification.
### Content CMS development gate (2026-10-07)

Run only new read-only 08_preflight_content_cms.sql first. If prerequisite009 is true and all content-presence flags false, run the ENTIRE 08_install_content_cms_clean.sql once in a NEW empty development query. Any existing/partial content state requires inspection rather than rerun. Expect content_present, homepage_media_rls and receipt_matches all true. Do NOT rerun earlier installers. Installer hash ff891628343b3429a0fc9c9f82b55beb8fba2c5b280d2af3b43aeec8d277dae7. Details and existing environment names: content-setup.md. No secrets should be provided in chat.

New hosted CMS RPC currently404; actual article/homepage media and browser/freshness/cleanup verification awaits010. The owner must approve real editorial text, authors, tags, optional SEO and images; synthetic/mock content is isolated. Theme choices reuse existing sage/warm/blush designs. Long titles/summaries may require editorial adjustment to fit the fixed narrow slide. Article/index layouts reuse existing storefront styles and are not separately approved wireframes.

Production domain remains unset; no fabricated canonical URLs. Existing social/policy/photo/hosting/shipping/courier/payment/email decisions persist. Chrome mobile emulation is available; physical Safari/device checks remain unperformed. Four development-only npm findings affect the existing ESLint glob dependency chain; npm's incompatible downgrade was not applied. Production dependency advisories were not reported.

## Current external setup: reviews and incremental product fields (2026-10-08)

Confirm review migration 011 installation/receipt with its read-only preflight; current public endpoint is HTTP 404, which may also be a schema-cache/exposure issue. Configure SUPABASE_SECRET_KEY and REVIEW_SESSION_SECRET locally, never in chat. Then review/apply only new 012 using 10_preflight_product_markdown.sql and 10_install_product_markdown_clean.sql; do not rerun applied installers. Hosted synthetic review/provider and final product-save checks remain pending these prerequisites. No decisions about production publication, delivery/payment providers or approved assets were changed. Detailed steps and hashes: product-content-admin-update.md.


### Reviews/product-content development prerequisites resolved (2026-10-08)

The owner confirmed migrations 011/012 receipts/preflight flags. Both required server secrets are present locally; values were neither displayed nor requested. Next was restarted and the actual review RPC returned 200. The requested hosted review/image/moderation/Markdown/status/stock checks passed with safe synthetic cleanup and unchanged business records. This supersedes the earlier missing-key/migration/RPC blockers; do not rerun their installers. No further setup is needed for these completed development checks.

Physical iOS Safari and production load/ingress verification remain outside this run. Hosting/domain, trusted production client-address ingress, approved real reviews/content/photos, social/policy URLs and shipping/payment/courier/email decisions remain owner-controlled. No automatic real publication/approval or next stage was performed. Detailed actual-versus-local evidence: reviews-product-content-hosted-results.md.


## Current admin-list development gate (2026-10-09)

Only new migration 013 needs installed-state confirmation/application. Run 11_preflight_admin_catalog_list.sql read-only first; if prerequisite012 is true and all new presence/receipt flags false, run complete tested 11_install_admin_catalog_list_clean.sql once in a new development SQL Editor query. Existing/partial objects require inspection, not rerun. All final flags should be true. Share result flags only; no secrets or earlier installers are required. API404 alone does not prove absence. The actual admin Auth login works, but the new RPC is unavailable; synthetic hosted search/filter/stock/reminder verification remains pending this gate. Local/disposable/browser-double verification passed independently.

Business provider/publication/approved-asset decisions are unchanged. Ignoring reminders never bypasses publication. Physical Safari is untested. No next commerce stage begins. See admin-product-list.md for exact files, preservation and verification boundaries.

Final actual browser access evidence: four checks passed (anonymous list denial, non-admin login denial, admin Auth login, CSRF-less dismissal denial). New list RPC still unavailable; the guarded runner stopped before fixtures, with zero hosted catalog mutations. Actual synthetic search/filter/stock/reminder/pagination verification remains pending migration 013; do not interpret local SQL or Chrome provider doubles as hosted results. Production boundary checks passed. Evidence: admin-list-live-verification.json and admin-list-verification.json.


## Use the corrected 013 artifact (2026-10-11)

Replace any previously copied 013 installer with the complete regenerated 11_install_admin_catalog_list_clean.sql. First run 11_preflight_admin_catalog_list.sql read-only in the development SQL Editor. prerequisite_012 must be true; all *_present flags and both receipt flags must be false; private_rls is null, no_client_policies true, refresh_triggers_installed false before installation. If any new object/receipt/refresh trigger is already present, stop and inspect rather than rerun or drop anything. After applying the complete corrected installer once in a new query, all 19 final flags must be true. Do not rerun earlier installers. No secrets needed in chat.

Hosted application and subsequent hosted synthetic search/filter/reminder checks remain owner-dependent. This turn intentionally performed no hosted SQL or network verification. The supplied exact file was verified in a disposable database, preserving seeded business rows; Supabase Auth/Storage and Cloudinary metadata were local doubles. No business/provider/commerce decision was changed.


## Admin-list hosted gate resolved; precision refinement remains (2026-10-11)

Migration 013 installation is owner-confirmed and actual hosted/browser verification is complete. No extra setup or secrets are needed for the tested flows. Do not rerun 013 or earlier installers.

A measured exact-identifier precision issue remains: long SKU aliases can return a close sibling SKU through trigram matching. A subsequent admin-search correction should prioritize exact original SKU/alias matches ahead of fuzzy alternatives. Do not silently edit the applied migration; prepare an incremental correction if requested. No hosted SQL was applied in this verification stage.

All synthetic fixtures are archived, both test images are deleted and no anonymous-visible test product remains. Private audit/import/inventory histories are retained. Physical Safari and production load remain untested. Business/provider decisions are unchanged; commerce has not started. See admin-list-hosted-results.md for actual checks and preservation.


## Apply incremental exact-search 014 once (2026-10-12)

Run read-only 12_preflight_admin_exact_search.sql, then the tested complete 12_install_admin_exact_search_clean.sql in DEVELOPMENT SQL Editor only. Before: six prerequisite/security flags true, three 014 flags false; afterwards all nine true. Inspect already/partly-installed state rather than rerun. Applied 013 and earlier installers must not be rerun. No direct database connection is configured locally; no credentials requested in chat. Hosted fixed exact-isolation tests await this application; live reproduction/authorization/general search and cleanup passed. Steps/hashes: admin-exact-search-results.md. No new business decision or commerce stage.


## Exact search installation and live gate resolved (2026-10-13)

Owner confirmed 014 installation and all nine final flags. Do not rerun 014 or earlier installers. Actual Next/Chrome/Supabase exact identifier, filter/no-fallback and typo-search checks passed; no further setup or credentials are needed for this gate. Earlier application/pending-hosted instructions are historical. All synthetic fixtures are archived and private; homepage/business records and sources remain unchanged. Other browser engines, physical mobile devices and production load remain outside tested coverage. Commerce has not started. See admin-exact-search-hosted-results.md.


## Commerce application pause and business configuration (2026-10-13)

Owner confirms 015 is not installed and requests corrected payment/dispatch/allocation safeguards before application. Exact regenerated installer and preflight are tested; wait for owner application. Before: prerequisite_014/no_client_policies true and other nine false; after: all eleven true, including transitions_and_safeguards_present. Do not rerun 001-014 or run hosted SQL. Actual guest/order/inventory tests remain pending.

Real checkout stays unavailable until explicit approved delivery cities/rules/fees, tax treatment and payment availability are supplied, along with secure ingress/server sessions and eventual hosting/scheduling. Current approved-mode implementation can support owner-selected COD; unpaid development holds cannot be confirmed/dispatched and no fake paid state or remittance is generated. Executable maintenance exists but no scheduler is deployed. No email/courier/tracking/payment-provider promises made. Test configuration is process-only and clearly labelled, not production policy. See commerce-setup.md and commerce-verification.md.

## Manual payment decisions (2026-10-15)

Resolved: advance-only manual Bank Transfer, Easypaisa and JazzCash; no COD or gateway/API. Only explicit administrator confirmation against actual receiving-account history records receipt. Proofs are permanently private to secure guest access and admins, with no Cloudinary publication.

Pending: owner receiving account titles/numbers/IBAN/wallet details and instructions; stable bank/account naming; payment window and bounded review extension; approved shipping/cities/tax treatment; eventual hosting and independent maintenance schedule; financial-proof retention/orphan housekeeping policy; handling/refunding under/over/late receipts with unavailable stock. No amounts, account details, refunds or production promises were invented. Cross-device guest recovery and equivalent account-number/IBAN alias reconciliation are not implemented. Hosted lifecycle verification waits for owner application of incremental 016 and its receipt checks; earlier installers must not be rerun. See manual-payments-setup.md.

## Hosted verification dependency resolved (2026-10-15)

016 is installed and actual manual-commerce verification is complete; no further installer application is requested. Real checkout remains disabled. Still required before real checkout: approved receiving account titles/numbers/IBAN/wallet details and instructions; consistent bank/account identifiers; payment/review deadlines; shipping/cities and tax treatment; hosting/trusted ingress; an independently scheduled server-only commerce:maintenance job (tested once, not scheduled); private proof retention/orphan housekeeping and human resolution/refund policies for under/over/late payments. Tests used synthetic entries and no real money or bank APIs. Physical devices/other browsers/production load remain untested. See manual-payments-hosted-results.md.


## Deals rollout dependencies (2026-10-17)

Apply only the new incremental 017 after its read-only preflight; confirm all fifteen final flags, then complete actual hosted synthetic deal/media/mixed-cart/payment/race verification. The connected project currently returns PGRST202 for storefront_deals; existing commerce remains reachable. No hosted SQL was run.

Stock return choice is explicit and documented: cancelled/expired transferred units return to the same unchanged open deal generation; changed/hidden/ended deals release them to general availability. Saving a deal replaces its unused set-aside target; accepted orders retain their own stock. No business policy or discount amount is invented. Owners choose deal titles/components/prices/approved imagery/dates/manual homepage positions.

The independent every-minute maintenance scheduler still needs a hosting decision; 017 adds unused-deal-allocation expiry to the existing runner. All prior production receiving-account, shipping/tax, deadline, ingress and human payment-resolution/retention decisions still apply. Real checkout stays disabled; reports/refunds/courier/deployment are outside this stage.


## Deals dependency update (2026-10-18)

017 and security-only 018 are installed, confirmed by owner; do not rerun them. A newly observed stale policy-helper OID blocks hosted media reads. Owner must apply only incremental 019 after its read-only preflight (17_preflight_media_policy_dispatch.sql / 17_install_media_policy_dispatch_clean.sql); configured API credentials cannot execute DDL, and no direct SQL connection is configured. This is an implementation correction, not a business-policy choice or new feature stage. Exact-file disposable testing passed; hosted lifecycle verification remains pending. No secrets are requested. Normal checkout remains disabled, and existing approved shipping/payment/deadline/hosting/expiry-scheduler decisions remain required. See deals-hosted-results.md.


## Deal hosted dependencies resolved (2026-10-18)

017 and security corrections 018/019 are installed and actual hosted synthetic deal verification is complete. Do not rerun their installers; no additional migration is requested. Normal checkout remains disabled. Remaining owner/hosting decisions: receiving accounts/instructions and stable payment-account identifiers; shipping/cities/fees/tax treatment; payment/review deadlines; retention and human resolution/refund policy; hosting/trusted ingress and external every-minute commerce:maintenance scheduling. No account details, real transfers or shipping promises were invented. No next feature stage started. See deals-hosted-results.md for passed live results and physical-device/other-engine/load limits.


## Reporting/refunds stage paused by user (2026-10-18)

Work is saved but unfinished; no hosted 020 SQL or financial fixtures were run. The generated installer is deliberately blocked as an unverified draft and must not be applied. Final tests/installer regeneration and hosted verification remain pending. Do not rerun 001–019. Resume from docs/reports-resume-checkpoint.md; it records exact files, passed/failed/pending checks and next actions. Real checkout remains disabled; prior hosted deals results are unchanged.


## Reporting/refunds implementation prepared (2026-10-20)

Supersedes the paused/unverified 020 notes. Reports, private completed-sale/receipt/refund/return ledgers, exact component entitlements, explicit manual Sent confirmation, independent inspected stock returns, audited reversals and balance/stock resolution are implemented. Business/test reporting scopes are explicit. New wrapper guards preserve ordinary order idempotency and existing history. No real money movement or hosted financial writes occurred.

The exact complete 020 installer passed fresh 001–019 ON_ERROR_STOP=1 with all 15 flags, unchanged seeded rows, repeat refusal, 60 SQL assertions and independent approval/duplicate-transfer races. Five CSV/PKR tests and desktop/mobile mocked UI passed separately; these are not hosted finance verification. Build/TypeScript and production preview/reference security checks passed. Actual hosted read-only Auth/CSRF/privacy checks pass; reporting RPC returns PGRST202, so owner application and full synthetic hosted verification remain pending. See reports-setup.md for exact installer/hash, flags, definitions, limits and commands. Do not rerun 001–019. Normal checkout remains disabled; no next stage.


## Partial-value refund follow-up prepared (021, 2026-10-20)

Frozen 020 is unchanged. Separate 021 extends the same private workflow for cancelled partial payments and optional per-item/component monetary amounts, including value-only refunds with quantity zero. Cash, item value and quantity entitlements remain independently bounded; no shipping/overpayment classification is fabricated. The editor advertises these inputs only with the installed contract. Exact fresh 001–019 + exact 020 + exact 021 testing preserved all existing financial rows/function OIDs/grants and passed original races plus 11 extra assertions; seven 021 flags true, repeat refused. Desktop/mobile mocked UI covers partial values. Both installed receipts and actual hosted financial verification remain pending. Do not rerun 020 or earlier installers if already installed. See reports-setup.md for exact files/hashes and expected preflight flags.


## Final local reporting-stage checks (2026-10-20)

020 and 021 are exact-file tested and ready; hosted installation/financial verification remain pending, not completed. Current evidence: 60 original SQL assertions plus independent approval/send races, 11 partial-value assertions, 14 intercepted Chrome UI checks, five precise-money/CSV tests, lint/type/final build and production security pass. Eight homepage/scaffold browser checks pass with two intended skips; 21/23 desktop screenshot pairs are identical, while the existing search-link pixel threshold remains flagged and a small full-page difference is reported honestly. All 64 original inputs/14 reference CSS blocks intact. Seven real hosted read-only Auth/API checks pass; new RPC was PGRST202 before owner installation. No hosted financial writes or actual money, no source storefront changes, no next stage. Full setup/hashes/definitions: reports-setup.md; passed-versus-pending evidence: reports-verification.md/json.


## Hosted financial verification completed (2026-10-20)

Supersedes earlier pending-installation/hosted-verification notes. Owner confirmed 020/021 receipts and all 15/seven flags; no installer or hosted SQL was run. Actual Chrome, Next.js, hosted Supabase/Auth/PostgREST, private Storage and Cloudinary checks passed: 91 main, 22 supplemental and 44 independent cleanup/read-back checks. No intercepted provider responses were used in these runs.

Six synthetic orders covered exactly-once completion, separate receipts/shipping/cash, mixed-cart frozen deal attribution, full/partial-value/item/shipping/overpayment refunds, cancelled/uncompleted cash-only refunds, competing approvals and duplicate-reference sends, retry/stale-edit protection, explicit outgoing-history confirmation, independent inspected resale/damaged returns, partial deal components and dispatched limits. Real browser request/approve/send/return controls and desktop/mobile Reports layouts passed. Historical order/report values remained unchanged after synthetic catalog/deal price edits; hidden visibility was preserved. Actual CSV totals/privacy, Pakistan-day filtering and previous-day exclusion passed. Anonymous/non-admin financial RPCs and all seven private financial tables were inaccessible; private financial responses remained no-store.

Cleanup: two products and three deals hidden, options archived, five approved test media/private originals deleted; all six order/financial histories and audit events retained. No active fixture reservations, idle deal pools or approved/requested financial holds remain. Global reconciliation: zero balance mismatches, overdue holds and ended allocations. All 1525 pre-existing rows across 40 tables, homepage selections and pre-existing business/development financial events were preserved. All 64 handoff/import files and 14 reference CSS blocks remain byte-identical. Normal checkout stays disabled; no real funds moved, storefront design changes, courier integration or next stage.

Verification limits: exact 18:59:59/19:00:00 UTC Pakistan-midnight fixtures and hostile formula-like CSV names were tested in disposable PostgreSQL/unit tests, not newly fabricated/backdated hosted financial history. Actual hosted day windows and CSV totals/privacy passed. Bank/wallet outgoing-history acknowledgements were synthetic; no account statements or real transfers were verified. Chrome desktop/mobile emulation is not physical-device, other-engine or production-load evidence. Prior storefront comparison remains 21/23 pixel-identical with the documented existing search-link/full-page differences; no new fidelity claim follows from these financial tests.

Evidence: reports-hosted-live-verification.json, reports-hosted-supplement.json, reports-hosted-cleanup-readonly.json; screenshots under .local/reports-hosted. Local SQL, intercepted UI and unit evidence remains separately labelled in reports-verification.md/json. Receiving-account/shipping/tax/deadline approval, trusted ingress and an independent commerce-maintenance scheduler remain launch setup decisions.


## Category filters and navigation responsiveness — 2026-11-23

Implemented a scoped filter sidebar and mobile modal drawer: expandable groups, compact native checkboxes, inventory counts, selected-count indicator, sort/reset/apply controls, rounded chips, keyboard focus return and reduced-motion support. Fixed the broad input rule that styled checkboxes as full-width inputs. Existing filter URL/query and eligibility semantics remain intact.

Storefront markup internal anchors now use Next Link; filter/search forms use Next Form client navigation. Category metadata avoids an unnecessary unfiltered query on filtered pages and reuses identical query arguments on unfiltered pages. Only anonymous shared navigation uses a 60-second tagged server cache, expired immediately by existing authorized public invalidation. Product prices, visibility, inventory, checkout and private reads remain uncached. No backend, schema, packages or production data changed.

Read-only deployed baseline (nookandglow-three.vercel.app): category headers 1010–2040ms, complete HTML 1375–2705ms; product headers 1031–1039ms, complete HTML 1290–1782ms from this client connection. Network/cold-start/database contributions are not separately instrumented; Vercel bom1 response-edge identifier does not establish function/database co-location. Recommend checking Vercel function region against Supabase region, then measuring after deployment. No claimed deployed speedup: changes are local and not deployed.

Verification: TypeScript and lint passed; 14 actual Chrome/Next checks with synthetic RPC/image responses passed, including no document reload on filter submission, URL chips, pagination, variants, missing/error handling, compact mobile checkboxes, focus restoration and no overflow/runtime errors. Desktop/mobile screenshots visually inspected. See storefront-mock-ui-verification.json and storefront-response-baseline.json. Provider data was not mutated. Existing homepage structure/assets preserved.


## Optional boxed-set contents — 2026-11-23

Owner requested removing boxed-set confirmation as a publication requirement for AXI-004 and future products. A read-only hosted admin check confirmed AXI-004 (The Mini Glow Set) is draft, sellable_kind=unconfirmed_set, with set_contents_missing as its only essential blocker and no specific issues. No hosted product or publication state was changed.

Incremental 023 removes boxed contents gates from publication_blockers, variant public eligibility and admin reminder generation, plus the boxed-pack-only import confirmation flag. Other identity/scope/claim issues, required price/category/description/stock and approved-media safeguards remain. Original classifications, factory contents, exact SKUs, content, stock, orders and audit history are retained. Existing derived boxed reminders become inactive; dismissals/history are retained. No automatic publication or product reclassification.

The exact complete SQL Editor file 20_install_optional_boxed_sets_clean.sql passed psql -X -v ON_ERROR_STOP=1 -f against a fresh disposable PostgreSQL database with all 23 existing migration files (001–022 plus the additional SEO migration). All seven final flags true; business-row snapshots and function OIDs/owners/ACLs/settings preserved. Local fixtures demonstrated daily Publish for unconfirmed_set, public eligibility for factory_set without contents, removed reminders and repeat-install refusal. Supabase Auth/Storage were local test doubles, not hosted verification. Evidence: boxed-set-local-verification.json and boxed-set-installer-manifest.json.

Pending owner SQL Editor application: run 20_preflight_optional_boxed_sets.sql read-only, then only the complete 20_install_optional_boxed_sets_clean.sql once using ordinary Run. Before: prerequisites_present/admin_write_grants_preserved true and five correction/receipt flags false. After: all seven true. Do not rerun older installers. Refresh AXI-004 and choose Publish explicitly afterward. Existing HTTP configuration cannot apply DDL; no passwords/keys requested in chat. No Git push/deployment performed for this follow-up.


## Collapsible product information — 2026-11-25

Replaced long product-copy panels with shared native details/summary disclosures for Product description (initially open), How to use, Key benefits and Delivery information (initially closed). Each row toggles independently, including keyboard interaction before JavaScript hydration. Optional empty/whitespace-only copy is omitted. Published and explicit sample product pages use the same component; no product copy is rewritten. Existing Markdown sanitation, product metadata, reviews, pricing, inventory and admin data remain unchanged. Styling uses cream/ink/bronze, fine dividers, compact uppercase labels and inline SVG chevrons; responsive spacing and reduced-motion rules are scoped to product disclosures.

Verification: production build, lint and TypeScript passed; 19 Chrome/Next browser checks with explicit synthetic catalog/image responses passed, including expanded/collapsed defaults, keyboard How to use, independent benefit expansion, mobile collapse/no overflow and missing optional sections. Desktop/mobile screenshots visually inspected under .local/storefront-verification/product-disclosures-*.png. These are browser UI checks, not new hosted provider verification. No database mutation, auto-publication or deployment.

Owner separately confirmed 023 installation: all seven flags true. Do not rerun its installer. The product-disclosure change requires no migration.


## Similar products — 2026-11-25

Product pages now stream an optional Similar products section between product details and reviews using existing catalog cards, approved images, brand, actual PKR price and product links. Desktop has four columns; mobile has two. One bounded anonymous existing storefront_catalog query fetches at most 24 same-category/scope candidates; ranking prefers actual matching type, brand and price proximity, takes up to four, excludes the current product/duplicates, and shows only variants with available stock and media. The shown variant and minimum price come from those eligible available options. Home Fragrance and personal fragrance never cross scopes. No inferred concerns, personalised claims, fabricated sales ranks, sample fallback or new provider.

The server component is inside Suspense and does not gate the main product rendering on its extra query. Empty or failed recommendations omit the section. Product copy, admin, checkout, prices, stock, homepage and database remain unchanged. No schema/dependency changes. Candidate ranking is bounded to the first 24 returned category products, not a full-catalog similarity model. Explicit local sample-preview pages retain their existing behavior; published storefront pages use actual catalog results only.

Verification: production build, lint and TypeScript passed; three recommendation unit tests passed (self/duplicate/scope/category/stock/image exclusion; ranking/cap; available option price and immutability). All 22 real Chrome/Next browser checks with explicit synthetic catalog/image responses passed, including related-product links, mobile fit and no unrelated empty-category fallback. A separate actual hosted anonymous read-only query passed category/scope membership: two candidates, one other available product. No hosted writes or synthetic products created. Evidence: storefront-mock-ui-verification.json and recommendations-hosted-readonly.json. Changes not pushed or deployed yet.


## Category discovery editor — 2026-11-25

Optional category-scoped concern/features now join the normal authorized, revision-checked/idempotent Save transaction. Reuses existing normalized taxonomy/evidence/search with a simple owner confirmation and internally generated records. All eight skincare concern groups, scoped fragrance family/notes/concentration, occasion/season and makeup/body/hair/cutlery fields are available. No real claims assigned/published automatically; optional discovery does not block ordinary publication. The actual hosted read-only audit found the existing concerns/facets inactive.

Separate incremental 024 adds inactive vocabulary, private save support, inherited-scope validation/RLS/projections, supported navigation fields and searchable labels/EDP vocabulary. Recommendations rank shared assigned attributes within the same category/scope. Existing 023 remains owner-confirmed installed, unchanged; do not rerun it.

Verification: exact installer passed fresh 001–023 plus SEO using ON_ERROR_STOP=1: all eight flags and 37 SQL assertions, existing business rows preserved, repeat refused. Six Chrome/Next admin checks with provider doubles and 23 storefront mock checks passed; four recommendation unit tests, final production build, TypeScript and lint passed. Hosted assignment/freshness verification is pending owner SQL application and frontend deployment; no synthetic hosted products created. Full matrix, semantics, exact SQL steps and limitations: docs/product-discovery.md. Evidence: product-discovery-local-verification.json, product-discovery-browser-mock.json, product-discovery-taxonomy-audit.json and product-discovery-installer-manifest.json. Not pushed/deployed.


## 024 owner-confirmed installed — 2026-11-25

Owner supplied expected before/after results: all eight final installation checks true, including receipt/security. Do not rerun 024 or earlier installers. Actual hosted Auth/PostgREST read-only verification then passed 11 checks: admin/non-admin membership; installed discovery capability; 023 boxed gate still removed; anonymous/non-admin private report denial; eight concern definitions; new category vocabulary; public navigation facets contract; helper unavailable as a public RPC; zero Synthetic matches in admin. No SQL installer, hosted product write or synthetic product was created. Evidence: product-discovery-hosted-readonly.json.

Full hosted Save/removal/search/navigation freshness tests remain pending. The user asked to avoid leftover synthetic products; the current API can archive but cannot fully delete audit-linked product-save fixtures without owner SQL. Therefore persistent fixtures were deliberately not created. The 37 disposable-database assertions, six admin/browser mock checks and 23 storefront mock checks remain separately labelled evidence, not hosted write verification. Frontend changes are still local/unpushed; deployment remains required.
