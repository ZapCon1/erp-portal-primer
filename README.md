# ERP Customer Portal — Claude Code Primer

**Version 0.20.0** (2026-09-05) — see `CHANGELOG.md`. Record this version in
your adopted repo (adoption step 1) so you can diff against future releases
(see **Staying current** below).

**In one breath**: an opinionated starter kit of Claude Code context
files for building a custom ERP-with-customer-portal — decided stack
(Next.js/TypeScript/Prisma/Postgres, panel-vetted), a 30-minute guided
start (`/perp-scope`), the financial guardrails (parity, tenant
isolation, audit-everything), and the shop-floor domain (travelers,
dispatch, purchasing, customers viewing their own CAD parts in the
portal). Forward this paragraph to your boss.

A starter kit of **Claude Code context files** for building a
professional-services / job-shop **ERP with a customer portal** — the kind
of system that tracks *clients → estimates → projects → phases → tasks →
time → invoices → payment*, and for manufacturing shops the floor side
too: *routing & travelers, outside processing, promised dates & the
dispatch list, CAD part viewing*. One back-office app for staff, a scoped
portal for customers. **The whole point of building your own ERP is
friction removal** — in both directions: how work moves through your
shop, and how customers deal with you. Every feature in this kit traces
to a named friction; the guardrails exist to prevent the three bugs
that kill that goal: cross-tenant data leaks, two surfaces disagreeing
on a number, and untracked financial mutations.

This is **not** application code. It's the set of documents that teach Claude
Code (and human contributors) how to reason about this *kind* of product: its
domain model, its invariants, its security posture, and a verification +
review workflow. Drop these into a fresh repo and start building with the
guardrail **blueprints** in place — the rules, checklists, and review
commands are pre-written, but the enforcement half (your stack's verify
commands in `/perp-check`, CI, the auth wrappers) only becomes real as you
fill in the `<TODO>`s. What works on day one: the docs, `.gitignore`,
`.env.example`, `/perp-scope`, `/perp-build-core`, `/perp-feature`,
`/perp-commit`, `/perp-push`, `/perp-status`, `/perp-voice`, and
`/panel-review`. What needs your stack first:
`/perp-check` and CI — both refuse to pretend otherwise, and
**`/perp-setup-testing` is the bridge**: one command wires the framework,
entity factories, a real starter test, coverage, CI, and the pre-push
hook, and fills the testing `<TODO>`s for you.

**Start here**: after copying the files in, run **`/perp-scope`** —
About 30 minutes, one question at a time, and it tailors the whole kit to
your answers. Then run **`/perp-build-core`**: one pass, zero
questions, and you're clicking around your own app — your vocabulary,
your colors, your pain point on the dashboard, sample data everywhere,
a "view as your customer" switch — before any talk of logins or
plumbing. That's the demo. From there it's one question at a time:
"what should we make real first?"

The kit is **opinionated about the stack**: **Next.js + TypeScript +
Prisma + PostgreSQL**, chosen after an advocate/judge panel for the
target adopter — a small company, often one AI-assisted developer,
which is exactly who the TypeScript compile-time net protects — with a
decided library for every concern (auth realms, payments, email, S3,
jobs, PDF invoices, CAD part viewing) and pinned conventions to keep
AI-generated code on the rails. The full decision record — including
the panel scores and the honest costs — is `docs/STACK.md`. The
*principles* still hold on any stack — STACK.md § "If you deviate"
covers swapping (Django, the panel's aggregate winner, is the
documented second path). Your business specifics stay yours (marked
with `<TODO>` throughout).

**What this kit knows that a generic rules file doesn't** — checkable
in-file, not marketing: portal session cookies must be `lax`, not
`strict`, or magic-link logins break (`secure_coding.md` § 8); cross-tenant
access returns 404, never 403 (§ 3–4); webhook handlers re-fetch amounts
from the provider rather than trusting the payload (§ 16); a stored
rollup needs a stored==recomputed parity test (`DOMAIN_MODEL.md`
invariant 11); sent invoices are immutable — corrections are credit
notes, and invoice numbers are gap-free. That is the scar tissue of a
production ERP-with-portal, which is where this kit came from.

