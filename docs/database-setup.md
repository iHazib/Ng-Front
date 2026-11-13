# Database stage — local/test setup

Six ordered migrations in `supabase/migrations` implement the approved contract. They have been applied only to fresh disposable PostgreSQL clusters. No storefront connection, production import, admin upload UI, real payment, shipment or deployment is included.

## Repeat verification

Use Python 3.11+ (standard library) and PostgreSQL 16 binaries with pg_trgm installed:

```powershell
python scripts/catalog_import.py
python scripts/prepare_database_contract.py
python -m unittest discover -s tests -p test_catalog_import.py -v
python scripts/test_database.py --pg-bin 'C:/Program Files/PostgreSQL/16/bin'
npm run sources:check
npm run lint
npm run typecheck
```

The database runner creates a new random `.local/database-test-*` cluster, binds only loopback port 55439 and stops that cluster in `finally`. It never reads a connection URL or touches an existing server. Local trust authentication is limited to this disposable fixture: do not expose its port or use this configuration for shared environments. Logs and the synthetic SQL assertion results remain under ignored `.local/`. Test fixtures contain no customer records from a live service.

The runner installs minimal **Auth and Storage SQL test doubles**, then applies all six migrations, imports all 121 source SKUs as drafts, repeats the import, tests anonymous/ordinary-user/admin roles, rolls back synthetic publication/commerce fixtures and generates TypeScript definitions from the actual applied database catalog. `database-verification.json` records the engine and limitations. Generated `database.types.ts` contains row/insert/update and enum types; RPC result shapes are explicitly typed in the access layer. It is not Supabase CLI-generated output.

Tested engine: PostgreSQL 16.11, the installed local binary. PostgreSQL 16 is supported; this installed minor release is not represented as the latest patch. Application dependencies and lockfile remain pinned and unchanged.

## Full Supabase integration still required

Docker is installed but its daemon was unavailable, and no Supabase CLI or test project credentials were configured. Actual GoTrue token verification, PostgREST requests, private Storage uploads/downloads and hosted migration compatibility therefore remain unverified. SQL permission tests are not a substitute for those service tests.

Follow the [fresh isolated stack procedure](supabase-integration-verification.md), which uses a random project directory/identity, pinned local CLI tooling and `migration up --local`. Do not reset an existing database. `supabase/config.toml` disables automatic data seeding and signups. Migrations create inactive taxonomy, not the 121 catalog records. Do not run a remote push or production import as part of this stage.

Configure `.env.local` from `.env.example` using the test project URL and publishable key. No privileged key is needed by the current access layer. It verifies the caller through Supabase Auth `/auth/v1/user`, checks `is_admin`, and uses the same caller token for RLS-protected operations. Every exposed privileged SQL RPC also checks membership. Reserved secret/provider variables remain unused and server-only.

Create the first administrator through an owner-controlled SQL session after creating and verifying their Auth user. Insert that verified Auth UUID into `app_private.admin_members(user_id, reason)`; ordinary users and user metadata cannot grant this role. The private schema must not be added to the API's exposed schemas. Revoke access by setting membership `active=false`. Choose real administrators and Auth policies before connecting any UI.

## Import and publication rules

`prepare_database_contract.py` generates private `database-payload.json` and the taxonomy migration from contract v1.1.0. The authenticated `importAdminDrafts` access method calls the transaction-safe import RPC. Existing UUIDs and exact original SKUs remain immutable; normalized keys detect collisions without renaming spaced SKUs. A repeated source/contract hash is a no-op. Changed source versions create review records, never overwrite admin content/prices or reset inventory. Each affected invalid/colliding row is quarantined independently.

Source quantities (270 total) remain private provenance. Live balances start at zero, unreconciled; an explicit audited inventory adjustment establishes physical stock. Missing price, photos or optional concerns do not prevent draft import/search. No ambiguous families are merged. Factory sets have their own variant inventory; assembled deals reserve aggregated component variants and snapshot their composition.

Publication checks separate common identity/copy/condition/taxonomy/media/review requirements from category-specific label/safety/specification requirements. Makeup allows explicit not-applicable judgments for tools; home fragrance is distinct from perfume; hair care is supported. Sunscreen additionally requires SPF-label approval. Primary approved media (including an explicitly approved neutral placeholder) is a publication requirement, never an import requirement. Secondary images, reviews, concerns, extra verified facets and collections are optional. Concern research remains **partially complete**, with all eight groups available but no automatic assignments.

Public RLS requires eligible published parent records and approved media/reviews/evidence. Raw workbook/costs, draft records, order/customer data, audit logs and private review media remain admin-only. Cloudinary metadata supports ordered product/variant associations and one primary per owner. Pending media belongs in private `catalog-private` Supabase Storage; no upload/publish service was built here.

Inventory changes/reservations are transactional RPCs with idempotency keys and row locks. Financial history is append-only and over-refunds are rejected. Money uses bounded integer PKR minor units (100 paisa per rupee), timestamps use `timestamptz`, and `karachi_day_bounds` returns half-open UTC reporting boundaries. A later commerce stage must implement the approved order/payment lifecycle, reservation-expiry scheduling and provider reconciliation; this stage supplies persistence and primitives only.

## Official references

- [Supabase local development](https://supabase.com/docs/guides/local-development/cli-workflows)
- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Server-verified Auth user](https://supabase.com/docs/reference/javascript/auth-getuser)
- [PostgreSQL supported versions](https://www.postgresql.org/support/versioning/)

Next.js server-only boundaries follow the installed `node_modules/next/dist/docs/01-app/02-guides/data-security.md` guide.
