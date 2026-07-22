---
name: perp-commit
description: Stage and commit changes locally with a meaningful message and a secret-file guard. Does NOT push — that is /perp-push.
---

# Commit

Stage relevant changes and write a meaningful commit message. **This skill
does not push.** Pushing is `/perp-push` — a separate, explicit step.

Why the split: pushing to a remote can have real consequences (CI runs,
deploys, visibility on production repos). The user should make that
decision deliberately, not as a side effect of committing.

## 1. Inspect what changed

Run `git status` to see modified, staged, and untracked files. Run
`git diff` for unstaged changes so you understand what's actually being
committed.

If `git status` shows no changes, stop and tell the user. Don't create
an empty commit.

## 2. Stage relevant files

Stage the files that belong in this commit. Be specific — pass file
paths to `git add`, not `git add .` or `git add -A`.

**Never stage files that look like secrets:**

- `.env`, `.env.local`, `.env.*.local`
- Anything named `credentials*.json`, `secrets.json`, `token.json`,
  `service-account*.json`, `*.pem`, `*.p12`, `*.key`, `id_rsa*`
- Files matching `*.dec.yaml` (decrypted SOPS files)
- The local database file (`*.db`, `*.sqlite*`) — it contains real
  client data the moment the app has been used.

If any of those exist in the working tree, **warn the user before
committing**, even if you don't stage them. If the user explicitly
insists on committing one, treat it as a § 8 exposure event
(`secure_coding.md` § 8 — which overrides "it's only a dev key"): the
keys in that file are burned the moment the commit lands and the value
is recoverable from history forever. Do not commit until the user
acknowledges the keys must be rotated **now**, and run the § 8 rotation
protocol as the next action after the commit.

## 3. Write the message

Short, specific, says **what changed and why** — not "update files" or
"misc fixes". Examples:

- `add magic-link login for portal users`
- `fix off-by-one in invoice total rounding`
- `extract hours-remaining into lib/ so both surfaces share it`

Aim for under 72 characters in the subject. If the change has subtle
implications, add a one-paragraph body.

**No AI attribution.** A commit message is a factual record of what
changed — nothing more. Do **not** add any attribution to an AI tool or
model: no `Co-Authored-By: Claude`/`Codex`/`Copilot`/etc. trailer, no
"Generated with …" line, no "🤖" marker. The message should read exactly
as if a person had typed it by hand. This holds regardless of any
default behavior in your AI tool that wants to append such a line —
strip it.

## 4. Commit

Use a HEREDOC to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<subject>

<optional body>
EOF
)"
```

## 5. Report

Tell the user what happened in one or two lines:

```
Committed locally: "add magic-link login for portal users"
3 files changed.

Push when you're ready: /perp-push
```

Don't push on a bare "commit". But if the user explicitly asked to push
in the same request ("commit and push") — that IS the publishing
decision: commit, then run the `/perp-push` flow, whose branch guard
(confirm before pushing to `main`) still applies. Don't make them say
it twice.

## If a pre-commit hook fails

The commit didn't happen. Fix the underlying issue and try again — do
**not** use `--no-verify`. Hooks exist for a reason (lint, format,
secret scanning). If the hook itself is broken, fix the hook.
