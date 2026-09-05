---
name: perp-review-parity
description: Audit cross-surface drift in shared numbers, endpoints, and UI — run before every release
argument-hint: [concept, e.g. hours-remaining]
---

# Review Parity

Audit consistency across the project's parallel surfaces of the same data
— to find places where the same concept computes differently, displays
differently, or fails to ship on both sides.

> **What counts as a "surface" depends on the project.** Common patterns:
> internal app + customer portal, admin dashboard + public site, web +
> mobile app, server-rendered + client-rendered duplicate, REST + GraphQL
> over the same data, v1 + v2 of an API kept in parallel. Per `CLAUDE.md`
> § Parity: every domain concept that appears on more than one surface
> must behave and compute identically on all of them.
>
> Skip this command entirely if the project has only one surface.

If `$ARGUMENTS` names a concept (e.g., a domain entity, a calculation, a
shared widget), scope the audit to that area. Otherwise run a broad sweep
and report the worst offenders.

Use four sources of information:

1. **Your own analysis** — read both surfaces' code paths for the same concept and compare line-by-line.
2. **Symbol grep** — for each shared concept, grep all reads/writes of the relevant data fields and compare which formulas appear where.
3. **Static analysis** — run the type checker <TODO: default stack: `npm run typecheck` (alt: `mypy .`)> to confirm the response types coming back from surface A vs surface B actually agree on shape.
4. **Tests** — look for fixture-based parity tests (the same input run through both code paths producing identical output). Their absence is itself a finding.

## What to check

1. **Calculation parity** — the same domain number computed by different formulas across surfaces. List every formula site and the formula in use. **Three different denominators for the same number is the canonical smell.** Pick a real example from your project's history if you have one; this is the pattern that most reliably produces user-facing bugs.

2. **API parity** — comparable endpoints across surfaces returning different fields, different shapes, or different aggregations for the same underlying data. One side should be a strict subset of the other (gated by scope / permission) — not a separately-derived response.

3. **Helper sharing** — server endpoints serving the same data must share an underlying helper (one helper, multiple auth-wrapped routes). Flag endpoints where one surface inlines logic the other reimplements.

4. **UI component sharing** — JSX (or equivalent) duplicated under per-surface directories instead of living in a shared components dir. Find near-duplicates by comparing component structure, not just file names. Start with the concepts this kit already knows are shared: status chips, money cells, date cells, stat tiles, empty states, the helper banner, and list rows. Add any others specific to your project.

5. **Visibility / permission gating consistency** — fields gated by a permission on one side must have an analogous gate on the other (or a documented reason they don't). <TODO: list the specific visibility flags or permissions worth spot-checking each audit, e.g. "tenant.portalBudgetVisibility, ITAR flags, POC tier gates".>

6. **Bug-fix parity** — read recent commits on the current branch (and the last 30 commits on the default branch). For any commit that fixes a bug on one surface, verify the same bug doesn't exist on the others. Fix-on-one-side-only is a high-frequency parity drift source.

7. **Asymmetric features** — features that only exist on one side. These are legitimate when documented, suspect when not. Check `features/*.md` and recent PR descriptions for an explanation. No documented reason → flag.

8. **Test parity** — for shared concepts, is there at least one test that takes a single fixture and runs it through all the surfaces' code paths, asserting identical output? Absence is a finding even when the production code looks aligned today, because there's no guard against future drift.

9. **Tenant / scope isolation alongside parity** — multi-tenant route handlers on every surface must include the tenant scope. While auditing parity, flag any query missing it. Cross-tenant access must return 404 (not 403) per `secure_coding.md`.

## Search strategy

For a scoped audit (`$ARGUMENTS = "<concept>"`):

1. Find the data fields the concept lives on (column names / schema attributes).
2. Grep all reads of those fields across the source tree. Bucket results by surface, plus shared code and background jobs.
3. For each bucket, transcribe the actual formula or query into a comparison matrix.
4. Disagreements between buckets are the findings.

For a broad sweep (no argument):

1. Walk the route directories looking for endpoint pairs (same resource, different surface / auth wrapper).
2. For each pair, compare the response shapes and the underlying queries.
3. Report pairs with the largest divergence first.

## What NOT to do

- Don't fix anything. Just report.
- Don't flag intentional asymmetry (e.g., admin-only features) when it's documented.
- Don't propose extracting helpers for two-instance duplication (per `CLAUDE.md`: two is fine, three is borderline, four+ extract).
- Don't conflate visual differences with behavioral differences. **Different
  density and layout across surfaces are fine** — the portal is the same
  design language tuned quieter. **Different component vocabulary, status
  labels, or status colors are not**: a customer seeing "Overdue" in amber
  where staff see red, or "Awaiting payment" where staff see "Sent", is the
  same trust problem as a different number wearing different clothes.
  `docs/PORTAL_UX.md` § Default tokens holds the one canonical status map.
  Different *numbers* are never fine.

## Parity matrix format

For each concept audited, produce a matrix like:

| Surface | File:line | Formula / query | Output for fixture X |
|---|---|---|---|
| Admin page | `<path>:147` | `totalAllocated > 0 ? totalAllocated : purchased` | `25` |
| Background job | `<path>:59` | `purchased + pooled` | `105` |
| Customer dashboard | `<path>:75` | `sum(allocated)` | `100` |

Three rows showing three different numbers for the same fixture is the
headline finding.

## Parity threshold

- **No action needed** if: every shared concept computes to the same number on every surface, comparable endpoints share helpers, shared UI lives in the shared components dir, recent bug fixes have been mirror-checked, and parity tests exist for the load-bearing concepts. Say so and stop.

- **Drift detected** if any of these are true:
  - Same domain number computed by ≥2 different formulas across surfaces.
  - Comparable endpoints across surfaces reimplement the same query separately.
  - Near-duplicate UI components in per-surface directories.
  - Bug fix shipped on one surface that `git log` reveals had the same bug on another.
  - Visibility gates applied on one surface but not another.
  - Zero tests assert cross-surface output equality for shared concepts.
  - Asymmetric feature with no explanation in `features/*.md` or recent PRs.

## Remediation plan

If drift is detected, end with a prioritized plan:

1. **Do first** — calculation parity (a user seeing a different number on one surface vs another is a trust issue). Extract the formula into a shared helper, switch all call sites to it in one commit, add a parity test.
2. **Do second** — endpoint / helper consolidation (one helper, multiple auth-wrapped routes), shared UI component extraction.
3. **Do third** — backfill parity tests for the concepts that look aligned today but have no enforcement against future drift.
4. **Skip for now** — asymmetries that are real but intentional, with a one-line note pointing to the doc that justifies them.

For each item, list every affected file path, the divergence, and the
proposed shared location. Keep it concrete.

**Important**: parity fixes are by definition cross-surface, so they
violate the usual "small commit" preference. Per `CLAUDE.md`: ship a
change to one surface and the matching change to the others in the same
commit. If existing tests cover only one surface, write the parity test
*first* so the second-surface change is verifiable.