---

## The three ideas this primer is built around

1. **Two surfaces, one source of truth.** Staff and customers see the same
   data through different doors. Every number must compute identically on
   both. This is the defining concern of an ERP-with-portal and it never
   goes away — hence `/perp-review-parity` and the Parity section in
   `CLAUDE.md`.

2. **The money is the product.** Budgets, hours, balances, and tax are the
   reason the system exists. One formula per number, exact arithmetic,
   approved-only inputs, and an audit-log entry on every financial mutation.
   See `DOMAIN_MODEL.md` § Invariants.

3. **Tenant isolation, enforced below the query.** The customer is the
   tenancy boundary; every portal query filters by client id — and the kit
   tells you to back that with a mechanism that fails closed (Postgres RLS or
   a Prisma client extension), with wrappers, tests and the parity audit as
   layers on top. Cross-tenant access returns 404, never 403.

---

## Should you build this at all?

Honest gate before you invest: Tier-0 alone (two auth realms, invoicing,
audit log, a portal) is **months of engineering** plus a permanent
operating tax — parity review, backups, security upkeep, schema migrations
under live financial data (see **Operating cadence** below for the honest
list). Off-the-shelf **PSA tools** (professional-services automation — the
software category covering clients → projects → time → invoices; search
that phrase to find and price them) cover most of Tier-0 for tens of
dollars a month. Building your own is rational when at least one of
these is true: your **workflow is the moat** (e.g. phase-type billing rules
no product supports), you carry **regulated data** with handling rules
off-the-shelf tools can't express, or the **portal itself is your
differentiator** with customers. If none apply, buy — this primer will
still be here if you outgrow it. If you're not sure what some of these
words mean, start with `docs/GLOSSARY.md`.

**Honest note on the comparison.** For a *manufacturer*, the alternative to
compare against is not a PSA tool — it's a job-shop ERP (JobBOSS, E2,
Fulcrum, ProShop, Paperless Parts). Those cost hundreds to thousands a month
rather than tens, and they ship the shop-floor half — travelers, routing,
outside processing — that no PSA does. If one of them fits how you work,
buy it. "My workflow is the moat" has to mean something narrower than "PSA
can't do shop floor," because that's true of every shop.

**What the operating tax table below does not price**, and you should: the
AI subscription and token spend to build and maintain an ERP against this
spec; your own hours, converted from "months of engineering" into evenings;
what happens if the one person doing this stops; and — until the Accounting
sync module ships — re-keying every invoice into QuickBooks by hand, which
is *new* work relative to your status quo.

## If you want out

The realistic failure of a self-built ERP isn't "it doesn't work." It's "I
ran out of evenings in month four," and that decision arrives when you're
tired, with real customer data already inside. So the exit is a Tier-0
feature, not an afterthought:

- **Full data export** ships in Tier 0 (`docs/FEATURE_CATALOG.md`) — one
  command, every table, CSV or JSON. Build it before the first real record
  exists, not when you need it.
- **What moves cleanly**: clients, contacts, jobs, time, invoices, payments.
  Most PSA and shop-ERP products import a CSV of those.
- **What doesn't**: the audit log (nobody else's schema has yours) and the
  file store (export it as a folder tree beside the CSVs, not as links that
  die with the app). Say this out loud before you start, not after.
- **The stopping points that leave you whole**: after Tier-0 you have a
  working quote-to-cash system; after `/perp-build-core` alone you have a
  clickable skeleton and no obligation. Neither is a trap. The trap is a
  half-migrated business with data in two places — so don't turn off the old
  spreadsheet until the export works.

---

## What's in here

**Core guides (repo root):**

