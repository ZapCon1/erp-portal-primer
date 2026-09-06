# Controls — what actually enforces the rules

This kit states a lot of rules. This file answers the only question that
matters about any of them: **what happens if I break it?**

**Canonical scope** (per `CLAUDE.md` § Architecture): which controls
exist, which kind each is, and which ones can fail a push or a release. The
rules themselves live in their canonical homes — this file never restates
them, it maps them.

---

## Two kinds of control

| Kind | When it acts | How it works | How much to trust it |
|---|---|---|---|
| **Guide** | *Before* the work — CLAUDE.md, the domain docs, the skills | Steers a person or a model by telling it the rule | **Weak.** A guide is advice. It is followed when it is read, remembered, and not in tension with anything else. |
| **Sensor** | *After* the work — type checks, tests, linters, review passes | Observes what was actually produced | **Strong when computational** (deterministic, fast, ungameable), weaker when it's a judgement call |

Sensors split again, and the difference decides where one belongs:

- **Computational** — `tsc`, the test suite, a migration check, a grep. Runs
  in seconds, same answer every time. These can gate.
- **Inferential** — `/perp-review-parity`, `/perp-review-code`, `/panel-review`.
  Slow, probabilistic, surfaces judgement calls. These belong **outside** the
  commit path, in front of a human. They are drift detection, never gates.

### The rule this file exists to enforce

> **A rule stated in a guide with no sensor behind it is not enforced — it
> is a hope.** When you notice one, that is a finding, not a gap to leave
> quiet. `/perp-check` reports it explicitly rather than omitting the line.

This kit is mostly guides. That is appropriate for domain judgement (what a
billing atom *is*) and inappropriate for binary invariants (whether a portal
query filtered by `clientId`). Every rule below that could become a sensor
and hasn't is listed as such, honestly.

---

## The sensor map

`/perp-check` runs this column and reports every line, including the ones
that aren't installed.

| Sensor | Enforces | Where it runs | **Gates today?** | To make it gate |
|---|---|---|---|---|
| Type check | — | agent loop, pre-push, CI | **yes** | — |
| Unit tests | `TEST-*`, `TENANT-1` (isolation tests) | agent loop, pre-push, CI | **yes** | — |
| Dependency audit | `DEP-1` | CI | **yes** | — |
| Build | — | CI, pre-deploy | **yes** | — |
| **Dev-auth assertion** | `SEC-2` | app startup | **yes, at boot** | it refuses to start; a CI step asserting the guard's *polarity* is not written yet |
| Migration one-shot exit 0 | `OPS-2` | deploy | by the runbook | automate it in the deploy job |
| Integrity construct tests | `MONEY-4` | — | **no — nothing creates them** | `/perp-setup-testing` must scaffold the two concurrency stubs |
| Accessibility scan | `A11Y-1` | CI slot, commented out | **no — not enabled** | uncomment the `pa11y-ci` step once a portal view exists |
| Exact-pin + lockfile check | `PIN-1`, `PIN-2` | `/perp-check` | on request only | add the step to `ci.yml` |
| Toolchain contract | `PIN-3`, `PIN-4` | `/perp-check` | on request only | add the step to `ci.yml` |
| Stack review freshness | `PIN-5` | `/perp-check`, kit-check | no — drift signal | never; a date is not a gate |
| Controlled-file egress gate | `CUI-1` | — | **no — not built** | the `File.classification` column + the uploader check (§ Compliance) |
| Released-revision immutability | `DOC-1` | — | **no — not built** | ships with the Doc Control module |
| Approval-before-release | `DOC-2` | — | **no — not built** | ships with the Doc Control module |
| Flagged-file access audit | `CUI-2` | — | **no — not built** | ships with the Doc Control module |
| Coverage | `TEST-2` | CI, reported | no — drift signal | never (§ Why some rules must never gate) |
| Complexity / file size | `STRUCT-1` | reported | no — drift signal | never |
| `/perp-review-parity` | `PARITY-*` | before every release | no — inferential | never |
| `/perp-review-code` | `STRUCT-*`, `SCALE-*` | on request | no — inferential | never |
| `/perp-review-testing` | `TEST-*` | on request | no — inferential | never |
| `/panel-review` | everything | pre-release, on request | no — inferential | never |

> **Read the fourth column literally.** It says what stops a bad change
> *today*, in this repo, with what is actually shipped — not what the design
> intends. An earlier version of this table marked ten rows "CI | **yes**"
> when the CI template implemented one of them, which is the precise failure
> this file exists to prevent, committed by this file.

### Gating a merge is a GitHub setting, not a CI step

Even a **yes** above only blocks a *push* (via the pre-push hook, which
`--no-verify` skips). Making it block a **merge** or a **deploy** requires
repository settings that live in GitHub, where no check in this repo can see
them: required status checks, `enforce_admins`, and a deploy environment
with a required reviewer.

