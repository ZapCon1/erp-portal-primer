---
name: perp-build-core
description: Build the entire core app skeleton in one pass from the /perp-scope answers — both shells, dashboards, settings, the spine's screens in the shop's vocabulary, portal faces, sample data, dev-mode sessions — then run it and hand over the URL. Run immediately after /perp-scope. The owner's first interaction should feel like magic.
---

# Build Core — the magic moment

The adopter has just finished `/perp-scope`. They have little to no
software experience. This skill turns their answers into a **running,
clickable app** in one pass — no plumbing questions, no login screens,
no "what framework do you want" — and ends with a URL and one question:
*"what should we make real first?"*

Canonical spec: `docs/DOMAIN_MODEL.md` § "What to build first" (Phase
One). This skill is its executable form. The stack is decided
(`docs/STACK.md`); don't relitigate any of it.

## Preconditions

Check these **before writing any file** — a scaffold that dies halfway is
the worst outcome this skill can produce, and every one of these is knowable
in advance.

- `docs/SCOPE.md` exists (else: run `/perp-scope` first — say so, one
  line, and offer to).
- **The toolchain is present**: `node --version` (LTS or newer), `npm`,
  `git`. For the database, either a reachable Postgres or Docker to run
  one. **If anything is missing, stop before step 1** and say in plain
  language which single thing to install and where to get it. The owner
  is a machinist, not a developer — "npm: command not found" mid-build
  reads as *the kit is broken*, not *Node isn't installed*.
- **Postgres is required, not preferred.** Do not fall back to SQLite: the
  pinned integrity constructs — the locked invoice counter
  (`SELECT … FOR UPDATE`), the immutability trigger, and pg-boss itself —
  do not exist there, and Prisma's SQLite connector rejects the `enum`
  blocks step 2 mandates. A build on SQLite cannot satisfy this skill's
  own schema step. Offer `docker compose up -d db` instead.
- **Existing app code?** If the repo has real source beyond this kit, STOP —
  `/perp-feature` drives incremental work. **Exception: a previous run of
  this skill that didn't finish.** If the only commits are this skill's own
  (`build-core: step N`), that is a resumable failure, not a brownfield
  repo — resume from the first incomplete step rather than refusing.

## If the build fails partway

Commit after each numbered step, message `build-core: step N — <what>`, so
every step boundary is a restore point.

If a step fails twice, **stop**. Don't loop. Say plainly which step broke and
what the error was, then offer exactly two options in the owner's language:

> Step 6 of 11 didn't finish — the database rejected the schema. Nothing is
> lost and nothing is broken. I can either **fix just that piece and carry
> on**, or **undo everything and start clean** (`git reset --hard <the
> commit before step 1>`).

Never leave the default branch non-building without saying so. Never end a
failed run with the success handoff script — the scripted URL line at the end
of this skill is for a build that actually runs.

## What to build (one pass, no questions until the end)

Work from SCOPE.md, BRAND.md, and the feature index — every naming and
scoping decision was already made in the interview; do not re-ask.

1. **Scaffold the app** on the default stack (Next.js App Router + TS
   strict + Prisma + Postgres, per STACK.md's pinned conventions:
   `(app)/` + `portal/` route groups, shared `lib/`, `import
   'server-only'` on DB modules, route handlers as the one mutation
   door). **Postgres, always** — the preconditions above already
   established one is reachable, and the integrity constructs the schema
   step depends on do not exist anywhere else.
2. **Schema**: Client, User, ClientPoc, CompanySettings, and the spine
   in the shop's vocabulary (Project/Job, Phase, Task, plus the
   pain-point entity — e.g. Quote/Estimate — as SCOPE.md names them),
   with `promisedDate`/`dueDate` and the tenancy `clientId` columns
   from this first migration. Statuses are enums, money is integer
   cents — the invariants apply from the first migration, not later.
3. **Both shells**: staff side nav + portal frame. Brand colors from
   `docs/BRAND.md` (the accessible text variants where recorded).
