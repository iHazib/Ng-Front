# Media integration service

## Actual development provider verification completed

The configured development Cloudinary/Supabase cycle passed **14 live checks** using a generated neutral PNG: private upload and exact bytes, no Cloudinary asset before review, explicit approval, signed publication, Admin API/original-byte validation, stored metadata, one primary ordered association, duplicate completion, responsive transformed delivery, referenced-asset cleanup denial and final deletion. See `cloudinary-provider-verification.json` and `cloudinary-final-cleanup.json`.

Live testing fixed two issues: the runner now accepts empty successful HTTP 201 responses, and deletion confirmation uses the authoritative Storage object listing instead of a potentially cached download. Private uploads use `Cache-Control: max-age=0`; the service refuses private reads in deleting/deleted states. Storage/CDN invalidation can propagate after origin deletion; a cached response alone is not evidence that an object still exists. See [Supabase Storage CDN behavior](https://supabase.com/docs/guides/storage/cdn/smart-cdn).

The final audit covered every attempt: three media tombstones, no Cloudinary assets, no private Storage objects and no media associations. Four synthetic parents remain archived; workflow/tombstone and append-only audit history is intentionally retained. No real catalog was imported. A harmless Node module-type warning did not affect verification. No installer rerun, migration change, admin UI or storefront edit was needed.

Separately, **seven mock/pure tests** passed, including the new deletion-confirmation regression. TypeScript, targeted lint and source-preservation checks passed. These mock results are distinct from the live provider results above. This verifies the synthetic PNG flow and one responsive delivery transformation; it does not claim a UI/browser upload workflow or all possible image formats were exercised against the provider.

The storefront is unchanged. This stage adds server-only media services and an additive database migration, not an admin upload screen or SKU-image import. No real catalog records or existing photographs were uploaded.

## Account and database setup

1. In Cloudinary Console, create/select a **development product environment**, separate from production. Check its Dashboard **Folder mode** is **Dynamic folders**. This service uses `asset_folder`; do not change an existing production environment's folder mode. See [folder modes](https://cloudinary.com/documentation/folder_modes).
2. In that environment's **Settings → API Keys**, obtain the cloud name, API key and API secret. Put them directly into your Git-ignored `.env.local`, never in chat, source files or `NEXT_PUBLIC_*` variables. See [Cloudinary API credentials](https://cloudinary.com/documentation/image_upload_api_reference).
3. Configure these exact server variables:

```dotenv
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
MEDIA_ENVIRONMENT=development
```

Keep the existing `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` and local test-account variables. No Supabase service-role key is required. Restart a running server/test process after updating configuration. Use distinct credentials/product environments for staging/production and their matching explicit `MEDIA_ENVIRONMENT` values; there is no implicit production fallback.

### Hosted deployment

All four server variables above must exist in the hosting project for **every** environment that serves the admin, not only locally. `MEDIA_ENVIRONMENT` must equal the `media_environment` stored on `media_assets`, because every private read, approval, publication and cleanup compares the two and refuses on a mismatch. A missing variable makes `mediaSettings()` throw before any provider call, so images stop loading, approval and removal all fail together. The admin now reports that as *"Media provider configuration is incomplete."* instead of a generic failure.

Vercel project `nookandglow` runs with `MEDIA_ENVIRONMENT=development`, matching the staged catalog media (17 images carry `media_environment=development` and `nook-glow/development/<media id>` public IDs). Re-tag media only through the media service, never by editing those columns.

4. Do **not** create an unsigned upload preset. This service signs every upload on the server and does not use a preset. Avoid default incoming transformations that modify original bytes; the service checks the delivered original against the reviewed source hash. If your account restricts dynamic transformations, authorize the documented responsive delivery transformations rather than guessing delivery works.
5. In the connected **development Supabase SQL Editor**, run the entire `supabase/sql-editor/05_install_media_service.sql` once. Expect `MEDIA SERVICE MIGRATION COMMITTED`. It requires the six existing receipts, adds migration 007 and a seventh receipt, and refuses a duplicate install. Do not rerun the old installer. Existing media receives `lifecycle=legacy`; its associations and source values remain intact. No existing product rows or files are deleted by this migration.
6. After configuration and migration, run the actual development check below or tell me setup is ready. No passwords/secrets should be posted to chat.

## Service contract

All public service entry points live in `src/lib/server/media/service.ts`, import `server-only`, and call the existing Supabase Auth/admin authorization. They use the caller's verified token and database RLS, not a privileged Supabase bypass. Cloudinary signing/lookup/deletion helpers are internal server adapters, not HTTP actions or signature endpoints. The Cloudinary API secret is only read in the server adapter.

| Operation | Behavior |
| --- | --- |
| `uploadPendingMedia(token, input, bytes)` | Input contains stable media UUID, product UUID, optional variant UUID, alt text and optional replacement association UUID. Validates allowed file signatures/10 MiB limit; creates an idempotent private intent, uploads under `media/<environment>/<uuid>/original`, reads back and verifies SHA-256. No manual filename/SKU-folder convention. |
| `getPrivateReviewImage` | Admin-authorized private bytes only; never a public review URL. The future UI must keep this response private/non-cacheable. |
| `approveMediaForPublication` | Explicit human review action, bound to original bytes. It authorizes those bytes becoming public on Cloudinary, even if the associated product is still a draft. Confidential draft imagery must not receive this approval. |
| `publishApprovedMedia` | Requires review; reads exactly those private bytes; makes a server-side SHA-256-signed upload with fixed UUID public ID and `overwrite=false`; fetches authoritative Cloudinary Admin API metadata and verifies the delivered original's hash before linking. A browser cannot swap the signed file because signatures and the upload request stay server-side. |
| `selectPrimaryMedia` / `reorderMedia` | Uses existing primary selection plus exact-list atomic ordering. Separate product/variant owners can each have one primary. Detaching a primary promotes the remaining first image. |
| Replacement | New UUID/asset first; only after verification does a transaction replace the association, preserving its ID, position and primary flag. It detects a changed replacement target. It does not overwrite or immediately destroy the old provider image. |
| `getMediaRecoveryCandidates` | Bounded admin-only list in the configured environment for retry/cleanup review. No automatic recurring job was scheduled. |
| `detachMedia` / `cleanupOrphanMedia` | Explicit per-UUID operations. Cleanup checks product, article and homepage references, other provider identity owners, then claims deletion under a lock. Reference triggers prevent new links while deleting. It verifies provider deletion and private-object removal before recording a tombstone. |

Images use `nook-glow/<environment>/<media UUID>` public IDs and environment-separated asset folders. Supabase stores Cloudinary immutable asset ID, public ID, version, resource type, format, dimensions, byte size, SHA-256, alt text and lifecycle; workflow rows preserve original private paths and review identity/time. Approved media/associations are public only through existing publication RLS. Pending files and workflow details remain private.

This intentionally implements signed **server-to-Cloudinary** uploads rather than handing a public upload signature to the browser. Pending-review/confidential files must never be placed in public Cloudinary storage. The later admin UI can send bytes through the authorized private upload/review/publish service; no route or UI was added here.

## Validation and retry boundaries

Local input accepts PNG/JPEG/WebP file signatures only (not SVG, GIF, PDF or arbitrary remote URLs). File signatures are an early rejection check, not a full image decoder. Cloudinary image decoding/metadata is authoritative at publication: correct ID/type, format, version, size, dimensions, single page and at most 40 million pixels are required. Delivered original bytes must match the approved SHA-256. Reads are bounded to 10 MiB. Arbitrary provider URLs returned by callbacks are never fetched.

No unauthenticated webhook endpoint is installed. Completion does not accept callback metadata: repeated completion requests use the persisted UUID and re-fetch provider evidence as necessary. Lost upload responses are reconciled by exact public ID; `overwrite=false` and immutable reviewed hashes prevent overwrites. Duplicate completion preserves one association. Provider/validation errors retain the intent with a sanitized error code; retries use the same UUID. No provider response bodies or secrets are logged.

Uncertain uploads (`uploading`, `failed`, `private_uploading`) must settle for 24 hours before cleanup. This exceeds Cloudinary's one-hour signature validity and protects against late uploads. Confirmed linked-but-unreferenced/retired images can be explicitly cleaned sooner. A partial provider/Storage deletion leaves `deleting` for safe retries. Tombstones, workflow history and audit events remain; they are not silently purged. Cleanup is limited to tracked intents, never a broad Cloudinary folder sweep. Manual provider-console edits/deletions are outside these guarantees; avoid changing service-owned IDs.

## Shared rendering contract

`src/lib/catalog/media.ts` still accepts the existing local-preview interface and returns identical local paths. Approved public Cloudinary metadata uses versioned URLs with `f_auto,q_auto`, responsive width candidates and `sizes`. Default `c_limit` preserves the full product frame; `c_fill,g_center` requires an explicit aspect ratio. It does not invent secondary angles or automatically crop product packshots. No homepage code or local asset mapping was replaced.

## Verification and exact commands

```powershell
# Mock transport and pure validation/resolver tests; no credentials/network:
& '.tools/node-v24.21.0-win-x64/node.exe' --conditions=react-server --test tests/media-service.test.mjs
# Disposable local SQL tests (Auth/Storage test doubles, not Cloudinary):
python scripts/test_database.py --sql-editor
# Real provider check: only after local configuration and migration 007:
& '.tools/node-v24.21.0-win-x64/node.exe' --conditions=react-server scripts/verify-cloudinary-development.mjs --run-development
```

Actual provider verification is now **passed** after the user configured credentials locally and applied migration 007. `docs/cloudinary-provider-verification.json` records the real checks. The opt-in runner refuses any environment except development and creates only a generated neutral pixel and synthetic draft parent. It retains an archived synthetic parent plus deletion tombstone/workflow/audit metadata to preserve history; no real SKU or catalog import occurs. A failed uncertain upload is reported for reconciliation rather than unsafe deletion.

Local SQL lifecycle tests and mock provider tests remain separate from successful actual Supabase and Cloudinary service checks. The real runner now supplies account-level signed-upload and delivery evidence.

Official signing and upload references: [signature generation](https://cloudinary.com/documentation/authentication_signatures), [signed uploads](https://cloudinary.com/documentation/upload_images). Next.js boundaries follow the installed data-security guide; no new app dependency or backend was introduced.
