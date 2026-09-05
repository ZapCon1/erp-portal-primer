---
name: perp-check
description: Run every verification sensor and report honestly — split into gates (a failure blocks the push) and drift signals (a number to watch). Reports pass, fail, and every skip with its reason. Use for "check", "verify", "is everything passing", or after any significant change.
---

# Check

Run every **sensor** in `docs/CONTROLS.md` and report the results honestly:
what passed, what failed, and what was skipped **and why**.

Report in two groups, never one flat list. `docs/CONTROLS.md` says which is
which, and the split is not cosmetic: it tells the user which lines are
**gates** (a failure blocks a push or a release) and which are **drift
signals** (a number worth watching whose single readings mean little). A
complexity warning and a failing test in the same undifferentiated list
invite treating them the same way, and they are not the same thing.

**A silent skip is worse than a failure.** A skipped line that isn't printed
looks exactly like a clean run, so the user believes it passed. Every skip
gets a line and a reason.

## 1. Find the commands — detect, don't guess

Read the repo before running anything:

- `package.json` `scripts` — the default stack. Prefer what's actually
  defined (`typecheck`, `test`, `test:ci`, `build`) over any command
  written below.
- `.github/workflows/*.yml` — **in an existing repo this is the best source
  of truth** for what the project really runs on every push. If CI runs
  `test:ci` and not `test`, run `test:ci`.
- `Makefile`, `pyproject.toml`, `Cargo.toml`, `go.mod` for other stacks.

Only if the repo tells you nothing, fall back to the defaults in the table.
**Never improvise a command that would fail for a reason unrelated to the
code** — a missing script is a skip with a reason, not a failure.

**No `package.json`, no source, pre-code repo?** Report
`⊘ N/A — no application code yet` for the build-dependent lines and stop
there calmly. A pristine primer must not produce a wall of red that looks
like a broken project.

## 1b. The toolchain contract (PIN-*) — run this FIRST

Idiom churn is the failure this catches, and it is worth catching **before**
the other sensors, because otherwise it surfaces as a baffling error inside
a migration rather than as "the command we depend on is gone".

Check four things and report each as a gate:

- **`PIN-1` — exact pins.** Read `package.json`: the load-bearing
  dependencies (the framework, the ORM, the auth library, the job runner)
  must have **no `^` and no `~`**, and a lockfile must be committed. A caret
  is an unattended upgrade. Report each offender by name.
- **`PIN-2` — CI uses `npm ci`.** Grep the workflow. `npm install` in CI
  makes the lockfile advisory, which defeats `PIN-1`.
- **`PIN-3` — the commands still exist.** For every command this kit's docs
  tell you to run, confirm the installed CLI still has it:

  ```
  npx prisma --help    → must list `generate` and `migrate`
  npx next --help      → must list `build`
  ```

  A **missing subcommand is a `✗` gate failure, not a skip** — it means a
  major version removed something the CI workflow and the deploy runbook
  both invoke.
- **`PIN-4` — documented idioms match the installed major.** Version-
  conditional, so it stays true as the stack moves:

  | If | Then assert |
  |---|---|
  | `prisma` major ≥ 7 | `prisma.config.ts` exists **and** `schema.prisma` contains no `url =` inside `datasource` |
  | `prisma` major ≤ 6 | the opposite — `url = env("DATABASE_URL")` in the datasource block |
  | `next` major ≥ 13 | no `getServerSideProps` / `pages/api/` anywhere (App Router only — `docs/STACK.md` § Pinned conventions) |

**And one habit that is not a version check at all:** *verify the artifact,
not the exit code.* `create-next-app` has been observed exiting **0** after
refusing to scaffold. After any generator runs, assert the thing it was
supposed to produce actually exists.

**`PIN-5` — stack freshness (drift signal, never a gate).** Read the
`_Reviewed:_` stamp at the top of `docs/STACK.md`. Over 90 days, say so in
one line; over 180, treat it as a finding. This is the only rule here a
human satisfies rather than a check, and it exists because the quiet middle
— a command that still works but is deprecated — is invisible to every
detector above and visible in release notes.

## 2. Run the sensors

Run all of them in order, **even if an earlier one fails** — the user wants
the full picture, not stop-at-first-failure.

### Gates

