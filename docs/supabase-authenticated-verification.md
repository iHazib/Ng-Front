# Actual Supabase authenticated verification — 2026-10-05

**45 checks passed; zero failed.** Machine-readable results: [supabase-authenticated-verification.json](supabase-authenticated-verification.json). The configured development project was used with the two existing confirmed accounts and publishable key. No passwords, keys, tokens, account emails or response row contents were printed or saved in the report.

| Area | Actual result |
| --- | --- |
| Auth | Both password logins returned 200. `/auth/v1/user` validated each token against its login identity. Database membership was true only for the admin. |
| Next.js server-only access source | Directly executed the existing TypeScript `authorizeAdmin`, `searchAdminCatalog`, `getAdminProduct`, `getPublicationReport` and `searchPublishedCatalog` functions against Supabase. Admin accepted; non-admin and invalid token rejected. A photo-free synthetic draft was found by admin SKU search and hidden from public search. |
| Data-bearing RLS | Created only a synthetic draft product, its variant and an empty synthetic draft order. Anonymous and signed-in non-admin reads could not see these known rows. Privileged search RPC denied both. Non-admin create returned 403; attempted update affected no row and the admin verified original content remained intact. |
| Private membership | A non-admin request to expose `app_private` returned 406. Membership was not changed or granted by the test. |
| Known private Storage object | Admin uploaded synthetic text and downloaded byte-identical content. Anonymous/non-admin requests could not download, list, upload or sign a URL. The public object route could not expose the known existing private file. |
| Cleanup | Deleted only this run's exact synthetic object paths and UUID-addressed rows. Admin reads confirmed every fixture row absent and the unique Storage prefix empty. |
| Preservation | All 64 supplied source files and 14 reference CSS blocks verified unchanged. No storefront files, routes, application dependencies or migration files changed. No real catalog import, payment, shipment or installer rerun. |

Storage denial responses were HTTP 400, while its filtered anonymous/non-admin list requests returned 200 with empty arrays. Product/variant RLS filtering likewise returned empty 200 responses; these are not authorization bypasses. The admin positive read of the same known fixture makes these meaningful isolation checks rather than tests against missing data.

The wrapper harness uses the pinned Node 24 runtime, its native TypeScript stripping and the package's real `react-server` export condition. It imports application source directly with a resolver for its extensionless TypeScript imports. No wrapper was mocked or copied. No Next.js route was added or browser bundle exposed. This tests the service/data-access code, **not** a future login UI, Next.js HTTP cookie/session pipeline, CSRF handling or deployment. A harmless Node module-type warning was observed; app package configuration was not changed to suppress it.

Synthetic mutation audit events and provider Auth/session logs remain as designed. The test does not delete append-only audit history. No product, variant, order or Storage fixture remains. Actual HTTP catalog import, stock/financial mutations and uploads through an admin UI were outside this request; no claim is made that those flows were verified here. Earlier local SQL tests remain separate evidence.

Repeat only when synthetic verification is authorized for the configured development project:

```powershell
& '.tools/node-v24.21.0-win-x64/node.exe' --conditions=react-server scripts/verify-supabase-authenticated.mjs
```

Credentials are loaded locally from `.env` and `.env.local`; the required `TEST_ADMIN_EMAIL`, `TEST_ADMIN_PASSWORD`, `TEST_USER_EMAIL`, `TEST_USER_PASSWORD` values are never command arguments. The script creates fresh UUID-named fixtures and restricts cleanup to their IDs/paths. Remove local test-password entries after testing if no longer needed; do not share them in chat.