| File | Goes in | Purpose |
|---|---|---|
| `CLAUDE.md` | repo root | Loaded by Claude each session. Engineering principles + the ERP-with-portal domain shape + the **Parity** discipline. Pre-filled; fill the `<TODO>`s. |
| `secure_coding.md` | repo root | Required security practices for API routes, auth, input validation, secrets + the secret-exposure rotation protocol. (Stack-agnostic baseline.) |
| `testing-conventions.md` | repo root | Test philosophy + mechanics, including tenant-isolation tests. (Mock examples are Vitest-flavored — rewrite for your stack.) |
| `ARCHITECTURE.template.md` | rename → `ARCHITECTURE.md` | Skeleton for documenting your non-obvious wiring (auth wrappers, tenant isolation, webhooks, server-only boundary). |

**Domain & reference docs (`docs/`):**

| File | Goes in | Purpose |
|---|---|---|
| `docs/STACK.md` | `docs/` | **The stack decision record**: Next.js + TypeScript + Prisma + PostgreSQL, pinned conventions, the per-concern library table, integrity rules, deployment (never serverless), the CAD part-viewing architecture, and what deviating costs you. |
| `docs/DOMAIN_MODEL.md` | `docs/` | The conceptual entity model and the **invariants** that keep an ERP correct — including what must never be pruned. |
| `docs/FEATURE_CATALOG.md` | `docs/` | The menu of features an ERP-with-portal grows into, tagged by surface, with sequencing advice. A planning aid. |
| `docs/CONTROLS.md` | `docs/` | **What actually enforces the rules.** Splits every control into *guides* (steer before — docs and skills; weak) and *sensors* (observe after — types, tests, scans; strong), maps each rule to whatever enforces it, and marks which sensors **gate** a push versus which are only drift signals. Names the rules nothing enforces yet, rather than letting silence read as coverage. Home of the permanent **go-live gates**. |
| `docs/DEPLOYMENT_TARGETS.md` | `docs/` | **Where it runs.** Maps STACK.md's web + worker + Postgres shape onto a VPS, a PaaS, AWS, **AWS GovCloud**, Azure, and GCP — the four concerns that change per substrate, the two rules that never do, why Fargate honors the never-serverless pin and Lambda doesn't, the CUI egress trap, and a decision ladder that ends in "the VPS" for most shops. |
| `docs/MODULES.md` | `docs/` | The **boundary map** over that menu: spine vs. capability modules vs. integration modules vs. dimensions, the dependency graph, the module contract, and the shared integration scaffold. Answers "what can I leave out?" — including AS9100 doc control, the CAD/OpenCascade module, Toolpath DFM, and the CMMC posture. |
| `docs/PORTAL_UX.md` | `docs/` | Portal UX + accessibility baseline — required states, keyboard/semantic-HTML rules. MUST for portal (👤) and public (🌐) UI work. |
| `docs/GLOSSARY.md` | `docs/` | Plain-language definitions of the terms of art in these docs — domain, security, and build/ship vocabulary. |
| `docs/TESTING-PIPELINE.md` | `docs/` | **Optional, stack-specific**: ready-to-copy Vitest + Playwright + merged-coverage + a11y pipeline. Delete if you're not on that stack. |
| `docs/runbooks/backup-restore.template.md` | rename → `backup-restore.md` | The backup set, encryption, restore procedure, rehearsal log. Fill in **before the first real client data**. |
| `docs/runbooks/deploy.template.md` | rename → `deploy.md` | The executable deploy: compose skeleton (web + worker + Postgres), migrations run exactly once, rollback. Fill in **before go-live**. |
| `docs/runbooks/incident-response.template.md` | rename → `incident-response.md` | One-page incident playbook: secret leak, breach, data loss, downtime. Fill in **before go-live**. |
| `docs/runbooks/release-checklist.template.md` | rename → `release-checklist.md` | The pre-release ritual, with `/perp-review-parity` as its anchor. |

