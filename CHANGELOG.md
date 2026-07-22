# Changelog

All notable changes to the primer. Adopters: record the version you
adopted in your repo (see README § How to adopt) so you can diff
against future releases.

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
