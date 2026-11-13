# Customer reviews setup — migration 011

Implementation is ready locally; hosted review verification is pending. No real catalog/content was modified, and no hosted synthetic review was created. The connected project's read-only review RPC probe returned HTTP 404 on 7 October 2026.

## Apply one installer in the development SQL Editor

1. Open a **new query** in the connected development project's SQL Editor. Run the entire `supabase/sql-editor/09_preflight_customer_reviews.sql` file. Before installation, `content_present` and `content_receipt_matches` must be true; all new-object flags must be false; `reviews_receipt_matches` will be null. Stop if any new object already exists or the prerequisite receipt differs.
2. Open another **new query**, paste the entire `supabase/sql-editor/09_install_customer_reviews_clean.sql`, and run it once. Do not combine it with older text or rerun installers 00–08. The installer is atomic and refuses an existing/partial review installation.
3. Its four final checks must all be true: `reviews_present`, `review_media_rls`, `limits_rls`, `receipt_matches`. Run the same read-only preflight again; all flags should now be true.

The exact delivered installer was executed with `psql -X -v ON_ERROR_STOP=1 -f` in a fresh PostgreSQL 16 database with canonical migrations 001–010 applied. See `docs/reviews-database-verification.json` and `docs/reviews-installer-structure.json` for its SHA-256 and evidence directory. Local Auth/Storage schemas are test doubles, not a claim of hosted Supabase verification.

**Statements to review:** `DROP POLICY public_read ON public.reviews` is immediately replaced with stricter eligibility; two `DROP CONSTRAINT` statements immediately replace the media-owner constraint. A function is renamed into `app_private` and wrapped by one authorized dispatcher. No table is dropped/truncated, no stock is reset, and installation performs no business-row updates/deletes/publication. Runtime review text edits re-enter Pending; runtime decline/hide is audited.

## Configure locally, never in chat

- `SUPABASE_SECRET_KEY`: from this **development** project's Settings → API Keys, create/copy a secret key into `.env.local`. Use a dedicated backend key if available. A publishable key cannot substitute for it. Someone with project key-management permission must configure this if your account cannot access secret keys. See [Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys).
- `REVIEW_SESSION_SECRET`: at least 32 random characters, server-only, stored in `.env.local`. For example, generate it securely into that ignored file without printing it:

```powershell
& ./.tools/node-v24.21.0-win-x64/node.exe -e "const fs=require('node:fs'),crypto=require('node:crypto');const p='.env.local';const s=fs.existsSync(p)?fs.readFileSync(p,'utf8'):'';if(/^REVIEW_SESSION_SECRET=.+/m.test(s))throw Error('Already configured; preserve existing value');fs.appendFileSync(p,'\nREVIEW_SESSION_SECRET='+crypto.randomBytes(32).toString('hex')+'\n');console.log('Review session secret saved locally; value not printed.');"
```

- Preserve existing `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `MEDIA_ENVIRONMENT=development` and Cloudinary configuration. No new Cloudinary account or public Storage bucket is needed.
- `REVIEWS_TRUSTED_IP_HEADER`: leave unset for local development. For hosting, choose `cf-connecting-ip` or `x-vercel-forwarded-for` **only after** confirming that the chosen ingress strips client-supplied values. Other hosting needs a reviewed ingress adapter. Non-development submissions fail closed until a trusted client address is configured; hosting remains a business decision.

Never prefix secret keys with `NEXT_PUBLIC_`, put them in SQL files, or send them in chat. New `sb_secret_` keys go only in the `apikey` header; legacy server JWT keys are also supported as `SUPABASE_SERVICE_ROLE_KEY`. The guest gateway exposes only two named submission RPCs and exact UUID Storage paths. Admin operations continue to verify real Auth tokens and database membership on every request. Private buckets remain subject to access control; see [Supabase private Storage](https://supabase.com/docs/guides/storage/buckets/fundamentals).

Restart Next after configuration. `npm run verify:reviews:setup` is read-only. It checks configuration presence and RPC availability without displaying values or creating fixtures. Receipt inspection still requires SQL Editor.

## Behaviour and verification boundaries

- Customer rating/name/text with optional title/private email and up to three JPEG/PNG/WebP images, maximum 5 MB each. Text is plain, length-bounded and excludes HTML, links and control characters. Images use the existing raster validator and Storage readback hash validation.
- Same-origin + session-bound CSRF, HttpOnly/SameSite guest cookie, signed one-hour session, honeypot, minimum form time, immutable submission/image identities, SHA-256 duplicate detection and atomic database quotas (five submissions per client-address bucket/hour, 100 total/hour). Rate limit returns HTTP 429 using the documented [PostgREST custom error mechanism](https://postgrest.org/en/v14/references/errors.html). Development shares one loopback quota. This is bounded abuse protection, not a claim that distributed bot traffic is impossible.
- All submissions start Pending. Unfinished upload remains private and unapprovable. Approve explicitly approves each image, invokes the existing server-signed Cloudinary verification/publication service, then approves review text only if every active image is linked and approved. Failure leaves the review private; retries reconcile the same media identity.
- Admin `/admin/reviews`: Pending/Approved/Declined, private previews, Approve/Decline/Hide/Edit text, simple history. Hidden entries live in Declined and show “Hidden”. Editing visible content returns it to Pending, even through direct admin database writes; stale moderation/save is rejected.
- Public RPC projects only approved eligible text/images and computes approved-only averages/counts. No contact, source fields or purchase badge is emitted. No purchase prerequisite exists. Existing order evidence remains internal; this stage deliberately emits no “Verified purchase” label.
- Review images have a true `review_id` media owner. Referenced assets cannot be cleaned up. Previous public Cloudinary URLs cannot be made confidential retroactively; hidden/re-moderated reviews and their media are removed from public application responses.
- Product pages show explicit unavailable/empty states; no mock reviews silently replace an empty/unavailable database. Existing sample experiences remain restricted to the explicit development preview.

Passed: exact disposable SQL installer/regressions/permissions, unit input checks, actual Next/Chrome against explicitly mocked Auth/PostgREST/Storage, desktop/mobile review layouts. Actual browser submission and moderation **against hosted Supabase**, real private Storage uploads, Cloudinary review publication/delivery, hosted rating calculations/freshness and fixture cleanup remain pending until migration/configuration above are available. Real catalog/content/homepage selections remain untouched.


## Actual development verification completed (2026-10-08)

011/012 installation was confirmed by the owner; local key/session-secret presence checks passed and Next was restarted. Actual hosted customer submission, private Storage access, admin approval/decline/hide, real Cloudinary publication/delivery, approved-only ratings, re-moderation and public freshness passed. Synthetic files were safely cleaned and reviews hidden; business content remained unchanged. No installer rerun is required. See reviews-product-content-hosted-results.md for the live report and remaining browser/production boundaries.