**`GH-1`: a check that cannot block a merge is a report, not a gate.**
`docs/GITHUB.md` is the six-step setup, and confirming it is a go-live line.

### Rules with no sensor yet

Named here so they stay visible instead of feeling covered. Each is a
candidate for promotion, and `/perp-check` reports the honest gap.

| Rule | Currently enforced by | To fix it |
|---|---|---|
| `TENANT-1` tenant filter on every portal query | discipline + tests + review | **Yes — and it should be.** Postgres RLS, or a Prisma client extension that requires a tenant argument on scoped models. See the note below. |
| `MONEY-1` integer minor units | review | Yes — a schema lint rejecting float/decimal money columns |
| `SCALE-1` composite index on every `clientId` table | prose in two docs | Yes — a schema lint |
| `SCALE-2` list endpoints take a limit/cursor | prose | Yes — a lint on route handlers |
| `AUDIT-1` money mutations write an audit entry | review | Partly — a test per mutation route |
| `A11Y-1` portal a11y baseline | a scan that isn't wired until a portal ships | Yes, and the wiring is the gate |
| `OPS-1` runbooks filled before go-live | a checklist | Yes — a check for `<TODO>` in `docs/runbooks/*.md` |
| `DOC-3` superseded revisions retained, never deleted | prose | Yes — a test asserting delete is refused |
| `DOC-4` printed controlled docs stamped "uncontrolled when printed" | prose | Yes — assert the stamp in the render test |
| `DOC-5` the app owns the rev letter, not the storage service | prose | Partly — a test that an out-of-band file change does not advance a revision |
| `QUAL-1` scrap + rework + shipped reconcile against qty ordered | prose | **Yes, and it is a money rule** — one arithmetic identity, testable |
| `CUI-3` audit records retained for the contracted period | prose | Yes — a retention setting plus a check that it is set |
| `CUI-4` MFA on privileged access | go-live checklist | Yes, once real login lands |
| `CUI-5` delete sanitizes rather than soft-deletes flagged data | prose | Write a test that the row and the object are gone |
| `OPS-3` error tracking + uptime, one alert reaching a human | a go-live checkbox | Name one uptime poller and one error tracker in `docs/runbooks/deploy.md`; the acceptance test is **send one test alert and confirm a human got it** |
| `STOP-1..7` the rules binding the assistant when the owner cannot review the work | prose in `CLAUDE.md`, read by the model | Nothing computational can verify the model obeyed them. kit-check asserts the *sentences* survive (and tripwires their inversion); the owner-facing detector is `docs/WHEN-IT-GOES-WRONG.md` § Warning signs. **Treat these as the least-enforced rules in the kit, not the most** |
| `PARITY-1` the two surfaces compute every shared number identically | one shared `lib/` helper, by discipline | `/perp-review-parity` is inferential. A real sensor is a test that calls the same helper from both surfaces and asserts equality |
| `GH-2`/`GH-6` a red build blocks the merge and the deploy | **nothing in this repo** — they are GitHub settings | Work through `docs/GITHUB.md`, then open one throwaway PR with a deliberate break and confirm the merge button is disabled |

⚠️ **On `TENANT-1` specifically.** Earlier versions of this kit asserted that
no ORM-level safety net exists for tenant isolation. That is not true on the
pinned stack: **Postgres row-level security** and **Prisma client extensions**
both enforce it below the query site, and both fail *closed* on the filter
someone forgot. The kit applies belt-and-braces to invoice immutability (an
app-level hook *and* a database trigger) — the failure that ends the business
deserves at least as much. Treat discipline, tests, and
`/perp-review-parity` as the layers *on top of* a mechanism, not as the
mechanism.

---

## Compliance controls (AS9100 · ITAR/EAR · CMMC)

Two regimes, three questions each, and the same answer shape: **who may see
this, may it leave, what do we keep.** Neither is a module —
`docs/MODULES.md` § Compliance posture explains why — but both need
*controls*, not paragraphs.

### The one field everything hangs off

`File.classification` — `unrestricted` · `export-controlled` · `cui` —
checked in **one** predicate, honored by every module and every integration.
Provision it in the first migration; retrofitting a classification onto live
files means classifying them by hand, from memory.

### AS9100 document control

**Status is the third column, and it is the one to read first.** This section
describes what these controls must be. Nothing below is built yet — it ships
with the Doc Control module. An imperative sentence is a specification, not a
receipt.

