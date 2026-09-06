# GitHub guardrails — making a red build actually stop something

_Reviewed: 2026-09-06_

**Who this is for:** the owner. You do not need to understand the YAML. You
need to click about six things once, and this page says which six and why.
Unfamiliar word? `docs/GLOSSARY.md`.

---

## The one thing to understand

**GitHub does not stop anything by default.** A failing check shows a red ✗
next to the pull request and the merge button stays green. Nothing prevents
a deploy either. Every automatic guardrail this kit describes — the type
check, the tests, the dev-auth assertion (`SEC-2`), the pin checks
(`PIN-1..4`) — runs in CI and then, out of the box, **politely reports its
result to nobody.**

That is the difference between a *sensor* and a *gate*
(`docs/CONTROLS.md`). CI gives you the sensor. The settings below are what
turn it into a gate. Until you do this, `docs/CONTROLS.md`'s "Gates? yes"
column is describing an intention, not your repository.

**`GH-1` A check that cannot block a merge is a report, not a gate.**

---

## Do these six, in this order

You can do all of it in the web UI, or paste the `gh` commands. Both are
given. `gh` is GitHub's official command-line tool; if you do not have it,
use the click path.

### 1. Require the checks to pass before merging (`GH-2`)

This is the one that matters most. Everything else is a refinement.

**Click path:** repo → **Settings** → **Rules** → **Rulesets** → **New
branch ruleset**. Name it `main`. Target: **Default branch**. Tick:

- ✅ **Require a pull request before merging**
- ✅ **Require status checks to pass** → search and add your CI job names
  (with this kit: **`kit-check`**, and once `/perp-setup-testing` has run,
  **`ci`**)
- ✅ **Require branches to be up to date before merging**
- ✅ **Block force pushes**

Then set **Enforcement status: Active**. A ruleset left in "Evaluate" mode
reports and blocks nothing — that is the same trap one level down.

**Command path:**

```bash
# adjust the contexts to your actual job names, then:
gh api -X PUT repos/:owner/:repo/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=kit-check' \
  -f 'required_status_checks[contexts][]=ci' \
  -f 'enforce_admins=true' \
  -f 'required_pull_request_reviews[required_approving_review_count]=0' \
  -f 'restrictions=null' \
  -f 'allow_force_pushes=false'
```

**Solo?** Set required approving reviews to **0** — you cannot approve your
own PR, and a rule you have to bypass every time is a rule you will turn
off. Keep the *status checks*; drop the *review*. `enforce_admins=true` is
the line that matters: without it the rule does not apply to you, which on a
solo repo means it does not apply at all.

> ⚠️ **The check name must match exactly.** A required check that never
> reports is indistinguishable from one that passes — GitHub waits for it,
> and if it never arrives some configurations merge anyway. After setting
> this up, open one throwaway PR with a deliberate break and confirm the
> merge button is actually disabled. This is `STOP-6` applied to GitHub:
> verify the artifact, not the settings page.

### 2. Turn on push protection for secrets (`GH-3`)

Stops a key from reaching the remote at all, rather than telling you
afterwards. On public repos this is free.

**Click path:** **Settings** → **Code security** → enable **Secret
scanning** and **Push protection**.

