# Apply the six migrations using Supabase SQL Editor

Prepared 2026-10-05. This is for the connected **development** project. Do not select production. The project URL/publishable key cannot execute DDL, so application is performed by you in the project's owner-controlled SQL Editor. No password or secret is needed in chat.

## Exact sequence

1. Open the intended project in Supabase Dashboard. Confirm its Project URL matches your local `.env` and that it is your development project. Preserve any existing backup. Open **SQL Editor → New query**, using the default owner/postgres role.
2. Open `supabase/sql-editor/00_preflight.sql` locally. Copy the **entire file** into the query and run it. It must return `PREFLIGHT PASSED`. If it raises an exception, stop and keep the existing data; do not delete conflicting objects or policies. The check is deliberately conservative about existing Storage policies because permissive policies could expose the new bucket.
3. Open a new query. Paste the **entire** `supabase/sql-editor/01_install_all_six.sql`, including `begin` and `commit`, and run it once. Expect `ALL SIX MIGRATIONS COMMITTED`. Do not highlight/run individual portions. The installer repeats preflight inside its transaction. Any failure rolls back this installation. It refuses to overwrite an existing installation; it is not a rerunnable repair script.
4. Open a new query and run the entire `supabase/sql-editor/02_verify_installation.sql`. Expect six receipt rows; 47 Nook & Glow public tables with RLS enabled; public-schema usage true for anon/authenticated; private-schema usage false for both; `catalog-private` with `public=false`; zero visible products and `is_admin=false` in anonymous/unprovisioned role checks. These are SQL checks, not proof of actual Auth login or Storage HTTP permissions.
5. In the project's **Data API settings**, ensure the Data API is enabled and `public` is among **Exposed schemas**. Preserve other existing exposed schemas. Never expose `app_private`, `auth` or `storage` as application schemas. The installer supplies table/function grants explicitly; do not add blanket grants or disable RLS.
6. Tell me the installation completed (or provide only the SQL error text, without credentials). I can then recheck the configured products endpoint. No background polling is scheduled.

The combined installer is the recommended runnable entry point. It contains the six authoritative migrations verbatim in this order, with preflight and receipt/cache-notification additions:

| Order | Migration | Dependency |
| --- | --- | --- |
| 1 | `202610050001_catalog.sql` | Supabase Auth/Storage schemas and roles; UTF8; PostgreSQL 15+; pg_trgm in extensions |
| 2 | `202610050002_commerce_content.sql` | Catalog tables/types |
| 3 | `202610050003_security_publication.sql` | Catalog plus commerce/content tables; adds policies and audit triggers |
| 4 | `202610050004_access_import.sql` | Admin authorization, stock schema and private Storage |
| 5 | `202610050005_taxonomy.sql` | Controlled taxonomy tables; seeds inactive vocabulary only |
| 6 | `202610050006_invariants.sql` | Replaces two initial policies and tightens existing functions/triggers |

Do not also apply the six raw migration files separately. The single transaction avoids a window in which early tables exist without their final RLS. Hashes in `supabase/sql-editor/manifest.json` identify the exact reviewed revisions. Rebuild the package with `python scripts/prepare_sql_editor.py` after any later migration edit; do not manually edit the generated installer.

## Data safety and statements to flag