| Rule | What must enforce it | Status |
|---|---|---|
| `DOC-1` A released revision is immutable | The same belt-and-braces as invoices: app-level hook **and** a DB constraint. Editing a released rev in place is how a controlled document quietly becomes uncontrolled. | not built yet |
| `DOC-2` Release requires every named approval | Blocked in the state machine, tested. `draft → in-review → released` cannot skip. | not built yet |
| `DOC-3` Superseded revisions are retained | Delete is refused, not soft-flagged. An auditor asks for rev B after rev C shipped. | not built yet |
| `DOC-4` Prints are stamped and logged | Render asserts rev + timestamp + "uncontrolled when printed". | not built yet |
| `DOC-5` The app owns the rev letter | If files live in Box/Dropbox/SharePoint, their native version history is **not** the record (`docs/MODULES.md` § File storage). | not built yet |
| `QUAL-1` Quantities reconcile | ordered = shipped + scrapped + reworked-out. A drift here bills a customer for parts they never got — a `MONEY-1` failure wearing a quality costume. | not built yet |

### ITAR/EAR and CMMC/CUI

**Status column again — read it before the prose.** The classification field
and the egress gate are the two that must exist in the first migration;
neither is written by `/perp-build-core` yet.

| Rule | What must enforce it | Status |
|---|---|---|
| `CUI-1` Flagged data never reaches a third party | The integration scaffold's `mayReceiveControlledData`, **default false**, checked at the uploader — not filtered downstream and not left to the operator. It is the highest-leverage control in the kit, and its reach has a hard edge. It gates **deliberate, app-initiated transfers of a classified `File` to a registered provider**: Toolpath, hosted converters, email attachments, file-storage sync. It structurally **cannot** gate three paths people assume it does — an **error tracker** (an SDK auto-captures payloads and stack locals; there is no uploader and no connection record in that path — scrub at `beforeSend`, or self-host), a **CDN or presigned URL** (infrastructure the object store serves directly — for flagged files the app-proxy path in `CUI-2` is the only compliant option, not an alternative), and **LLM/assistant tooling** (it reads the repo on the owner's machine, outside the app entirely — the control is the rule in `docs/WHEN-IT-GOES-WRONG.md`: never open a controlled drawing in the repo the assistant reads). | not built yet |
| `CUI-2` Every access to a flagged file is audit-logged | And a presigned URL is a **bearer credential the object store serves without telling your app** — so flagged files are proxied through the app, or issued single-use URLs whose *issuance* is the logged event (`docs/STACK.md` § Part viewing). | not built yet |
| `CUI-3` Audit records are retained and protected | Retention is a decision, not a default. Write it down and check it is set. | not built yet |
| `CUI-4` MFA on privileged access | Lands with real login (`SEC-2`), not after. | not built yet |
| `CUI-5` Delete means gone | Sanitization, not a soft-delete flag — the row *and* the stored object. | not built yet |

⚠️ **The honest limit of all of this.** These controls make compliance
*achievable*; they do not confer it. You still owe a system security plan, a
POA&M, evidence, and an assessor conversation — and for CUI in a cloud, a
hosting decision that may be constrained
(`docs/DEPLOYMENT_TARGETS.md` § AWS GovCloud). **A kit cannot certify you.**
What it can do is make sure the expensive, retrofit-hostile pieces — the
classification field, the egress gate, the audit trail — exist from the
first migration rather than being discovered at audit.

---

## Idiom churn (PIN-*) — the one risk this kit can actually measure

`docs/STACK.md` § Honest costs names idiom churn as the strongest argument
against the pinned stack. For a long time that was all it was: a warning.
It is not a judgement call, though — it is **deterministic and cheap to
detect**, which makes it a sensor problem, not a prose problem.

**What churn actually looks like.** Not "a version number moved". It is one
of three specific things, and each has a different detector:

| Failure | Real example | Detector |
|---|---|---|
| A command you depend on disappears | `prisma@8` (the `latest` tag, on a clean install) has no `generate`, `validate` or `migrate dev` — breaking `/perp-check`, CI and the deploy runbook at once | assert the subcommand exists |
| An idiom you documented is rejected | Prisma 7 refuses `url = env(...)` inside `datasource` — every tutorial and most training data still teach the old shape | assert the shape matches the installed major |
| A tool "succeeds" without doing anything | `create-next-app` exits **0** after refusing to scaffold | assert the artifact exists, not the exit code |

| Rule | What it means | Gates? |
|---|---|---|
| `PIN-1` | Load-bearing dependencies are pinned **exactly** — no `^`, no `~` — and the lockfile is committed. A caret is an unattended upgrade. | **yes** |
| `PIN-2` | CI installs with `npm ci`, never `npm install`, so the lockfile is authoritative rather than advisory. | **yes** |
| `PIN-3` | Every command the kit's own docs invoke still exists in the installed toolchain. | **yes** |
| `PIN-4` | Documented idioms match the installed major version (e.g. Prisma ≥ 7 ⇒ `prisma.config.ts` exists **and** the schema carries no `url =`). | **yes** |
| `PIN-5` | The `_Reviewed:` stamp on `docs/STACK.md` is fresh. | no — drift signal, then a gate once badly stale |

