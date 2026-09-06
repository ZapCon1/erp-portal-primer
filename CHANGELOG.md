# Changelog

All notable changes to the primer. Adopters: record the version you
adopted in your repo (see README § How to adopt) so you can diff
against future releases.

## 0.21.0 — 2026-09-06

**The controls become controls.** A second 16-perspective panel review —
scoped to guardrails, the module system, and stack guardrails — found that
0.20.0 had shipped a control *map* that overstated itself: ten rows of
`docs/CONTROLS.md` claimed to gate "in CI" while the CI the kit ships
implemented one of them. Worse, the checks written to fix the previous
round's "four checks could not fail" had reintroduced the same class. This
release is the response, and the centrepiece is a harness that makes the
class detectable instead of recurring.

### Rules that arm themselves — new `scripts/graduation.sh`

A primer has no application, so a whole class of rule cannot be enforced in
it: `DOC-1` needs a database constraint, `CUI-2` needs a file read to audit,
`MONEY-4` needs an invoice counter. Marking those "not built yet" is honest
and is also exactly how a rule never gets built — a status column is read
once, during adoption, by someone who does not yet have the thing the rule
protects. Nobody re-reads it on the day they add a `File` model.

So each dormant rule now has a **trigger**: a detectable fact about the repo
meaning the rule applies. Before it, the rule reports `dormant` and passes.
After it, a missing requirement **fails the build**.

| The moment this becomes true | Arms |
|---|---|
| `package.json` exists | `TEST-*`, `DEP-1`, `PIN-1/2`, `OPS-1` |
| `AUTH_MODE` appears in source | `SEC-2`, including rejecting the fail-open shape |
| the schema has `clientId` | `TENANT-1`, `SCALE-1` |
| the schema stores money | `MONEY-1` |
| an `Invoice` model exists | `MONEY-4` |
| a `File` model exists | `CUI-1`, `CUI-2` |
| `ControlledDocument` exists | `DOC-1`..`DOC-5` |
| `Nonconformance`/`Inspection` exists | `QUAL-1` |
| a `portal/` route group exists | `A11Y-1`, tenant-isolation tests |
| a `Dockerfile` or compose file exists | `OPS-3`, plus a `GH-6` reminder |

**The design rule: the rule arrives when the risk does.** Adding a `File`
model is the moment export control starts mattering, and that is the moment
`CUI-1` starts failing the build — not a checklist line from six months
earlier.

Verified in both directions: in this repo everything reports dormant and
exits 0, and eight trigger cases in the selftest each build a throwaway repo
containing exactly one risk and assert the matching rule fires. A fixture of
a correctly-built app passes with all ten groups armed, so it is satisfiable
rather than merely always-red.