| `docs/BRAND.template.md` | rename → `docs/BRAND.md` | Company display name, logo, the one accent color (with its accessible text variant), and tone. `/perp-scope` writes it **always** — with neutral defaults in force when no brand was collected — because `/perp-build-core` depends on it. |

**Templates (`features/`):**

| File | Goes in | Purpose |
|---|---|---|
| `features/_TEMPLATE.md` | `features/` | Per-feature plan-doc template. |
| `features/feature_overview.md` | `features/` | Living index of your features, seeded with the Tier-0 set. |

**Skills (`.claude/skills/` — the `/perp-*` commands):**

| Skill | Purpose |
|---|---|
| `/perp-scope` | **Run this first.** Guided-start interview (~30 min, or ~10 in express mode; plain language): your business, volume and who-sees-what, how you quote, billing model, deposits, shop floor, shipping, certification and regulated data, portal, notifications, where files live, stock, goals, and the one feature you wish you had → fills the CLAUDE.md `<TODO>`s, writes `docs/SCOPE.md` + `docs/BRAND.md` + `docs/VOICE.md`, proposes what to prune and build first. |
| `/perp-build-core` | **Run this second — the magic moment.** One pass, no questions: both shells, both dashboards (your pain point top-left), Settings pre-filled, your spine's screens in your vocabulary, portal faces, SAMPLE data so everything's clickable, dev-mode sessions behind real auth wrappers — ends with a running URL and "what should we make real first?" |
| `/perp-feature <name>` | Scaffold a `features/<name>.md` plan doc and register it in the index. **The one-minute demo.** |
| `/perp-check` | Full verification suite. Per-step `<TODO>` guard — runs what's configured, reports what isn't, never improvises. |
| `/perp-commit` | Stage + commit locally (secret-file guard, no AI attribution). **Never pushes on a bare "commit".** |
| `/perp-push` | The explicit publish step; confirms before pushing to `main` (documented opt-out for solo repos). |
| `/perp-status` | Read-only session checkpoint: what changed, what's open, anything risky uncommitted (including a stale backup-rehearsal check). |
| `/perp-setup-testing` | Wire a test framework, factories, coverage, CI, and the pre-push hook from zero — hook-manager-aware, monorepo-aware. |
| `/perp-review-code` | Structural quality audit. |
| `/perp-review-testing` | Test-quality audit. |
| `/perp-review-parity` | **Drift audit between the internal app and the portal.** The signature command for this kind of app. |
| `/perp-voice` | Makes the system write like *you*, not like AI — emails, empty states, confirmations, help text. Seeded automatically from how you answered `/perp-scope` (no extra interview), so two shops adopting this kit don't ship the same copy. Security error text, a11y labels, and money/date/legal strings are excluded by design. |
| `/panel-review` | 16-perspective product review (UX **and** depth/correctness). Works day one. Note: if you also keep a personal copy of this skill, project and user copies both load — keep them identical or delete one. |

**Config & meta:**

