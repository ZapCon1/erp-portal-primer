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

## Required states — every view ships all of these

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

5. **Truncated** — any paged or capped list says so: a count, a cursor
   control, or "showing 20 of 143". `docs/DOMAIN_MODEL.md` § Scale notes
   requires list endpoints to take a limit from day one; if the UI never
   says a limit was applied, a customer looking for a 2023 invoice concludes
   it doesn't exist. **A silent first page is a data-loss bug, not a layout
   choice** — and it is exactly the kind of disagreement between surfaces
   `CLAUDE.md` § Parity calls trust-destroying.
6. **Success** — a mutation that appears to do nothing has failed as far as
   the user is concerned. Show a visible confirmation and announce it in a
   live region (a silent repaint is invisible to a screen reader).
7. **Destructive confirm** — name the object in the prompt ("Delete job
   ABC2601?"), make Cancel the default action, and if there is no undo, say
   so in the prompt.

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

**Target: WCAG 2.2 Level AA.** That is what ADA settlements and EN 301 549
(the standard the European Accessibility Act points at) both resolve to, and
it is the answer to give a customer's procurement team or a VPAT request.
The rules below are this project's high-frequency subset — they are not a
substitute for the standard. The EAA also expects a covered service to
publish an **accessibility statement**; add that page before go-live.

- **Semantic HTML**: real `<button>`, `<a>`, `<label>`, `<table>`
- **Financial tables need more than `<table>`**: a `<caption>`, `<th scope>`
  on row and column headers, and header association — otherwise a screen
  reader reads invoice lines as a stream of unlabelled numbers.
- **Money-moving actions are confirmed or reversible** (WCAG 3.3.4, which
  exists specifically for legal and financial transactions): a review step
  before "Pay", or an undo after it.
- **Session expiry warns before it happens** with a way to extend (WCAG
  2.2.1) — portal magic-link sessions do expire, and silently losing a
  half-filled form is the failure this prevents.
- **Reflow at 400% zoom / 320px** without two-axis scrolling. Wide financial
  tables are where this breaks, and the portal is explicitly a phone and
  shop-tablet surface.
- **Per view**: a unique `<title>`, one `<h1>`, headings in order, a skip
  link, and `<html lang>`. — no
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

## Documents customers receive (PDFs)

The invoice is the artifact the portal exists to deliver, and it has legal
and financial consequence — so it is inside the accessibility baseline, not
beside it.

- **`@react-pdf/renderer` cannot emit tagged PDFs.** An untagged PDF has no
  document structure, no reading order and no table headers: a screen reader
  gets unstructured characters, which for money is worse than nothing.
- **Ship an accessible path either way**: render the PDF through the
  Chromium fallback (`docs/STACK.md`) with tagging enabled, **or** publish an
  HTML view of the same invoice at a stable URL, generated from the same
  money helpers the PDF uses. The HTML route is usually cheaper and it
  satisfies parity for free.
- Set the document `Lang`, give it a real title, and never encode status by
  color alone in a document someone may print in greyscale.

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

### Default tokens — real values, so "designed" is checkable

Zero concrete values makes "the skeleton must be sexy" unspecifiable and two
runs of `/perp-build-core` produce two unrelated-looking apps. These are
brand-neutral defaults; `docs/BRAND.md` overrides the accent only.

```
Type scale   12 / 14 / 16 / 20 / 28 / 36px   weights 400, 500, 600
             body 14–16px, line-height 1.5; headings 1.2
Spacing      4 8 12 16 24 32 48 64  (one 4px rhythm — no 5s, no 13s)
Radius       6px controls · 10px cards
Shadow       rest  0 1px 2px rgb(0 0 0 / .06)
             float 0 4px 12px rgb(0 0 0 / .10)
Neutrals     #0F1115 ink · #3A4150 body · #6B7382 muted
             #E4E7EC border · #F6F7F9 surface · #FFFFFF card
Semantic     success #0F7B4F · warning #9A6400 · danger #B3261E · info #1B5FB0
             (all ≥ 4.5:1 on white; pair every one with text or an icon)
```

**Status chips — one canonical mapping, both surfaces.** The statuses are
discriminated unions in the domain model; their appearance must be equally
canonical, or "overdue" ends up amber on the dashboard and red in the list.

| Status | Label | Tone |
|---|---|---|
| draft | Draft | neutral |
| sent | Sent | info |
| paid | Paid | success |
| overdue | Overdue | danger |
| accepted | Accepted | success |
| declined / expired | Declined · Expired | neutral |

**Theme:** light only in Phase One. The token layer is what makes dark a
later swap — until then, "check contrast on dark backgrounds" is checking a
surface that doesn't exist.

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