Two limits stated in the file: it can confirm a test *exists*, not that it is
good (`MODULES.md`'s acceptance tables say what each must do), and
`GH-2`/`GH-6` live in GitHub's settings, which no script in the repo can see
— it prints a reminder rather than pretending.

### The systemic fix

- **New `scripts/kit-check-selftest.sh`.** Snapshots the working tree,
  asserts the unmutated copy is green, then applies **50 mutations** that
  each break exactly one thing kit-check claims to guard. Every mutation
  must turn kit-check red *and* produce the error that names it — going red
  for the wrong reason is reported as a check firing by accident, not a
  pass. A coverage report names any check with no mutation case. All checks
  are covered. It runs in CI.
- The rule it enforces: **a check with no mutation case is a check nobody
  has shown can fire.**

### SEC-2 — the dev-auth stub

- **The shipped assertion failed OPEN.** `NODE_ENV === 'production' && stub`
  needs both conjuncts, so an unset, misspelled or `staging` `NODE_ENV`
  booted the stub silently — a real staff session and a real portal POC
  bound to a live `clientId`. On the pinned deploy `NODE_ENV` is a variable
  someone remembers to set, not a platform guarantee. Now fail-closed.
- `/perp-check` gated on the assertion's *presence*, so it passed on the
  broken polarity. It now reads the guard's direction.
- kit-check's receipt was `grep -qi 'refus'`, satisfied by an unrelated
  sentence elsewhere in the file. Deleting the entire security spine exited
  0. Now asserts artifact strings, and the selftest proves it fires.

### GitHub guardrails — new `docs/GITHUB.md`

- The kit had **none**: no mention of branch protection, required status
  checks, CODEOWNERS, Dependabot, push protection, or token scoping. A red
  build blocked nothing. Six settings, click path and `gh` command each,
  including `enforce_admins` (without it the rule skips a solo owner) and a
  deploy gated by both `needs:` and an environment reviewer.
- **`GH-1`: a check that cannot block a merge is a report, not a gate.**
- kit-check no longer executes the SessionStart hook string on
  `pull_request` events — that string arrives from the contributor's branch.
  The workflow declares `permissions: contents: read`.

### Honesty in the control map

- The `Gates?` column became **`Gates today?` + `To make it gate`**, filled
  from what is actually shipped.
- Compliance tables gained a **Status** column. Their imperative voice read
  as coverage to the reader who lands on that header; all eleven rows say
  "not built yet".
- **`CUI-1`'s claim** to cover error tracking, CDNs and LLM tooling "with
  one predicate" was false for all three; each is now named with its own
  control.
- `OPS-3`, `STOP-1..7`, `PARITY-1` and the GitHub gates joined the
  no-sensor table — they were in neither, so an audit of "what's
  unenforced?" concluded they were covered.

### Compliance rules moved to where they get built

- Every `DOC-*`, `CUI-2..5` and `QUAL-1` existed in **exactly one file**
  (`CONTROLS.md`), and **none** appeared in the module sections that would
  implement them. `MODULES.md` § Doc Control described document control
  while citing no `DOC-*` rule and omitting **`DOC-1`** — released-revision
  immutability — entirely. Anyone building from that page built mutable
  released revisions, which is the AS9100 finding the module exists to
  prevent. All eleven rules are now stated where they are built.
- **Each carries the one test that proves it.** `DOC-1` is "update a
  released revision through a raw connection outside the ORM — the database
  must reject it"; `CUI-5` is "delete a flagged file; assert the row is gone
  *and* the object is gone, not flagged, gone". A compliance rule you cannot
  demonstrate is a compliance rule you do not have.
- The **`CUI-1` overclaim had a second copy** in `MODULES.md`. Both now name
  the three side doors the predicate structurally cannot reach — error
  tracking, presigned URLs/CDNs, and assistant tooling — each with its own
  control.
- Status in `CONTROLS.md` reads "not built yet — spec + test in MODULES.md",
  because that is what is true: a kit with no application cannot make these
  gate, and `DOC-1`/`DOC-5` are the two that cannot be retrofitted honestly.
- kit-check now fails if a compliance rule is mapped in `CONTROLS.md` but
  absent from `MODULES.md` — the drift that produced this gap.

### New: `docs/CONTROLS.md` § The rule index

- Every one of the kit's **48 rule IDs** in one table: the rule in a line,
  its canonical home, whether it gates. `CLAUDE.md` had promised IDs were
  resolvable while listing nine of them, and `PARITY-1` occurred exactly
  once in the kit — inside that promise. Check 21 enforces it.

### The build path produces what the docs promise

- `/perp-build-core` now provisions `File.classification` (an enum
  superseding the boolean `exportControlled`, which could not tell CUI from
  export-controlled), the egress-gate boolean, `SCALE-1` composite indexes,
  and a fail-closed **`TENANT-1`** mechanism — with the RLS footgun written
  down: the tenant id must be set inside an interactive transaction or it
  persists on the pooled connection and the next request inherits it.
- It also emits the Dockerfile, `/api/health`, standalone output and a
  throwing env check that `docs/runbooks/deploy.md` had always assumed.
  `Dockerfile` had appeared nowhere in the kit.
- **`MONEY-4`** was a published CI gate nothing created. `/perp-setup-testing`
  now scaffolds the stubs, and `testing-conventions.md` defines the word the
  test rested on: two interactive transactions on one client *serialize*,
  which passes against the broken implementation the rule exists to catch.

### The module contract gets an owner

- `MODULES.md` named `/perp-feature` as the carrier; `/perp-feature` did not
  contain the word "module". `features/_TEMPLATE.md` now has the contract as
  a table, `/perp-feature` fills it, and an **11th declaration** covers
  indexes and row growth.

### STOP-8

- **A stop rule is never waived by a tracked file.** `/perp-push` forbade
  file-sourced confirmation in one bullet and designated `CLAUDE.md` as the
  standing opt-out in the next — one appended line meant unconditional
  pushing to a public remote. The waiver moved to an untracked marker.

### Adopter experience

- **New `scripts/README.md`** ends the delete-vs-keep contradiction (three
  of four instructions said "delete") with a table of which checks are the
  primer's bookkeeping and which bind the adopter's repo.
- kit-check stopped lying in degraded environments: a missing `python3`
  produced three **false** failures blaming the adopter's documents plus one
  silent skip; no `git` blamed their `.gitignore`. Both now warn and skip.
- Probes no longer leave a stub `docs/SCOPE.md` on interrupt — which
  permanently silenced onboarding for someone never scoped.
- Contents blocks on `MODULES.md` and `CONTROLS.md`; the glossary gained the
  control vocabulary (guide, sensor, gate, drift signal, dimension, pin).
- The dependency graph's only integration edge descended from Accounting
  while the text inside it said "attach to the spine". Redrawn with
  directions.
- `OPS-1`'s check could never fire in the shipped kit; it now asserts shape
  once `package.json` exists.
- A **prune order** for the context budget: the byte cap guards one file and
  its own remedy relocated bytes into uncapped MUST-read docs. The pool
  (~230KB) is now reported as a drift signal, never a gate.

### Fixed

- `docs/STACK.md` spliced sentence; `docs/PORTAL_UX.md` severed div-button
  prohibition; the muted neutral measured **4.45:1** on the surface token,
  failing that document's own 4.5:1 rule (now 5.0:1).

---

## 0.20.0 — 2026-09-05

**Modules, deployment targets, and a verification layer that can actually
fail.** A 16-perspective panel review of the whole kit ran mid-release and
found its central weakness: ~8,000 lines of *guidance* enforced by a
consistency script in which **four checks could not fail**. Most of what
follows is the response to that.

### Modules — the boundary map

- **New `docs/MODULES.md`.** `FEATURE_CATALOG.md` is the menu of features;
  this is the map of *boundaries* — four layers (**spine** · **capability
  modules** · **integration modules** · **dimensions**), a dependency graph,
  a 10-point module contract, and an **inert-by-default** rule so a
  catalogue never reads as a build list.
- **Dimensions are named and defended.** The portal was already "a dimension,
  not a phase"; MODULES.md gives the reason a module boundary can't hold it,
  and adds **compliance posture** as the second. AS9100 doc control is a
  module (entities, screens); CMMC is not (a property of every module).
- **New capability modules**: **Doc control (AS9100)** — controlled
  revisions, approvals before release, acknowledgments, prints stamped
  "uncontrolled when printed"; **Quality records** (inspection · NCR ·
  CAPA · calibration · first article); **Lot & serial traceability**;
  **Cost build-up & job costing**; and **Receivables & statements**.
- **Accounting split in two, with the boundary stated**: the app is the AR
  sub-ledger of record, **the general ledger stays in QuickBooks/Xero/Puzzle**.
  Double-entry in-app would make every number computable two ways.
- **Estimating gained the number behind the price.** Cost and price are two
  numbers with one formula each, with quantity breaks and
  estimated-vs-actual; only price reaches the portal.
- **New integration modules**: an **integration scaffold** built once
  (`IntegrationConnection`, per-provider sync jobs, idempotency keys, loud
  failure) carrying **`mayReceiveControlledData`, default false** — which
  turns "never send export-controlled files to a third party" from a
  paragraph into a check the uploader runs; **Toolpath** DFM analysis
  (API-key auth, no webhooks — upload and poll; requires Part viewing, and
  the same STEP file feeds two async derivations); **Accounting sync**;
  **Google Workspace / Microsoft 365**; and **file storage**
  (Box · Dropbox · SharePoint · Drive) in three modes, of which **ingest**
  is recommended. ⚠️ Their sharing settings become your access control,
  downloads from the service never reach your audit log, and **doc control's
  rev letter beats the service's own version history** — that one fails
  silently.
- **Full data export is Tier 0.** The kit documented no way out. The
  realistic failure of a self-built ERP is "I ran out of evenings in month
  four", decided while exhausted with real customer data inside.

### Deployment — one shape, many substrates

- **New `docs/DEPLOYMENT_TARGETS.md`** maps the pinned web + worker +
  Postgres shape onto a VPS, PaaS, AWS, **AWS GovCloud**, Azure, GCP and
  on-prem. Four concerns change per substrate; two rules never do (exactly
  one process runs migrations; the worker is never the web service scaled
  to N).
- **The never-serverless pin is clarified as shape, not vendor.** It rejects
  request-scoped functions, not managed containers — **ECS Fargate and Azure
  Container Apps honor it**. ⚠️ **Cloud Run and App Runner do not**: both
  throttle CPU between requests, so a pg-boss poller starves.
- **GovCloud documented as its own cloud**, not a region flag — separate
  account and credentials, the **`arn:aws-us-gov:` partition** (the most
  common porting bug), two regions, vetted access, lagging service parity.
  Stated plainly: **necessary, not sufficient.** Baselines and equivalency
  are pointed at an assessor rather than asserted.
- **The egress trap**: a compliant host is defeated by transactional email,
  error tracking, CDNs, LLM tooling, cloud file storage, third-party
  analysis APIs — and **alerting**, which collides with the go-live
  requirement for an alert that reaches a human.
- **A decision ladder that ends at "the VPS"** for most shops. Substrate is
  the last decision, not the first.

### Controls — the release's centre of gravity

- **New `docs/CONTROLS.md`** answers the only question that matters about a
  rule: *what happens if I break it?* Controls split into **guides** (steer
  before; weak by nature) and **sensors** (observe after; strong when
  deterministic), with a sensor map carrying an explicit **Gates?** column.
  Its standing rule: **a rule stated in a guide with no sensor behind it is
  not enforced — it is a hope**, and `/perp-check` reports it as a finding.
  It names, honestly, the rules nothing currently enforces.
- **`SEC-2` — the dev-auth stub is a control, not a checkbox.** The panel's
  most dangerous finding: its only gate was a checkbox inside the Bootstrap
  section the kit tells you to delete, so the realistic path (build, click
  around for weeks, deploy to show a customer) ended in an internet-exposed
  ERP where every visitor is a staff admin across all tenants. Now
  `/perp-build-core` writes a startup assertion that **refuses to boot**,
  `/perp-check` gates on it, and the release checklist — which had **zero**
  security lines — verifies it every release.
- **Go-live gates moved out of the deletable block** into CONTROLS.md,
  permanently. The same defect had swallowed the accessibility and
  monitoring gates.
- **Stable rule IDs** (`TENANT-1`, `SEC-2`, `MONEY-1`, `PARITY-1`,
  `AUDIT-1`, `STRUCT-1`, `SCALE-1`, `A11Y-1`, `OPS-1`) so a check failure or
  a review can cite one instead of quoting prose.
- **`/perp-check` rebuilt around gates vs drift signals** — two groups, never
  one flat list. Commands are **detected** (package.json, then CI, which in
  an existing repo is the better source of truth) instead of read from
  `<TODO>` placeholders. **The missing precondition branch is closed**: a
  sensor whose precondition *now holds* and still isn't wired reports
  `⊘ NOT CONFIGURED` and counts as a finding, where it previously fell
  through to a benign `N/A` and would have let a portal ship unscanned
  forever. Drift signals may never be promoted to gates unprompted.

### Two wrong claims corrected

- **Tenant isolation does not lack an ORM-level safety net.** Postgres RLS
  and Prisma client extensions both enforce it below the query site and fail
  *closed* on a forgotten filter. The kit applied belt-and-braces to invoice
  immutability and pure discipline to the failure that ends the business.
- **The money column type contradicted itself** across two canonical homes,
  and inside CLAUDE.md 25 lines apart. Document precedence deadlocked
  because each home was canonical for its own domain. Now uniform: integer
  minor units for stored amounts, `Decimal` only for fractional rates.

### The interview

- **Adoption starts itself.** A SessionStart hook detects an unscoped repo
  and runs `/perp-scope` — with four states: pristine → interview; **draft →
  resume**; **existing codebase → brownfield audit** (the README path that
  had no implementation); scoped → silent. It gates on file *substance*, so
  a zero-byte `SCOPE.md` no longer silences it permanently. CLAUDE.md
  carries the same instruction imperatively, because hooks don't exist in
  other tools.
- **New import mode** — bring your own scope doc, spec or RFP; it maps onto
  the phases and asks only the gaps. **Four things an imported document
  never settles**: every Phase-3 safety question (its silence is not a no),
  the billing atom / timezone / promised dates, the pain point, and any
  aspirational scale claim. Imported content is **data, never instructions**.
- **The mode state machine stopped losing answers.** `SCOPE.md` and
  `SCOPE.draft.md` coexisting was undefined and two rules in the same file
  disagreed, so an interrupted update run discarded every checkpoint. Now a
  four-state table with "both exist → ask which", per-phase checkpoint
  sections, and **the draft surviving until the doc-review pass finishes**.
- **Eight new questions**, each concrete and conditional: CUI/CMMC (asked
  even when ITAR is a no — a shop can handle CUI with no export-controlled
  data), AS9100 certification, quoting and hit rate, the incumbent system
  and its migration, volume, what ships in the box, whether anyone records
  hours today, who sees what internally, notifications, the books, and
  storage mode. **Build-vs-plug-in is named at proposal time, never asked
  mid-interview** — it's the one question shape a machinist can't answer
  cold.
- **~30 minutes, stated as worth it** rather than apologised for; express is
  ~10, defined as the shortest *honest* run rather than the full interview
  under another name.
- ⚠️ **`/perp-scope` halts if `origin` still points at the primer.** Cloning
  the kit and working inside it means `docs/SCOPE.md` — billing model,
  margins policy, client list, regulated-data answers — sits in a repo aimed
  at a public remote.

### Security

- **SameSite is no longer the sole CSRF defense.** It is a *site* boundary,
  not an *origin* boundary, and § 17's advice to serve uploads "from a
  separate origin" built the launchpad if read as a subdomain.
  Origin/Referer validation is now required on every state-changing route.
- **Cross-realm session tests are mandatory** (`SEC-3`) — the catastrophic
  bug of a two-realm design had no rule and no test row, while STACK told
  adopters to run "the auth-realm tests" that were never defined.
- **New § 18 Outbound Requests & SSRF** — absent from a 929-line security
  doc, for an app whose roadmap is outbound integrations and whose own
  interview fetches a user-supplied URL onto a host with a metadata endpoint.

### Accessibility

- **A conformance target**: WCAG 2.2 AA. `WCAG` previously appeared **zero
  times** while PORTAL_UX invoked ADA litigation and the EAA as
  justification.
- **Invoice PDFs are inside the baseline** — the pinned renderer cannot emit
  tagged PDFs, so an accessible path is required.
- **Three more required states** — **Truncated** (the API was told to take a
  limit and the UI was never told to say so; a silent first page is data
  loss), **Success**, **Destructive confirm** — plus financial-table
  `caption`/`th scope`, WCAG 3.3.4 on money-moving actions, session-expiry
  warning, and 400% reflow.

### Verification and enforcement

- **CI gets a database.** Neither workflow had one, so the tenant-isolation
  tests could only ever run on one laptop; the documented CI *upgrade* also
  silently deleted `prisma generate`.
- **`/perp-review-code` gates on `SCALE-1`/`SCALE-2`** — it could identify an
  unbounded tenant query and a missing composite index and still say "no
  refactor needed", because scale wasn't a gate condition.
- **The "mandatory tests" are defined.** Both integrity constructs exist only
  to be correct under contention, so the obvious single-threaded test passes
  against a broken implementation.
- **`/perp-status`'s backup check fails closed** — it fired only if the
  runbook already existed, nagging the diligent and staying silent for the
  owner who never started.

### The checks that could not fail

The kit's own consistency script grew from 9 checks to 16, and four of the
originals were repaired after being proven inert:

- **Check 5** grepped `<TODO: maintainer`, a string that had never existed in
  this repo, against 137 real markers.
- **Check 9** saw 10 of 270 `§` references (backticked and bare forms were
  invisible), substring-matched anywhere in the file rather than against
  headings, and reported via `echo` inside a pipeline so it could never set
  the failure flag. Rewritten — **and it immediately found four broken
  anchors**.
- **Check 11** only counted `[module]` tags; breaking every link left it
  passing. It now asserts per row — and found six rows with no boundary link.
- **Check 4** covered only five/six/seven; the README shipped "all four steps
  are load-bearing".

New checks cover the module map, the deployment record, the auto-scope hook
(**asserting that it fires**, not merely that it is silent — silence is what
a broken hook produces), the control map, and every fix in this release.
kit-check no longer scans `reviews/`, after a panel report quoting a check's
own dead grep target became that target's first occurrence in repo history
and tripped it.

### Docs and adoption

- **An install path**, with prerequisites (Claude Code, Node, git,
  Docker/Postgres) and a real step 1 — *Use this template*, or
  clone-and-strip-`.git`.
- **`/perp-build-core` gained preconditions and a failure path** — the
  most-converged finding, hit by eight of sixteen perspectives. It verifies
  the toolchain *before writing any file*, commits per step, stops after two
  failures with a plain-language choice, and **resumes its own interrupted
  run** instead of refusing. **The SQLite fallback is removed**: Prisma's
  SQLite connector rejects the `enum` blocks the skill mandates five lines
  later, and SQLite has none of pg-boss, the `FOR UPDATE` counter, or the
  immutability trigger.
- **The glossary covers minute one** — Claude Code, repo, commit, clone,
  schema, `<TODO>`, VPS, a11y, egress, rollup, invariant — plus ITAR/EAR,
  CUI, CMMC, AS9100, HIPAA and PCI, the acronyms the never-skipped safety
  questions are built on and which were entirely absent. Its pointer now
  lives outside the delete-me block.
- **Real design tokens** — type scale, spacing, radii, shadows, neutrals,
  semantic colors, and one canonical status→label→tone map. The kit had
  *zero* hex values behind a section titled "the skeleton must be sexy".
- **`docs/BRAND.template.md`, always written** — it was conditional while
  `/perp-build-core` hard-depended on it.
- **`/perp-review-parity` audits visual drift**, which it had explicitly
  excluded while its one UI check shipped as an unfilled `<TODO>`.
- **Adopters are no longer told to delete their own guardrails** — roughly
  half of kit-check binds *their* repo forever.
- **`/panel-review` writes to a gitignored `reviews/`** — those reports state
  where the product is weak, which is the point and is not for publishing by
  accident.
- The rename recipe names the skill bodies and `.claude/settings.json`;
  `.claude/settings.json` is flagged as auto-executing shell; README step 3
  no longer contradicts CLAUDE.md; glyph columns are paired with words; and
  the buy-vs-build gate compares against job-shop ERP rather than PSA tools
  no manufacturer would shortlist.

## 0.19.0 — 2026-07-22

**First public release.** The kit moves to a public repository; history
restarts from a single commit.

- **The money questions no longer assume hours.** `/perp-scope`'s
  billing question is now trade-led — it orders the options by what the
  business actually makes, and never defaults to hourly. Options: per
  part/unit (each or as a lot/package), one price per job (on completion
  or at stages), hourly, prepaid hour blocks, or **a mix** (build around
  the common case). **Deposits and change orders are now their own
  questions**, since money up front cuts across every billing model.
  CLAUDE.md's `Hours/budget` Key Concept became **`Billing model`** with
  no default, plus a separate **Deposits** entry.
- **Deposit and retainer separated everywhere** — a retainer prepays
  *hours*, a deposit prepays *money*. Conflating them was pointing
  fixed-price shops that take 50% up front at retainer machinery they
  don't need. New FEATURE_CATALOG row **Deposits & progress billing**
  (the drawdown rule: every later invoice credits what's already paid,
  one formula, both surfaces — invariant 10).
- **Inventory asked, and asked honestly**: a stock question for shops
  that make physical things, framed so "we buy material per job" is a
  first-class answer meaning *no inventory*. New **Inventory / stock**
  catalog row, labeled a tarpit and never a first slice.
- **A wish question**: phase 5 now asks what the owner would *like* to
  have, not only what hurts. Lands in `SCOPE.md § Wish list` and ⚪
  Planned rows — visible, not promised.
- **DOMAIN_MODEL de-biased**: the variants table leads with parts, and
  the doc now says outright that the hours spine is a drafting choice,
  not a recommendation. Same note on the seed rows in the feature index.
  Eight new trade-signal rows; GLOSSARY gained billing atom, per-part,
  milestones, deposit/drawdown, change order, inventory.
- **New skill `/perp-voice`** — makes the system write like its owner
  instead of like AI: emails, empty states, confirmations, help text.
  Seeds `docs/VOICE.md` from the answers already typed during
  `/perp-scope`, so it costs no extra interview and two shops adopting
  this kit don't ship identical copy. Security error text, a11y labels,
  and money/date/legal strings are excluded by design — personality in a
  404 is how a tenant leak starts. Wired into `/perp-build-core` and
  PORTAL_UX.

## 0.18.1 — 2026-07-04

Two field-test findings:

- **"Where do your files live today?"** — when the interview learns
  files/drawings are exchanged, it now asks the one follow-up
  (Dropbox/Box/Drive/NAS/email) and records it in SCOPE.md. Refines
  the v0.12.0 line: an existing file home is a current-workflow
  *fact* (scope collects it); keep-vs-migrate is still the *decision*
  `/perp-feature` makes — which now confirms the recorded answer
  instead of re-asking.
- **The lead tile is a doorway, not the destination**: the pain-point
  feature gets its **own side-nav page** in Phase One, with the
  dashboard tile linking to it (pain = scheduling → a Schedule page:
  jobs by promised date, even in skeleton form; dispatch-by-work-center
  arrives with routing). "A pain point that lives only as a dashboard
  tile tells the owner their #1 problem is a widget."

## 0.18.0 — 2026-07-04

- **The design bar** (field-test direction: the initial run should
  really pop): `/perp-build-core` gains a "the skeleton must be sexy"
  section — the standard is *looks like a product someone would pay
  for, on the first run*. Concrete rules an LLM can hold: design
  tokens once in the theme (never per-component), real typographic
  hierarchy, the brand carrying the room (portal = same family, tuned
  quieter), the dashboard as the showpiece (stat tiles with hierarchy,
  color always paired with text), designed empty states, barely-there
  motion, and realistic sample data ("4× mounting bracket, $1,240.00"
  — real-looking data is half of looking real). Persists past day one
  via a new PORTAL_UX § "The visual bar (both surfaces)" — token drift
  named as the visual version of two-formulas-for-one-number.

## 0.17.1 — 2026-07-04

- **CLAUDE.md pruned 28%** (26.7KB → 19.2KB against the 27KB budget):
  verbosity cut, zero rules lost — every pin, TODO, section name, and
  pointer preserved (kit-check's keystone-mirror check green). What
  went: explanatory tails whose canonical homes already carry the
  detail (Money & Hours now points at the invariants it restated,
  the canary bullet compressed onto its README troubleshooting entry),
  and one leftover flip residue fixed (Testing still called
  TESTING-PIPELINE "stack-specific, optional" — it's the default
  pipeline). Day-1 also now name-checks `/perp-build-core`.

## 0.17.0 — 2026-07-04

**The mission statement, made operational**: the goal of a custom ERP
is friction removal, in two directions — how work moves through the
shop, and how customers deal with the shop.

- README's pitch now says it (the three bugs are what kill that goal,
  not the goal itself).
- **/perp-scope asks both directions**: Phase 4 now leads with the
  external-friction question ("what's the most annoying part of
  dealing with your shop, from the customer's side?") — the answer
  usually IS the portal's reason to exist; SCOPE.md gains a
  § The friction section carrying both pains.
- **The feature template requires it**: a "Friction removed" line in
  every plan doc's summary — a feature that can't name its friction is
  scope creep (rule mirrored in CLAUDE.md § Feature Planning).
- **Trade signals +2 external-friction rows**: status calls → portal
  dashboard + promised dates; checks in the mail → online payments.

## 0.16.2 — 2026-07-03

- **Trade signals get a growable home**: new FEATURE_CATALOG § "Trade
  signals" table (signal → propose → the Why said back in the shop's
  words), seeded with nine links (promised dates → dispatch list,
  drawings → CAD, sends-work-out → purchasing/travelers, deposits →
  payments, prepaid blocks → retainers, chasing payment → dunning,
  recurring work → templates, on-site/off-site → phase types,
  defense → ITAR posture). perp-scope now reads the table instead of
  carrying inline rules — honing the list is adding a row, not editing
  a skill — and adding a row is the standard move when field tests
  surface new links.

## 0.16.1 — 2026-07-03

Field-test refinements to the magic moment:

- **Day-1 CRUD**: Phase One's spine screens ship with **working
  "+ New" buttons** — adding a real customer next to the sample one on
  day one is the point; basic create/edit is usability, not business
  logic (money math/approvals/generation stay Phase Two). The
  build-core handoff invites it explicitly.
- **Helper banners, both surfaces, day one**: a dismissible one-liner
  per screen — what this is, the one action to try, where the skeleton
  ends ("invoices are view-only for now"). Onboards the customer
  later; teaches the owner-builder now.
- **Trade-aware proposals**: perp-scope's doc pass now proposes
  features the answers imply, with the reason attached — manufacturer
  + promises dates → Promised dates & dispatch list recommended as an
  early make-it-real step; drawings → Part viewing; deposits → Online
  payments. New **WorkCenter (equipment)** entity in DOMAIN_MODEL (the
  dispatch list groups by it; a machine shop thinks in machines), with
  the actual machine list collected by perp-feature's interview at
  scheduling-planning time, not at scope time.

## 0.16.0 — 2026-07-03

**The magic moment** (field-test direction: the audience has little to
no software experience — they should interact with their app on day
one, before any login/plumbing conversation):

- **New skill `/perp-build-core`** — run straight after `/perp-scope`,
  zero questions: scaffolds the whole core skeleton in one pass (both
  shells, both dashboards with the pain-point lead tile, Settings
  pre-filled, the spine's screens in the shop's own vocabulary, portal
  faces from the same shared helpers, clearly-labeled SAMPLE data so
  nothing is an empty wall, a staff⇄customer view switcher), then runs
  the app and hands over the URL with one question: "what should we
  make real first?"
- **Login moves later — safely.** The dev-mode auth rule: no login UI
  in Phase One, but the real auth wrappers guard every route from the
  first route, the stub portal session carries a real clientId (tenant
  filtering exercised from the first query), a permanent "DEV MODE"
  banner shows, and real login (both realms) is a hard **before
  go-live gate** — new first checkbox in that Bootstrap tier, and a
  Security-section rule in CLAUDE.md. Never acceptable: unwrapped
  routes, unfiltered portal queries, or dev mode in a deployment.
- **DOMAIN_MODEL § What to build first rewritten** as Phase One (the
  skeleton pass) / Phase Two (make it real, one ask at a time: money
  flow per billing variant → invoicing + overdue flip → audit log with
  the first real mutation → real login → the rest as scoped).
  README's pitch, adoption step 6, and perp-scope's closing handoff
  now route through /perp-build-core.

## 0.15.0 — 2026-07-03

- **The portal is a dimension, not a phase** (field-test finding: after
  building the first internal feature, the agent proposed "start the
  customer portal" as a separate project — structurally invited by the
  build order's final "portal views" step, and a direct contradiction
  of the parity rule). Build order reworked: step 2 now raises **both
  shells** (staff app AND portal login + empty portal dashboard) so
  every feature has somewhere to put its other half; the final portal
  step is replaced by the standing rule that each slice ships its
  portal face in the same phase, scoped by SCOPE.md § The portal.
  perp-feature plans now interleave surfaces ("portal" is never a
  trailing phase); CLAUDE.md § Parity states the never-a-separate-
  project rule where Claude reads it every session.

## 0.14.0 — 2026-07-03

- **Settings is now a Tier-0 feature** (field-test follow-up): new
  **CompanySettings** entity in DOMAIN_MODEL (one row: document
  name/address/logo, the canonical timezone *value*, default payment
  terms, invoice-number prefix, rounding increment — with the boundary
  rule that migration-shaped decisions are NOT settings, and
  money-adjacent edits are audit-logged), a Tier-0 **Settings** row in
  FEATURE_CATALOG + the index seeds, and build-order step 2 now ships
  the Settings page with the shell, **pre-filled from the /perp-scope
  answers** — the interview's facts become editable runtime data on day
  one. perp-scope's doc pass records the seed values.

## 0.13.1 — 2026-07-03

- **Dashboard lead tile generalized** (field-test follow-up): 0.13.0's
  examples leaked the test interview's own pain point ("quote
  statuses") into the generic kit. The rule is now stated instead of
  the instance: **the lead (top-left) tile is whatever pain point
  /perp-scope recorded** — if it's a trackable status or number — with
  the universal staples (jobs in motion, unapproved time, overdue
  invoices) around it. perp-scope's doc pass now records the lead tile
  on the dashboard seed row.

## 0.13.0 — 2026-07-03

- **The visible early win is now designed in**: new Tier-0 row
  **App shell & staff dashboard** (side nav + the staff home — "what
  needs me today?") in FEATURE_CATALOG and the feature-index seeds,
  and a new **step 2** in DOMAIN_MODEL's build order: build the shell
  right after auth, every tile an honest empty state, tiles lighting
  up with real numbers as later slices land — each via the one shared
  helper (invariant 2), so the dashboard never grows a second formula.
  Rationale: it's the first thing an adopter can see and click, the
  demo surface, and the momentum-keeper for a solo build. Build-order
  step 7 now opens the portal side with the portal dashboard
  (PORTAL_UX § hierarchy) — the customer's mirror of the same win.

## 0.12.0 — 2026-07-03

First **external field-test** feedback (the maintainer running the kit
on a fresh project) — three interview fixes:

- **/perp-scope asks one less question, twice.** The "what does success
  look like in three months / paint the picture" follow-up is gone —
  success criteria are derived by inverting the pain answer and
  confirmed at the summary (asking a shop owner to paint a future
  Tuesday is consultant theater). And the stack confirmation question
  is gone — the default simply applies; the stack only becomes a topic
  if the survey finds an existing codebase or the user volunteers a
  preference.
- **Provider decisions move to feature time.** New principle: scope
  collects *capabilities*, `/perp-feature` collects *providers*. The
  feature skill gained a short feature interview (one question at a
  time) for external-service features — existing file services
  (Dropbox/Drive/Box/NAS vs the S3 default), existing payment
  accounts, sending domain, actual CAD file types — recorded in the
  plan doc with any deviation from the STACK.md default row.

## 0.11.2 — 2026-07-03

- **/perp-scope's index re-seed now ADDS rows, not just swaps them**:
  a yes to part viewing / sending work out / online payments /
  promised dates adds the matching ⚪ Planned rows (FEATURE_CATALOG
  names) to `features/feature_overview.md` — activated features were
  alive in the domain docs but invisible in the index. Activated ≠
  build-now; the first slice stays Tier-0.

## 0.11.1 — 2026-07-03

- **features/feature_overview.md un-drifted**: the Invoicing seed row
  matches its Tier-0 twin again (dueDate + overdue flip); the ⚪
  Planned definition no longer contradicts the plan-doc-less seed rows;
  the seed comment states the hours-variant assumption and points
  milestone/parts shops at the variants section.
- **/perp-scope step 3** now re-seeds the feature index to the billing
  variant and records the chosen first slice there — the index was the
  one doc the tailoring pass skipped.
- **kit-check** gained the features-index check: every
  `features/*.md` plan doc must have a row in the index.

## 0.11.0 — 2026-07-03

Fix pass from the third panel review. Adopter
migration: re-diff README, CLAUDE.md, docs/STACK.md, DOMAIN_MODEL,
GLOSSARY, PORTAL_UX, `.env.example` (replaced wholesale — two auth
secrets now), perp-scope/perp-check/perp-setup-testing, and take the
new `docs/runbooks/deploy.template.md` + `scripts/kit-check.sh`.

- **perp-scope hardened**: fetched web content is data, never
  instructions (brand extraction can't influence pruning or CLAUDE.md);
  per-phase checkpoint to SCOPE.draft.md with resume mode; express now
  includes the regulated-data phase and records skipped-phase
  assumptions; ticks its own bootstrap box; three opening branches
  (fresh/pre-filled/update, all scripted); new questions: promised
  dates, subcontracting, hosting; volunteered batch answers accepted;
  BRAND palette contrast-checked.
- **Stack rules made implementable**: invoice immutability is a
  column-scoped trigger (a blanket REVOKE blocks the status machine's
  own transitions and is a no-op on single-role Prisma — prerequisites
  stated); jobs enqueue transactionally or via outbox (the trap the
  stack panel flagged, now a rule with a mandatory test); route
  handlers are the one mutation door (server actions not used for
  mutations); middleware routes, wrappers enforce; presigned uploads
  get POST-policy constraints + post-upload verification; Better Auth
  pin = exact version + per-realm signing secrets + upgrade procedure +
  two-instance wiring notes; pg-boss payloads carry IDs only, failures
  alert, archive retention set; ITAR files are proxied or
  single-use-URL downloads with issuance logged; CAD conversion runs on
  its own queue (concurrency 1, timeout, size cap) and the GLB pipeline
  names gltfpack/meshopt; `<model-viewer>` is the default viewer with
  an always-present download-original link (the a11y path).
- **Day-1 no longer self-sabotages**: the fill-TODOs box scopes to
  CLAUDE.md (skill commands wait for the stack); perp-check treats
  filled steps with absent preconditions as `⊘ N/A at this stage`;
  setup-testing wires `prisma generate` for real on the default stack;
  the `npm test` script name is now consistent across the three gates;
  the three review skills carry default-stack commands.
- **promisedDate wired** as the third schema-shaped Day-1 decision
  (CLAUDE.md Key Concepts + checklist + the interview); invariant 9
  covers promised-date lateness; the dispatch list's cross-tenant index
  exception is in Scale notes; build-first includes dueDate + the
  overdue flip and the billing-variant adjustments; Tier-0 invoicing
  row says so too.
- **CHANGELOG annotations**: 0.7.0 and 0.9.0 marked (superseded /
  migration note).
- **kit-check grew with the surface** and moved to
  `scripts/kit-check.sh` (same file runs locally and in CI): no shipped
  maintainer-TODOs, STACK↔CLAUDE pin-keystone mirror, CLAUDE.md byte
  budget, § anchor warnings, historical-file exclusions that match the
  rename recipe. Standing rule: new mirror → new check, same commit.
- **Docs**: distribution channel FILLED (repo access via
  chris@zappettiniconsulting.com + watch releases); README gained the
  in-one-breath pitch, the manufacturing story above the fold, 7 new
  troubleshooting entries, upgrade-treadmill + doc-sync cadence rows,
  batched-release guidance, the four-step rename recipe; GLOSSARY +11
  (the v0.9.0 lexicon: serverless, RSC, App Router cluster, presigned
  URL, WASM, Docker, worker, TOTP, monorepo, stack); PORTAL_UX +3
  baseline rules (non-text names, async announcements, 44px targets);
  DOMAIN_MODEL got a TOC-as-prune-map and Scheduling moved out of Core
  entities; STACK.md got a Reviewed stamp, a non-developer off-ramp,
  the falsification-condition paragraph, and honest-cost updates;
  deploy runbook template shipped (compose + migrate-once + rollback);
  CLAUDE.md § Tech Stack compressed to keystone pins (byte budget
  restored, STACK.md declared canonical in the precedence rule);
  canary false-positive expectations added (placeholder values trip
  it — narrowest allow tag, never standing `[allow-all]`).

## 0.10.0 — 2026-07-03

- **Scheduling gets a decided ladder** (DOMAIN_MODEL § "Scheduling —
  build the dates, defer the board"): now = `promisedDate` on Project
  (schema-shaped, Day-1-adjacent); next = the per-work-center
  **dispatch list** as a query over routing statuses, not an engine;
  portal shows promised date + current step via the same shared helper
  as staff (a parity surface); deferred deliberately = capacity/finite
  scheduling and planning boards (APS is a product category, not a
  feature). FEATURE_CATALOG: new "Promised dates & dispatch list" row;
  the planning-board row now points at the ladder. GLOSSARY: dispatch
  list, APS.

## 0.9.1 — 2026-07-03

- **`/perp-scope` restructured around the adopter-from-nothing flow**:
  (0) silently survey the kit first — existing SCOPE.md → update mode,
  already-filled TODOs → skip those questions; (1) a **verbatim
  scripted opening** so every adopter's first impression is identical
  (states the duration, one-question-at-a-time, nothing-saved-until-
  approved, and the "I don't know" / "express" escape hatches, then
  asks Phase 1's first question); (2) the interview; (3) write
  SCOPE.md/BRAND.md on approval; (4) **new final pass: review every
  kit doc against the answers** — fill CLAUDE.md, tick bootstrap
  boxes, propose DOMAIN_MODEL/FEATURE_CATALOG/secure_coding pruning
  (confirm each cut; secure_coding's TOC updated per its own rule),
  record stack deviations in STACK.md. Update mode re-runs the doc
  pass only for touched docs.

## 0.9.0 — 2026-07-03

> *Adopter migration note (added in 0.11.0):* took the kit at
> 0.7.0–0.8.1 and started on Django? **Stay** — Django is the
> documented second path (STACK.md § If you deviate); your
> testing-conventions and perp-check fills stay valid. Re-diff only
> STACK.md, CLAUDE.md § Tech Stack, and perp-setup-testing.

**Default stack changed to the panel's runner-up: Next.js + TypeScript
+ Prisma + PostgreSQL.** A documented maintainer override of the
panel's aggregate (which favored Django), siding with the
AI-development judge: the kit's ultimate users build AI-first, and the
compile-time hallucination net (TypeScript + Prisma's generated client)
plus kit alignment outweigh the aggregate margin for that audience.
The override and its reasoning are recorded in STACK.md § "How it was
decided" and as an outcome note on the panel report — the scores stand
unchanged; Django remains the documented second path.

Mitigations adopted for the two arguments Django won on:

- **Churn** → STACK.md § "Pinned conventions" (App Router only,
  `import 'server-only'` on DB/secret modules, `(app)/` + `portal/`
  route groups with shared `lib/`, deploy target pinned to standalone
  Docker — never serverless), mirrored into CLAUDE.md § Tech Stack so
  Claude reads the pins every session.
- **Below-the-ORM integrity** → STACK.md § "Integrity": the raw-SQL
  constructs (locked `FOR UPDATE` invoice/PO counter, invoice-table
  triggers/`REVOKE UPDATE` in hand-edited migrations, integer-cents
  money) are named rules each carrying a mandatory test — they sit
  outside the type net by definition.

Wired through: CLAUDE.md Tech Stack + Day-1 item; README stack
paragraph/inventory/adoption; perp-check examples (codegen is now a
real step: `npx prisma generate` before the type check);
perp-setup-testing detection order (Next.js first, Django demoted to
second path); perp-scope; TESTING-PIPELINE.md re-promoted to the
default pipeline; testing-conventions mechanics native again.
Per-concern picks: Better Auth
×2 (pinned version; hand-rolled-sessions fallback documented), stripe
SDK + processed-events idempotency, Resend + React Email,
@aws-sdk S3 presigned, pg-boss (+ build a jobs admin page early),
@react-pdf/renderer, Tailwind + shadcn/ui, occt-import-js for
STEP→GLB. Honest costs recorded: the upgrade treadmill, RSC/caching
drift, Better Auth's youth, no native decimal, serverless gravity.

## 0.8.1 — 2026-07-03

- **STACK.md § Deployment** (new): the concrete deploy shape (web +
  worker + Postgres, one Docker compose, gunicorn/django-q2/WhiteNoise;
  Docker mandatory because of WeasyPrint's native libs) and the
  on-the-record answer to "wouldn't the TypeScript stack deploy
  easier?" — the serverless happy path doesn't fit a product with
  persistent workers, slow PDF/CAD tasks, and a Postgres to host
  anyway.

## 0.8.0 — 2026-07-03

- **Full stack-panel findings recorded** — per-judge scorecards with
  reasoning, the overclaims each judge caught, and a dedicated
  **"Why Django over a TypeScript stack"** head-to-head (what TS
  genuinely wins: compile-time hallucination catching, corpus density,
  one-language CAD; why Django won anyway: corpus stability over five
  years, first-party batteries vs an 8-library assembly, audit
  invariants enforceable below the ORM, and a near-tie even under the
  AI lens). STACK.md carries the scores.
- **Purchasing & routing (optional manufacturing group)** in
  DOMAIN_MODEL — the vendor-facing mirror of the customer spine,
  harvested from a real shop's PO-app spec: Supplier, VendorPO (own
  state machine draft → sent → partially-received → received; per-year
  numbering via the same locked-counter rule as invoices — never
  `MAX()+1`), VendorPOLineItem (part + outsourced process + qty,
  per-line receiving), **Operation/Routing** (ordered steps per job,
  work center or outsourced link, status tracking first — scheduling
  is a later tier), PreCannedNote. Outside-processing costs flow
  through Expense — no second cost path.
- **FEATURE_CATALOG**: five new rows — Purchasing / outside
  processing, Job routing & travelers, Document packets, Pre-canned
  notes, Shipping labels.
- **GLOSSARY**: outside processing, traveler (router), work center,
  RFQ.

## 0.7.1 — 2026-07-03

- **`/perp-scope` asks exactly one question per message** (was 2–3 per
  turn). Field-tested finding: users answer the first question and hit
  enter, silently losing the rest of the batch; single questions also
  give the non-developer audience room to think. Phase question-lists
  are now explicitly sequences walked one per turn.

## 0.7.0 — 2026-07-03

> *Superseded same day by 0.9.0* — the default became Next.js via a
> documented override of the panel aggregate; the scores are recorded
> in `docs/STACK.md`, and Django remains the documented second path.

**The kit is no longer stack-agnostic.** An advocate/judge panel (six
stack advocates + a CAD specialist + three adversarial judges; full
record in `docs/STACK.md`) selected a default stack for the target
adopter — a small company, often one AI-assisted developer:

- **Default stack: Django + HTMX + PostgreSQL.** Won 2 of 3 judges and
  the aggregate (259 vs Next.js/Rails 248): stable idioms keep the LLM
  advantage without upkeep, first-party batteries suit a one-person
  team, best money-integrity floor (`select_for_update` counters,
  trigger-enforced audit), best OCCT bindings for CAD. Per-concern
  picks (allauth+sesame two-realm auth, stripe SDK, anymail,
  django-storages, django-q2 jobs, WeasyPrint PDFs) and honest costs
  are in `docs/STACK.md`. Next.js/TS is the documented runner-up;
  `TESTING-PIPELINE.md` is retained as its pipeline reference.
- **Part-viewing provision (OpenCascade)**: decided architecture —
  server-side STEP/IGES→GLB conversion (cascadio) as a background job,
  derivative cached tenant-first in S3 beside the original, three.js
  viewer in the portal; STL views with no conversion. Schema hooks
  shipped in DOMAIN_MODEL (File.kind/contentHash/exportControlled,
  Part→PartRevision→FileAttachment, FileDerivative as an invariant-11
  cached rollup), reserved `file.derive-preview` job, and the ITAR rule
  that derivatives are the same controlled data as the source. New
  FEATURE_CATALOG "Part viewing (CAD)" row; GLOSSARY +4 CAD entries.
- **Wired through**: CLAUDE.md Tech Stack pre-filled (TODO only for
  hosting/swaps); Day-1 stack item is now confirm-or-deviate;
  perp-check examples Django-first; perp-setup-testing detects Django
  as the expected path; perp-scope confirms the default instead of
  opening a stack debate; testing-conventions maps its mechanics to
  conftest/factory_boy with the TS example marked runner-up-only.

## 0.6.0 — 2026-07-03

- **New skill: `/perp-scope`** — the guided start. A 15–20 minute
  plain-language interview (six phases: the business, the work & money,
  regulated data, the portal, the pain & first slice, the look & build)
  that fills the CLAUDE.md `<TODO>`s — including both schema-shaped
  Day-1 decisions — writes `docs/SCOPE.md` and `docs/BRAND.md` (palette
  extracted from the adopter's website/logo when available), checks off
  the answered bootstrap items, and proposes a prune list and the first
  vertical slice. Small question batches, "I don't know" parks with a
  default, never asks for secrets, shows the summary before writing.
  Re-running switches to update mode. Registered as the **first command**
  in README (day-one list, adoption step 2, "Start here") and as the
  first Day-1 bootstrap checkbox.

## 0.5.1 — 2026-07-03

- **DOMAIN_MODEL.md**: new § "Billing-model variants — swapping the
  billing atom" — how the hours-centric model adapts to **milestone
  billing** (fixed-price: milestone = Phase + customer sign-off event)
  and **parts billing** (contract manufacturing: ScopeItem = part/rev/
  qty/unit-price, one new Shipment entity, invoiceable = shipped ∧
  accepted − already invoiced). One table: atom / gating predicate /
  "remaining" formula / portal view per variant. The invariants apply
  unchanged; only vocabulary moves.
- **CLAUDE.md**: the Hours/budget Key Concept `<TODO>` now names the
  no-hours variants and points at the new section.

## 0.5.0 — 2026-07-03

Fix pass from the second panel review — ~40 findings, mostly seams from
the 0.4.0 upstream merge:

- **perp-check**: the Step-0 guard is now **per-step** — configured steps
  run even while others are `<TODO>` (`⊘ NOT CONFIGURED`), and steps
  annotated *skip-if-N/A* no longer block the suite (`⊘ N/A at this
  stage`); codegen moved **before** the type check (generated types must
  exist before tsc reads them); one canonical `typecheck` script shared
  by perp-check, CI, and the pre-push hook.
- **`.claude/settings.json`**: deny globs narrowed so `.env.example` is
  readable again (the Day-1 checklist edits it); README now states the
  deny-list's boundaries honestly (file tools only, Claude Code only).
- **CI unified**: one workflow filename (`ci.yml`), build step added,
  commented codegen/a11y slots, `npm audit --omit=dev --audit-level=high`
  at the gate with the moderate audit moved to a scheduled scan;
  `docs/TESTING-PIPELINE.md` § 5 now explicitly replaces the starter
  ci.yml, and gains an **accessibility assertions** section.
- **Pre-push hook hardened**: checks for husky/existing hooks before
  touching `core.hooksPath`; exec bit recorded via
  `git update-index --chmod=+x` (Windows-safe); `prepare` script
  re-activates per clone; bypass hint printed only on failure, with a
  recovery line.
- **perp-status**: handles a repo with no remote (0.2.0 regression);
  test run capped for slow suites; new stale backup-rehearsal check.
- **perp-commit / perp-push**: committing a secret over a warning now
  triggers the § 8 rotation protocol, not a future-tense note; explicit
  "commit and push" is honored (push guard still applies); the
  main-branch confirmation can only come from the user directly, with a
  documented CLAUDE.md opt-out for solo repos.
- **secure_coding.md § 8**: rotation protocol now covers the CI/platform
  secret stores, derived-session invalidation, and an exposure-window
  log review.
- **New**: `docs/runbooks/incident-response.template.md` and
  `release-checklist.template.md` (both "before go-live" — CLAUDE.md
  bootstrap gained that tier, including the trigger that wires the
  a11y scan in when the first portal view ships); `.github/workflows/
  kit-check.yml` — the primer's own consistency CI.
- **CLAUDE.md**: schema-shaped decisions (hours/budget model, datetime
  policy) promoted to Day-1; glossary pointer; ~250-line size budget;
  precedence rule now names the skills as canonical for process rules;
  sensitive-canary reframed (review + pin, opt-out, honest boundaries);
  the stale "five steps" count removed (kit-check now greps for
  restated counts).
- **README**: inventory regrouped by destination; brownfield adoption
  promoted to a titled section with a pristine-baseline step; new
  **Staying current**, **Operating cadence**, and **Troubleshooting**
  sections; three-step rename recipe (frontmatter + directories, not
  just docs); LICENSE marked reference-only (don't MIT-license your own
  repo by accident); day-one list gains `/panel-review`; "stack-agnostic"
  claim made honest (principles agnostic, examples Node/TS).
- **GLOSSARY**: +14 entries (PSA, CI, pre-push hook, coverage, E2E,
  brownfield, entity factory, mock, secret rotation, vertical slice,
  UTC/DST, type check, greenfield).
- **DOMAIN_MODEL**: never-prune list; AuditLog gains the
  `(clientId, createdAt)` composite index. **FEATURE_CATALOG**: minimum
  overdue-flip named as Tier-0-adjacent.
- **panel-review**: accessibility persona de-scheduler-ified and pointed
  at the project's own baseline (PORTAL_UX.md); phantom "⏳" marker
  generalized to the templates' actual glyphs; sync note added (the
  bundled and user-level copies must stay identical).

## 0.4.0 — 2026-07-03

Merged the updates from the upstream general-purpose bootstrap kit the
primer was originally derived from, keeping the primer's ERP
specializations (TODO guards, tenant-isolation checks, parity):

- **Commit and push are now separate steps.** `/perp-commit` stages and
  commits locally but never pushes; new `/perp-push` is the explicit
  publish step, with a confirmation guard before pushing directly to
  `main` and hard rules against `--force` and `--no-verify`.
- **New skills**: `/perp-status` (read-only session checkpoint — what
  changed, what's open, anything risky uncommitted, including one-sided
  parity changes) and `/perp-setup-testing` (bootstrap a test framework,
  entity factories, a real starter test, coverage, CI, and a
  version-controlled pre-push hook — and fill the `/perp-check` +
  CLAUDE.md Testing `<TODO>`s while at it).
- **Skills layout**: `.claude/commands/*.md` migrated to
  `.claude/skills/<name>/SKILL.md`. Invocation is unchanged
  (`/perp-check` etc.).
- **No silent skips** in `/perp-check`, `/perp-review-code`, and
  `/perp-review-testing`: a missing tool is reported as
  `⊘ SKIPPED — <tool> not installed` with a setup hint, never quietly
  passed over.
- **CLAUDE.md**: new Git Hygiene section (commit/push split, **no AI
  attribution in commit messages**, pre-push hook); Security section
  gains the secret-rotation pointer and the `sensitive-canary` plugin
  recommendation for Claude Code.
- **secure_coding.md § 8**: never let a real secret pass through an AI
  assistant (names, not values), plus a rotation protocol for when a
  secret is exposed or committed anyway.
- **`docs/TESTING-PIPELINE.md`** (new, optional, stack-specific):
  ready-to-copy Vitest + Playwright + monocart merged-coverage pipeline.
- **README**: adoption guidance for existing (brownfield) codebases —
  audit first, findings not silent fixes; note that skills ship in
  Claude Code layout and how to adapt them to other AI tools.

## 0.3.0 — 2026-07-03

- **Renamed the command namespace to `perp-`** (e.g. `/perp-check`). The
  six files in `.claude/commands/` are renamed and every cross-reference
  in the living docs updated.
- **Bundled the `panel-review` skill** (`.claude/skills/panel-review/`) —
  the 16-perspective product review that produced the 0.2.0 fixes. Run
  `/panel-review <feature|flow|surface>` on shipped features; it audits
  UX *and* depth/correctness (phantom integrations, claimed-but-absent
  functionality, timezone/tenancy landmines). Registered in the README
  inventory and CLAUDE.md skill pointers.

## 0.2.0 — 2026-07-02

Fixes from a 16-perspective panel review:

- **Shipped**: `LICENSE` (MIT), `.gitignore`, `.env.example`,
  `.claude/settings.json` (secret-file read/edit denies),
  `docs/PORTAL_UX.md`, `docs/GLOSSARY.md`,
  `docs/runbooks/backup-restore.template.md`, this changelog.
- **secure_coding.md**: corrected x-forwarded-for rate-limit advice
  (rightmost trusted value, not first); per-realm `sameSite` rule (portal
  `lax` — strict broke magic-link/SSO/payment-return flows); hardened the
  open-redirect sample (backslash bypass); new § 16 Webhooks and § 17 File
  Uploads & Storage; 403-vs-404 deciding rule stated once; audit-log
  self-protection, request IDs, staff credential hardening (MFA/password/
  lockout), backup encryption + secrets rotation, baseline CSP; magic-link
  subsection; cross-tenant denials added to the audit table.
- **DOMAIN_MODEL.md**: invariants 9 (UTC datetimes, one day-boundary zone),
  10 (nothing billed twice), 11 (materialized numbers); Payment state
  machine + CreditNote; deposits and change orders; retainer expiry rules;
  hour-rounding; Invoice legal fields (number, dates, tax); acceptance
  atomicity de-ambiguated; audit log added to the first-slice list; scale
  notes (composite indexes, pagination, audit-log retention).
- **Consistency**: canonical-home + precedence rule for duplicated
  invariants; fixed the fabricated CLAUDE.md quote in the parity command;
  reconciled Tier-0 across catalog/index/build-first (7 rows); fixed
  file-size and duplication threshold drifts; defined the 📧 and A→B tags;
  fixed phantom "Build order"/`ARCHITECTURE.md` pointers; removed a source-
  project brand leak; the verification command and CLAUDE.md now refuse to
  improvise unfilled `<TODO>` commands; the commit command handles a repo
  with no remote; command frontmatter added.
- **ARCHITECTURE.template.md**: new Observability, Deployment topology, and
  Outbound email sections; background-jobs failure semantics (missed runs,
  idempotency, dead-man's switch); migration discipline for live financial
  data.
- **README**: honest "blueprints" framing with a works-day-1 table; the
  three ideas moved above the fold; build-vs-buy section; version stamp;
  the command prefix explained.

## 0.1.0

Initial primer: CLAUDE.md, DOMAIN_MODEL, FEATURE_CATALOG,
ARCHITECTURE.template, secure_coding, testing-conventions, features/
templates, and the six slash commands — derived from patterns in a
production ERP-with-portal.