| File | Goes in | Purpose |
|---|---|---|
| `.gitignore` | repo root | Secrets/artifacts ignore list — verify it covers your stack **before the first commit**. Also ignores `reviews/`, where `/panel-review` writes: those reports state plainly where the product is weak, and that candor is meant to stay local. |
| `.env.example` | repo root | Placeholder env contract (no real secrets). Copy to `.env`, fill in, and add a startup check for required vars. |
| `.claude/settings.json` | `.claude/` | Two things. (1) Permission denies for Claude Code's file Read/Edit tools on `.env` variants, keys, and credentials (`.env.example` is deliberately readable). **Boundaries**: shell output is not covered, and none of it applies in other AI tools — the `secure_coding.md` § 8 rules are the defense there. (2) A **SessionStart hook** — **executable shell that runs automatically at session start** — that auto-starts `/perp-scope` when `docs/SCOPE.md` is missing. ⚠️ **Treat this file like CI config**: review every change to it in a PR, and never merge an edit to the `hooks` block you didn't write; once a second person can land a commit, editing that one string is code execution on your machine with no permission prompt, so a freshly adopted repo goes straight into the guided setup. It emits nothing once you've been scoped, and nothing if you renamed the `perp-` prefix away — delete the `hooks` block to opt out. |
| `.github/workflows/kit-check.yml` + `scripts/kit-check.sh` | **keep the half that's yours** | Mixed: some checks are the primer's own bookkeeping (version stamps, its cross-references) and are safe to delete. **Others bind *your* repo forever** and should be kept and wired into your CI — skill-name-matches-directory, the CLAUDE.md size budget (yours is the one that will grow), every `features/*.md` registered in the index (that's the `/perp-feature` workflow), `§` anchors resolving, the auto-scope hook still firing, and `reviews/` staying gitignored so panel reports are never committed. Deleting the lot removes the only thing enforcing the discipline the rest of this kit argues for. Your app's test CI is separately the `ci.yml` that `/perp-setup-testing` writes. |
| `LICENSE` | **reference only** | MIT, for the primer itself — keep it as `LICENSE-primer.md` or in your notes. Do NOT place it at your repo root unless you intend to MIT-license your own code. |
| `CHANGELOG.md` | reference only | The primer's own version history — check it when a new primer version ships. |

**Renaming the `perp-` prefix** — it's just a namespace; rename it freely,
but every step below is load-bearing: (1) rename the
`.claude/skills/perp-*` directories, (2) update the `name:` frontmatter
inside each `SKILL.md` to match, (3) search-and-replace `/perp-` and bare
`perp-` across **every file except `CHANGELOG.md`** — which specifically
includes the `.claude/skills/*/SKILL.md` **bodies** (they cross-reference
each other dozens of times; renaming only the directories leaves every
skill pointing at commands that no longer exist) and **`.claude/settings.json`**,
whose auto-scope hook names the skill path — miss it and the guided start
silently stops firing. The one-liner:
`grep -rl 'perp-' . --exclude=CHANGELOG.md | xargs sed -i 's/perp-/yourprefix-/g'`,
(4) update or delete `.github/workflows/kit-check.yml`, whose checks
know the `perp-` prefix. Skipping (1) or (2) leaves the commands
registered under the old names while the docs point at the new ones.

**Using another AI tool?** The skills ship in Claude Code layout
(`.claude/skills/<name>/SKILL.md`); the SKILL.md files are written as
playbooks — copy them into your tool's command format, or tell the agent
to read the relevant SKILL.md and execute the steps. **Know what does NOT
transfer outside Claude Code**: `CLAUDE.md` won't auto-load (map it to
your tool's context file — `.cursorrules`, `AGENTS.md`, etc.), the
self-surfacing Bootstrap checklist must be driven by hand, the
`.claude/settings.json` secret-file denies don't exist (your AI can read
`.env` — the § 8 rules are the only defense), and the `sensitive-canary`
plugin has no equivalent.

---

## How to adopt it

**Two paths — pick yours first.** Fresh, empty repo → the numbered steps
below. Existing codebase → skip to **Brownfield adoption** after them.

0. **Before you start**, you need four things installed. If none of these
   words mean anything to you, that's fine — ask Claude Code to walk you
   through installing them before going further.
   - **Claude Code** (paid subscription) — this kit is a set of files it reads.
   - **Node.js** (LTS) and **git**.
   - **A Postgres you can reach.** `/perp-build-core` needs a real database
     and will stop before writing anything if there isn't one. Docker is the
     easiest route (`docker run -d -e POSTGRES_PASSWORD=devpw -p 5432:5432
     postgres:17`), but you don't have to install anything —
     `docs/STACK.md` § Getting a database has a no-installer option that
     unzips, runs, and deletes cleanly.

   **And one thing to start now rather than later:** if you'll have a
   customer portal, customer login is a **magic link**, so the portal cannot
   work until email sends from a domain you've verified — which means adding
   DNS records and waiting. **Begin domain verification in week one**, even
   though you won't send for a while. Development is never blocked by it
   (dev writes the email to the console), but go-live is.
   `docs/MODULES.md` § Transactional email has the order to do it in.

