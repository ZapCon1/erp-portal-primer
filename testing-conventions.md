# Test Conventions (IMPORTANT — follow these to avoid drift)

## Testing Philosophy

These principles govern *what* makes a good test, independent of framework
mechanics. They apply across test runners, languages, and stacks.

### Test behavior, not implementation
- Test names describe what the system does, not what the code calls: `"returns 404 when project belongs to another tenant"` not `"calls db.findUnique"`.
- If you can refactor the implementation without changing behavior and the test breaks, the test is wrong.

### Real assertions
- Use specific assertions: `expect(result).toEqual({ id: "1", name: "Foo" })`, not `toBeDefined()` / `toBeTruthy()` / `not.toBeNull()`.
- Every test should verify real functionality and have a specific bug it would catch — no coverage-padding tests.

### Collection sizes: 0, 1, 2, N
- For any function that handles collections, test with empty, single-element, two-element, and many-element inputs.
- Boundary conditions are where bugs live.
- For anything touching datetimes: also test across a **day boundary in the declared business timezone** and across a **DST transition** (see DOMAIN_MODEL.md invariant 9) — "overdue", "hours this week", and threshold alerts all break exactly there, and parity review can't catch it.

### Round-trip testing
- Every encode/decode, save/load, parse/serialize pair gets a round-trip test.
- The output of one operation fed into its inverse should produce the original input.

### Mock at architectural seams
- Mock storage (database), network (HTTP clients, third-party SDKs), and time — not every function.
- If you're mocking more than the boundary, you're testing the mock, not the code.

### Snapshot discipline
- No snapshot tests for computed values — snapshots are for rendered output only.
- When a snapshot test fails, read the diff — don't blindly update.

### Coverage philosophy
- Don't enforce hard coverage thresholds — they incentivize gaming.
- Core business logic: aim for near-complete coverage.
- UI / framework glue, pure presentation, type definitions: lower coverage is fine.
- Some files are correctly untested: bootstrap configs, type exports, pure layout components.
- **Accessibility is the carve-out from "presentation is low-value":** an automated a11y assertion (axe-core or equivalent) per portal page template is cheap, catches a real defect class the rules above would otherwise deprioritize forever, and is not coverage-padding. See `docs/PORTAL_UX.md`.

### E2E Testing Guidelines
- **E2E tests validate real user-facing behavior**, not code coverage. Every E2E test should answer: "what user-visible outcome does this protect?"
- **Do not write idiomatic E2E tests for coverage.** If the behavior is already covered by a unit test against the same logic, an E2E test adds no value. E2E tests exist to catch integration failures that unit tests structurally cannot — broken routing, missing middleware, auth flows that span multiple requests, UI state that depends on server responses.
- **When unsure about scope, ask.** Before writing an E2E test, propose what it would check and why.
- **Keep E2E tests focused on golden paths and critical edge cases.** A login flow, a payment flow, a tenant user seeing only their own data — worth E2E tests. A tooltip rendering correctly is not.
- **Run the portal's golden paths keyboard-only at least once** (login, view an invoice, pay) — it doubles as the accessibility smoke test (`docs/PORTAL_UX.md`).
- **E2E tests are expensive to maintain.** They break when UI changes, they're slow to run, and they're flaky in CI. Every E2E test must earn its place by catching a class of bug no cheaper test can catch.

### Pre-fix test pattern (security & regression)
When fixing a bug or vulnerability, write the test FIRST. It must FAIL
against the current code (proving the bug exists), then PASS after the
fix. A test that passes both before and after isn't testing the fix.

---

## Test Mechanics

> The principles above are universal. The mechanics below are
> conventions for *this specific project*, written for the **default
> stack** (`docs/STACK.md`: Next.js + TypeScript + Vitest — `vi.mock`,
> `vi.hoisted`, `next/headers`). <TODO: fill in the paths and mock
> lists once `/perp-setup-testing` runs. Deviated to another stack?
> Replace this section wholesale — e.g. on Django/pytest the shape maps
> to conftest.py fixtures, factory_boy factories, pytest-mock at the
> seams — because wrong-stack mechanics are noise that will mislead
> Claude. The shape of the section — shared-setup vs per-file, factory
> naming, mock locations — is what to preserve.>

### Shared setup

**DO NOT** re-declare in individual test files — these belong in the
shared test-setup file (e.g., `<TODO: path to your setup file>`):

- <TODO: list the global mocks that every test inherits. Examples: mocks for `server-only`, `next/headers`, an env loader, a logger silencer.>

