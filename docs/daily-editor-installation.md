# Daily product editor installation — clean complete file

The user-provided SQL Editor preflight confirms `media_service_present=true` and all eight daily-editor object/receipt booleans false. Migration 008 was not left partially installed. The earlier instruction to wait for preflight is now resolved. Do not rerun installers 00–05 or reset/drop existing objects.

Use `supabase/sql-editor/06_install_daily_product_editor_clean.sql`, generated completely from the single migration source. The canonical `06_install_daily_product_editor.sql` contains identical bytes. Generation overwrites the complete artifacts; it does not append a patch. Structural validation requires exactly four unique function declarations, five matched named-dollar-quote pairs, one receipt insert, one transaction/commit, one cache reload and one final SELECT. Evidence is in `daily-editor-installer-structure.json`.

1. Open the DEVELOPMENT project → SQL Editor → New query.
2. Paste the ENTIRE clean file into that empty query. Do not append it to an existing query containing an older installer or patch.
3. Run the complete query once. Both final booleans, `daily_editor_installed` and `count_audit_rls`, must be true.
4. Confirm application so the already authorized live single-product/two-option save and published/hidden preservation checks can run.

The first line is `-- CLEAN COMPLETE INSTALLER: daily editor v2. Replace the entire SQL Editor query; do not append.` The file ends with the single two-column verification SELECT. It keeps the corrected ordinary Save behavior: product and existing option statuses are preserved; Draft/Publish/Hide are explicit choices. Invalid published edits are rejected and rolled back.

The installer refuses any known installed or partial daily-editor state before creating objects. Its installation transaction does not update/delete existing product, variant, price, inventory, media, source or audit rows. Runtime functions can explicitly change fields or visibility only when an authorized administrator saves those choices. Optional concerns remain non-blocking; existing stock/source/audit protections remain.

The exact-file test command is:

```powershell
& 'C:/Users/mhazi/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' scripts/test_database.py --daily-editor-installer --daily-editor-file supabase/sql-editor/06_install_daily_product_editor_clean.sql
```

It creates a fresh disposable PostgreSQL 16 database, applies migrations 001–007 directly without earlier installers, seeds 121 drafts and executes the exact clean file with `psql -f`. Business snapshots, rollback, repeated-install refusal, read-only preflight and catalog/security/media/daily-editor regressions are checked. Auth/Storage are doubles in that local test, not hosted provider verification. The exact artifact SHA-256 and results are recorded in `daily-editor-exact-installer-verification.json`.

After confirmed development application:

```powershell
& '.tools/node-v24.21.0-win-x64/node.exe' scripts/verify-admin-usability.mjs --run-development
```

The live runner uses configured local test credentials without printing them. Only synthetic products, taxonomy records and neutral media are created/changed; existing catalog records and source stock remain intact. It tests actual browser saves, two options and published/hidden preservation, then archives synthetic history and invokes guarded media cleanup. It does not import/publish real products or change the storefront. Live write checks remain pending application; no new secret is needed.
