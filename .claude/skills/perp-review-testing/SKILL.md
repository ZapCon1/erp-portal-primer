---
name: perp-review-testing
description: Audit test-suite quality — assertions, edge cases, tenant-isolation tests, CI wiring
---

# Review Testing

Audit the project's test suite for substantive quality — what the tests
actually verify about behavior, not just whether coverage numbers look
good. Use four sources of information:

1. **Your own analysis** — read the existing tests and evaluate what they actually assert.
2. **Static analysis** — run the project's type checker over test files <TODO: default stack: `npm run typecheck`>. Run the unit suite <TODO: default stack: `npm test`> and note any failures.
3. **Coverage data** — run the coverage report <TODO: default stack: `npm run test:coverage`>. Identify files with real logic that have low or no coverage. Focus on the business-logic and API directories. **If no coverage tooling is configured at all**, report it as `⊘ SKIPPED — no coverage tooling configured` and surface it as a finding (with a setup suggestion, e.g. `@vitest/coverage-v8` / `pytest-cov`, or `/perp-setup-testing`) — don't silently pass.
4. **CI pipeline inspection** — read the CI workflow file <TODO: e.g. `.github/workflows/ci.yml`> and confirm the same tests that pass locally also run in CI on every PR and push.

## What to check

1. **Untested logic files** — source files with real business logic that have no corresponding tests. List them.
2. **Weak assertions** — tests that use `toBeDefined()`, `not.toBeNull()`, or loose matchers when they should assert specific computed values.
3. **Missing edge cases** — functions that take collections but are only tested with one size. Look for missing tests at sizes 0, 1, 2, and N.
4. **Missing round-trip tests** — any encode/decode, save/load, or serialize/parse pair that isn't tested in both directions.
5. **Tests that mirror implementation** — tests where the assertion is just the function's logic copied into the test.
6. **Over-mocking** — tests that mock so many dependencies that they only verify the mocks. Mocks should be at architectural seams (database, HTTP clients, third-party SDKs, time) only. See `testing-conventions.md`.
7. **Coverage gaps on critical paths** — core business logic that isn't near 100% coverage. <TODO: list what counts as "core" for this project — e.g. "scheduling, billing, hours calculation".>
8. **Tenant isolation** (`TENANT-1`) — multi-tenant route tests must verify tenant scoping. Every such test file should include a cross-tenant access denial test.
9. **Realm isolation** (`SEC-3`) — in a two-realm app, both directions must be tested: a portal session presented to a staff route returns 401, and a staff session to a portal route returns 401. Rejection must come from signature verification, not a cookie-name comparison. Its absence is a finding, not a gap — if a staff wrapper ever accepts a portal session, every customer is staff across every tenant, silently.
10. **Integrity constructs tested concurrently** (`MONEY-4`) — the gap-free counter and the immutability trigger exist only to be correct under contention, so a single-threaded test proves nothing (`testing-conventions.md` § Integrity constructs). A test that generates two invoice numbers in sequence and asserts 1, 2 is the shape to flag.

## CI pipeline check

Open the CI workflow and verify:

1. A workflow exists that runs tests on every PR and push (not just nightly or manual).
2. It runs the full suite, not a subset.
3. Test discovery matches the filesystem — count test files on disk vs what CI reports.
4. The test step can fail the build (no `continue-on-error: true` or `|| true`).
5. E2E tests run in CI (if the project has them).
6. Coverage from unit and E2E is merged (if both exist).

Report CI gaps as first-class findings.

## What NOT to do

- Don't write tests. Just report and plan.
- Don't suggest testing type-only files, pure-presentation components, or framework glue with no logic.
- Don't chase coverage percentage as a goal. Focus on whether important code is meaningfully tested.

## Testing threshold

- **No action needed** if: all files with business logic have tests, assertions check real values, edge cases are covered, coverage on core logic is 80%+, and the full suite runs in CI on every PR. Say so and stop.
- **Improvement recommended** if any of these are true:
  - Source files with real logic have zero test coverage.
  - Core business logic below 80% coverage.
  - Tests rely primarily on weak assertions.
  - No round-trip tests for encode/decode pairs.
  - CI does not run the full suite on every PR.
  - Multi-tenant route tests lack cross-tenant isolation checks.

## Testing plan

If the threshold is met, end with a prioritized plan:

1. **Do first** — fix CI gaps, add tests for untested business logic files, replace weak assertions, add tenant-isolation tests.
2. **Do second** — round-trip tests, E2E tests for critical user flows (login, the primary value flows of the product, multi-tenant data access).
3. **Skip for now** — things that look like gaps but aren't worth the effort, with a one-line explanation.

For each item, list the file, what behavior should be tested, and what kind of test (unit or E2E). Keep it concrete.

**Important**: this pairs with `/perp-review-code`. Run `/perp-review-testing` first to build a safety net, then use `/perp-review-code` to plan structural refactors.
