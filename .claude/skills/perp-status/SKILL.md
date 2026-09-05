---
name: perp-status
description: Session checkpoint — what changed, what's still open, anything risky uncommitted. Use when the user says "status", "where are we", or before /perp-commit on a long session.
---

# Status

Produce a short, scannable session checkpoint. The user runs this when
they've been working for a while and want to know: *what have I done,
what's left, is anything at risk?* Aim for under 20 lines of output.

This skill is read-only. **Do not change any files.** If you spot
something that needs fixing, mention it as a finding — don't act.

## 1. What changed

Run `git status` and `git diff --stat`. Group changes into three
buckets:

- **Committed locally, not pushed** — `git log @{u}..HEAD --oneline`
  (or against `origin/main` if no upstream). **No remote configured at
  all** (a freshly adopted project)? Report the local commits as
  "committed; no remote to push to yet", skip this bucket's
  ahead-of-remote comparison, and continue — it is not an error.
- **Staged, ready to commit** — files with green markers in `git
  status`.
- **Unstaged work in progress** — modified or new files not yet
  staged.

Show file counts per bucket, not full lists. If a bucket has only a
few files, name them; if many, summarize ("12 files across `lib/` and
`app/api/`").

## 2. What's still open

This is the most useful part of the checkpoint. Scan for:

- **Test failures** — quick run of the unit suite, only if the project
  has tests configured AND the suite is fast (last known runtime under
  ~60s). On a slower suite, run only tests touching this session's
  changed files (`vitest --changed`, `pytest --testmon`), or report
  `⊘ suite too slow for a checkpoint — run /perp-check before
  committing`. A "quick" status that blocks for ten minutes stops
  getting run. If anything's red, flag it.
- **TODO comments added in this session** — `git diff` for new TODO /
  FIXME / XXX markers in changed files.
- **Skipped tests** — `.skip`, `xit`, `@pytest.mark.skip` introduced
  in this session (per `git diff`).
- **Feature branches with no PR** — if on a feature branch, mention
  whether a PR exists yet.
- **One-sided surface changes** — if the session touched a shared
  domain concept (a number, a status, an endpoint) on only one of the
  two surfaces (internal app vs customer portal), flag it: parity says
  both sides ship in the same commit, or the gap gets noted and
  justified. See `CLAUDE.md` § Parity.
- **Stale feature docs** — if the session shipped a phase of a
  `features/<name>.md` plan, check whether its Progress table was
  updated.

Don't invent items. If nothing's open, say "Nothing flagged." Don't
manufacture a TODO list.

## 3. Anything risky uncommitted

Specifically look for:

- **Uncommitted secrets** — modified or new files that match `.env`,
  `*.key`, `credentials*`, etc. The biggest risk on a long session.
- **Uncommitted package/lockfile changes** without a matching install
  confirmation — easy to forget to re-run tests after deps change.
- **Uncommitted work older than 2 hours** — a hint to checkpoint with
  `/perp-commit` soon. Don't be preachy about it; one line.
- **Backups — and this check must fail closed.** Two cases, and the second
  is the one that used to be silent:
  - `docs/runbooks/backup-restore.md` **exists** → read its rehearsal log;
    last dated row more than 90 days old (or the table still all dashes) →
    flag it.
  - `docs/runbooks/backup-restore.md` **does not exist** → flag it *louder*,
    as the top line of the report, **if the schema has any real data**
    (any client/invoice row not marked SAMPLE, or a migration history
    beyond the initial one). The old form only nagged people who had
    already done the work; the owner most likely to skip the runbook got
    zero reminders, forever. Silence about backups reads as "nothing is
    wrong", which is the worst possible default for the one ritual whose
    failure mode is losing the business's system of record (`OPS-1`).

## 4. Report

Short, scannable. Example:

```
Status — feature/invoice-rounding (no PR yet)

Committed, not pushed:  3 commits
  • add hour-rounding helper in lib/billing
  • apply rounding at time entry, not invoice
  • add sizes-0/1/N tests for roundHours

Staged:                 0 files
Unstaged:               2 files
  • lib/billing/rounding.ts (~40 lines added)
  • app/(app)/timesheet/page.tsx (~10 lines added)

Open:
  • 1 new TODO in lib/billing/rounding.ts:88 ("revisit retainer case")
  • Rounding changed on the internal timesheet but the portal
    hours-remaining view wasn't checked — parity gap

Risky:
  • .env modified but not staged (good — leave it that way)

Next steps you might consider:
  • Check the portal side, then commit (/perp-commit)
  • Run /perp-review-parity hours-remaining
  • Push the branch and open a PR (/perp-push)
```

End with a 2–3 line "next steps you might consider" list. Suggestions,
not commands — the user picks.
