#!/usr/bin/env bash
# Consistency checks for the PRIMER'S OWN cross-references.
# Run locally (bash scripts/kit-check.sh) or via .github/workflows/kit-check.yml.
# Adopters: see scripts/README.md - some checks are the primer's bookkeeping
# (delete them), others bind YOUR repo forever (keep them). Do not delete blind.
# Rule: every new mirror/claim a release adds gets its check added HERE in
# the same commit.
set -uo pipefail
fail=0
err() { echo "::error::$1"; fail=1; }

# One interpreter, resolved once. Bare `python` does not exist on stock macOS
# (12.3+) or most Linux — only `python3`. Hard-coding it turned a missing binary
# into three FALSE failures blaming the adopter's own documents, plus one control
# that vanished with no output at all. A skip must announce itself.
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)
# The SessionStart hook string is executable shell that kit-check runs live to
# prove the hook fires. On a pull_request that string arrives from the
# CONTRIBUTOR'S branch, so running it would make CI a shell for anyone who can
# open a PR. Static shape assertions still run; only the live-fire is skipped.
KC_ALLOW_EXEC=1
if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
  KC_ALLOW_EXEC=0
  echo "::warning::pull_request event — hook live-fire probes SKIPPED (untrusted branch content)"
fi

[ -n "$PY" ] || echo "::warning::no python3 on PATH — checks 9, 13 and 19 are SKIPPED, not passed"

# Probes below write real files into the repo. Without this trap a Ctrl-C between
# the write and the rm leaves a stub docs/SCOPE.md, which permanently silences the
# onboarding hook for someone who has never been scoped — the check breaking the
# very thing it checks.
KC_PROBE_SCOPE=0
cleanup() {
  [ "$KC_PROBE_SCOPE" = "1" ] && rm -f docs/SCOPE.md
  rm -f reviews/.kit-check-probe.md
  rmdir reviews 2>/dev/null || true
  return 0
}
trap cleanup EXIT INT TERM

# The changelog keeps old names/verdicts by convention — excluded where noted.
HIST_EXCLUDE='CHANGELOG\.md'
# reviews/ holds gitignored panel reports that quote kit strings verbatim, so
# scanning them makes every review trip the very drift checks it is reporting on.
# (Found the hard way: a report describing check 5's dead grep target became
# that target's first occurrence in repo history, and check 5 fired on it.)

echo "1. every /perp-* reference resolves to a shipped skill (living docs only)"
for name in $(grep -rhoE '/perp-[a-z-]+' --include='*.md' --exclude-dir=reviews . | sed 's|^/||' | sort -u); do
  refs=$(grep -rlE "/$name" --include='*.md' --exclude-dir=reviews . | grep -vE "$HIST_EXCLUDE" || true)
  if [ -n "$refs" ] && [ ! -f ".claude/skills/$name/SKILL.md" ]; then
    err "/$name referenced in living docs but .claude/skills/$name/SKILL.md missing"
  fi
done

