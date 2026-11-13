# Supabase service verification — 2026-10-05

Latest result: actual authenticated verification completed with **45 passed checks**; see [current service and wrapper report](supabase-authenticated-verification.md). Both logins, roles, known-row RLS and private-file access were exercised and synthetic fixtures removed. Earlier missing-account/runtime statuses below are historical. Real catalog import remains unperformed.

## Subsequent configured-project read-only check

The user supplied `.env` with the project URL and publishable key. Git ignores this file; no values were printed. A network-enabled read-only check returned Auth health HTTP 200, REST root HTTP 401 and `GET /rest/v1/products?select=id&limit=1` HTTP 404 / `PGRST205` (products unavailable in the exposed schema cache). This verifies reachability, not login, schema installation or RLS correctness. The REST-root denial alone is not a key-validation conclusion. Database connection credentials/admin sessions remain unavailable, and development-only project identity has not been confirmed. No mutations were performed. Earlier absence-of-configuration statements below describe the initial attempt.

## Actual results

| Check | Result |
| --- | --- |
| Previous disposable PostgreSQL migrations/import/RLS tests | Passed previously: six migrations, 121 drafts, repeat no-op, 54 SQL assertions |
| Docker availability on this attempt | Docker Desktop was stopped; launch succeeded, but engine health check timed out after 20 seconds |
| Supabase CLI | Not installed; npm registry lookup failed with EACCES; official v2.119.0 release verified through the web |
| Source preservation on this attempt | Passed: all 64 supplied files byte-identical; all 14 reference CSS blocks match |
| Separate development-project configuration | No `.env.local` or Supabase environment variables present; no remote database contacted |
| Actual Supabase migrations | Pending |
| Actual Auth login, token validation and admin authorization | Pending |
| Actual PostgREST anonymous/non-admin/admin access | Pending |
| Actual private Storage upload/read/list/delete | Pending |
| Draft import via actual PostgREST | Pending |

The earlier SQL test doubles do not count as real Supabase service verification. No existing database was reset or modified. Docker Desktop was launched; no Supabase stack was created. Application code, migrations, dependencies, lockfile and supplied source assets were not changed in this attempt.

## Fresh local stack — no reset

First finish Docker Desktop setup on this Windows machine. Enable its Linux-container/WSL2 engine as appropriate in Docker Desktop and resolve any startup error it displays. Continue only when `docker info --format '{{.ServerVersion}}'` returns a server version. Do not reset Docker or delete existing containers/volumes to make this test work.

The following uses a new random directory/project identity and the CLI's documented isolated-stack support. Version 2.119.0 is pinned to its official release; the stack feature is experimental. It is installed only in ignored local tooling, preserving the app's package files. Run from the repository root:

```powershell
$repo = (Get-Location).Path
$env:PATH = (Join-Path $repo '.tools/node-v24.21.0-win-x64') + ';' + $env:PATH
$verificationId = 'ng-verify-' + [guid]::NewGuid().ToString('N')
$verificationRoot = Join-Path $repo ('.local/' + $verificationId)
New-Item -ItemType Directory -Path (Join-Path $verificationRoot 'supabase') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'supabase/migrations') -Destination (Join-Path $verificationRoot 'supabase/migrations') -Recurse
$verificationConfig = Get-Content -Raw -LiteralPath (Join-Path $repo 'supabase/config.toml')
$verificationConfig = $verificationConfig -replace 'project_id = "nook-glow-local"', ('project_id = "' + $verificationId + '"')
$verificationConfig = $verificationConfig -replace '(?m)^(port|shadow_port)\s*=.*\r?\n', ''
$verificationConfig += "`n[experimental]`nstack = true`n"
[IO.File]::WriteAllText((Join-Path $verificationRoot 'supabase/config.toml'), $verificationConfig)
npm.cmd install --prefix $verificationRoot --save-exact supabase@2.119.0
if ($LASTEXITCODE -ne 0) { throw 'CLI installation failed; stop here.' }
$verificationCli = Join-Path $verificationRoot 'node_modules/.bin/supabase.cmd'
Push-Location $verificationRoot
& $verificationCli --version
& $verificationCli start *> (Join-Path $verificationRoot 'startup.private.log')
if ($LASTEXITCODE -ne 0) { throw 'Stack startup failed; inspect the private local log.' }
& $verificationCli migration up --local *> (Join-Path $verificationRoot 'migration.private.log')
if ($LASTEXITCODE -ne 0) { throw 'Migration application failed; stop verification.' }
& $verificationCli status --env --output-format text > (Join-Path $verificationRoot '.env.local')
Pop-Location
```

Do not run `db reset`, remote `db push`, project linking, Docker prune or stack destroy. A failed start should be investigated locally; do not fall back to an existing project. Default stack identity in this new directory is deliberate: the documented migration commands do not target named stacks. The first start may already apply migrations; `migration up --local` applies only pending versions.

Keep startup/status output private because it includes local keys. Open the generated local env file yourself; do not paste it into chat. CLI output names are `API_URL`, `DB_URL`, `PUBLISHABLE_KEY`, `SECRET_KEY`, `ANON_KEY`, `SERVICE_ROLE_KEY`. The last three privileged/legacy values are not needed by the application access layer.

Configure these **existing application names** in a private `.env.local` if testing the server access layer, without connecting the storefront:

| Variable | Value/source |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Fresh stack's `API_URL` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Fresh stack's `PUBLISHABLE_KEY` |
| `SUPABASE_DB_URL` | Fresh stack's `DB_URL`; owner-only migration/test connection |
| `SUPABASE_SECRET_KEY` | Leave unset; current access layer does not use it |

No Cloudinary, courier or payment credentials are needed. `PREVIEW_USERNAME` / `PREVIEW_PASSWORD` remain relevant only to existing non-development preview protection, not database roles.

## Service verification procedure

Use only the Studio/API/database URLs emitted for this new stack. Studio's Auth users screen can create two synthetic confirmed-email users with unique passwords: one admin candidate and one ordinary user. Do not reuse a real customer's account. Signups stay disabled. In this stack's SQL editor, grant only the verified candidate UUID:

```sql
insert into app_private.admin_members(user_id, reason)
values ('<verified synthetic Auth user UUID>', 'Isolated service verification');
select version from supabase_migrations.schema_migrations order by version;
```

Expect migration versions `202610050001` through `202610050006`. Do not paste arbitrary UUIDs or grant roles through user metadata.

For HTTP testing, use a local REST client with secrets masked. Set a private environment with `TEST_SUPABASE_URL`, `TEST_SUPABASE_PUBLISHABLE_KEY`, `TEST_ADMIN_EMAIL`, `TEST_ADMIN_PASSWORD`, `TEST_USER_EMAIL`, `TEST_USER_PASSWORD`. These `TEST_*` names are REST-client inputs, not app configuration. Save returned tokens only as private `TEST_ADMIN_ACCESS_TOKEN` and `TEST_USER_ACCESS_TOKEN`; do not print tokens, login responses or request headers in reports.

Every request includes `apikey: <TEST_SUPABASE_PUBLISHABLE_KEY>`. Authenticated requests also include `Authorization: Bearer <matching access token>`. Anonymous requests omit Authorization. JSON requests use `Content-Type: application/json`.

1. **Auth**: for each user, `POST /auth/v1/token?grant_type=password` with their `email` and `password`. Expect 200. With the resulting token, `GET /auth/v1/user` must return the same user UUID. A corrupted token must return 401. `POST /rest/v1/rpc/is_admin` with `{}` must return true only for the provisioned admin.
2. **Draft import**: admin `POST /rest/v1/rpc/import_catalog_drafts`, body = the complete existing private `data/catalog-dry-run/database-payload.json`. Expect `accepted:121`, `quarantined:0`. Repeat the identical request; expect `state:unchanged` and the same batch ID. Ordinary/anonymous attempts must fail (401/403), never import.
3. **Admin search/read**: admin `POST /rest/v1/rpc/admin_search_catalog` with `{"p_query":"","p_limit":200,"p_offset":0}` must return 121 rows without requiring media. Admin `GET /rest/v1/variants?select=id,original_sku` must return all 121. Repeat search for `DANM - 001`; confirm exact original spelling. Confirm missing SB-001 price remains null in private import records and source quantity sum remains 270 using owner SQL.
4. **Public/non-admin RLS**: for both anonymous and ordinary-user identities, `GET /rest/v1/products?select=id` and `GET /rest/v1/variants?select=id` must return `[]`. Public `POST /rest/v1/rpc/search_published_catalog` with `{"p_query":"blush"}` must return `[]`. Reads of orders/import_records/audit_logs must return no rows or permission denial, never private data. Non-admin admin-search and stock RPC calls must fail. Attempting `POST /rest/v1/products` with `{"name":"unauthorized"}` must fail. The `app_private` schema must not be API-exposed; user metadata changes cannot change `is_admin`.
5. **Private Storage**: create a tiny neutral test file locally, no customer content. Admin `POST /storage/v1/object/catalog-private/service-verification.txt` with its bytes and `Content-Type: text/plain` must succeed. Admin `GET /storage/v1/object/authenticated/catalog-private/service-verification.txt` must return identical bytes. Admin `POST /storage/v1/object/list/catalog-private` with `{"prefix":"","limit":100}` must list it. Anonymous/non-admin download must fail; listing must deny or omit it; uploading a different path must fail. `GET /storage/v1/object/public/catalog-private/service-verification.txt` must fail even for a logged-in admin. Admin `DELETE /storage/v1/object/catalog-private` with `{"prefixes":["service-verification.txt"]}` removes only that synthetic object.
6. **Access-layer authorization**: invoke the server-only `authorizeAdmin` through a local server test harness (not a public route). Admin succeeds; ordinary/corrupted tokens fail. Exercise `importAdminDrafts` and `searchAdminCatalog` with the same fixtures. Direct HTTP tests alone do not mark this wrapper check passed.
7. **Repeat safety**: in this synthetic stack, use `adjust_inventory` for one draft SKU and record its balance. Send a changed-source envelope with new source/contract hashes and a changed source quantity, retaining original UUIDs/SKU. Verify live balance, admin-edited content and current price are unchanged. No fixture is published and no real order or shipment is created.

Record status codes, counts and assertion outcomes only, never tokens/customer/source-cost payloads. Keep a separate pending status for each step that did not run. Stop this stack without deletion from its own directory with `supabase stop` using the local pinned executable; leave existing stacks alone.

## References

- [Official CLI release v2.119.0](https://github.com/supabase/cli/releases/tag/v2.119.0)
- [Isolated local projects and dynamic ports](https://supabase.com/docs/guides/local-development/running-multiple-local-projects)
- [CLI setup and Docker prerequisites](https://supabase.com/docs/guides/local-development/cli/getting-started)
