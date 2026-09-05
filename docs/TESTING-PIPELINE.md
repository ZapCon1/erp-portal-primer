# Testing Pipeline

> **This is the default stack's testing pipeline** (`docs/STACK.md`:
> Next.js + TypeScript, tested with Vitest + Playwright and monocart
> merged coverage). `/perp-setup-testing` wires the basics and points
> here for the full pipeline; `testing-conventions.md` carries the
> principles. Deviated to another stack? Delete this file and apply the
> same shape with your ecosystem's tooling.

How to set up a full testing pipeline with unit tests, E2E tests, and merged coverage.
This guide gives you every config file and script needed to go from zero to a working
CI pipeline that reports combined coverage.

## Overview

The pipeline uses three tools from one family (monocart) so coverage stays in the same
format (raw V8) from collection through merging — no format conversion, no data loss.

- **Unit tests**: Vitest with `vitest-monocart-coverage` (custom coverage provider)
- **E2E tests**: Playwright with `monocart-reporter` (collects browser V8 coverage)
- **Merge**: `monocart-coverage-reports` combines raw V8 data from both into one report

```
vitest (unit)                    playwright (E2E)
    │                                │
    ▼                                ▼
coverage/unit/raw/               coverage/e2e/raw/
    │                                │
    └──────────┬─────────────────────┘
               ▼
    scripts/merge-coverage.mjs
    (monocart-coverage-reports)
               │
               ▼
    coverage/merged/
    ├── v8 report
    ├── console-details
    └── lcov
```

## Packages

```bash
npm install -D vitest vitest-monocart-coverage monocart-reporter monocart-coverage-reports @playwright/test
npx playwright install chromium
```

## Step 1: Unit test coverage (Vitest)

