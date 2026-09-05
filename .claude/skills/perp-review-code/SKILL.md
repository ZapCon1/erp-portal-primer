---
name: perp-review-code
description: Audit structural quality — file sizes, duplication, dead code, tangled logic, type safety, query patterns
---

# Review Code

Review the codebase for structural quality. Use three sources of information:

1. **Your own analysis** — read the code and identify issues.
2. **Static analysis** — run the project's type checker and linter. <TODO: default stack: `npm run typecheck` and `npm run lint` (alt: `mypy .` and `ruff check`).>
3. **Coverage data** — run the coverage report. <TODO: default stack: `npm run test:coverage` (alt: `pytest --cov`).> Low coverage on logic-heavy files is a structural smell — it often means logic is tangled into framework code and can't be tested in isolation.

**Before running any of the above, check that the tool exists.** If the
project has no linter, no coverage script, or no dependency-audit tool,
**don't silently skip** — report each as `⊘ SKIPPED — <tool> not
configured` with a one-line install or setup hint. A silent skip looks
identical to a clean run; an honest skip tells the user where the audit
has gaps, and absent tooling is itself a finding.

## What to check

1. **File sizes** — per `CLAUDE.md` § Code Structure: 250–500 lines is the soft target; files **over 500 lines** are split candidates (list with line counts); 250–500 is worth a look, not a finding. Focus on non-test files in business-logic and API directories. <TODO: name those dirs for this project, e.g. `src/lib/`, `src/app/api/`, `internal/`.>
2. **Duplicated logic** — per `CLAUDE.md` § Duplication & Abstraction: two instances is fine, three is borderline (note it), **four or more is an extraction finding**. Point out where.
3. **Dead code** — unused exports, commented-out blocks, unreachable branches.
4. **Tangled logic** — pure business logic embedded in UI components, API handlers, or other framework glue that should be extracted into testable modules.
5. **Type safety gaps** — `any` / dynamic / untyped escapes, unsafe casts, missing return types on public functions.
6. **Security concerns** — refer to `secure_coding.md` for the full checklist. Flag immediately.
7. **Dependency health** — run the package audit and report any issues.
8. **Query patterns** — unbounded list queries on tenant-scoped tables (no limit/cursor), aggregate helpers called per-row in a loop (N+1), tenant-scoped tables missing a `(clientId, <filter>)` composite index, and any shared rollup helper whose cost grows with total history rather than the page's window. See DOMAIN_MODEL.md § Scale notes.

## What NOT to do

- Don't fix anything. Just report and plan.
- Don't nitpick formatting or style.
- Don't suggest speculative future improvements.
- Don't propose refactors for code that has no test coverage — flag it as needing tests first (use `/perp-review-testing` for that).

## Refactor threshold

- **No refactor needed** if: no non-test files over 500 lines, no logic block duplicated four or more times, no tangled business logic, the dependency audit is clean, type coverage is solid, **and no `SCALE-*` violation below**. Say so and stop.
- **Refactor recommended** if any of these are true:
  - 3+ non-test files over 500 lines.
  - Same logic block duplicated 4+ times (per `CLAUDE.md`: three is borderline — note it, don't force the refactor).
  - Business logic embedded in framework code that can't be unit-tested.
  - **`SCALE-1` — any table carrying `clientId` without a composite index
    `(clientId, <primary filter>)`.** This is a schema fix and it gets
    cheaper the earlier it happens (`docs/DOMAIN_MODEL.md` § Scale notes).
  - **`SCALE-2` — any tenant-scoped list query without a limit or cursor.**
    "A customer with three years of history is not an edge case; it's a
    customer." These two used to be findable here and still permit a
    "no refactor needed" verdict, because scale was not one of the gate
    conditions — it is now.
  - The dependency audit reports moderate or higher vulnerabilities.
  - Multiple type-safety escape hatches in core logic files.

## Refactor plan

If the threshold is met, end with a prioritized plan:

1. **Do first** — high-value, low-risk items (extracting duplicated logic, splitting oversized files, fixing audit vulnerabilities).
2. **Do second** — medium-value items (extracting tangled logic into pure modules, replacing escape hatches with real types).
3. **Skip for now** — items that are real but not worth the effort yet, with a one-line explanation.

For each item, list the file path, what's wrong, and what the fix would be. Keep it concrete.

**Important**: if any files in the refactor plan lack test coverage, note that tests should be added *before* refactoring.