1. **Get the files into *your* repo — do not work inside a clone of the
   primer.** Either click **Use this template** on GitHub, or:

   ```bash
   git clone --depth 1 https://github.com/ZapCon1/erp-portal-primer.git primer
   mkdir my-shop && cp -r primer/. my-shop/ && rm -rf my-shop/.git primer
   cd my-shop && git init
   ```

   ⚠️ **Why this matters more than it looks.** If you clone the primer and
   start working in it, `origin` still points at a public repository. Your
   `docs/SCOPE.md` will hold your billing model, your margins policy, your
   client list, and your regulated-data answers — and a `/perp-push` to a
   fork publishes all of it. `/perp-scope` refuses to run if `origin` is
   still the primer, but get this right at step 1 rather than relying on
   the guard.

   Then: **record the primer version** (top of this file) in your repo, and
   **commit the pristine copy first**, so you can diff your adaptations and
   future primer releases against it. Prove it works with
   `/perp-feature invoicing` — a scaffolded plan doc in under a minute.
2. **Run `/perp-scope`** — the guided interview fills `What It Is`, the
   billing and datetime decisions, and your brand/scope docs
   conversationally. The default stack (Next.js + TypeScript + Prisma +
   PostgreSQL — `docs/STACK.md`) simply applies; it isn't a question
   unless you bring a preference or an existing codebase. Provider
   choices (which storage/payment service) wait for `/perp-feature`'s
   feature interview — scope collects capabilities, not vendors.
3. **Fill the `<TODO>`s that are yours** — in `CLAUDE.md`, `secure_coding.md`,
   and the runbook templates. **Leave the ones inside `.claude/skills/`
   alone until your stack exists in code**: filling `/perp-check`'s commands
   before there's a `package.json` turns its honest "not configured" into
   failures you can't diagnose. `/perp-setup-testing` fills those when the
   time comes. Easiest route: ask Claude *"which TODOs do I still need to
   answer?"* rather than searching by hand.
4. **Prune.** Delete entities/features/sections you don't need. A two-person
   shop does not need SSO, retainers, or a partner program on day one. Don't
   carry dead rules forward — but read `DOMAIN_MODEL.md`'s "what's prunable
   and what isn't" note first: the invariants, invoice immutability, and
   tenant isolation are not on the menu.
5. **Leave the "Project Bootstrap" checklist** at the top of `CLAUDE.md` in
   place — it's self-deleting and prompts Claude to create the things this
   primer intentionally doesn't ship (`ARCHITECTURE.md`, CI, runbooks) at the
   right moments. Check items off; delete the section when all are done.
6. **`/perp-build-core`, then make it real one ask at a time** (the
   full order: `DOMAIN_MODEL.md` § What to build first): Phase One is
   the whole clickable skeleton in one pass — both shells, dashboards,
   settings, your spine's screens, sample data, dev-mode sessions
   behind real auth wrappers. Phase Two is driven by what you ask for
   next — money flow, invoicing + audit log, real login before anyone
   else touches it — with **each feature's portal face shipping in the
   same phase** (the portal is a dimension, never a follow-up project).
   Resist building the whole catalog at once.

### Brownfield adoption (existing codebase)

Don't reshape the repo to match this kit on first contact. Audit first:
read the principles, walk the code, and report what already fits, what's
borderline, and what clashes (secrets in plaintext, weak assertions, no
CI gate) — as findings, not silent fixes. Map the existing test/CI/build
commands into the `<TODO>`s rather than introducing new tools, and let
the user pick what to act on.