echo "2. skill frontmatter name matches its directory"
for dir in .claude/skills/*/; do
  skill=$(basename "$dir"); declared=$(sed -n 's/^name: //p' "$dir/SKILL.md" | head -1)
  [ "$declared" = "$skill" ] || err "$dir declares 'name: $declared'"
done

echo "3. README version matches CHANGELOG latest entry"
readme=$(grep -oE 'Version [0-9]+\.[0-9]+\.[0-9]+' README.md | head -1 | cut -d' ' -f2)
changelog=$(grep -oE '^## [0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | head -1 | cut -d' ' -f2)
[ "$readme" = "$changelog" ] || err "version stamps disagree: README=$readme CHANGELOG=$changelog"

echo "4. no count restatements (counts drift; reference the source count-free)"
grep -rniE '\b(one|two|three|four|five|six|seven|eight|nine|ten|[0-9]+) (steps|checks|phases|perspectives|invariants|gates)\b' \
  --include='*.md' --exclude-dir=reviews . | grep -vE "$HIST_EXCLUDE" && err "a count is restated in prose — drop the number or derive it"

echo "5. no unfilled TODO in a doc the checklist calls done"
# The old form grepped '<TODO: maintainer', a string that never existed anywhere
# in this repo — so it could not fire. Count real markers instead and hold the
# line: docs promoted out of template status must carry none.
for f in $(ls docs/runbooks/*.md 2>/dev/null | grep -v '\.template\.md$'); do
  n=$(grep -c '<TODO' "$f" || true)
  [ "$n" -eq 0 ] || err "$f is a live runbook but still has $n <TODO> marker(s) — CONTROLS.md OPS-1 gates on this"
done
# OPS-1's loop above iterates non-template runbooks - and in the shipped kit
# there are none, so it can never fire here. Once an adopter has code, assert
# the SHAPE instead: the two runbooks that must be real before go-live.
if [ -f package.json ]; then
  for rb in deploy incident-response; do
    if [ ! -f "docs/runbooks/$rb.md" ]; then
      err "docs/runbooks/$rb.md does not exist - OPS-1 requires it filled before go-live, and the first outage is not when to write it"
    fi
  done
fi
todo_total=$(grep -ro '<TODO' --include='*.md' --exclude-dir=reviews . | wc -l | tr -d ' ')
echo "   (${todo_total} <TODO> markers across the kit — expected while templates are unfilled)"

echo "6. STACK.md pin keystones mirrored in CLAUDE.md"
for pin in "App Router only" "server-only" "serverless"; do
  grep -qiF "$pin" docs/STACK.md || err "pin keystone '$pin' missing from STACK.md"
  grep -qiF "$pin" CLAUDE.md || err "pin keystone '$pin' missing from CLAUDE.md mirror"
done

echo "7. CLAUDE.md context budget (bytes — line counts hide long-line packing)"
bytes=$(wc -c < CLAUDE.md)
[ "$bytes" -le 27000 ] || err "CLAUDE.md is ${bytes}B (> 27000B budget) — see CONTROLS.md § The context budget for the prune order, and do NOT just move bytes into docs/"
# The cap above guards ONE file, and its obvious remedy - "move detail to
# docs/" - relocates bytes into files with no cap that are all reached by a
# MUST pointer. So report the pool too. A DRIFT SIGNAL, never a gate: a byte
# count with a hard threshold is satisfied by three dishonest files instead
# of one honest one.
pool=0
for f in secure_coding.md docs/MODULES.md docs/DOMAIN_MODEL.md docs/FEATURE_CATALOG.md          CLAUDE.md docs/STACK.md docs/CONTROLS.md docs/PORTAL_UX.md testing-conventions.md; do
  [ -f "$f" ] && pool=$((pool + $(wc -c < "$f")))
done
echo "   (MUST-read pool: ${pool}B across 9 docs — drift signal, not a gate)"
[ "$pool" -le 260000 ] || echo "::warning::the MUST-read pool is ${pool}B (>260000B) — prune before adding; CONTROLS.md § The context budget"

echo "8. every feature plan doc is registered in the index"
for f in features/*.md; do
  base=$(basename "$f")
  case "$base" in _TEMPLATE.md|feature_overview.md) continue ;; esac
  grep -q "$base" features/feature_overview.md || err "$f has no row in feature_overview.md (/perp-feature registers; don't skip it)"
done

echo "9. section anchors resolve: '<file> § <Heading>' references"
# Was theatre three ways: the regex needed '.md' adjacent to ' § ' so every
# backticked reference was invisible; it substring-matched anywhere in the file
# rather than against a heading; and it reported via echo inside a pipeline, so
# it could never set fail. All three fixed — this one gates now.
# Python, because the matching needs real prefix logic: a reference is written
# `docs/STACK.md` § Deployment assumes ... — the heading is "Deployment" and the
# rest is prose, so the test is "does some heading in that file start this text",
# not string equality. The old grep version was blind to backticked refs, matched
# substrings anywhere in the file, and reported via echo inside a pipeline so it
# could never fail the run.
if [ -n "$PY" ]; then
"$PY" - <<'PY' || err "one or more § anchors do not resolve to a heading"
import os, re, sys
try: sys.stdout.reconfigure(encoding="utf-8")
except Exception: pass

SKIP_FILES = {'SCOPE.md', 'BRAND.md', 'VOICE.md'}   # interview outputs, absent until /perp-scope runs
ROOT_FILES = {'secure_coding.md', 'testing-conventions.md', 'ARCHITECTURE.md',
              'README.md', 'CLAUDE.md', 'CHANGELOG.md'}
REF = re.compile(r'([A-Za-z_]+\.md)`? § ([A-Za-z][A-Za-z0-9 \-/&]+)')

headings_cache = {}
def headings(path):
    if path not in headings_cache:
        out = []
        with open(path, encoding='utf-8') as fh:
            for line in fh:
                if line.startswith('#'):
                    out.append(line.lstrip('#').strip().lower())
        headings_cache[path] = out
    return headings_cache[path]

def resolve(base):
    if base in SKIP_FILES: return None
    if base in ROOT_FILES: return base if os.path.exists(base) else None
    p = os.path.join('docs', base)
    return p if os.path.exists(p) else None

bad, seen = [], set()
for dirpath, dirnames, filenames in os.walk('.'):
    dirnames[:] = [d for d in dirnames if d not in ('.git', 'reviews', 'node_modules')]
    for fn in filenames:
        if not fn.endswith('.md') or fn == 'CHANGELOG.md':
            continue
        src = os.path.join(dirpath, fn)
        with open(src, encoding='utf-8') as fh:
            for line in fh:
                for base, text in REF.findall(line):
                    target = resolve(base)
                    if not target:
                        continue
                    text = text.strip().lower()
                    key = (base, text)
                    if key in seen:
                        continue
                    seen.add(key)
                    # Citations run into prose (a ref to Deployment continues
                    # "... assumes a VPS"), and headings carry parentheticals
                    # ("Integrity (the below-the-ORM defense)"), so neither string
                    # is reliably a prefix of the other. Match on
                    # the first word: enough to catch a renamed or deleted heading,
                    # which is what this check is for, without policing prose.
                    first = text.split()[0]
                    if any(h.split() and h.split()[0] == first for h in headings(target) if h):
                        continue
                    bad.append(f"{src}: [{base} -> {text}] does not resolve to a heading in {target}")

for b in sorted(bad):
    print(f"::error::anchor: {b}")
sys.exit(1 if bad else 0)
PY
fi

echo "10. MODULES.md is registered and its dimension claim is mirrored"
[ -f docs/MODULES.md ] || err "docs/MODULES.md missing (README and CLAUDE.md both point at it)"
grep -q 'docs/MODULES\.md' README.md || err "docs/MODULES.md not listed in README § What's in here"
grep -q 'docs/MODULES\.md' CLAUDE.md || err "docs/MODULES.md not referenced from CLAUDE.md"
# TWO different claims; the old alternation let either one satisfy both, so the
# boundary claim could be deleted kit-wide with the check still green.
#   "dimension, not a phase"  = sequencing  (never defer the portal to later)
#   "dimension, not a module" = boundary    (it can never be an optional add-on)
for f in CLAUDE.md docs/MODULES.md; do
  grep -qi 'dimension, not a phase' "$f" || err "$f lost the portal sequencing claim (dimension, not a phase)"
done
grep -qi 'dimension, not a module' docs/MODULES.md   || err "MODULES.md lost the boundary claim (dimension, not a module) - compliance posture would become an optional module"

echo "11. every [module]-tagged catalog row links into MODULES.md's map"
# Was a no-op: it only counted tags, so every MODULES.md link could be broken
# and the check still passed. Now it asserts per row, which is what it claimed.
mod_rows=$(grep -c '\*\*\[module\]\*\*' docs/FEATURE_CATALOG.md || true)
[ "$mod_rows" -gt 0 ] || err "no [module] tags in FEATURE_CATALOG.md — the boundary map lost its anchor rows"
# NB: do NOT pipe this into `grep -q ... && err`. grep -q exits on the first
# match and closes the pipe; upstream dies of SIGPIPE, and under `set -o
# pipefail` that makes the whole pipeline non-zero - so the `&& err` never
# ran and this check could not fail. Windows timing hid it; Linux CI did not.
unlinked=$(grep -n '^|.*\*\*\[module\]\*\*' docs/FEATURE_CATALOG.md | while IFS=: read -r ln rest; do
  case "$rest" in
    *MODULES.md*|*DOMAIN_MODEL.md*|*STACK.md*) : ;;
    *) printf '%s ' "$ln" ;;
  esac
done)
[ -z "$unlinked" ] || err "FEATURE_CATALOG.md row(s) $unlinked are tagged [module] but link to no boundary doc"

echo "12. DEPLOYMENT_TARGETS.md is registered and the never-serverless pin still reads as shape-not-vendor"
[ -f docs/DEPLOYMENT_TARGETS.md ] || err "docs/DEPLOYMENT_TARGETS.md missing (README, CLAUDE.md, STACK.md and the deploy runbook all point at it)"
for f in README.md CLAUDE.md docs/STACK.md docs/runbooks/deploy.template.md; do
  grep -q 'DEPLOYMENT_TARGETS\.md' "$f" || err "$f does not reference docs/DEPLOYMENT_TARGETS.md"
done
# Fargate-vs-Lambda is the misreading this doc exists to prevent; both halves must survive.
grep -qi 'fargate' docs/DEPLOYMENT_TARGETS.md || err "DEPLOYMENT_TARGETS.md lost the Fargate/Lambda disambiguation"
# Was `grep -qi 'gov'`, which passes on "government" or "governance".
grep -qiE 'govcloud|us-gov-(west|east)' docs/DEPLOYMENT_TARGETS.md || err "DEPLOYMENT_TARGETS.md lost the GovCloud target"
# The kit's own answer must stay the VPS — a matrix that quietly becomes a cloud recommendation is drift.
grep -qiE 'never serverless|never-serverless' docs/STACK.md || err "STACK.md lost the never-serverless pin"

echo "13. the auto-scope SessionStart hook is present, valid, and correctly gated"
if [ -n "$PY" ]; then
"$PY" - <<'PY' || err "SessionStart auto-scope hook is missing or malformed (see README § What's in here)"
import json,sys
try:
    s=json.load(open('.claude/settings.json',encoding='utf-8'))
except Exception as e:
    print(f"::error::settings.json does not parse: {e}"); sys.exit(1)
if not s.get('permissions',{}).get('deny'):
    print("::error::secret-file deny rules vanished from settings.json"); sys.exit(1)
try:
    cmd=s['hooks']['SessionStart'][0]['hooks'][0]['command']
except Exception:
    print("::error::no SessionStart hook"); sys.exit(1)
for needle in ('docs/SCOPE.md','perp-scope','additionalContext','SessionStart'):
    if needle not in cmd:
        print(f"::error::SessionStart hook lost '{needle}'"); sys.exit(1)
PY
fi
# Silence is what a BROKEN hook produces too, so proving only the quiet branch
# would stay green while every adopter got a dead session. Assert it fires.
if [ -n "${HOOKCMD:-}" ] || HOOKCMD=$("$PY" -c "import json;print(json.load(open('.claude/settings.json',encoding='utf-8'))['hooks']['SessionStart'][0]['hooks'][0]['command'])" 2>/dev/null); then :; fi
if [ -z "$PY" ] || [ "$KC_ALLOW_EXEC" = "0" ]; then
  [ -n "$PY" ] || echo "::warning::hook live-fire probe skipped — no python3"
elif [ -n "${HOOKCMD:-}" ] && [ ! -e docs/SCOPE.md ] && [ ! -e docs/SCOPE.draft.md ] && [ ! -e package.json ]; then
  timeout 10 sh -c "$HOOKCMD" 2>/dev/null | "$PY" -c "
import sys, json
raw = sys.stdin.read().strip()
if not raw:
    print('::error::SessionStart hook emitted nothing on a pristine repo — the auto-scope onboarding is dead'); sys.exit(1)
try:
    d = json.loads(raw)
except Exception as e:
    print(f'::error::SessionStart hook emitted invalid JSON: {e}'); sys.exit(1)
ctx = d.get('hookSpecificOutput', {})
if ctx.get('hookEventName') != 'SessionStart':
    print('::error::hook output missing hookEventName=SessionStart'); sys.exit(1)
if 'perp-scope' not in ctx.get('additionalContext', ''):
    print('::error::hook fires but never names perp-scope'); sys.exit(1)
" || err "SessionStart hook does not fire correctly on a pristine repo"
fi
# The hook must stay silent once a project is scoped, or every session nags forever.
# The probe writes a temp docs/SCOPE.md, so it NEVER runs where a real one exists —
# an adopted repo's scope doc is not ours to clobber. There, the hook is already proven
# silent by the fact that nothing nagged.
HOOKCMD=$("$PY" -c "import json;print(json.load(open('.claude/settings.json',encoding='utf-8'))['hooks']['SessionStart'][0]['hooks'][0]['command'])" 2>/dev/null)
if [ -n "$HOOKCMD" ] && [ "$KC_ALLOW_EXEC" = "1" ] && [ ! -e docs/SCOPE.md ]; then
  printf '# kit-check probe\n' > docs/SCOPE.md
  out=$(sh -c "$HOOKCMD" 2>/dev/null)
  rm -f docs/SCOPE.md
  [ -z "$out" ] || err "SessionStart hook still fires when docs/SCOPE.md exists — it would nag every session"
fi
# CLAUDE.md carries the fallback for adopters whose tool has no hooks.
grep -q 'invoke it as your first action' CLAUDE.md || err "CLAUDE.md lost the run-perp-scope-first fallback (hooks do not exist in other AI tools)"
grep -qi 'import mode' .claude/skills/perp-scope/SKILL.md || err "perp-scope lost import mode (bring-your-own scope doc)"

echo "14. panel-review reports stay local (reviews/ gitignored, and the skill writes there)"
for pat in 'reviews/' 'screenshots/' 'shots/' 'docs/reviews/' 'docs/audits/' '\*.review.md' '\*.audit.md' 'panel-review-\*.md'; do
  grep -qE "^${pat}$" .gitignore || err "'${pat}' missing from .gitignore — review/screenshot output would be committed"
done
# Deliberately NOT blanket-ignoring images: BRAND.md may reference a logo.
grep -qE '^\*\.png$' .gitignore && err ".gitignore blanket-ignores *.png — that blocks the BRAND.md logo; ignore the output locations instead"
grep -q 'reviews/panel-review-' .claude/skills/panel-review/SKILL.md || err "panel-review no longer writes to reviews/"
grep -q 'docs/reviews' .claude/skills/panel-review/SKILL.md && err "panel-review still references the old docs/reviews path"
# Prove git actually ignores it — an unmatched pattern is discovered only after a push.
probe="reviews/.kit-check-probe.md"
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  mkdir -p reviews && printf 'probe\n' > "$probe"
  git check-ignore -q "$probe" || err "git does not ignore $probe despite the .gitignore rule"
  rm -f "$probe"
  rmdir reviews 2>/dev/null || true
else
  # A ZIP download or a pre-`git init` adopter is not a broken .gitignore.
  echo "::warning::not a git repository — the ignore-rule probe was SKIPPED, not passed"
fi
# The user-level copy shadows the project one; a stale copy silently writes to the old path.
if [ -f "$HOME/.claude/skills/panel-review/SKILL.md" ]; then
  diff -q "$HOME/.claude/skills/panel-review/SKILL.md" .claude/skills/panel-review/SKILL.md >/dev/null 2>&1 \
    || echo "::warning::~/.claude/skills/panel-review/SKILL.md differs from the project copy — the skill's own sync note says keep them byte-identical"
fi


echo "15. CONTROLS.md is registered and its gates-vs-signals split survives"
[ -f docs/CONTROLS.md ] || err "docs/CONTROLS.md missing (CLAUDE.md and /perp-check both point at it)"
grep -q 'docs/CONTROLS\.md' CLAUDE.md || err "CLAUDE.md does not reference docs/CONTROLS.md"
grep -q 'CONTROLS\.md' .claude/skills/perp-check/SKILL.md || err "/perp-check no longer reads the control map"
# The whole point of the file: some sensors gate, some never do, and rules with
# nothing behind them are named rather than hidden.
grep -qi 'drift signal' docs/CONTROLS.md || err "CONTROLS.md lost the drift-signal category"
grep -qi 'Rules with no sensor yet' docs/CONTROLS.md || err "CONTROLS.md lost its honest list of unenforced rules"
grep -qi 'Go-live gates' docs/CONTROLS.md || err "CONTROLS.md lost the go-live gates (they must not live only in the deletable Bootstrap block)"
# The dev-auth stub is the highest-consequence rule in the kit; it must be a
# control in three places, not a checkbox in one.
grep -q 'SEC-2' docs/CONTROLS.md || err "CONTROLS.md lost the SEC-2 dev-auth gate"
# NOT a word stem: 'refus' also matches an unrelated resume sentence in the
# same file, so the old check passed with the whole security spine deleted.
grep -q 'dev auth stub is active outside an explicitly allowed development' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core no longer emits the dev-auth startup assertion (SEC-2)"
grep -q 'DEV MODE' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core lost the DEV MODE banner requirement (SEC-2)"
grep -q 'Fail CLOSED' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core's dev-auth assertion lost its fail-closed polarity (SEC-2)"
grep -q 'fails open' .claude/skills/perp-check/SKILL.md   || err "/perp-check no longer reads the dev-auth guard's direction (SEC-2)"
grep -qi 'dev-auth' .claude/skills/perp-check/SKILL.md || err "/perp-check lost the dev-auth gate step (SEC-2)"


echo "16. the panel-review fixes stay fixed"
# Every claim below was a confirmed finding; each check is its receipt.
grep -q 'docs/BRAND.template.md' README.md || err "BRAND.template.md not registered in README (/perp-build-core hard-depends on BRAND.md)"
[ -f docs/BRAND.template.md ] || err "docs/BRAND.template.md missing"
grep -qi 'Full data export' docs/FEATURE_CATALOG.md || err "Tier-0 data export row gone — the kit must document a way out"
grep -qi 'If you want out' README.md || err "README lost the exit section"
grep -qi 'Outbound Requests & SSRF' secure_coding.md || err "secure_coding.md lost the SSRF section"
grep -qi 'Origin/Referer' secure_coding.md || err "CSRF section regressed to SameSite as the sole defense"
grep -qi 'portal session is presented to a staff route' secure_coding.md || err "cross-realm session tests (SEC-3) gone from the mandatory table"
grep -qi 'WCAG 2.2 Level AA' docs/PORTAL_UX.md || err "PORTAL_UX lost its conformance target"
grep -qi 'Truncated' docs/PORTAL_UX.md || err "PORTAL_UX lost the truncated required-state (silent pagination is data loss)"
grep -qi 'Type scale' docs/PORTAL_UX.md || err "PORTAL_UX lost the concrete design tokens"
grep -qiE 'services:|postgres:16' .claude/skills/perp-setup-testing/SKILL.md || err "CI template lost its database — tenant-isolation tests cannot run without one"
grep -qi 'SCALE-1' .claude/skills/perp-review-code/SKILL.md || err "/perp-review-code no longer gates on the scale rules"
grep -qi 'Integrity constructs are tested concurrently' testing-conventions.md || err "the 'mandatory tests' on the integrity constructs are undefined again"
grep -qi 'App Runner' docs/DEPLOYMENT_TARGETS.md || err "App Runner row gone (it is web-only; do not re-merge it with Fargate)"
grep -qi 'mem_limit' docs/runbooks/deploy.template.md || err "deploy skeleton lost the CAD worker memory cap"
grep -qi 'Claude Code' docs/GLOSSARY.md || err "GLOSSARY lost the definition of the tool this kit is files for"
grep -qi 'ITAR / EAR' docs/GLOSSARY.md || err "GLOSSARY lost the regulatory acronyms Phase 3 asks about"
# The interview's mode table is what stops an interrupted run losing every answer.
grep -qi 'ask which' .claude/skills/perp-scope/SKILL.md || err "perp-scope lost the SCOPE.md + draft precedence rule"
grep -q 'git remote get-url origin' .claude/skills/perp-scope/SKILL.md || err "perp-scope lost the clone-vs-copy origin guard (SCOPE.md holds margins and client lists)"
# Found by actually running the flow: the new precondition was added while the
# old fallback sentence stayed in the build list, so the skill said both.
grep -qi 'SQLite is acceptable' .claude/skills/perp-build-core/SKILL.md && err "/perp-build-core still offers the SQLite fallback its own preconditions forbid"
grep -qi 'Postgres is required, not preferred' .claude/skills/perp-build-core/SKILL.md || err "/perp-build-core lost the Postgres precondition"
grep -qiE 'node --version|node -v' .claude/skills/perp-build-core/SKILL.md || err "/perp-build-core lost the toolchain precondition check"


echo "17. compliance guardrails are in the control map, not just in prose"
# Found by audit: AS9100 and CMMC were described across six docs and appeared
# nowhere in CONTROLS.md — the one file that answers "what enforces this?".
for id in DOC-1 DOC-2 DOC-3 CUI-1 CUI-2 QUAL-1; do
  grep -q "$id" docs/CONTROLS.md || err "CONTROLS.md lost compliance rule $id"
done
grep -qi 'Compliance controls' docs/CONTROLS.md || err "CONTROLS.md lost its compliance section"
# A compliance rule must be stated where it gets BUILT, not only where it is
# mapped. All of DOC-1..5, CUI-2..5 and QUAL-1 once lived in exactly one file
# (this one), so MODULES.md described doc control while citing no DOC-* rule
# and silently omitting DOC-1 - the immutability rule the module exists for.
for id in DOC-1 DOC-2 DOC-3 DOC-4 DOC-5 CUI-1 CUI-2 CUI-3 CUI-4 CUI-5 QUAL-1; do
  grep -q "$id" docs/MODULES.md     || err "compliance rule $id is mapped in CONTROLS.md but absent from MODULES.md, the module that must build it"
done
grep -qi 'Acceptance - how you prove each one\|Acceptance — how you prove each one' docs/MODULES.md   || err "MODULES.md lost the compliance acceptance tests - a rule you cannot demonstrate is a rule you do not have"
grep -qi 'classification' docs/CONTROLS.md || err "CONTROLS.md lost the one data-classification field everything hangs off"
# The egress gate is the highest-leverage control in the kit; it must default false.
grep -qi 'default false' docs/CONTROLS.md || err "CUI-1 no longer states that the egress gate defaults to false"
grep -q 'mayReceiveControlledData' docs/MODULES.md || err "the egress gate field vanished from MODULES.md"
# Toolpath facts were verified against the live spec — keep them honest.
# The graph's only integration edge used to descend from the Accounting column
# while the text inside that same edge said "attach to the spine".
grep -q 'INTEGRATION MODULES' docs/MODULES.md   || err "MODULES.md's graph no longer shows integration modules attaching to the spine"
grep -q 'Toolpath (DFM) .*Part Viewing' docs/MODULES.md   || err "MODULES.md's graph lost the Toolpath -> Part Viewing dependency (the one the text calls easy to miss)"
grep -q '## Contents' docs/MODULES.md   || err "MODULES.md lost its table of contents (600+ lines, 17 sections)"
grep -q '## Contents' docs/CONTROLS.md   || err "CONTROLS.md lost its table of contents"

# The three integration detail pages. MODULES.md keeps the summary plus the
# facts that are dangerous to miss; the long form lives here. If a stub loses
# its pointer, the detail becomes unreachable rather than merely long.
# The deploy scaffold. The runbook curls a health endpoint and runs
# `docker build .`; before this shipped, neither artifact existed anywhere in
# the kit, so the runbook described a deploy nobody could perform.
[ -f docs/runbooks/Dockerfile.template ] || err "Dockerfile.template missing - deploy.template.md runs 'docker build .' against nothing"
[ -f .github/workflows/deploy.yml.template ] || err "deploy.yml.template missing - there is no gated deploy scaffold"
grep -q 'needs: \[build\]' .github/workflows/deploy.yml.template || err "the deploy job no longer depends on the build/verify chain - a red build could deploy (GH-6)"
grep -q 'environment: production' .github/workflows/deploy.yml.template || err "the deploy job lost its production environment - the human gate is gone (GH-6)"
grep -qi 'required reviewer' .github/workflows/deploy.yml.template || err "deploy.yml.template no longer says the environment needs a required reviewer, without which the gate is decoration"
grep -qi 'api/health' .github/workflows/deploy.yml.template || err "the deploy no longer verifies the app is serving - an exit code is not proof (STOP-6)"
grep -q "output: 'standalone'\|standalone" docs/runbooks/Dockerfile.template || err "Dockerfile.template lost the standalone requirement (there is no server.js without it)"
grep -q 'npm ci' docs/runbooks/Dockerfile.template || err "Dockerfile.template uses npm install - the lockfile becomes advisory (PIN-2)"
for t in "VPS" "ECS" "Container Apps" "Fly"; do
  grep -qi "$t" .github/workflows/deploy.yml.template || err "deploy.yml.template lost the $t target block"
done

for m in toolpath transactional-email file-storage; do
  [ -f "docs/modules/$m.md" ] || err "docs/modules/$m.md missing - MODULES.md points at it"
  grep -q "modules/$m.md" docs/MODULES.md || err "MODULES.md no longer links to docs/modules/$m.md - the detail is orphaned"
done
grep -q 'docs/modules/' README.md || err "docs/modules/ is not registered in README"
grep -qi 'endpoint\|/v1/' docs/modules/toolpath.md || err "the Toolpath detail page lost its API specifics"
grep -qiE 'SPF|DKIM' docs/modules/transactional-email.md || err "the email detail page lost the domain-verification path"
grep -qi 'ingest' docs/modules/file-storage.md || err "the file-storage detail page lost the three modes"

grep -qi 'millimetres' docs/MODULES.md || err "MODULES.md lost the Toolpath mm/degrees unit warning (a 25.4x error in a number that feeds a price)"
grep -qi 'server-sent event' docs/MODULES.md || err "MODULES.md reverted to polling; the API offers an SSE stream"
grep -qi 'Bearer' docs/MODULES.md || err "MODULES.md lost the Toolpath Bearer-auth detail"


echo "18. setup path stays painless (the blockers a new adopter actually hits)"
# The first migration is the only cheap moment for these. Each was promised by
# a doc and absent from /perp-build-core, which is the skill that writes it.
grep -q 'File.classification\|classification' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core does not provision File.classification - CUI-1's gate has nothing to read, and retrofitting means hand-classifying live files"
grep -q 'mayReceiveControlledData' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core does not provision the egress-gate boolean (CUI-1)"
grep -q 'SCALE-1' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core no longer adds the composite clientId indexes (SCALE-1) - a later fix is a migration against live data"
grep -q 'SET LOCAL' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core lost the RLS pooled-connection warning (TENANT-1) - half-implemented RLS leaks across tenants"
grep -qi 'client extension' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core names no fail-closed TENANT-1 mechanism - discipline alone is not the control"
grep -q "output: 'standalone'" .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core builds an app the deploy runbook cannot deploy (no standalone output, no server.js)"
grep -q 'api/health' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core emits no health endpoint, but deploy.template.md curls one forever"
grep -qi 'Dockerfile' .claude/skills/perp-build-core/SKILL.md   || err "/perp-build-core emits no Dockerfile, but the deploy runbook runs docker build ."
grep -q 'exportControlled' docs/DOMAIN_MODEL.md   && err "DOMAIN_MODEL.md still specifies the boolean exportControlled - it cannot express CUI vs export-controlled"

# The mechanism that converts "not built yet" into a real gate once an app
# exists. Without it, every dormant rule depends on someone re-reading a
# status column on exactly the right day.
# Anti-pattern guard. `... | grep -q X && err` is silently broken under
# `set -o pipefail`: grep -q exits on the first match, upstream dies of
# SIGPIPE, the pipeline reports non-zero, and the `&& err` never runs. It
# shipped once and could not fail for two releases. Capture into a variable
# and test that instead.
if grep -nE '^[^#]*\| *grep -q.*&& *err' scripts/*.sh | grep -v 'construct cannot fail' >/dev/null 2>&1; then
  err "a script uses '| grep -q ... && err' - that construct cannot fail under pipefail (SIGPIPE). Capture the output into a variable and test it"
fi

[ -f scripts/graduation.sh ] || err "scripts/graduation.sh missing - the dormant compliance and integrity rules would have nothing to arm them"
grep -q 'Rules that arm themselves' docs/CONTROLS.md || err "CONTROLS.md lost the graduation section - the dormant rules stop being discoverable"
grep -q 'graduation.sh' .claude/skills/perp-setup-testing/SKILL.md || err "the CI template no longer runs graduation.sh, so arming rules would never gate"
grep -q 'graduation.sh' scripts/README.md || err "scripts/README.md does not tell adopters to keep graduation.sh"
for id in DOC-1 CUI-1 MONEY-4 TENANT-1 SEC-2 QUAL-1 A11Y-1; do
  grep -q "$id" scripts/graduation.sh || err "graduation.sh no longer arms $id"
done
[ -f scripts/README.md ] || err "scripts/README.md missing - adopters are left to triage 400 lines of bash to decide what to delete"
grep -qi 'bind YOUR repo' scripts/README.md || err "scripts/README.md no longer says which checks bind the adopter's repo"
grep -q 'delete it after adoption' README.md && err "README again tells adopters to delete kit-check wholesale - half of it binds their repo (see scripts/README.md)"
grep -qi 'Getting a database' docs/STACK.md || err "STACK.md lost the how-to-get-Postgres section (build-core refuses to run without one)"
grep -q 'prisma.config.ts' docs/STACK.md || err "STACK.md lost the Prisma 7 datasource change - adopters hit a P1012 on their first migration"
grep -qi 'dist-tags' docs/STACK.md || err "STACK.md lost the warning that prisma@latest may be a release candidate"
# MONEY-4 and the PIN gates had a "yes" in the Gates column and no carrier.
# If the carrier goes, the row must stop claiming to gate.
grep -q 'gates.sh' .claude/skills/perp-setup-testing/SKILL.md   || err "the CI template no longer writes scripts/gates.sh - SEC-2 and PIN-1..4 would stop gating"
grep -qi 'required status check' .claude/skills/perp-setup-testing/SKILL.md   || err "the CI template no longer says a green CI blocks nothing without branch protection"
grep -qi 'two separate client instances' testing-conventions.md   || err "MONEY-4's concurrency test lost the two-connection requirement - one client serializes and passes against a broken counter"
grep -qi 'invoice-counter.concurrency' .claude/skills/perp-setup-testing/SKILL.md   || err "/perp-setup-testing no longer scaffolds the MONEY-4 stubs that CONTROLS.md says it does"

grep -qi 'Transactional email' docs/MODULES.md || err "MODULES.md lost the transactional-email module"
grep -qiE 'SPF|DKIM' docs/MODULES.md || err "email module lost the domain-verification setup path"
grep -qi 'magic link' docs/MODULES.md || err "email module no longer says portal login depends on it"
grep -qi 'DNS' README.md || err "README step 0 lost the DNS lead-time warning"

# GH-*: CI that cannot block a merge is a report, not a gate. These live in
# GitHub's settings, so no check in this repo can see them - the doc is the
# only carrier and it must at least still exist and be reachable.
[ -f docs/GITHUB.md ] || err "docs/GITHUB.md missing - nothing tells the owner how to make a red build block a merge"
grep -q 'docs/GITHUB\.md' README.md || err "docs/GITHUB.md not listed in README"
grep -q 'docs/GITHUB\.md' docs/CONTROLS.md || err "CONTROLS.md does not point at the GitHub-side gates"
grep -qi 'required status check' docs/GITHUB.md || err "GITHUB.md lost the required-status-checks step (GH-2) - the one that actually gates"
grep -qi 'enforce_admins' docs/GITHUB.md || err "GITHUB.md lost enforce_admins - without it the rule does not apply to a solo owner"
grep -qi 'push protection' docs/GITHUB.md || err "GITHUB.md lost secret-scanning push protection (GH-3)"
grep -qi 'pull_request_target' docs/GITHUB.md || err "GITHUB.md lost the fork-PR warning (GH-8)"
grep -qE '^permissions:' .github/workflows/kit-check.yml || err "kit-check workflow lost its least-privilege permissions block (GH-5)"
grep -q 'kit-check-selftest' .github/workflows/kit-check.yml || err "CI no longer proves the checks can fail"


echo "19. idiom-churn guardrails (PIN-*) and the stack review stamp"
for id in PIN-1 PIN-2 PIN-3 PIN-4 PIN-5; do
  grep -q "$id" docs/CONTROLS.md || err "CONTROLS.md lost idiom-churn rule $id"
done
grep -q 'PIN-3' .claude/skills/perp-check/SKILL.md || err "/perp-check lost the toolchain contract (PIN-3/PIN-4)"
grep -qi 'verify the artifact' .claude/skills/perp-check/SKILL.md || err "/perp-check lost the exit-code-is-not-proof rule (create-next-app exits 0 having done nothing)"
grep -q 'The context budget' docs/CONTROLS.md   || err "CONTROLS.md lost the prune order - at the byte cap the only sanctioned move would again be relocating bytes into uncapped MUST-read docs"
grep -qi 'upgrade drill' docs/CONTROLS.md || err "CONTROLS.md lost the upgrade drill"
# PIN-5, enforced on the kit's own stack record. STACK.md has declared this
# convention since 0.19.0 and nothing checked it until now.
if [ -n "$PY" ]; then
"$PY" - <<'PY2' || err "PIN-5: docs/STACK.md review stamp is stale or unreadable"
import re, sys
from datetime import date
try:
    head = open('docs/STACK.md', encoding='utf-8').read(600)
    m = re.search(r'_Reviewed:\s*(\d{4})-(\d{2})-(\d{2})', head)
    if not m:
        print("::error::docs/STACK.md has no _Reviewed:_ stamp"); sys.exit(1)
    stamped = date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    age = (date.today() - stamped).days
    if age > 180:
        print(f"::error::STACK.md reviewed {age} days ago (>180) - re-verify the ecosystem claims and re-stamp"); sys.exit(1)
    if age > 90:
        print(f"::warning::STACK.md reviewed {age} days ago (>90) - due a re-verify (PIN-5)")
    else:
        print(f"   (stack record reviewed {age} days ago - fresh)")
except Exception as e:
    print(f"::error::PIN-5 check failed: {e}"); sys.exit(1)
PY2
fi


echo "20. novice guardrails: stop rules bind the AI, and the owner has a way out"
for id in STOP-1 STOP-2 STOP-3 STOP-4 STOP-5 STOP-6 STOP-7; do
  grep -q "$id" CLAUDE.md || err "CLAUDE.md lost $id - the owner cannot review the work, so these are not optional"
done
[ -f docs/WHEN-IT-GOES-WRONG.md ] || err "docs/WHEN-IT-GOES-WRONG.md missing - the owner-facing recovery guide"
grep -q 'WHEN-IT-GOES-WRONG' README.md || err "the recovery guide is not registered in README"
grep -q 'WHEN-IT-GOES-WRONG' CLAUDE.md || err "nothing points the owner at the recovery guide"
# The two things that make everything else recoverable.
grep -qi 'commit when it works' docs/WHEN-IT-GOES-WRONG.md || err "recovery guide lost the commit-when-it-works habit"
grep -qi 'Stop. In plain language' docs/WHEN-IT-GOES-WRONG.md || err "recovery guide lost the reset phrase"

# STOP-8: the waiver mechanism must stay OUT of the blast radius. /perp-push
# forbade file-sourced confirmation in one bullet and designated a TRACKED file
# as the opt-out in the next; one appended line then meant auto-push to a public
# remote. Assert both halves: the rule exists, and the marker is untracked.
grep -q 'STOP-8' CLAUDE.md || err "CLAUDE.md lost STOP-8 (a stop rule is never waived by a file)"
grep -q 'push-standing.local' .claude/skills/perp-push/SKILL.md   || err "/perp-push no longer reads its standing confirmation from an untracked marker (STOP-8)"
grep -qE '^\.claude/\*\.local$' .gitignore   || err ".claude/*.local is not gitignored - the push waiver would become a tracked, PR-writable file (STOP-8)"
grep -q 'standing confirmation for' CLAUDE.md   && err "CLAUDE.md still grants /perp-push standing confirmation in a TRACKED file (STOP-8)"

# The 10-point module contract named /perp-feature as its carrier, and
# /perp-feature did not contain the word 'module'. A contract with no owner is
# answered by nobody.
grep -qi 'module contract' .claude/skills/perp-feature/SKILL.md   || err "/perp-feature does not fill the module contract that MODULES.md says it fills"
grep -qi 'Module contract' features/_TEMPLATE.md   || err "features/_TEMPLATE.md has no Module contract section - the contract has nowhere to be answered"
grep -qi 'Data classification' features/_TEMPLATE.md   || err "the feature template dropped contract row 8 (data classification) - the most retrofit-hostile line in the kit"
# STOP-2 is the one a novice can never catch unaided.
# A presence-grep is blind to INVERSION: flipping "never weaken a test" to
# "you may weaken a test" keeps the fragment and passes. Assert the normative
# sentence, then add tripwires for the negations that would replace it.
grep -qi 'Never weaken a test to make it pass' CLAUDE.md   || err "CLAUDE.md lost the STOP-2 sentence (never weaken a test to make it pass)"
grep -qiE '(may|can|ok to|fine to|acceptable to) weaken a test' CLAUDE.md   && err "STOP-2 has been INVERTED in CLAUDE.md - a test-weakening permission is not a rule"
grep -qi 'Two failures at the same step = stop' CLAUDE.md   || err "CLAUDE.md lost the STOP-1 sentence (two failures at the same step = stop)"
grep -qi 'Never report done from an exit code' CLAUDE.md   || err "CLAUDE.md lost the STOP-6 sentence (never report done from an exit code)"

echo "21. every rule ID in the kit resolves in CONTROLS.md's index"
# CLAUDE.md promises an ID can be cited and resolved without re-reading the
# file. That failed on the first try: PARITY-1 occurred exactly once in the
# whole kit - inside the sentence claiming IDs were resolvable. An ID with no
# index row is a citation to nothing.
grep -q '## The rule index' docs/CONTROLS.md || err "CONTROLS.md lost its rule index - IDs stop resolving"
unresolved=""
for id in $(grep -rhoE '(TENANT|SEC|MONEY|PARITY|AUDIT|STRUCT|SCALE|A11Y|OPS|DOC|QUAL|CUI|PIN|STOP|TEST|DEP|GH)-[0-9]+' --include='*.md' --exclude-dir=reviews . | sort -u); do
  grep -qE "^\| \`$id\`" docs/CONTROLS.md || unresolved="$unresolved $id"
done
[ -z "$unresolved" ] || err "rule IDs used but absent from CONTROLS.md's index:$unresolved"

echo "exit: $fail"
exit $fail
