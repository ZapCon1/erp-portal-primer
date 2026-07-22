# Portal UX & Accessibility Baseline

Parity keeps the *numbers* honest across surfaces; this doc keeps the
*experience* honest. The customer portal is used by arbitrary employees of
your customers — people you've never met, on devices you don't control.
**MUST be followed for any UI work on 👤 portal or 🌐 public surfaces**;
recommended for 🛠 internal too.

> Legal note: a business-facing portal with invoices/payments is ADA
> litigation territory in the US, and the EU European Accessibility Act
> (in force June 2025) covers exactly this class of portal. Accessibility
> here is exposure management, not polish.

## Required states — every view ships all four

1. **Empty** — zero projects, zero invoices, the brand-new client's first
   login. Say what will appear here and (if applicable) what action creates
   it. An empty table with no explanation reads as "broken."
2. **Loading** — skeleton or spinner; never a blank page while a rollup
   computes.
3. **Error** — generic message (per `secure_coding.md` § 6), plus a
   **request ID** and a contact/next-step affordance. A dead end with
   "Operation failed" is a guaranteed support ticket with no exit.
4. **Partial** — optional data missing (no phases yet, no payments yet)
   renders as an explained gap, not a layout collapse.

## Error copy mirrors the security semantics

- Never reveal another tenant's existence in copy, URLs, or autocomplete —
  the 404-not-403 rule (`secure_coding.md` § 4) applies to words too.
- Expired/used magic links land on a page with a "request a new link"
  action (see `secure_coding.md` § 13) — never a bare error.
- **Voice never overrides these.** Customer-facing prose runs through
  `/perp-voice` (`docs/VOICE.md`) so the portal sounds like the shop
  rather than like a template — but error text, a11y labels, and
  money/date/legal strings are excluded from that pass. Personality in a
  404 is how a tenant leak starts.

## Accessibility baseline

- **Semantic HTML**: real `<button>`, `<a>`, `<label>`, `<table>` — no
  div-buttons, no click-handlers on spans.
- **Keyboard**: every action reachable and operable by keyboard; modals
  trap and restore focus; visible focus indicator.
- **Forms**: every field labeled; validation errors programmatically
  associated with their field, not just colored red.
- **No color-only signaling**: status chips (draft/sent/paid/overdue,
  project health) pair color with text or icon.
- **Contrast**: 4.5:1 for text; check the status-color palette against
  both light and dark backgrounds. (Brand colors from `docs/BRAND.md`
  often fail as text — use the accessible variants it records.)
- **Non-text content has a name**: images and file thumbnails carry
  meaningful alt text or an accessible name (part number + revision
  beats decorative silence); the CAD viewer canvas is named and always
  accompanied by a persistent "download original" link (the
  screen-reader path — see STACK.md § Part viewing).
- **Async status changes are announced**: conversion status
  (pending→ready/failed), payment results, and similar updates go
  through a live region — a silent repaint is invisible to a screen
  reader, and axe won't catch this one.
- **Touch targets ≥ 44px** on portal views — the portal's real-world
  device is a phone or a shop-floor tablet on Wi-Fi.
- **Automated scan**: run axe/pa11y (or equivalent) against each portal
  page template — wire it into `/perp-check` (see that command's optional
  step). Automated scanning catches ~40% of issues; the keyboard walk
  catches most of the rest.
- **E2E golden paths keyboard-only**: login, view an invoice, pay — per
  `testing-conventions.md`, these earn their E2E place.

## The visual bar (both surfaces)

The app should look like a product someone pays for — from the first
`/perp-build-core` run onward, not as a later polish pass:

- **Tokens once**: type scale, spacing rhythm, radius, shadows live in
  the design config (Tailwind/shadcn theme), tuned to `docs/BRAND.md` —
  never restyled per-component. Drift in padding and focus rings is the
  visual version of two formulas for one number.
- **Hierarchy**: every screen has one clear primary element; dashboards
  lead with confident stat tiles (big number, quiet label, color paired
  with text).
- **Empty states are designed** (icon + one warm line + the action),
  and system banners (helper, DEV MODE) are styled parts of the system.
- **Two surfaces, one family**: the portal is the same design language
  tuned quieter — customers get calm and legible; staff get density.
  Shared components carry the consistency (CLAUDE.md § Parity).

## Mobile

Portal read views (dashboard, project status, invoice) must work on a
phone — customers check invoices from email, and email is read on phones.
Internal-app density is fine on desktop; the portal is not the internal app.

## Portal dashboard hierarchy

Three levels, in this order: **money owed** (open invoices, amount, due
date) → **action needed** (estimate awaiting acceptance, sign-off pending,
file requested) → **status** (project health, recent activity). The
customer's question is always "do I owe anything, do you need anything from
me, is my job on track" — in that order.

## Share UI across surfaces

Anything rendering the same concept on both surfaces uses the shared
component (CLAUDE.md § Parity) — this doc's states/a11y rules then apply
once, not twice.
