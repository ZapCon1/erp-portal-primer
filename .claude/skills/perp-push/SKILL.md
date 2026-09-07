---
name: perp-push
description: Push committed changes to the remote, with branch-aware safety. Use after /perp-commit, or when the user says "push".
---

# Push

Push committed changes to the remote. **This skill is deliberately
separate from `/perp-commit`** so the user makes the publishing decision
explicitly — pushing can trigger CI, deploys, and visibility on
production repos.

## 1. Check what you're about to push

Run `git status` and `git log @{u}..HEAD --oneline` (or
`git log origin/main..HEAD --oneline` if no upstream is configured) to
see what commits are ahead of the remote. Show the user the list before
pushing.

If there's nothing to push (no commits ahead), say so and stop.

If the repo has **no remote configured at all** (a freshly adopted
project), say so plainly and offer to add one — do not treat the missing
remote as an error.

## 2. `GIT-1` — never push to `main`

`main` is only ever updated by **merging a pull request whose CI is green**.
That is the rule, not the safer option, and it holds on a solo repo — a solo
repo is exactly where "just this once" becomes the habit and where nobody
else is going to catch it.

    branch -> commit -> push -> PR -> CI green -> merge -> deploy

Run `git rev-parse --abbrev-ref HEAD`.

**If on a feature branch**: push without ceremony —
`git push -u origin <branch>` (or plain `git push` if it has an upstream).

**If on `main` / `master` / `production` / `release`**: do **not** push.
Move the work to a branch instead, and say plainly what you are doing:

1. Name the branch after the work (`git branch -f <name> HEAD`).
2. Reset `main` back to the remote so the local `main` never diverges
   (`git reset --hard origin/main`), then `git checkout <name>`.
   ⚠️ Only when everything is committed — check `git status --porcelain`
   is empty **first**, and say so. Uncommitted work is not yours to discard
   (`STOP-3`).
3. Push the branch and open the PR (step 3 below).

If the repo has branch protection configured (`docs/GITHUB.md`), a direct
push is refused by the remote anyway — this step just means the refusal is
never how the owner finds out.

## 2a. Open the pull request, then wait for CI

- `gh pr create --base main --head <branch>` with a title and a body that
  says what changed and how it was verified.
- **Wait for the checks.** Report the result plainly. A red PR is a finding
  to fix, never something to merge around or force through.
- On green, merge it: `gh pr merge --squash --delete-branch`.
- Then `git checkout main && git fetch --prune && git reset --hard
  origin/main` so the next branch starts from the merged state.

**Who authorizes the merge.** Opening a PR needs no permission — it changes
nothing. **Merging** does:

- The user said so in this conversation, **or**
- the untracked file **`.claude/push-standing.local`** exists (its contents
  are ignored; one line naming who decided and when is good practice). That
  is the standing authorization for merge-when-green on solo/prototype
  repos, where asking every time is pure friction. When you merge on it,
  **say so**: "merging on the standing decision in
  `.claude/push-standing.local`".

Without either, stop at the open PR and hand the user the link.

⚠️ **The authorization must never live in a tracked file** (`STOP-8`).
`CLAUDE.md` was the old home for it and that was wrong: it is committed, so
the assistant, a merged PR, or a dependency's install script can each append
a line and grant themselves passage. A gate you disable by editing the file
the gate reads is not a gate. `.claude/*.local` is gitignored, so a remote
change cannot reach it, and a fresh clone starts with the prompt back on —
the right default once someone else can push.

**Never**, on any authorization: force-push to `main`, merge a red PR, or
use `--no-verify` outside a genuine emergency.

## 3. Push

```bash
git push
# or first time:
git push -u origin <branch>
```

If the project has a `.githooks/pre-push` hook (see
`/perp-setup-testing`), `git push` runs it automatically — it re-runs
the type check and unit suite and aborts the push if either fails. Let
it run; don't reach for `--no-verify` to push past a red suite.

If the push fails with "rejected (non-fast-forward)", **do not
`--force`**. Tell the user the remote has commits they don't have
locally, suggest `git pull --rebase`, and let them decide.

## 4. Report

```
Pushed 3 commit(s) to origin/feature/invoice-rounding.
https://github.com/<owner>/<repo>/tree/feature/invoice-rounding
```

Include the GitHub URL when you can derive it from `git remote get-url
origin`. Makes it easy for the user to open the PR or check CI.

## Never

- `--force` / `--force-with-lease` unless the user explicitly asks AND
  confirms the consequences.
- `--no-verify` to push past a red suite — it is for genuine emergencies
  only (CLAUDE.md § Git Hygiene), and an inconvenient hook is not an
  emergency.
- Push to a branch the user didn't name. If you're unsure which branch
  is current, stop and ask — never guess.