Two brownfield-specific cautions: keep an **unmodified copy of the primer
files** (e.g. under `docs/primer-pristine/`, or just record the adopted
version tag) — with primer content interleaved into an existing repo,
it's your only baseline for taking a future release. And before
`/perp-setup-testing` touches git hooks, note that it checks for husky /
existing hooks first — that check exists because `core.hooksPath` would
otherwise silently disable them.

---

## Staying current

The primer is versioned (top of this file) and each release is tagged.
To take a new release:

1. Get the new version: `git pull` from
   **github.com/ZapCon1/erp-portal-primer**, or use GitHub's
   "Watch → Releases" for notifications. Questions or a defect to
   report: **chris@zappettiniconsulting.com**.
2. Read the `CHANGELOG.md` entries **back to your adopted version — and no
   further.** Anything before **v0.19.0** predates the public repo, has no
   diff base you could act on, and is kept only as history. Releases may
   come in bursts (they did during the kit's bootstrap; expect batched,
   occasional ones from here; pre-1.0 may still reorganize files).
   Security-section changes are do-not-skip.
3. Diff the new release against your **pristine-copy commit** (adoption
   step 1) **once, against the latest tag** — no need to walk
   intermediate tags — then apply the hunks that touch files you kept.
   Your filled `<TODO>`s and pruned sections stay yours. (History note:
   the public repo starts at **v0.19.0**; earlier versions were
   pre-release and have no public diff base — re-adopt from current.)

Found a defect? **Open an issue** — that is the preferred channel, because
a public issue means the next adopter can find that someone already hit it,
and the fix that followed. Email works too if the report contains anything
you'd rather not publish. This kit improves by adopters' findings: the
release history shows several rules that exist only because one shop hit a
wall and said so.

---

## Operating cadence — the honest tax list

The build-vs-buy gate above says "permanent operating tax"; this is it,
priced. If you keep only three: the audit log in code, parity before
release, and the quarterly restore rehearsal.

| When | Ritual | Rough cost |
|---|---|---|
| Every commit | Type check + tests run (`/perp-check` on significant changes) | seconds–minutes |
| Every push | Pre-push hook (fast gate) | under ~90s, by design |
| Long sessions | `/perp-status` checkpoint | one minute |
| Every feature | `features/<name>.md` plan + Progress updates | 15–30 min over the feature's life |
| Every release | `release-checklist.md`, anchored by `/perp-review-parity` | 30 min–2 h, scales with surface |
| Quarterly | Backup **restore rehearsal** (`/perp-status` nags when stale) | ~1 h |
| Quarterly (or per framework minor) | **Dependency/framework upgrade pass** — audit, changelog review (Better Auth is pinned exact), migration work (STACK.md § Honest costs) | 1–4 h |
| When a schema or scope decision changes | Update DOMAIN_MODEL/SCOPE **in the same commit** (perp-scope update mode helps) | minutes |
| Per primer release (batched is fine) | Diff + selectively merge (see Staying current) | 15–60 min |

---

## Troubleshooting

- **`/perp-check` refuses to run anything** — by design: its steps are
  still `<TODO>`. Run `/perp-setup-testing` to fill the testing ones; it
  reports exactly which steps remain.
- **The guided setup didn't start when I opened the project** — that's the
  auto-scope *session* hook, which is a convenience, not the mechanism.
  It stays quiet if hooks are disabled, if you're in another AI tool, or on
  a shell that can't run its POSIX one-liner (Windows without Git Bash).
  Nothing is broken: just type `/perp-scope`. That always works.
- **Claude keeps starting the guided setup and I'm not ready** — the same
  session hook. It stops on its own the moment `docs/SCOPE.md` exists; to
  silence it now, delete the `hooks` block from `.claude/settings.json`.
  Adopting into an existing codebase? It detects that and switches to
  brownfield advice instead of pushing the interview.
