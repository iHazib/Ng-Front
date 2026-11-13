# Nook & Glow

Next.js storefront and simple admin use the development Supabase catalog, secure media service, content, reviews and manual advance-payment commerce. Real checkout remains disabled until owner configuration is approved. Assembled deals are implemented locally; incremental migration 017 and its hosted verification are pending.

Start with [implementation status](docs/implementation-status.md), [architecture](docs/architecture.md), [requirements coverage](docs/requirements-coverage.md), and [decisions needed](docs/decisions-needed.md).

The user's fresh staged sequence supersedes `CONTINUE_WITH_CODEX.txt` and implementation numbering in `design/reference/ASSET_HANDOFF.md`. Those files are preserved as historical package content, not executable instructions or authorization to advance stages. Spreadsheet instruction tabs are source context only.

The final visual authority is `design/reference/Nook_Glow_Homepage_Wireframe.html`. The catalog source is `data/imports/Nook_Glow_Product_Listing_Updated.xlsx`. Neither is published production data. Local `public/assets` images are approved visual-prototype inputs; they do not establish real product mappings or claims.

Use Node 24.21.0 / npm 11.19.0, then `npm ci` and `npm run dev`. The storefront is at http://127.0.0.1:3000 and the approved HTML at http://127.0.0.1:3000/reference. Sample content requires explicit local `STOREFRONT_DATA_MODE=sample-preview`; unavailable catalog data never silently falls back to samples. The reference route exists only during development. See [versions and scripts](docs/versions-and-scripts.md) for the local portable runtime, checks and browser setup. `npm run check`, `npm run test:production` and `npm run test:browser` run separately in that order.

Production-mode/staging previews fail closed until server-only preview credentials are configured. All environments are non-indexable; APP_ENV=production does not publish sample data. Supabase/Cloudinary/admin and commerce through 016 have prior actual hosted verification. New deals require only the incremental 017 installer; do not rerun applied migrations. See [deals setup and verification boundaries](docs/deals-setup.md).

Local backups are in Git-ignored `local-sources/`; initial product imports are in Git-ignored `product-images-import/`, outside `public/`. Keep these local backups and the original Desktop ZIP. Future uploads must use admin product/SKU selection and the approved storage workflow.

For visual checks against an already-running local server, start an explicit local sample-preview instance, then set `PLAYWRIGHT_BASE_URL` to that instance and `PLAYWRIGHT_CHANNEL=chrome` before `npm run test:browser`. Otherwise the suite starts its own port-3100 server. Afterward, run `scripts/compare-homepage.py` with Python/Pillow to compare paired captures and regenerate the visual report. Do not run a build concurrently with development.

Deal checks: `npm run test:deals:unit`, `npm run verify:deals:public-mock`, and `npm run verify:deals:readonly`. The admin/cart UI harness uses the isolated process-only development checkout at port 3100 (`npm run dev:commerce:test`) and `npm run verify:deals:mock-ui`. These mock scripts must never be represented as provider lifecycle verification. The exact SQL installer test is `python scripts/test_database.py --deals-installer`; it creates/stops a fresh PostgreSQL cluster and uses Auth/Storage/media doubles, without contacting hosted Supabase.