4. **Both dashboards**: staff home with the **pain-point lead tile**
   top-left (from SCOPE.md § First slice) + the universal staples (jobs
   in motion, unapproved time, overdue invoices) as honest empty-state
   tiles; portal dashboard per `docs/PORTAL_UX.md` § Portal dashboard hierarchy.
   **The lead tile is a doorway, not the destination**: the pain-point
   feature also gets its **own side-nav page** (next step), and the
   tile links to it. A pain point that lives only as a dashboard tile
   tells the owner their #1 problem is a widget.
5. **Settings page**: the CompanySettings row, **pre-filled from the
   interview** (display name, logo, timezone, payment terms).
6. **Spine screens WITH working create/edit**: list + detail for
   clients and the work spine, the pain-point feature front and center
   — in their vocabulary ("Quotes", not "Estimates", if that's what
   they said). **Every list has its obvious "+ New" button, and it
   works** — basic CRUD (add/edit a customer, a job, a quote with line
   items) is usability, not business logic. Entering a *real* customer
   next to the sample one on day one is the magic. **The pain-point
   feature is a first-class nav destination** with its own page, not
   just a tile — pain = "keeping track of quotes" → a Quotes page;
   pain = scheduling/dates → a **Schedule page** (skeleton form: jobs
   ordered by promised date, grouped by status — the
   dispatch-by-work-center view arrives when routing lands in Phase
   Two). What stays Phase Two: money math, approvals, generation,
   sending — a quote can be *created* day one; it can't be *accepted
   into a project* yet.
