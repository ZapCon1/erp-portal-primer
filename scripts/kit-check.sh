#!/usr/bin/env bash
# Consistency checks for the PRIMER'S OWN cross-references.
# Run locally (bash scripts/kit-check.sh) or via .github/workflows/kit-check.yml.
# Adopters: delete scripts/ + the workflow, or adapt if you renamed perp-.
# Rule: every new mirror/claim a release adds gets its check added HERE in
# the same commit.
set -uo pipefail
fail=0
err() { echo "::error::$1"; fail=1; }

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
todo_total=$(grep -ro '<TODO' --include='*.md' --exclude-dir=reviews . | wc -l | tr -d ' ')
echo "   (${todo_total} <TODO> markers across the kit — expected while templates are unfilled)"

echo "6. STACK.md pin keystones mirrored in CLAUDE.md"
for pin in "App Router only" "server-only" "serverless"; do
  grep -qiF "$pin" docs/STACK.md || err "pin keystone '$pin' missing from STACK.md"
  grep -qiF "$pin" CLAUDE.md || err "pin keystone '$pin' missing from CLAUDE.md mirror"
done

echo "7. CLAUDE.md context budget (bytes — line counts hide long-line packing)"
bytes=$(wc -c < CLAUDE.md)
[ "$bytes" -le 27000 ] || err "CLAUDE.md is ${bytes}B (> 27000B budget) — move detail to docs/, leave pointers"

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
python - <<'PY' || err "one or more § anchors do not resolve to a heading"
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

echo "10. MODULES.md is registered and its dimension claim is mirrored"
[ -f docs/MODULES.md ] || err "docs/MODULES.md missing (README and CLAUDE.md both point at it)"
grep -q 'docs/MODULES\.md' README.md || err "docs/MODULES.md not listed in README § What's in here"
grep -q 'docs/MODULES\.md' CLAUDE.md || err "docs/MODULES.md not referenced from CLAUDE.md"
# The load-bearing claim: the portal is a dimension, never a module.
for f in CLAUDE.md docs/MODULES.md; do
  grep -qiE 'dimension, not a (phase|module)' "$f" || err "$f lost the 'portal is a dimension' claim"
done

echo "11. every [module]-tagged catalog row links into MODULES.md's map"
# Was a no-op: it only counted tags, so every MODULES.md link could be broken
# and the check still passed. Now it asserts per row, which is what it claimed.
mod_rows=$(grep -c '\*\*\[module\]\*\*' docs/FEATURE_CATALOG.md || true)
[ "$mod_rows" -gt 0 ] || err "no [module] tags in FEATURE_CATALOG.md — the boundary map lost its anchor rows"
grep -n '^|.*\*\*\[module\]\*\*' docs/FEATURE_CATALOG.md | while IFS=: read -r ln rest; do
  case "$rest" in
    *MODULES.md*|*DOMAIN_MODEL.md*|*STACK.md*) : ;;
    *) echo "::error::FEATURE_CATALOG.md:$ln is tagged [module] but points at no boundary doc" ;;
  esac
done | grep -q '::error::' && err "a [module] row does not link into its boundary doc"

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
python - <<'PY' || err "SessionStart auto-scope hook is missing or malformed (see README § What's in here)"
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
# Silence is what a BROKEN hook produces too, so proving only the quiet branch
# would stay green while every adopter got a dead session. Assert it fires.
if [ -n "${HOOKCMD:-}" ] || HOOKCMD=$(python -c "import json;print(json.load(open('.claude/settings.json',encoding='utf-8'))['hooks']['SessionStart'][0]['hooks'][0]['command'])" 2>/dev/null); then :; fi
if [ -n "${HOOKCMD:-}" ] && [ ! -e docs/SCOPE.md ] && [ ! -e docs/SCOPE.draft.md ] && [ ! -e package.json ]; then
  sh -c "$HOOKCMD" 2>/dev/null | python -c "
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
HOOKCMD=$(python -c "import json;print(json.load(open('.claude/settings.json',encoding='utf-8'))['hooks']['SessionStart'][0]['hooks'][0]['command'])" 2>/dev/null)
if [ -n "$HOOKCMD" ] && [ ! -e docs/SCOPE.md ]; then
  printf '# kit-check probe\n' > docs/SCOPE.md
  out=$(sh -c "$HOOKCMD" 2>/dev/null)
  rm -f docs/SCOPE.md
  [ -z "$out" ] || err "SessionStart hook still fires when docs/SCOPE.md exists — it would nag every session"
fi
# CLAUDE.md carries the fallback for adopters whose tool has no hooks.
grep -q 'invoke it as your first action' CLAUDE.md || err "CLAUDE.md lost the run-perp-scope-first fallback (hooks do not exist in other AI tools)"
grep -qi 'import mode' .claude/skills/perp-scope/SKILL.md || err "perp-scope lost import mode (bring-your-own scope doc)"

echo "14. panel-review reports stay local (reviews/ gitignored, and the skill writes there)"
grep -qE '^reviews/$' .gitignore || err "'reviews/' missing from .gitignore — panel reports would be committed"
grep -q 'reviews/panel-review-' .claude/skills/panel-review/SKILL.md || err "panel-review no longer writes to reviews/"
grep -q 'docs/reviews' .claude/skills/panel-review/SKILL.md && err "panel-review still references the old docs/reviews path"
# Prove git actually ignores it — an unmatched pattern is discovered only after a push.
probe="reviews/.kit-check-probe.md"
mkdir -p reviews && printf 'probe\n' > "$probe"
git check-ignore -q "$probe" || err "git does not ignore $probe despite the .gitignore rule"
rm -f "$probe"
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
grep -qi 'refus' .claude/skills/perp-build-core/SKILL.md || err "/perp-build-core no longer emits the dev-auth startup assertion (SEC-2)"
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
grep -qi 'classification' docs/CONTROLS.md || err "CONTROLS.md lost the one data-classification field everything hangs off"
# The egress gate is the highest-leverage control in the kit; it must default false.
grep -qi 'default false' docs/CONTROLS.md || err "CUI-1 no longer states that the egress gate defaults to false"
grep -q 'mayReceiveControlledData' docs/MODULES.md || err "the egress gate field vanished from MODULES.md"
# Toolpath facts were verified against the live spec — keep them honest.
grep -qi 'millimetres' docs/MODULES.md || err "MODULES.md lost the Toolpath mm/degrees unit warning (a 25.4x error in a number that feeds a price)"
grep -qi 'server-sent event' docs/MODULES.md || err "MODULES.md reverted to polling; the API offers an SSE stream"
grep -qi 'Bearer' docs/MODULES.md || err "MODULES.md lost the Toolpath Bearer-auth detail"

echo "exit: $fail"
exit $fail
