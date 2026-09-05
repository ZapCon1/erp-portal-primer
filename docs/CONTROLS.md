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

| Sensor | Enforces | Where it runs | **Gates?** |
|---|---|---|---|
| Type check | — | agent loop, pre-push, CI | **yes** |
| Unit tests | `TEST-*`, `TENANT-1` (isolation tests) | agent loop, pre-push, CI | **yes** |
| Dependency audit | `DEP-1` | CI | **yes** |
| Build | — | CI, pre-deploy | **yes** |
| **Dev-auth assertion** | `SEC-2` | app startup, `/perp-check`, CI | **yes** |
| Migration one-shot exit 0 | `OPS-2` | deploy | **yes** |
| Integrity construct tests | `MONEY-4` | CI | **yes** |
| Accessibility scan | `A11Y-1` | CI, once a portal view exists | **yes** *(once live)* |
| Coverage | `TEST-2` | CI, reported | no — drift signal |
| Complexity / file size | `STRUCT-1` | reported | no — drift signal |
| `/perp-review-parity` | `PARITY-*` | before every release | no — inferential |
| `/perp-review-code` | `STRUCT-*`, `SCALE-*` | on request | no — inferential |
| `/perp-review-testing` | `TEST-*` | on request | no — inferential |
| `/panel-review` | everything | pre-release, on request | no — inferential |

### Rules with no sensor yet

Named here so they stay visible instead of feeling covered. Each is a
candidate for promotion, and `/perp-check` reports the honest gap.

| Rule | Currently enforced by | Could be a sensor |
|---|---|---|
| `TENANT-1` tenant filter on every portal query | discipline + tests + review | **Yes — and it should be.** Postgres RLS, or a Prisma client extension that requires a tenant argument on scoped models. See the note below. |
| `MONEY-1` integer minor units | review | Yes — a schema lint rejecting float/decimal money columns |
| `SCALE-1` composite index on every `clientId` table | prose in two docs | Yes — a schema lint |
| `SCALE-2` list endpoints take a limit/cursor | prose | Yes — a lint on route handlers |
| `AUDIT-1` money mutations write an audit entry | review | Partly — a test per mutation route |
| `A11Y-1` portal a11y baseline | a scan that isn't wired until a portal ships | Yes, and the wiring is the gate |
| `OPS-1` runbooks filled before go-live | a checklist | Yes — a check for `<TODO>` in `docs/runbooks/*.md` |

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
- [ ] `OPS-1` Backup scheduled **and one restore rehearsed**, with the date
      recorded.
- [ ] `OPS-3` Error tracking and an uptime check wired, with one alert
      reaching a human. The audit log says what happened; this says what
      failed to happen.
- [ ] `A11Y-1` Accessibility scan wired and green, and one keyboard-only pass
      through the portal.
- [ ] Incident-response and deploy runbooks filled — no `<TODO>` left.
- [ ] `/perp-review-parity` clean.
