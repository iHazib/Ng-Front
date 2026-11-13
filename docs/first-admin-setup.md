# First administrator setup

The live products endpoint now returns HTTP 200. Anonymous admin search, orders, import records and audit access returned 401; `is_admin` returned false; an invalid Auth token returned 403. Anonymous private Storage listing returned an empty array. No installer, catalog import or storefront change was made. See `supabase-live-access-checks.json` for the machine-readable results.

Your reported six receipts, products RLS and private bucket configuration are recorded as **user-confirmed SQL results**, not independently queried owner metadata. Auth health and anonymous HTTP checks now pass, but they do not prove signed-in role behavior or known-object Storage privacy.

## Create your account

1. Open the connected **development** Supabase project. Go to **Authentication → Users → Add user → Create new user** (the create-user action in that menu).
2. Enter an email address you control and a unique strong password directly in Dashboard; keep the password in your password manager. Confirm the address through the supported confirmation flow, or use the owner-controlled auto-confirm option only for your own verified address in this development project. Do not insert users or passwords directly into `auth.users` with SQL.
3. Open the created user's details and copy its **User UID**. This is the Auth user's UUID, not the project ID. Check the email and confirmation status before granting access.
4. Open `supabase/sql-editor/04_provision_first_admin.sql` in a new SQL Editor query. Replace `REPLACE_WITH_AUTH_USER_UUID` and `REPLACE_WITH_YOUR_ACCOUNT_EMAIL` **locally in Dashboard**, then run the full file as the owner/postgres role. Expect `active_admin_count = 1`. It refuses to proceed if an active admin already exists, or if UUID/email/confirmation do not match. It does not change or recreate your account.
5. Do not add an `admin` flag to user-editable metadata. The only authorization source is `app_private.admin_members`; leave that schema unexposed and membership writes unavailable to clients.

This grants database application permissions, not Supabase organization ownership. There is no storefront admin-login screen yet; this stage verifies Auth and API access only.

## Enable actual login/role checks without sharing secrets

Create a second confirmed synthetic user through the same Auth Dashboard flow. Do **not** run the membership SQL for this ordinary test user.

Add these names to Git-ignored `.env.local` with your actual values locally:

```dotenv
TEST_ADMIN_EMAIL=
TEST_ADMIN_PASSWORD=
TEST_USER_EMAIL=
TEST_USER_PASSWORD=
```

Keep the existing URL/publishable key in `.env`. No service-role key or database password is required for the HTTP checks. Do not paste any passwords or tokens into chat. You may remove the test password entries after verification.

Then say that the accounts and local test configuration are ready. The verifier can sign in, validate each token through `/auth/v1/user`, and check admin versus ordinary-user RPC/table permissions. `python scripts/verify_supabase_access.py` is also runnable locally. It makes no database/Storage writes and reports only status codes/outcomes, never emails, keys, tokens or row bodies. Its simple dotenv reader supports plain single-line `NAME=value` entries, with optional surrounding quotes; avoid inline comments on value lines.

## Remaining verification

- Actual admin and ordinary-user password login, server token validation and role enforcement: pending local credentials.
- A known private Storage test object: upload as admin, verify admin download, deny anonymous/ordinary-user download and upload, then remove only that synthetic object. Pending authenticated setup; empty listing alone is insufficient.
- HTTP draft import and data-bearing isolation checks: still pending; no catalog records have been imported into this project by the verifier.
- The Next.js server-only TypeScript wrapper has not been invoked by this Python HTTP test. The storefront remains unchanged.

To revoke an administrator later, use the owner-controlled SQL Editor to set that verified user's membership `active=false`. The membership check is performed on each operation; do not delete Auth users as a substitute for role management.

Official background: [Supabase user management](https://supabase.com/docs/guides/auth/managing-user-data) and [Auth users](https://supabase.com/docs/guides/auth/users).
