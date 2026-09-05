---
name: perp-setup-testing
description: Wire up a test framework, write a meaningful starter test, and set up coverage, CI, and a pre-push hook. Use when the user says "set up testing" or when /perp-check reports no test framework configured.
---

# Setup Testing

Bootstrap a test framework on a project that doesn't have one — or that
has a half-configured setup. The goal is to leave the project with: a
test command that actually runs, at least one **real** test (not a
smoke test), coverage tooling configured, and CI that runs both on every
PR. Follow `testing-conventions.md` throughout — it is the canonical
test-philosophy doc for this project.

## 1. Detect or ask which framework

Inspect the project before suggesting anything:

- **Next.js project (`next.config.*`)?** → **Vitest** — this is the
  kit's default stack (`docs/STACK.md`), so it's the expected path;
  `docs/TESTING-PIPELINE.md` is the full ready-to-copy pipeline
  (including its § "Next.js / webpack projects" notes). If the repo
  already uses Jest, keep Jest and map its commands into the `<TODO>`s
  instead of migrating.
- **Has `vite.config.*` or uses Vite?** → **Vitest**. Same transform
  pipeline, native ESM, fast.
- **Django project (`manage.py`)?** → **pytest + pytest-django +
  pytest-cov**; Playwright (Python) for E2E. (Django is the panel's
  documented second-path stack.)
- **Plain Node library, no DOM?** → **Vitest** (or `node:test` if the
  user wants zero dependencies).
- **Python with `pyproject.toml`?** → **pytest** with **pytest-cov**.
- **Anything else** → ask the user. Don't guess.

**Workspaces / monorepo?** Detect per package — the root often has no
`vite.config.*` while `packages/*` do. Config lives in each package;
aggregate scripts at the root. If a test runner and CI already exist
anywhere in the repo, don't install a second framework — map the
existing commands into the CLAUDE.md / `/perp-check` `<TODO>`s instead.

State your detection and ask the user to confirm before installing
anything: *"This looks like a Vite + React project, so I'll set up
Vitest with `@vitest/coverage-v8`. OK?"*

Once confirmed, record the chosen framework and commands in
`CLAUDE.md` § Testing (replacing its `<TODO>` markers) and fill the
matching `<TODO>` steps in `/perp-check` — this is what makes the
verification suite real.

## 2. Install

For Vitest on a Vite project:

```bash
npm install -D vitest @vitest/coverage-v8 jsdom
```

For Jest on an existing Jest project:

```bash
npm install -D jest @types/jest @testing-library/react @testing-library/jest-dom jest-environment-jsdom
```

For pytest:

```bash
pip install pytest pytest-cov
```

Pin versions if the project pins everything else. Run the package
audit after installing.

## 3. Configure

Write the minimum config needed — don't add 30 options the user doesn't
understand yet. For Vitest:

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    coverage: {
      provider: 'v8',
      include: ['src/lib/**', 'src/data/**'],
      reportsDirectory: './coverage',
    },
  },
});
```

For Jest on Next.js, write a `jest.config.js` with the `next/jest`
preset. For pytest, add `[tool.pytest.ini_options]` to `pyproject.toml`
with `testpaths` and `addopts = "--cov=<package>"`.

The full Vite pipeline (Playwright E2E + merged unit/E2E coverage via
monocart) is documented in `docs/TESTING-PIPELINE.md`; point the user
there once the basics are working. Its Step 5 **upgrades the `ci.yml`
this skill writes** — same file, replaced in place, never two workflows.

## 4. Set up shared helpers (this project's shape)

An ERP-with-portal test suite needs two things from day one (see
`testing-conventions.md`):

- **Entity factories** that mint a realistic graph — at minimum a
  tenant (client) + a user + a project — so every test starts from
  plausible data rather than hand-rolled fragments. Build the factory
  file with the framework setup, not later.
- **A tenant-isolation test pattern**: every portal route test asserts
  that a cross-tenant request returns **404**. Establish the pattern in
  the very first route test so it gets copied, not retrofitted.

## 5. Write a **real** starter test

The default scaffold often produces `expect(1 + 1).toBe(2)`. **Don't
ship that.** Pick a small piece of real logic and write a tight test
that asserts specific computed values — in this project, money and
hours helpers are the natural first target:

```ts
import { describe, it, expect } from 'vitest';
import { formatCurrency } from './currency';

describe('formatCurrency', () => {
  it('formats whole-dollar cents with no decimal', () => {
    expect(formatCurrency(4200, 'USD')).toBe('$42');
  });
  it('formats fractional amounts with two decimals', () => {
    expect(formatCurrency(4250, 'USD')).toBe('$42.50');
  });
  it('handles zero', () => {
    expect(formatCurrency(0, 'USD')).toBe('$0');
  });
});
```

Not `expect(formatCurrency).toBeDefined()` — that catches almost
nothing. The starter test is *the template* the user will copy. Make it
good. Cover sizes 0/1/N where the function takes a collection.

## 6. Wire scripts in `package.json` (or `pyproject.toml`)

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage"
  }
}
```

The `typecheck` script is the **one canonical type-check command** —
CI, the pre-push hook, and `/perp-check` all call it, so the three
gates can never disagree on flags. Don't replace existing scripts; add
what's missing.

## 7. Wire CI

