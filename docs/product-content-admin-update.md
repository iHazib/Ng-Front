# Product content and admin usability revision

## Implemented

- Reuse `products.description` and `products.usage`; add only optional `products.key_benefits` in incremental migration 012. Existing rows receive NULL for the new field. There is no content backfill, automatic splitting, rewriting or invented benefits.
- Three independently stored Write/Preview Markdown fields. Paragraphs, headings, bold, bullets, numbered steps and safe links are rendered as React nodes. HTML is escaped, executable/protocol-relative/credential-bearing links are rejected, and embedded-image syntax stays literal. Images use the existing approval workflow.
- Ordinary saves omit unchanged content fields, preserving exact original values and line endings. Omitted fields are also preserved by SQL. Changed content is bounded at 30,000 characters per field. Empty optional usage/benefits sections are hidden on product pages. Publication blockers are unchanged; neither optional field is required.
- Scoped spacious admin navigation and section layouts; Products, The Edit, Homepage and Reviews are primary navigation. Import tools are under More. Responsive product summaries show photo, name/SKU, exact PKR price, stock and visibility; visibility filtering/pagination run on the server in one bounded query.
- Product sections: Basic details, Images, Content, optional Shades/sizes, Stock/visibility. Variant rows support Add shade/size, removal and existing private image controls. SKU/UUID relationships, stock reconciliation and original visibility behavior are preserved.
- Unsaved-change feedback/leave warnings, draft content preview, sanitized article preview, native upload progress and processing/error feedback. Existing article HTML stays in its rich-text editor. Homepage ordering/themes and review moderation remain functional.
- All protected operations use verified admin sessions, per-operation authorization, CSRF and private no-store responses. No hosted records were mutated during this revision.

## SQL Editor steps

1. Review `supabase/sql-editor/09_preflight_customer_reviews.sql` first if migration 011 is not yet confirmed. The hosted review endpoint currently returns HTTP 404. This alone cannot distinguish an absent migration from an unrefreshed PostgREST cache. Do not rerun an installed/partly installed migration. Inspect receipts/objects with the read-only preflight. If 011 is wholly absent, use its existing clean installer once; do not rerun 001–010.
2. In a NEW development SQL Editor query, run the entire `supabase/sql-editor/10_preflight_product_markdown.sql`.
3. Before installing 012, daily_editor_present, reviews_present, receipt_011_present and products_rls must be true. benefits_present, product_list_present and receipt_012_present must be false; receipt_matches is NULL. Any partial/new installation means stop and inspect; do not combine SQL manually or rerun.
4. In another NEW query, paste/run the entire `supabase/sql-editor/10_install_product_markdown_clean.sql` once. It contains one transaction, one receipt insert, a cache notification and one final read-only verification query.
5. All final result flags should be true. Refresh the admin. The new list and content-saving contract require 012; saving fails clearly until it is installed, so an old RPC cannot silently discard new fields.

Canonical migration SHA-256: `12038d5d88f52a014bca3050567d75e68e8d3066ac8771eb364b47d3f2381bc7`.
Exact complete installer SHA-256: `2f5df9628568e304f21250379ca1b993db4c8a05b4f2c03a3221cbcd404c1002`.

The installer executes ADD COLUMN / CREATE OR REPLACE definitions and grants. It executes no business-row UPDATE, DELETE, DROP or TRUNCATE. DELETE/UPDATE statements inside the retained save function run only during explicit owner operations (for example clearing a price, removing a homepage choice or archiving a removed option). Existing audit/revision/stock safeguards remain. Installer refuses repeat/partial installation.

## Verification boundaries

- Exact final installer is executed with `psql -X -v ON_ERROR_STOP=1 -f` against a fresh disposable PostgreSQL 16 database with canonical 001–011 applied. Existing public-table columns/rows are snapshotted before/after; repeat refusal, Markdown persistence, unchanged content, stale edits, public projection, admin list/filter, anon/non-admin restrictions and all earlier SQL regressions are tested. Local Auth/Storage are test doubles, not hosted Supabase services. See `product-markdown-database-verification.json`.
- Actual Next/Chrome on local provider doubles checks single/two-variant saving, previews, Markdown safety, mobile layouts, article editing/preview, homepage selection/themes and moderation. See `admin-refresh-ui-mock-verification.json`. These are explicitly mock-provider results, not real uploads or live RLS results.
- Markdown/security/media/content/review unit tests, lint, production build, original-source hashes and homepage browser comparisons are run separately. Homepage comparison uses explicit isolated development sample mode; no local .env changes or silent fallback.
- Browser coverage is desktop Chrome at 1440×1000 and mobile Chrome viewport 390×844, plus existing homepage responsive widths. Physical iOS Safari has not been tested.

## Hosted checks still pending

Read-only actual setup check: review RPC HTTP 404; `SUPABASE_SECRET_KEY` and `REVIEW_SESSION_SECRET` are not configured locally. The private installed receipt cannot be inferred through the public API. Confirm 011 with the read-only SQL query, resolve its API exposure/cache, and configure the two names locally. Keep values out of chat. See `reviews-setup.md` for account/setup guidance. `REVIEW_SESSION_SECRET` needs at least 32 random characters. Restart the local Next server after configuration.

After prerequisites and migration 012 are applied, actual hosted browser/provider verification must cover customer submission/private uploads, approval and Cloudinary delivery, moderation/ratings/freshness, final single/two-variant editing and status preservation, with synthetic fixtures only and safe cleanup. No real catalog/content was published or approved, and no next numbered stage was started.


## Hosted verification completed (2026-10-08)

The owner confirmed 011/012 installed. Both server secret presence checks and the actual RPC probe now pass; Next was restarted. Earlier pending setup statements are historical and must not prompt installer reruns. The actual hosted runner passed 58 checks, including single/two-variant safe Markdown persistence/public rendering, visibility/stock preservation and review/private media/moderation/ratings/freshness. All synthetic fixtures were safely hidden/cleaned and 923 baseline rows remained identical. See reviews-product-content-hosted-results.md; mocks and unit tests remain separate evidence.
