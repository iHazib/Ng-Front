# Versions and scripts

Verified on 2026-10-04 using official project documentation and npm package metadata.

| Component | Exact selection | Reason |
| --- | --- | --- |
| Node.js | 24.21.0 | Supported Node 24 LTS; pinned in engines, .nvmrc and .node-version |
| npm | 11.19.0 | Bundled with selected Node runtime; packageManager and engines pinned |
| Next.js | 16.3.8 | Current stable release shown by official documentation and registry; App Router |
| React / React DOM | 19.3.0 | Stable registry releases accepted by Next's React 19 peer range |
| TypeScript | 5.9.3 | Stable compiler compatible with Next and typescript-eslint; no prerelease/native compiler |
| ESLint | 10.12.0 | Supported major; ESLint 9 reached EOL on 2026-08-06 |
| @next/eslint-plugin-next | 16.3.8 | Next recommended/Core Web Vitals rules with standalone ESLint configuration |
| typescript-eslint | 8.71.0 | Supports ESLint 10 and TypeScript >=4.8.4 <6.1.0 |
| Playwright test | 1.63.0 | Browser checks for desktop/mobile; no external service |
| PostCSS / selector parser | 8.5.28 / 7.1.6 | Build-time reference CSS extraction/scoping |
| server-only | 0.0.1 | Import-time server boundary enforcement |
| Type definitions | Node 24.19.1; React/React DOM 19.3.0 | Compatible pinned types |

All direct dependencies use exact versions. Transitive versions/integrities are preserved in package-lock.json. Use npm ci to reproduce installation, not deletion/regeneration of the lockfile.

Dependency audit on 2026-10-04: `npm audit --omit=dev` reports zero vulnerabilities. The full audit reports four high entries in one development-only dependency chain: @next/eslint-plugin-next → fast-glob → micromatch → braces. [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) has no published patched braces version. This is lint tooling, not a storefront dependency; no user-supplied glob patterns are processed by the application. Keep the upstream issue visible and update when a compatible fix exists; do not run `npm audit fix --force`, which proposes an unrelated major downgrade of the Next plugin.

The standard eslint-config-next dependency tree includes React/JSX plugins whose declared peer ranges stop at ESLint 9. Use Next's officially documented standalone plugin with supported ESLint 10 and typescript-eslint instead of forcing conflicting peers or retaining an EOL linter. Lint is a separate command; Next 16 does not run it as part of build.

Official sources:

- [Next installation and requirements](https://nextjs.org/docs/app/getting-started/installation): Node >=20.9 and TypeScript >=5.1; manual initialization and App Router.
- [Next support policy](https://nextjs.org/support-policy): support lifecycle.
- [Node releases](https://nodejs.org/en/about/previous-releases): supported LTS runtime selection.
- [Official Node 24 archive checksums](https://nodejs.org/download/release/latest-v24.x/SHASUMS256.txt): local Windows ZIP verified as SHA-256 `158f7685b44de51f6c0df1d153526cbcd3e1bc739a8dfc607721cef75de9e541` before extraction.
- [Next ESLint configuration](https://nextjs.org/docs/app/api-reference/config/eslint), [ESLint support](https://eslint.org/version-support/), [TypeScript ESLint shared configs](https://typescript-eslint.io/users/configs/).
- [Next proxy](https://nextjs.org/docs/app/api-reference/file-conventions/proxy), [Playwright configuration](https://playwright.dev/docs/test-configuration).

## Commands

Use Node 24.21.0 and npm 11.19.0. A checksum-verified portable runtime is retained locally under ignored `.tools/node-v24.21.0-win-x64`; it is not an app dependency or committed runtime. On this Windows checkout, prepend that folder to PATH for the current terminal, then use npm.cmd. Other machines can use a Node version manager with .nvmrc.

| Script | Purpose |
| --- | --- |
| npm ci | Install exact lockfile dependencies |
| npm run dev | Loopback development at http://127.0.0.1:3000; /reference available |
| npm run lint | TypeScript and Next rules; warnings fail |
| npm run typecheck | Generate Next route types, then strict TypeScript check |
| npm run build | Production compilation; removes generated development reference route |
| npm start | Loopback production-mode preview; requires server preview credentials |
| npm run styles:extract | Regenerate scoped CSS/tokens from unchanged final reference |
| npm run sources:check | Verify all 64 supplied files and generated CSS against source |
| npm run check | Source preservation, lint, typecheck, build |
| npm run test:browser | Launch dev server at port 3100, compare foundation at desktop/mobile sizes and check media contracts |
| npm run test:production | Use existing build; ephemeral local credentials; verify fail-closed/auth/asset protection, noindex, production sample guard and reference exclusion |

For default Playwright Chromium, install its browser using `npx playwright install chromium`. Alternatively set PLAYWRIGHT_CHANNEL=msedge for installed Microsoft Edge or chrome for installed Chrome. Browser tests are local; they do not require an account. Reports/screenshots live under ignored test-results. Do not run the browser suite and a build simultaneously: the dev-only route lifecycle and Next outputs share this checkout.

The source-preservation gate includes ignored initial imports. A fresh clone must restore those unchanged files from the original package to run that particular audit. App build/runtime never reads the import workbook or temporary image folder.

Production builds and `typecheck` use tsconfig.build.json, which checks source, tests and the reference handler template against freshly generated production route types. It excludes stale .next/dev output, since the development-only /reference route is deliberately absent from production. Development keeps its own generated route types under .next/dev. Strict checks stay enabled in both configurations. next-env.d.ts is framework-generated and Git-ignored as required by the installed Next.js TypeScript guide.

Next dev generated AGENTS.md and CLAUDE.md. They are retained; the relevant installed Next.js guides must be consulted before future implementation changes.