### Why `PIN-3` and `PIN-4` are the interesting ones

Pinning alone (`PIN-1`) only defers the problem: it makes the day you
upgrade the day everything breaks, all at once, usually under time
pressure. The pair above turn that into a normal failing check.

They also catch the case pinning cannot: **an adopter following the kit's
prose on a newer toolchain than the prose was written for.** That is the
common shape — nobody upgraded, the docs were simply older than `npm`. It is
what a fresh `npm install prisma` did on 2026-09-05.

### The upgrade drill

When a pin moves, do it deliberately and in this order — never as a side
effect of an unrelated install:

1. **One library, one branch.** Never bundle upgrades; you lose the ability
   to attribute the breakage.
2. **Read the changelog for the three things this kit depends on**: removed
   or renamed commands, changed config shape, changed defaults.
3. **Run `/perp-check`.** `PIN-3`/`PIN-4` fail *first* and by name, which is
   the whole point — the alternative is a confusing error inside a migration.
4. **Fix the kit's own docs in the same commit** as the pin. A version bump
   that leaves `docs/STACK.md` teaching the old idiom is how the next
   adopter inherits your afternoon.
5. **Re-stamp `docs/STACK.md`** `_Reviewed:_` and note what changed.

### What this cannot do

It cannot tell you an idiom is *deprecated but still working* — the quiet
middle where a command exists, emits a warning, and is removed two releases
later. Nothing computational catches that; reading release notes does. So
`PIN-5` exists to force the reading on a schedule, and it is the only rule
here that a human has to satisfy rather than a check.

---

## Why some rules must never gate

Gating the wrong thing is worse than not gating, because it teaches people to
game the number.

- **Complexity thresholds** are satisfied by splitting one honest 13-branch
  function into three dishonest ones — worse code that scores better.
- **Coverage percentages** are satisfied by tests that assert nothing.
- **File-size limits** are satisfied by moving code somewhere less cohesive.

For these, the count over several sessions is the signal, and a single
reading means nothing. **Never promote a drift signal to a gate on your own
initiative**, and never report one as a failure.

---

## Where a control belongs

- **In the agent's own loop** — anything under a few seconds. Type check,
  unit tests. Fast enough to self-correct without a human turn, which is the
  entire value.
- **At pre-push** — the same fast gate. One hook, not several; a second hook
  means a second bypass flag to remember.
- **In CI** — everything, including the slow ones. CI is the only place that
  sees a clean checkout, so it is the only honest answer to "does this build
  from nothing?"
- **In front of a human** — every inferential sensor. `/perp-review-parity`
  before a release; `/panel-review` when depth is in question.

**CI must be able to fail the build**, and CI must have a database — the
tenant-isolation tests are the kit's most important tests and they need one.
A green CI that never ran them is the most expensive kind of false comfort.

---

## Go-live gates

These are the controls that must exist before anyone outside the shop touches
the system. **They are listed here, permanently, rather than only in
`CLAUDE.md`'s Bootstrap checklist — that section is designed to be deleted,
and a gate that disappears when a checklist is tidied away was never a gate.**

- [ ] `SEC-2` **Real login on both realms; the dev-auth stub cannot start in
      production.** Not a checkbox — an assertion in the auth module that
      refuses to boot, plus a `/perp-check` step.
- [ ] `SEC-3` Cross-realm rejection tested both directions (a portal session
      presented to a staff route returns 401, and vice versa).
- [ ] `TENANT-1` mechanism in place, not just discipline.
- [ ] `CUI-1` Egress gate live and defaulting to false, **if any file is
      flagged** — verified by trying to send a flagged file to an
      integration and watching it be refused.
- [ ] `CUI-2` Access to flagged files is audit-logged, including the
      presigned-URL issuance path.
- [ ] `DOC-1`/`DOC-2` If AS9100 is claimed: released revisions immutable,
      release blocked without approvals, supersessions retained.
- [ ] `OPS-1` Backup scheduled **and one restore rehearsed**, with the date
      recorded.
- [ ] `OPS-3` Error tracking and an uptime check wired, with one alert
      reaching a human. The audit log says what happened; this says what
      failed to happen.
- [ ] `A11Y-1` Accessibility scan wired and green, and one keyboard-only pass
      through the portal.
- [ ] Incident-response and deploy runbooks filled — no `<TODO>` left.
- [ ] `GH-2` Required status checks on the default branch, `enforce_admins`
      on — **verified by opening one PR with a deliberate break and seeing
      the merge button disabled**, not by looking at the settings page.
- [ ] `GH-3` Secret scanning + push protection enabled.
- [ ] `GH-6` Deploy gated: the deploy job `needs:` the CI job, and the
      `production` environment has a required reviewer.
- [ ] `/perp-review-parity` clean.