### Shared helpers

**DO** import shared helpers instead of redefining inline. Document them
in one place (e.g., `<TODO: path to your test helpers>`):

- `createMockUser(overrides?)` — entity factory with sensible defaults; callers spread overrides.
- `createParams({ id: "foo" })` — wrap route params in whatever shape your framework expects.
- `mockRequireAuth(fn, user)` / `mockRequirePermission(fn, user)` — configure auth mocks for happy-path tests.
- `mockRequireAuthUnauthorized(fn)` / `mockRequirePermissionForbidden(fn)` — negative-auth helpers.
- Date helpers: `daysAgo(n)`, `daysFromNow(n)`, `hoursAgo(n)`.

### Per-file mocks

**DO** still declare per-file (these vary by route):

- Database mock — each file mocks the specific tables/models it touches.
- Auth wrapper mock — varies by route (auth-only vs permission-gated).
- Audit mock — only for routes that audit.
- Domain-specific mocks (notifications, email, payments, storage, etc.).

### Naming conventions
- **Factory functions**: `createMock{Entity}(overrides?)` with `...overrides` spread.
- **Mock variables**: reserve the `mock` prefix for `vi.fn()` / `jest.fn()` variables. Never use bare `mock{Entity}` for factories.

### Mock pitfalls

- `vi.clearAllMocks()` clears **call history**, not **implementations** set via `mockImplementation`. If a previous `describe` block sets a custom implementation, it leaks into subsequent tests. Use `vi.resetAllMocks()` (or re-pin the implementation at the start of each test) when this matters.
- Mock variables referenced inside a `vi.mock()` factory must be declared with `vi.hoisted()` — hoisting otherwise puts the factory above the variable declaration.
- For routes using `requirePermission` + a type guard like `hasUser`: mock both in the auth wrapper mock, then use the helper to wire them. For 401 tests, return the unauthorized response *and* make the type guard return false.

### CI

- The same tests that pass locally must run in CI on every PR and push (not just nightly or manual).
- The test step must be able to fail the build (no `continue-on-error: true` or `|| true`).
- If unit and E2E coverage are merged, the merge step is part of the pipeline, not a local-only convenience.

## Integrity constructs are tested concurrently (MONEY-4)

`CLAUDE.md` and `docs/STACK.md` both call the raw-SQL integrity constructs
"mandatory tests". This is what that means, because a test written the
obvious way passes without proving anything.

Both constructs exist **only** to be correct under concurrency, so a
single-threaded test — "generate an invoice, assert 1; generate another,
assert 2" — passes trivially against a completely broken implementation.
That is exactly the test an LLM writes when told "add a test for the invoice
counter", so state the requirement explicitly:

- **Gap-free numbering under contention.** Open two overlapping
  transactions and have both request a number. Assert the results are
  distinct, sequential, and gap-free. A `MAX()+1` implementation fails this
  and passes the naive version.

  ⚠️ **"Overlapping" is the entire test, so make it real.** Two interactive
  transactions on a single client with a one-connection pool *serialize* —
  the second simply waits — which is indistinguishable from sequential and
  **passes against the broken implementation this test exists to catch**.
  So: use **two separate client instances** (or a pool of at least 2);
  raise the interactive-transaction `maxWait`/`timeout` for these tests,
  because the correct-but-contended path is slower than the default and
  will otherwise abort as a spurious failure; and assert that the second
  transaction **blocks** rather than only that the two numbers differ.

  **The acceptance test for the test:** deliberately swap the
  implementation for `MAX()+1` and confirm it goes red. If it does not,
  it is not a `MONEY-4` test regardless of what it is named.
- **Immutability at the database, not just the app.** Attempt a direct
  `UPDATE` of a financial column on a non-draft invoice **bypassing the
  ORM hook** — the Postgres trigger must reject it. A test that goes
  through the app layer only proves the app layer. "Bypassing" means a
  **raw connection outside the extended Prisma client** — not
  `$executeRaw` through the extended client, which the hook may still
  intercept, leaving you testing the hook you meant to bypass.
- **Status transitions still work.** The same trigger must permit
  `sent → paid` and the `paidAt` write, or you have made invoices immutable
  in a way that breaks collections.

`/perp-review-testing` treats the absence of these as a finding, and
`/perp-setup-testing` scaffolds them as failing stubs so the gap is visible
from day one rather than discovered by a duplicate invoice number.
