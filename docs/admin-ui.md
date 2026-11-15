# Admin interface

The store administration panel lives entirely under `src/app/admin` and
`src/components/admin`. It is a private, authenticated surface and is never
indexed.

## Structure

| Piece | File | Purpose |
|---|---|---|
| Shell | `src/components/admin/AdminShell.tsx` | Rail, top bar and content frame; renders the sign-in layout separately |
| Navigation | `src/components/admin/AdminNavigation.tsx` | Rail links with icons plus the account/tools menu |
| Design system | `src/app/admin/admin.css` | Tokens, shell, controls, surfaces and status language |
| Layout | `src/app/admin/layout.tsx` | Server entry that mounts the shell and the stylesheet |

The shell is a client component because it reads the current path to highlight
the active section. Everything else keeps its existing behaviour.

## Design principles

- **One shell.** A fixed rail on the left, a sticky context bar on top, and a
  single scrolling content column. On narrow screens the rail becomes a
  horizontally scrollable strip so no layout shift is needed.
- **Tokens, not one-off values.** Colour, radius, shadow and spacing are
  declared once on `.ng-admin` and consumed everywhere below it.
- **Clear action hierarchy.** `.btn-secondary`, `.btn-ghost`, `.btn-publish`,
  `.btn-danger` and `.btn-sm` distinguish a primary action from a supporting
  one without changing any button label or accessible name.
- **Status is never colour-only.** Every state also carries a text label.
- **Motion is optional.** All transitions are disabled under
  `prefers-reduced-motion`.

## Scope guarantees

The redesign is presentation only.

- No route, API handler, database call, migration or permission rule changed.
- Every `aria-label`, button label, role and status message is unchanged, so
  the admin verification suites remain valid.
- The storefront styles and the supplied reference blocks are untouched;
  `npm run sources:check` still verifies them byte for byte.

## Verification

| Suite | Covers |
|---|---|
| `scripts/verify-admin-list-ui-mock.mjs` | Catalog list, filters, reminders, pagination, mobile overflow |
| `scripts/verify-admin-refresh-ui-mock.mjs` | Product editor, articles, homepage, reviews, storefront product page |
| `npm run lint`, `npm run typecheck`, `npm run build` | Static correctness and production build |

Both mock suites render the real application against local provider doubles,
assert the documented DOM contract and capture desktop and mobile screenshots
into `.local/admin-list/` and `.local/admin-refresh/`.