```bash
gh api -X PATCH repos/:owner/:repo \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

This is a safety net, not a plan: it knows the *shapes* of well-known
provider tokens (AWS, Stripe, GitHub), not your database password. The rule
in `docs/WHEN-IT-GOES-WRONG.md` stands — **an exposed secret is burned and
must be rotated**, and deleting the commit does not fix it
(`secure_coding.md` § 8).

### 3. Turn on Dependabot (`GH-4`)

`DEP-1` is `npm audit` in CI, which tells you at build time. Dependabot
tells you when a CVE lands, which is usually sooner.

**Click path:** **Settings** → **Code security** → enable **Dependabot
alerts** and **Dependabot security updates**.

Leave *version* updates off at first. On a pinned stack (`PIN-1`) a bot
opening upgrade PRs weekly is noise that trains you to ignore it, and
`docs/CONTROLS.md` § Idiom churn says upgrades are a deliberate drill, not a
background process.

### 4. Make the default token read-only (`GH-5`)

Every workflow run gets a token. By default it can write to your repo.

**Click path:** **Settings** → **Actions** → **General** → **Workflow
permissions** → **Read repository contents permission**.

Workflows in this kit already declare `permissions: contents: read`
explicitly, which is the belt to this braces. A workflow that genuinely
needs to write asks for it in its own file, where you can see it in a diff.

### 5. Gate the deploy, not just the merge (`GH-6`)

Merging and deploying are different doors. A green `main` that deploys
automatically means the *merge* gate is the only gate — and `OPS-2` (exactly
one process runs migrations) plus `SEC-2` are exactly the failures you do
not want discovered in production.

Two mechanisms, use both:

- **`needs:`** — the deploy job must depend on the CI job in the same
  workflow, so it cannot start unless CI passed.
- **Environments** — **Settings** → **Environments** → **New environment**
  named `production` → tick **Required reviewers** and add yourself. A
  deploy then pauses and waits for a human click, even at 2am, even when
  the assistant is confident.

```yaml
jobs:
  deploy:
    needs: [ci]                 # cannot run unless ci succeeded
    environment: production     # pauses for the required reviewer
```

`docs/runbooks/deploy.md` is the human half of this. The environment gate is
what makes skipping the runbook require a deliberate click.

### 6. CODEOWNERS — only when there is a second person (`GH-7`)

A `.github/CODEOWNERS` file requires named people to review changes to named
paths. On a solo repo it does nothing except make merges annoying. The day
someone else can land a commit, add it, and put these paths in it first:

```
/.claude/            @you    # skills and the auto-run SessionStart hook
/secure_coding.md    @you
/docs/CONTROLS.md    @you
/scripts/            @you
```

Why those: `.claude/settings.json` contains a command that **executes
automatically when a session starts**. Editing that one string is code
execution on the machine of anyone who opens the repo, with no permission
prompt. It is the highest-value line in the repository to an attacker and
the least likely to be read carefully in a diff.

---

## Fork pull requests — the one to actually worry about

If your repo is public, anyone can open a pull request. Their branch
contains their code, and your workflow runs against it.

The kit's own workflow is built for this: it declares `contents: read`, and
it does **not** execute the `SessionStart` hook string on `pull_request`
events (a contributor could otherwise change that string and have CI run
it). If you add workflows, keep the rule:

**`GH-8` Never run untrusted branch content with write permissions or
secrets.** In particular do not switch a workflow to `pull_request_target`
to "make secrets work" — that runs *your* trusted context against *their*
code, which is the exact shape of the well-known GitHub Actions
vulnerability.

---

## What this does not do

- **It does not make the checks correct.** A required check that passes on a
  broken repo is worse than none — see `scripts/kit-check-selftest.sh`, which
  exists to prove the checks can fail.
- **It does not survive `--no-verify`** for the *local* pre-push hook. The
  branch rules above are server-side and cannot be bypassed that way, which
  is precisely why they are worth more than the local hook.
- **It is not access control.** Who can push, who can read a private repo,
  and who is in the org are separate settings.

---

## Where these rules live

| Rule | What it means | Gates? |
|---|---|---|
| `GH-1` | A check that cannot block a merge is a report, not a gate | n/a — the principle |
| `GH-2` | Required status checks on the default branch, `enforce_admins` on | **yes, once you set it** |
| `GH-3` | Secret scanning + push protection enabled | **yes** — blocks the push |
| `GH-4` | Dependabot alerts on; version updates off on a pinned stack | no — notification |
| `GH-5` | Default workflow token is read-only | **yes** — permission denial |
| `GH-6` | Deploy gated by `needs:` **and** an environment reviewer | **yes, once you set it** |
| `GH-7` | CODEOWNERS on `.claude/`, `scripts/`, security docs — once a second person exists | no — review routing |
| `GH-8` | Never run untrusted branch content with write scope or secrets | no — a design rule |

`docs/CONTROLS.md` is the canonical map of every rule and what enforces it.
These are the ones that live in GitHub's settings rather than in this
repository, which is exactly why they are easy to forget: **they are not in
any file, so no check in this repo can see them.** Confirming them is a
line on the go-live list.