Create `vitest.config.ts` at the project root:

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',           // or 'happy-dom' for lighter weight
    setupFiles: ['./src/test-setup.ts'],
    exclude: ['e2e/**', 'node_modules/**'],
    coverage: {
      provider: 'custom',
      customProviderModule: 'vitest-monocart-coverage',
      // Scope to production source files only
      include: ['src/lib/**', 'src/data/**'],
      exclude: ['src/**/__tests__/**', 'src/**/*.test.*'],
      reportsDirectory: './coverage/unit',
    },
  },
});
```

Key decisions:

- **`provider: 'custom'` + `customProviderModule: 'vitest-monocart-coverage'`** — this
  produces raw V8 coverage data instead of Istanbul JSON. Raw V8 is what monocart's merge
  tool expects, so using the same format everywhere avoids a conversion step.
- **`include`** — scope to directories containing production logic. Adjust to match your
  project structure (e.g. add `src/store/**` if you have a store layer).
- **`exclude`** — keep test files out of coverage reports. They'd inflate numbers without
  telling you anything useful.
- **`reportsDirectory: './coverage/unit'`** — separates unit coverage from E2E coverage
  so the merge script can find each one independently.

## Step 2: E2E coverage (Playwright)

### Playwright config

Create `playwright.config.ts` at the project root:

```ts
import { defineConfig } from '@playwright/test';

const collectCoverage = !!process.env.E2E_COVERAGE;

const reporters: any[] = [['list']];
if (collectCoverage) {
  reporters.push(['monocart-reporter', {
    name: 'E2E Coverage Report',
    outputFile: './coverage/e2e/report.html',
    coverage: {
      outputDir: './coverage/e2e',
      reports: [
        ['v8'],
        ['console-details'],
        ['raw'],               // raw V8 data — required for merging
      ],
      entryFilter: (entry: { url: string }) => {
        // Only collect coverage for your source files
        return entry.url.includes('/src/') &&
          !entry.url.includes('node_modules') &&
          !entry.url.includes('.vite');
      },
    },
  }]);
}

export default defineConfig({
  testDir: './e2e',
  timeout: 30000,
  use: {
    baseURL: 'http://localhost:5173',  // match your dev server port
    headless: true,
  },
  webServer: {
    command: 'npx vite --port 5173',
    port: 5173,
    reuseExistingServer: false,        // fresh server per test run
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
  reporter: reporters,
});
```

Key decisions:

- **`E2E_COVERAGE` gate** — coverage collection adds overhead (V8 profiler running in
  the browser). Gating it behind an env var keeps normal `playwright test` runs fast.
  CI sets the env var; local dev doesn't unless you want it.
- **`entryFilter`** — without this, coverage includes every JS file the browser loads
  (framework internals, vendor bundles, Vite client). The filter scopes to `/src/` files
  only.
- **`['raw']` reporter** — this writes the raw V8 coverage data that the merge script
  reads. Without it, you get reports but no mergeable data.
- **`reuseExistingServer: false`** — ensures a clean server for each run. In CI this
  prevents stale state; locally you can set it to `!process.env.CI` if you prefer reusing
  your dev server.

### Coverage fixture

Create `e2e/coverage-fixture.ts`:

```ts
import { test as base, expect } from '@playwright/test';
import { addCoverageReport } from 'monocart-reporter';

const COLLECT_COVERAGE = !!process.env.E2E_COVERAGE;

const test = base.extend({
  autoTestFixture: [async ({ page }, use) => {
    if (COLLECT_COVERAGE) {
      await page.coverage.startJSCoverage({ resetOnNavigation: false });
    }

    await use('autoTestFixture');

    if (COLLECT_COVERAGE) {
      const coverage = await page.coverage.stopJSCoverage();
      await addCoverageReport(coverage, test.info());
    }
  }, {
    scope: 'test',
    auto: true,
  }],
});

export { test, expect };
```

This fixture wraps every test with V8 coverage collection. The `auto: true` means it
runs automatically — you don't need to opt in per-test.

### Using the fixture in test files

Import `test` and `expect` from the fixture instead of from `@playwright/test`:

```ts
// e2e/calculator.spec.ts
import { test, expect } from './coverage-fixture';

test('computes cycle length', async ({ page }) => {
  await page.goto('/');
  // ...
});
```

The fixture is a drop-in replacement. When `E2E_COVERAGE` is not set, it behaves
identically to the standard `@playwright/test` exports.

## Step 3: Merge script

Create `scripts/merge-coverage.mjs`:

```mjs
import fs from 'fs';
import path from 'path';
import { CoverageReport } from 'monocart-coverage-reports';

const projectRoot = process.cwd();
const inputDir = [];

const e2eRawDir = path.resolve(projectRoot, 'coverage/e2e/raw');
if (fs.existsSync(e2eRawDir)) {
  console.log('Found E2E coverage at:', e2eRawDir);
  inputDir.push(e2eRawDir);
}

const unitRawDir = path.resolve(projectRoot, 'coverage/unit/raw');
if (fs.existsSync(unitRawDir)) {
  console.log('Found unit coverage at:', unitRawDir);
  inputDir.push(unitRawDir);
}

if (inputDir.length === 0) {
  console.error('No coverage data found to merge.');
  process.exit(1);
}

const coverageReport = new CoverageReport({
  name: 'Merged Coverage Report',
  inputDir,
  outputDir: './coverage/merged',
  cleanCache: true,
  reports: [
    ['v8'],
    ['console-details'],
    ['lcov'],
  ],
  sourceFilter: (sourcePath) => {
    // Exclude test files and dependencies from the merged report
    if (sourcePath.includes('__tests__/')) return false;
    if (sourcePath.includes('.test.')) return false;
    if (sourcePath.includes('test-setup')) return false;
    if (sourcePath.includes('node_modules')) return false;
    return sourcePath.startsWith('src/') && sourcePath.match(/\.(ts|tsx)$/);
  },
  sourcePath: (filePath, info) => {
    // Vite sourcemaps sometimes use bare filenames ("calculations.ts") instead
    // of full paths ("src/lib/calculations.ts"). This resolves them using the
    // dist entry URL that monocart provides in the info object.
    const distFile = info?.distFile || '';
    if (distFile.includes('/src/') && !filePath.includes('/')) {
      const urlPath = distFile
        .replace(/^localhost-\d+\//, '')
        .replace(/^https?:\/\/[^/]+\//, '');
      const dir = path.dirname(urlPath);
      return path.join(dir, filePath);
    }
    // Strip localhost prefix from non-sourcemapped entries
    return filePath.replace(/^localhost-\d+\//, '');
  },
});

await coverageReport.generate();
```

Key decisions:

- **Both inputs are optional** — the script works with unit-only, E2E-only, or both.
  It only fails if *neither* exists. This lets you add E2E coverage incrementally without
  breaking the merge step.
- **`sourceFilter`** — keeps test files and node_modules out of the merged report. Adjust
  the `sourcePath.startsWith('src/')` check if your source lives elsewhere.
- **`sourcePath`** — handles a Vite-specific quirk where sourcemaps reference files by
  bare name instead of full path. Without this, monocart can't match E2E coverage entries
  to unit coverage entries for the same file, and you get duplicates in the report. If
  your project uses a different bundler (Next.js/webpack), you may not need this handler —
  try without it first and add it if you see bare filenames in the report.

## Step 4: npm scripts

Add these to `package.json`:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "test:e2e:coverage": "E2E_COVERAGE=1 playwright test",
    "coverage:merge": "node scripts/merge-coverage.mjs",
    "coverage:full": "npm run test:coverage && npm run test:e2e:coverage && npm run coverage:merge"
  }
}
```

- `test` — fast, no coverage, for local development
- `test:watch` — re-runs on file changes
- `test:coverage` — unit tests with V8 coverage collection
- `test:e2e` — E2E tests, no coverage overhead
- `test:e2e:coverage` — E2E tests with browser V8 coverage
- `coverage:merge` — combine unit + E2E raw data into one report
- `coverage:full` — run everything end-to-end (unit → E2E → merge)

## Step 5: GitHub Actions CI

This **upgrades the `.github/workflows/ci.yml` that `/perp-setup-testing`
wrote** — same filename, replace it in place. Never keep two workflows
running overlapping gates.

⚠️ **Carry two things across from the workflow you are replacing**, or this
upgrade is a silent regression:

1. **`npx prisma generate` before the type check.** The earlier workflow
   flags it as required on the default stack — the generated client must
   exist before `tsc` reads it. Dropping it makes CI typecheck and build
   against a stale or missing client, and the failure looks like a code
   problem rather than a workflow one.
2. **The `services: postgres` block and `DATABASE_URL`.** The tenant-isolation
   tests (`TENANT-1`) need a real database. A CI run without one is green in
   a way that means nothing — see `/perp-setup-testing` for the block.

The YAML below shows the coverage wiring, not the whole file. Merge it into
what you have rather than pasting over the steps named above.

Create/replace `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Type Check, Unit Tests, E2E Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm ci

      # Gate on high-severity prod-dep vulns; run the full moderate audit as a
      # scheduled workflow that opens an issue, so an unrelated transitive
      # advisory doesn't block every PR.
      - name: Audit dependencies
        run: npm audit --omit=dev --audit-level=high

      - name: Type check
        run: npm run typecheck

      - name: Unit tests with coverage
        run: npm run test:coverage

      - name: Build
        run: npm run build

      - name: Install Playwright browsers
        run: npx playwright install chromium --with-deps

      - name: E2E tests with coverage
        run: npm run test:e2e:coverage

      - name: Merge coverage reports
        if: always()
        run: |
          npm run coverage:merge 2>&1 | tee /tmp/coverage-merge.log
          echo "## Combined Coverage (Unit + E2E)" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
          grep -E '^\s*(┌|│|├|└)' /tmp/coverage-merge.log >> $GITHUB_STEP_SUMMARY || true
          echo '```' >> $GITHUB_STEP_SUMMARY

      - name: Upload unit coverage
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: unit-coverage
          path: coverage/unit/
          retention-days: 14

      - name: Upload merged coverage
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: merged-coverage
          path: coverage/merged/
          retention-days: 14

      - name: Upload E2E test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: e2e-results
          path: test-results/
          retention-days: 14
```

The `grep -E '^\s*(┌|│|├|└)'` line extracts the box-drawing table from monocart's
console-details output and posts it to the GitHub Actions job summary. This gives you a
coverage table visible directly in the PR without downloading artifacts.

The `if: always()` on the merge and upload steps ensures coverage data is preserved even
when a test fails — you still want to see what was covered up to the failure point.

## Step 6: .gitignore additions

Add to `.gitignore`:

```
coverage/
test-results/
playwright-report/
```

## Scaling up

The single-job CI workflow above is the right starting point. As a project grows, here
are patterns to adopt when they become necessary:

### Parallel CI jobs

When E2E tests take more than a few minutes, split the workflow into parallel jobs so
unit tests and E2E tests run simultaneously. The merge step becomes a third job that
downloads artifacts from both:

```yaml
jobs:
  check:
    # type check + unit tests with coverage
    # uploads coverage/unit/ as artifact

  e2e:
    # install playwright, run E2E with coverage
    # uploads coverage/e2e/ as artifact

  coverage:
    needs: [check, e2e]
    if: always() && needs.check.result == 'success'
    # downloads both artifacts, runs coverage:merge
    # graceful fallback: if E2E failed, merge unit-only
```

The `if: always() && needs.check.result == 'success'` condition means coverage merging
runs even if E2E fails (you still get unit coverage), but skips entirely if unit tests
failed (no point merging garbage).

### Concurrency groups

For repos with frequent pushes, cancel redundant CI runs:

```yaml
concurrency:
  group: ci-${{ github.head_ref || github.ref_name }}
  cancel-in-progress: true
```

### Auth setup for apps with login flows

If your E2E tests need an authenticated session, use Playwright's setup project pattern:

```ts
// playwright.config.ts
projects: [
  {
    name: 'setup',
    testMatch: /auth\.setup\.ts/,
  },
  {
    name: 'chromium',
    use: { browserName: 'chromium' },
    dependencies: ['setup'],
  },
],
```

The setup project runs first, authenticates, and saves the session state. All other
projects reuse it.

### Accessibility assertions (don't skip this step)

`testing-conventions.md` makes one carve-out from "don't test
presentation": an automated a11y assertion per portal page template.
This is where it lives in the pipeline. Install:

```bash
npm install -D @axe-core/playwright
```

One spec per portal page template:

```ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('portal invoices page has no a11y violations', async ({ page }) => {
  await page.goto('/portal/invoices');
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations).toEqual([]);
});
```

And at least one **keyboard-only golden path** (log in → open an invoice
→ download it, driven entirely by `page.keyboard`) — see
`docs/PORTAL_UX.md` for the baseline these enforce. When the first
portal view ships, this is also the moment to fill `/perp-check` step 6
and enable the a11y step in CI (Bootstrap checklist § Before go-live).

### Next.js / webpack projects

The coverage fixture and merge script work the same way. Two differences:

1. **`entryFilter`** in playwright.config.ts — filter on `/_next/` instead of `/src/`:
   ```ts
   entryFilter: (entry) => {
     return entry.url.includes('/_next/') &&
       !entry.url.includes('node_modules') &&
       !entry.url.includes('webpack');
   },
   ```

2. **`sourcePath`** in merge-coverage.mjs — you likely don't need the Vite-specific
   bare-filename handler. Try without it first. If you see bare filenames in the report,
   adapt the handler to strip the `/_next/` prefix instead of `localhost-NNNN/`.