If `.github/workflows/` doesn't have a test workflow, write
`.github/workflows/ci.yml`. It should mirror `/perp-check`'s steps —
that is CLAUDE.md's definition of the CI gate:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      # Gate on high-severity prod-dependency vulns; run the full moderate-level
      # audit as a scheduled workflow that opens an issue, so an unrelated
      # transitive advisory doesn't block every PR.
      - run: npm audit --omit=dev --audit-level=high
      - run: npx prisma generate   # codegen BEFORE typecheck (default stack requires it;
                                   # delete only if your stack has no codegen)
      - run: npx prisma migrate deploy    # the tests need a real schema
        env: { DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test }
      - run: npm run typecheck
      - run: npm run test:coverage
        env: { DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test }
      - run: npm run build
      # - run: npx pa11y-ci               # accessibility — enable when the first
      #                                   # portal view ships (/perp-check a11y gate)
```

**CI needs a database, and this is not optional.** `CLAUDE.md` § Testing
makes tenant isolation a test *category* — every portal route test asserts a
cross-tenant request returns 404 — and those tests need Postgres. Without a
service block, CI green means "the tests that don't touch the database
passed", which is the most expensive kind of false comfort: the kit's most
important security tests would only ever run on one laptop. Add to the job,
above `steps:`:

```yaml
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
```

(Throwaway credentials for an ephemeral container — never reuse them
anywhere, and never point CI at a real database.)

The test step must be able to fail the build. If a workflow file
already exists, **don't overwrite it** — tell the user what change
you'd make and let them decide.

## 8. Add a pre-push hook

CI catching a red suite *after* the push is too late — and a push can
trigger a deploy. Add a version-controlled pre-push hook that runs the
same fast gate locally and aborts the push on failure.

**First, check what already exists.** `core.hooksPath` replaces ALL of
git's hook locations — setting it blindly silently disables every hook
the repo already has:

- `git config core.hooksPath` already set? → add the pre-push gate to
  **that** directory instead of repointing.
- A `.husky/` directory or a `"prepare": "husky"` script? → the repo
  uses husky: write the gate as `.husky/pre-push` and don't touch
  `core.hooksPath`.
- Non-sample files in `.git/hooks/`? → migrate them into `.githooks/`
  (and tell the user which ones) before repointing.

Then write `.githooks/pre-push` (Node shape shown; for Python drop the
typecheck line and use `pytest`). Keep the gate fast (~60–90s): when
the suite outgrows it, switch to changed-file mode (`vitest --changed
origin/main`, `pytest --testmon`) or a tagged fast suite, and let CI
run the full matrix.

```bash
#!/usr/bin/env bash
#
# pre-push hook — block a push when the gate CI runs would fail.
# Mirrors CI's fast gate: type check + the unit suite. Coverage and E2E
# are intentionally skipped here — a failing assertion fails the same
# without them.
set -euo pipefail

echo "pre-push: typecheck + tests …"

if ! npm run typecheck; then
  echo "pre-push: ✗ typecheck failed — push aborted." >&2
  echo "pre-push: fix the errors (run /perp-check, or paste this output to Claude), then push again." >&2
  echo "pre-push: emergency bypass ONLY: git push --no-verify" >&2
  exit 1
fi

if ! npm test; then
  echo "pre-push: ✗ tests failed — push aborted." >&2
  echo "pre-push: fix the failures (run /perp-check, or paste this output to Claude), then push again." >&2
  echo "pre-push: emergency bypass ONLY: git push --no-verify" >&2
  exit 1
fi

echo "pre-push: ✓ typecheck + tests passed."
```

Activate it — and make activation survive fresh clones:

```bash
# Record the exec bit in the index (chmod alone is a no-op on Windows and
# the bit would never reach teammates' checkouts):
git update-index --chmod=+x .githooks/pre-push
git config core.hooksPath .githooks
```

`core.hooksPath` is **local config — a fresh clone doesn't have it**,
and git gives no signal that hooks aren't running. Add a `prepare`
script so every clone re-activates automatically on `npm ci`/`install`:

```json
{ "scripts": { "prepare": "git config core.hooksPath .githooks" } }
```

(For non-Node stacks, put the `git config` line in the project README's
setup steps.) If `.githooks/pre-push` already exists, **don't overwrite
it** — show the user the change you'd make and let them decide.

## 9. Verify

Run the test command once to confirm everything works. Show the user
the output. If anything fails, fix it in the same session — don't leave
the project in a half-configured state.

## 10. Report

Report exactly which `/perp-check` steps are now real and which remain
`<TODO>` — do not claim the whole suite is configured:

```
✓ Vitest + @vitest/coverage-v8 installed (audit clean)
✓ vitest.config.ts written
✓ test factories scaffolded (tenant + user + project)
✓ src/lib/currency.test.ts written (3 tests, all passing)
✓ typecheck, test, test:watch, test:coverage, prepare scripts added
✓ .github/workflows/ci.yml written
✓ .githooks/pre-push written (+x recorded); core.hooksPath set
✓ CLAUDE.md § Testing TODOs filled
✓ /perp-check steps filled: audit, codegen (prisma generate — required on
  the default stack), types, tests (+ build if a build script exists)
⊘ /perp-check steps still TODO: a11y (when portal UI ships)

Next: `npm run test:coverage`, and /perp-review-testing once you have
more code to cover.
```