- **No table/schema drops, truncations, reset commands or executed catalog/customer row deletions.** No product import, admin account, review, order or shipment is created. Controlled taxonomy rows are inactive/draft.
- Migration 003 formerly iterated over all public tables/functions. It now restricts table policies, audit triggers, FK indexes and function revocations to the 47 Nook & Glow tables and named functions. Existing unrelated objects are not included.
- **Permission changes:** migration 001 revokes public-schema CREATE from PUBLIC/anon/authenticated and blocks their private-schema access. This changes permissions, not stored rows; it may affect an existing app that improperly relies on client schema creation. Migration 003 revokes/regrants access to our tables/functions and makes stock/financial/audit operations restricted.
- **`DROP POLICY` twice in migration 006:** replaces only `public_read` on the newly created `product_facets` and `product_concerns`, inside the same transaction. No rows are dropped and there is no externally visible unprotected interval.
- **`CREATE OR REPLACE FUNCTION`** tightens our newly created public-search function. Preflight rejects an existing function with the same name before installation.
- **Storage upsert:** migration 004 can set the `catalog-private` bucket to private. The packaged preflight rejects an existing bucket of that name, so this installer cannot change an existing bucket. Existing Storage policies also cause preflight to stop for manual review, not deletion.
- **`ON DELETE CASCADE`** on admin membership is a future rule for deleting an Auth user; it does not delete any user or membership during installation. Stock update statements in function bodies execute only when explicitly called later.
- There is no destructive rollback script. If the transaction errors, its own changes roll back. If it succeeds, do not drop anything to retry; use the receipt and diagnostics.

## If products still returns PGRST205

In SQL Editor first run `select to_regclass('public.products');` — it must be `public.products`. Check that the six receipts exist and that step 4 shows `anon_select=true` for products. Check Data API enabled / exposed `public` in Dashboard and confirm the configured `.env` points to this same project. Missing grants/schema exposure can resemble an absent table; do not interpret every PGRST205 as missing migrations.

Then run `supabase/sql-editor/03_reload_schema_cache.sql` (`NOTIFY pgrst, 'reload schema';`) and retry the endpoint after a few seconds. This only requests cache refresh. If still failing, inspect PostgREST service logs for schema-cache/notification errors and report the sanitized error code. Do not reset the database or disable RLS. The expected products response after schema-only installation is **200 with `[]`**, not public draft products.

## Actual Auth and Storage checks after application

URL/publishable key allow anonymous HTTP checks, but cannot impersonate an admin. In **Authentication → Users**, create two synthetic confirmed test users: admin candidate and ordinary user, with unique passwords. In SQL Editor grant only the verified admin candidate UUID:

```sql
insert into app_private.admin_members(user_id,reason)
values ('REPLACE_WITH_VERIFIED_TEST_ADMIN_UUID'::uuid, 'Development integration verification');
```

This placeholder intentionally fails until replaced locally. Keep the ordinary user out of membership. Store `TEST_ADMIN_EMAIL`, `TEST_ADMIN_PASSWORD`, `TEST_USER_EMAIL`, `TEST_USER_PASSWORD` in Git-ignored `.env.local` only; do not paste values into chat. No service-role key is required. The public URL/key remain under `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.

After that setup I can verify password login, `/auth/v1/user` token validation, `is_admin`, PostgREST read/deny results for all three identities, and private Storage access using an isolated synthetic object removed after testing. Customer/source payloads and tokens will not be logged. Existing production/customer data will not be used. Full service verification remains pending until the installation and test accounts exist; the explicit requests/expected outcomes are also in `supabase-integration-verification.md`.

## Verification already performed

The generated installer and postflight ran successfully on a fresh disposable PostgreSQL 16.11 cluster with explicit Supabase Auth/Storage SQL test doubles. A repeat installation was rejected safely; the installed schema remained usable. All 54 SQL assertions passed, including 121 local draft imports, repeat-import safety and permission checks. The cluster was stopped. This confirms executable SQL on that engine, not hosted Supabase service compatibility or actual login.

SQL Editor does not update Supabase CLI migration history automatically. A private six-row hash receipt is included instead. Before future CLI `db push`, reconcile the six versions using the CLI's migration-history repair workflow after verifying these receipts; do not re-run the migrations or invent history blindly. No Supabase-managed migration metadata is overwritten here.

Official references: [SQL Editor/grants and RLS](https://supabase.com/docs/guides/api/securing-your-api), [schema cache refresh](https://supabase.com/docs/guides/troubleshooting/refresh-postgrest-schema), [migration history caveat](https://supabase.com/docs/guides/deployment/database-migrations).
