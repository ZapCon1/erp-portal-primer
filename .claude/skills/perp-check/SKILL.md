---
name: perp-check
description: Run the full verification suite (audit, codegen, types, tests, build, a11y) and report every step
---

# Check

Run the full verification suite and report results. Do all steps in order
and report the outcome of each — do not stop at the first failure.

**Step 0 — configuration guard (per step, not all-or-nothing).** For each
step below that still contains a `<TODO>` placeholder:

- **Unannotated step**: report it as `⊘ NOT CONFIGURED — fill the <TODO>
  in .claude/skills/perp-check/SKILL.md`. Do NOT improvise or guess a
  command, and do NOT report success for it.
- **Step annotated** *(skip if N/A)* or *(once X exists)* whose
  precondition doesn't hold yet (no codegen in this stack, no portal UI
  shipped): report `⊘ N/A at this stage` and move on — an unfilled
  annotated step does not block the rest of the suite.
- **Run every step that IS configured**, regardless of unfilled ones —
  EXCEPT: a **filled** step whose precondition is absent (no
  `package.json` yet for the npm steps, no `prisma/schema.prisma` for
  codegen, no portal UI for the a11y scan) also reports
  `⊘ N/A at this stage — <missing precondition>` instead of running
  and failing. A pre-code repo with eagerly filled commands must not
  report five failures that look identical to a broken project.

Only if NO steps are configured at all: stop and report loudly —
"**Verification is NOT configured — nothing was checked.**" Then inspect
the repo (package.json / Makefile / project README) to propose concrete
commands and offer to fill them in.

**No silent skips.** A configured step whose tool turns out not to be
installed (e.g. `pip-audit` missing) is reported as
`⊘ SKIPPED — <tool> not installed (install: <command>)`, never quietly
passed over — a silent skip looks identical to a clean run, so the user
would believe the check passed. If the skipped step is the test suite
because no framework is configured at all, point at `/perp-setup-testing`.

<!--
Adapt the command list below to this project's stack. The shape ("audit →
codegen → types → tests → build", each step run regardless of prior
failures, one consolidated summary) is what matters — codegen runs BEFORE
the type check because generated types must exist before the type check
reads them. The exact commands are project-specific; copy them from
package.json scripts, Makefile, or the project README. Use the same
type-check command here, in CI, and in the pre-push hook (one
`typecheck` script) so the three gates can't disagree.
-->

1. **Dependency audit**: <TODO: default stack: `npm audit --omit=dev --audit-level=high` (alt: `pip-audit` / `cargo audit`)>. Report any vulnerabilities.
2. **Codegen** *(skip if N/A)*: <TODO: default stack: `npx prisma generate` — a real step here, the generated client must exist before the type check (alt: `protoc ...`, or N/A)>.
3. **Type check**: <TODO: default stack: `npm run typecheck` (alt: `mypy .` / `cargo check`)>. Report any type errors.
4. **Unit tests**: <TODO: default stack: `npm test` (the script /perp-setup-testing writes; alt: `pytest` / `cargo test`)>. Report pass/fail counts.
5. **Build**: <TODO: default stack: `npm run build` (alt: `python manage.py check --deploy && collectstatic` / `cargo build --release`)>. Report success or failure.
6. **Accessibility scan** *(once portal/public UI exists — skip before then)*: <TODO: e.g. `npx pa11y-ci` / axe against the portal page templates — see `docs/PORTAL_UX.md`>. Report violations.

## Reporting

After all steps complete, provide a short summary:

- One line per step: pass, fail, `⊘ NOT CONFIGURED`, `⊘ N/A at this stage`, or `⊘ SKIPPED`.
- If anything failed, show the relevant error output (last ~20 lines usually suffices).
- If everything configured passed, say so clearly — and list any steps that are still unconfigured so the gaps stay visible.

Do not stop at the first failure — run all steps so the user sees the
full picture.