7. **Helper banners on every screen, both surfaces** — a dismissible
   one-liner per view saying what this screen is and the one action to
   try ("This is your quote list — add your first real quote with
   + New Quote"). One shared component (parity), content in the shop's
   vocabulary. It teaches the customer later, but on day one it
   teaches the *owner* how to use the app they're building — and where
   dev-mode ends and real features begin ("Invoices are view-only for
   now — making them real is a next step").
8. **Portal faces** of everything SCOPE.md § The portal says customers
   see — same shared `lib/` helpers as the staff views (parity from
   birth), tenant-filtered by `clientId` from the very first query.
9. **Sample data** — a seed script minting one clearly-fake client
   ("Sample Manufacturing Co."), a job, a quote, a few tasks — in their
   vocabulary, every record visibly labeled **SAMPLE**. Every screen is
   alive; nothing is a wall of empty states. Provide the one command
   that deletes it all (`npm run sample:reset` or similar).
10. **Dev-mode sessions — the security spine stays intact**:
   - **Every route goes through the real auth wrappers from the first
     route** (`withPermission` / `withPortalAuth` per
     `secure_coding.md` § 2-3). Dev mode stubs the *session* behind
     them: one fake staff user; one fake portal POC carrying the sample
     client's real `clientId`.
   - A permanent, unmissable **"DEV MODE — no login"** banner on every
     page of both surfaces while active.
   - A realm switcher (staff view ⇄ "view as your customer") so the
     owner can feel the portal — this is the parity rule made tangible
     on day one.
   - **The stub must be unable to run in production** (`SEC-2`). Write
     the assertion in the auth module *in this pass*, not later:

     ```ts
     if (process.env.NODE_ENV === 'production' && AUTH_MODE === 'dev') {
       throw new Error('dev auth stub is active in production — refusing to start')
     }
     ```

     Refuse to boot; never degrade to "log a warning". This is the one
     line that turns a go-live checkbox into a control, and it costs
     nothing today. `/perp-check` gates on its presence.
   - What is NEVER acceptable, dev mode or not: a route without a
     wrapper, a portal query without a tenant filter, secrets in
     client bundles. Real login (both realms) is a **hard gate before
     anyone but the owner touches the app, and always before go-live**
     (`docs/CONTROLS.md` § Go-live gates).
   - **The realm switcher is dev-mode only** — it disappears with the
     DEV MODE banner. If it ever graduates into a real support feature,
     it needs a permission, a persistent banner naming the client being
     viewed, and an audit entry recording the real actor and the
     assumed `clientId` (`AUDIT-1`) — it is tenant impersonation.
11. **Verify and run**: typecheck + build must pass (fix, don't ship
    broken); start the dev server; hand over the URL.
12. **Write down what you built.** Fill `CLAUDE.md` § Dev Server (the run
    command, the port, the typecheck command) and the § Tech Stack hosting
    line if it was decided, and tick the Bootstrap "confirm the default
    stack" box. Without this, the very next session reads an unfilled
    `<TODO>`, obeys § Verification Habits ("don't guess"), and tells the
    owner verification is unconfigured on a repo they just watched build
    and run — a contradiction a non-developer cannot resolve.

## The design bar — the skeleton must be sexy

The magic moment is mostly visual: the same screens read as "programmer
demo" or "my company's software" depending entirely on polish. The bar:
**looks like a product someone would pay for, on the first run.**

- **Design tokens once, then never per-component**: pick the type scale,
  spacing rhythm (one consistent 4/8px system, generous whitespace),
  radius, and shadow language up front — shadcn/ui's defaults tuned to
  the brand, in the Tailwind config, not sprinkled inline.
- **Real typographic hierarchy**: one confident display size on
  dashboards and page titles, clear secondary/label tiers. If every
  text is 14px gray, it's a demo.
- **The brand carries the room**: BRAND.md's palette on the sidebar
  accent, active states, and the dashboard — using the accessible text
  variants where recorded. Logo in the shell. The portal must feel like
  the same family, tuned quieter (customers get calm; staff get dense).
- **The dashboard is the showpiece**: stat tiles with hierarchy — big
  number, quiet label, status color paired with text (never color-only,
  PORTAL_UX rule) — not uniform gray boxes.
- **Empty states are designed, not blank**: icon + one warm line + the
  action ("No quotes yet — + New Quote starts your first"). The helper
  banner styled as part of the system, and the DEV MODE banner a
  deliberate badge, not an eyesore.
- **The words are theirs, not the template's**: every sentence a person
  reads — empty states, button labels, confirmations, the sample
  transactional emails — runs through `/perp-voice` against
  `docs/VOICE.md`. This is the difference between "my company's
  software" and "a nice demo someone generated", and it costs one pass
  over copy you were writing anyway. The exclusions in `/perp-voice`
  § "Where voice applies" hold: security error text, a11y labels, and
  money/date/legal strings keep their canonical wording.
- **Motion, barely**: transitions on hover/focus/nav, nothing
  gratuitous.
- **Sample data is realistic** — "Sample Manufacturing Co. — 4× mounting
  bracket, $1,240.00", plausible dates — because real-looking data is
  half of looking real. "test 1 / $1" destroys the illusion.

This bar persists past day one: `docs/PORTAL_UX.md` § The visual bar.

## The handoff (script the moment)

End with exactly this shape — plain language, no tech inventory:

> Your app is running — open <URL>. Everything you see is filled with
> sample data (marked SAMPLE) so you can click around; the "DEV MODE"
> banner means there's no login yet — that's on purpose, and it goes
> on before anyone else ever touches this. Try the dashboard, open the
> sample quote, use "view as your customer" to see what they'd see —
> and **add one of your real customers with + New**; this is your app,
> it works.
>
> What should we make real first?

Then **one question at a time** from there, and `/perp-feature
<their-answer>` to plan the first make-it-real slice (DOMAIN_MODEL
§ Phase Two has the usual value order). Suggest `/perp-setup-testing`
before the first real money logic lands — sample-data clicking doesn't
need tests; the first real mutation does.

## Rules

- **No questions during the build.** The interview already answered
  them; "I'll use your answer about X" beats asking again. If something
  is genuinely undecided, use the documented default and note it in the
  handoff.
- **Don't gold-plate.** Skeleton means: real screens, real navigation,
  real schema, sample data — not real business logic. Money math,
  approvals, PDFs, emails are Phase Two.
- **Commit as you go** (`/perp-commit` conventions), and the sample
  seed + dev-mode stub are code like any other — reviewed, committed,
  reversible.
- The verification and portal-UX rules apply to the skeleton too:
  required states on every view (`docs/PORTAL_UX.md`), keyboard-usable,
  no color-only status.