- **`/panel-review` is listed twice** — you have a project copy and a
  personal one at `~/.claude/skills/`. **The project copy is the one to
  keep**: delete `~/.claude/skills/panel-review/`. Editing the wrong copy is
  a change that silently does nothing.
- **The pre-push hook blocked my push** — that's the *git* hook, and that's
  it working. (Two different hooks share the word: the git pre-push hook
  runs your tests; the session hook above starts the interview.) Fix the
  failure (`/perp-check` shows it), then push again. `--no-verify` is for
  genuine emergencies, not red suites.
- **The hook doesn't run at all on a fresh clone** — `core.hooksPath` is
  per-clone config; run `npm ci` (the `prepare` script re-activates it)
  or re-run `git config core.hooksPath .githooks`.
- **My existing husky/lint hooks stopped firing** — something set
  `core.hooksPath` blindly. Unset it (`git config --unset core.hooksPath`)
  and put the gate in `.husky/pre-push` instead; current
  `/perp-setup-testing` checks for this before touching hook config.
- **`/panel-review` is listed twice** — you have a project copy and a
  personal copy. Keep them identical or delete one.
- **My AI tool can't see the skills** — see "Using another AI tool?"
  above; the skills are Claude Code layout, and the settings.json
  protections don't transfer.
- **Windows: `chmod +x` did nothing** — expected; the exec bit is
  recorded with `git update-index --chmod=+x .githooks/pre-push`
  (`/perp-setup-testing` does this).
- **A secret got pasted/committed** — stop; `secure_coding.md` § 8
  rotation protocol, immediately. Deleting the message or commit is not
  a fix.
- **The session died mid-`/perp-scope`** — nothing is lost: the skill
  checkpoints each phase to `docs/SCOPE.draft.md`; re-run `/perp-scope`
  and it resumes from the first unanswered question.
- **`prisma generate` fails in `/perp-check`** — no `prisma/schema.prisma`
  exists yet (the kit ships none). The step reports `⊘ N/A at this
  stage` until your schema exists; if it's erroring instead, your
  perp-check copy predates v0.11.0.
- **A Better Auth upgrade broke login** — you're on the stack's
  youngest pinned dependency: roll back to the pinned exact version
  (lockfile), read its changelog for session/cookie/plugin changes, and
  see STACK.md's auth rows — including the hand-rolled-sessions
  fallback if the two-instance setup fights the new version.
- **sensitive-canary blocked `.env.example`** — expected: the plugin
  pattern-matches all `.env*` names; the file is placeholders only. Use
  `[allow-secret]` for that one read — never a standing `[allow-all]`
  (CLAUDE.md § Security has the framing).
- **kit-check fails after renaming `perp-`** — the rename recipe's
  search-and-replace deliberately skips CHANGELOG.md, and kit-check
  knows to exclude it; if you kept the workflow, update its skill-name
  checks for your new prefix or delete it (it only guards the primer's
  own consistency).
- **The generated copy doesn't sound like us** — that's `/perp-voice`'s
  job: correct the wording anywhere and it updates `docs/VOICE.md`, so
  the fix sticks instead of being re-made next week.

---

## What's intentionally NOT here

- **Application code, schema files, migrations.** This is context, not a
  codebase. Translate `DOMAIN_MODEL.md` into your Prisma schema yourself
  (or your ORM of choice, if you deviated).
- **`ARCHITECTURE.md`** — every project's wiring differs. Write one from the
  template once you have non-obvious wiring.
- **Your app's CI config and `.claude/settings.local.json`** — stack- and
  machine-specific; `/perp-setup-testing` writes the starting `ci.yml`
  when the stack exists. (The shipped `kit-check.yml` only guards the
  primer's own cross-references — delete it after adoption.)

---

*Derived from patterns in a production ERP-with-portal, generalized so any
shop can use it as a starting point. MIT-licensed (see `LICENSE`) — copy it,
adapt it, keep your derivative private.*