| # | Sensor | Default-stack command | Notes |
|---|---|---|---|
| 1 | Dependency audit | `npm audit --omit=dev --audit-level=high` | `pip-audit` / `cargo audit` elsewhere |
| 2 | Codegen | `npx prisma generate` | Runs **before** the type check — generated types must exist first. **If the command doesn't exist, that is a finding, not a skip**: report `✗ codegen — command not found in the installed CLI` and check the pinned version. A major-version bump can remove or rename it (`docs/STACK.md` § Honest costs). |
| 3 | Type check | `npm run typecheck` | Same command here, in CI, and in the pre-push hook, so the three can't disagree |
| 4 | Unit tests | `npm test` | Includes the tenant-isolation tests (`TENANT-1`) |
| 5 | Build | `npm run build` | |
| 6 | **Dev-auth assertion** (`SEC-2`) | see below | |
| 7 | Accessibility scan (`A11Y-1`) | `npx pa11y-ci` or axe | **Once any portal view exists** — see the precondition rule below |

**Step 6 — the dev-auth gate.** Grep the production auth path for the
dev-mode stub and for the assertion that must guard it:

- If an auth stub exists **and** no production guard is present (an assertion
  that throws or refuses to boot when the stub is active outside
  development): report `✗ FAIL — dev-auth stub reachable in production`.
  This is a gate. It does not get downgraded because the app "isn't deployed
  yet" — the whole failure mode is that the deploy happens later and nobody
  re-checks.
- If real login is live on both realms: `✓`.
- If there is no auth code at all yet: `⊘ N/A — no auth module yet`.

### Drift signals — report, never fail

| Sensor | Command | Why it never gates |
|---|---|---|
| Coverage | the project's coverage script | A percentage is satisfied by tests that assert nothing |
| Complexity / file size | the project's lint, or a line count | A hard threshold is satisfied by splitting one honest function into three dishonest ones |

`docs/CONTROLS.md` § Why some rules must never gate has the reasoning.
**Never promote a drift signal to a gate on your own initiative**, and never
report one as a failure.

## 3. The precondition rule (read this before reporting any skip)

Three cases, and the third is the one that used to be missed:

1. **No command available and none derivable** → `⊘ NOT CONFIGURED — <what
   would fix it>`. Never improvise, never report success.
2. **Command available, precondition genuinely absent** (no portal UI yet for
   the a11y scan, no `prisma/schema.prisma` for codegen, no `package.json`
   for the npm steps) → `⊘ N/A at this stage — <missing precondition>`.
3. **Precondition now HOLDS and the sensor still isn't wired** — a portal
   view exists but no a11y scan is configured; auth code exists but no
   dev-auth assertion; `clientId` tables exist but no isolation test →
   **`⊘ NOT CONFIGURED` and treat it as a finding.** It is *not* `N/A`.
   The precondition firing is precisely what makes the gap real, and this is
   the case where a quiet `N/A` would let a portal ship unscanned forever.

**Tool present but not installed** (`pa11y-ci` missing, `pip-audit` missing)
→ `⊘ SKIPPED — <tool> not installed (install: <command>)`, and treat it as a
finding, not a clean line.

**No test framework at all** → `✗ NO TEST FRAMEWORK CONFIGURED`, not a skip,
and offer `/perp-setup-testing`.

**A rule with nothing enforcing it is a finding.** If `docs/CONTROLS.md`
§ "Rules with no sensor yet" lists something whose precondition now holds —
most importantly `TENANT-1` once portal routes exist — say so once in the
summary. Offer the fix; don't nag every run.

## 4. Report

```
Gates — a failure here blocks the push
  ✓ audit       npm audit — 0 vulnerabilities
  ✓ codegen     prisma generate — client written
  ✗ types       tsc — 2 errors (src/lib/invoice.ts:41, :77)
  ✗ tests       3 failed of 47 (src/portal/invoices.test.ts:22)
  ✓ build       next build — ok
  ✗ dev-auth    stub reachable in production — no startup assertion (SEC-2)
  ⊘ a11y        NOT CONFIGURED — portal views exist, no scan wired (A11Y-1)

Drift signals — watch the trend, don't gate on the number
  ! complexity  3 files over 500 lines (was 1 last run)
  ✓ coverage    81% statements (was 79%)
```

Markers: `✓` passed · `✗` failed · `!` over threshold but not a failure
(drift signals only) · `⊘` skipped or N/A, **always with a reason**.

Every line gets a marker — no omissions. Show error output under the summary
for anything that failed (last ~20 lines usually suffices). If everything
configured passed, say so plainly **and list what is still unconfigured**, so
the gaps stay visible rather than being read as coverage.

If a drift signal is trending, one sentence is the useful form:

> Files over 500 lines went 1 → 3 in three runs, all under `lib/billing/`.
> Worth a look before it gets harder to change.
