#!/usr/bin/env bash
# Proves that scripts/kit-check.sh can actually FAIL.
#
# WHY THIS EXISTS
# ---------------
# A guardrail that cannot fail is worse than no guardrail: it buys false
# confidence and stops anyone looking. Two separate panel reviews of this kit
# found checks that could never fire — the worst of them a `grep -qi 'refus'`
# that was satisfied by an unrelated sentence, so deleting the entire dev-auth
# security spine still exited 0.
#
# Instance-fixing that class does not hold. This does: each case below takes a
# clean copy of the repo, breaks ONE thing kit-check claims to guard, and
# asserts kit-check goes red AND names it. A check with no mutation case here
# is a check nobody has proven can fire.
#
# Run: bash scripts/kit-check-selftest.sh
# CI:  .github/workflows/kit-check.yml runs it after kit-check itself.
#
# Adopters: this belongs to the primer's own bookkeeping. See scripts/README.md
# for what to keep and what to delete.

set -uo pipefail

PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)
if [ -z "$PY" ]; then
  echo "::error::kit-check-selftest needs python3 — cannot prove the checks fire"
  exit 1
fi
if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "::error::kit-check-selftest must run inside the git repo (it snapshots tracked files)"
  exit 1
fi

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT" || exit 1

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT INT TERM

pass=0; failed=0; declare -a COVERED=()

# ---------------------------------------------------------------- snapshot --
# Working-tree contents of tracked files: the selftest must test what is about
# to be committed, not what was committed last time.
mkdir -p "$W/base"
# NB: `python -` would take its program from stdin, so the file list cannot also
# arrive there. Plain bash, and NUL-delimited so paths with spaces survive.
# --cached --others --exclude-standard = tracked PLUS untracked-but-not-ignored,
# so a file added this session is tested before it is committed, not after.
git ls-files -z --cached --others --exclude-standard | while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  mkdir -p "$W/base/$(dirname "$f")"
  cp "$f" "$W/base/$f"
done

# kit-check probes `git check-ignore`, so the copy needs to be a repo.
( cd "$W/base" \
  && git init -q . \
  && git add -A \
  && git -c user.email=selftest@local -c user.name=selftest commit -qm snapshot ) >/dev/null 2>&1

# ------------------------------------------------------------ baseline gate --
echo "baseline: an unmutated copy must be green"
base_out=$(cd "$W/base" && bash scripts/kit-check.sh 2>&1); base_rc=$?
if [ $base_rc -ne 0 ]; then
  echo "::error::baseline copy is already RED — every mutation below is meaningless"
  echo "$base_out" | grep '::error::' | sed 's/^/    /'
  exit 1
fi
echo "  ok (exit 0)"
echo

# ------------------------------------------------------------------ helpers --
py_sub() {  # file  old  new   — replace EVERY occurrence, fail loudly if absent
            # (all, not first: leaving a second copy behind means the mutation
            #  did not actually remove the thing the check looks for)
  "$PY" - "$1" "$2" "$3" <<'PYX'
import io, sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(p, encoding='utf-8').read()
if old not in s:
    sys.exit("mutation target absent in %s: %r" % (p, old[:70]))
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
PYX
}

py_cut() {  # file  start_marker  end_marker  — delete the span between them
  "$PY" - "$1" "$2" "$3" <<'PYX'
import io, sys
p, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(p, encoding='utf-8').read()
try:
    i, j = s.index(a), s.index(b)
except ValueError:
    sys.exit("cut markers absent in %s" % p)
io.open(p, 'w', encoding='utf-8', newline='').write(s[:i] + s[j:])
PYX
}

py_re() {   # file  regex  replacement  — case-insensitive, every match
  "$PY" - "$1" "$2" "$3" <<'PYX'
import io, re, sys
p, pat, rep = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(p, encoding='utf-8').read()
out, n = re.subn(pat, rep, s, flags=re.I)
if n == 0:
    sys.exit("mutation regex matched nothing in %s: %r" % (p, pat))
io.open(p, 'w', encoding='utf-8', newline='').write(out)
PYX
}

# case <check-no> <name> <expected-substring-of-error> <mutation command...>
case_run() {
  local chk="$1" name="$2" expect="$3"; shift 3
  COVERED+=("$chk")

  # A PARTIAL copy would make the mutation land on a file kit-check never reads,
  # and this harness would then report "the check cannot fail" — the exact false
  # signal it exists to prevent. Verify the copy before trusting any verdict.
  rm -rf "$W/m"
  if ! cp -r "$W/base" "$W/m" 2>"$W/cp.err"; then
    echo "  ! $name — COPY FAILED, verdict withheld"
    sed 's/^/      /' "$W/cp.err"
    failed=$((failed+1)); return
  fi
  local n_base n_mut
  n_base=$(find "$W/base" -type f -not -path '*/.git/*' | wc -l)
  n_mut=$(find "$W/m"    -type f -not -path '*/.git/*' | wc -l)
  if [ "$n_base" -ne "$n_mut" ]; then
    echo "  ! $name — INCOMPLETE COPY ($n_mut of $n_base files), verdict withheld"
    failed=$((failed+1)); return
  fi

  if ! ( cd "$W/m" && "$@" ) 2>"$W/setup.err"; then
    echo "  ✗ $name — MUTATION SETUP FAILED (the thing it breaks may have moved)"
    sed 's/^/      /' "$W/setup.err"
    failed=$((failed+1)); return
  fi

  # A mutation that did not actually change a file would make kit-check pass
  # honestly, and this harness would report it as "the check cannot fail".
  # Verdict is only meaningful if the tree really differs.
  if diff -rq "$W/base" "$W/m" --exclude=.git >/dev/null 2>&1; then
    echo "  ! $name — MUTATION CHANGED NOTHING, verdict withheld"
    failed=$((failed+1)); return
  fi

  local out rc
  out=$(cd "$W/m" && bash scripts/kit-check.sh 2>&1); rc=$?

  if [ $rc -eq 0 ]; then
    echo "  ✗ $name — SURVIVED (check $chk exited 0 with this broken). The check cannot fail."
    failed=$((failed+1)); return
  fi
  if ! printf '%s' "$out" | grep -qi -- "$expect"; then
    echo "  ~ $name — went red, but not for the stated reason (check $chk may be firing by accident)"
    printf '%s' "$out" | grep '::error::' | sed 's/^/      /' | head -3
    failed=$((failed+1)); return
  fi
  echo "  ✓ $name — caught by check $chk"
  pass=$((pass+1))
}

# -------------------------------------------------------------------- cases --
echo "mutations (each must turn kit-check red, for the right reason):"

# --- SEC-2, the highest-consequence rule in the kit -------------------------
case_run 15 "dev-auth security spine deleted from /perp-build-core" \
  "no longer emits the dev-auth startup assertion" \
  py_cut .claude/skills/perp-build-core/SKILL.md \
         '11. **Dev-mode sessions' '12. **Deployability'

case_run 15 "dev-auth assertion silently reverted to the fail-OPEN shape" \
  "fail-closed polarity" \
  py_sub .claude/skills/perp-build-core/SKILL.md \
         '// Fail CLOSED. The stub runs only where something positively says' \
         '// (comment removed)'

case_run 15 "/perp-check stops reading the guard's direction" \
  "no longer reads the dev-auth guard" \
  py_sub .claude/skills/perp-check/SKILL.md 'fails open' 'is absent'

# --- STOP rules: inversion, not deletion, is the realistic drift ------------
case_run 20 "STOP-2 inverted (never weaken a test -> you may weaken a test)" \
  "INVERTED" \
  py_sub CLAUDE.md 'Never weaken a test to make it pass' \
                   'You may weaken a test to make it pass'

case_run 20 "STOP-1 sentence removed" \
  "lost the STOP-1 sentence" \
  py_sub CLAUDE.md 'Two failures at the same step = stop' 'Keep trying'

case_run 20 "the owner's recovery guide deleted" \
  "WHEN-IT-GOES-WRONG" \
  rm -f docs/WHEN-IT-GOES-WRONG.md

# --- module system ----------------------------------------------------------
case_run 10 "MODULES.md loses the boundary claim (dimension, not a module)" \
  "lost the boundary claim" \
  py_sub docs/MODULES.md 'dimension, not a module' 'module like any other'

case_run 10 "MODULES.md unregistered from README" \
  "not listed in README" \
  py_sub README.md 'docs/MODULES.md' 'docs/MODULES-old.md'

# --- review output must never reach the remote ------------------------------
case_run 14 "reviews/ dropped from .gitignore" \
  "missing from .gitignore" \
  py_sub .gitignore 'reviews/' '#reviews/'

case_run 14 "someone blanket-ignores *.png (kills the BRAND logo)" \
  "blanket-ignores" \
  "$PY" -c "open('.gitignore','a').write('\n*.png\n')"

# --- onboarding -------------------------------------------------------------
case_run 13 "SessionStart auto-scope hook gutted" \
  "SessionStart" \
  py_sub .claude/settings.json 'docs/SCOPE.md' 'docs/NOTHING.md'

case_run 13 "CLAUDE.md loses the no-hooks fallback" \
  "run-perp-scope-first fallback" \
  py_sub CLAUDE.md 'invoke it as your first action' 'consider running it'

# --- cross-reference integrity ---------------------------------------------
case_run 9 "a § anchor points at a heading that does not exist" \
  "anchors do not resolve" \
  py_sub CLAUDE.md 'secure_coding.md` § 7' 'secure_coding.md` § Nonexistent Heading'

case_run 1 "a doc references a /perp- skill that was never shipped" \
  "referenced in living docs" \
  "$PY" -c "open('README.md','a').write('\nSee /perp-imaginary for details.\n')"

# --- stack guardrails -------------------------------------------------------
case_run 19 "PIN-5 stack review stamp goes stale" \
  "reviewed" \
  py_re docs/STACK.md '_Reviewed: [0-9]{4}-[0-9]{2}-[0-9]{2}' '_Reviewed: 2019-01-01'

case_run 12 "STACK.md loses the never-serverless pin" \
  "never-serverless" \
  py_re docs/STACK.md 'never[ -]serverless' 'serverless-is-fine'

# --- the kit's own budget ---------------------------------------------------
case_run 7 "CLAUDE.md blows its context budget" \
  "context budget" \
  "$PY" -c "open('CLAUDE.md','a').write('\n'+'padding. '*4000)"


# --- bookkeeping the kit relies on to stay self-consistent ------------------
case_run 2 "a skill's frontmatter name stops matching its directory" \
  "declares 'name:" \
  py_sub .claude/skills/perp-status/SKILL.md 'name: perp-status' 'name: perp-stat'

case_run 3 "README version drifts from the CHANGELOG" \
  "version stamps disagree" \
  py_re README.md 'Version [0-9]+\.[0-9]+\.[0-9]+' 'Version 9.9.9'

case_run 4 "a count gets restated in prose (counts drift silently)" \
  "count is restated" \
  sh -c "printf 'This section has three gates.\n' >> docs/GLOSSARY.md"

case_run 5 "a runbook is promoted out of template status with TODOs still in it" \
  "live runbook but still has" \
  sh -c "printf '# Deploy\n<TODO: fill this in>\n' > docs/runbooks/deploy.md"

case_run 6 "a STACK.md pin keystone stops being mirrored in CLAUDE.md" \
  "pin keystone" \
  py_sub CLAUDE.md 'App Router only' 'Any router'

case_run 8 "a feature plan doc is never registered in the index" \
  "no row in feature_overview" \
  sh -c "printf '# Ghost feature\n' > features/ghost.md"

case_run 11 "a [module] catalog row stops linking into its boundary doc" \
  "link to no boundary doc" \
  py_re docs/FEATURE_CATALOG.md '(MODULES|DOMAIN_MODEL|STACK)\.md' 'NOWHERE.md'

case_run 16 "a previously-fixed panel finding regresses (BRAND unregistered)" \
  "not registered in README" \
  py_sub README.md 'docs/BRAND.template.md' 'docs/BRAND-old.md'

case_run 17 "MODULES.md loses the Toolpath millimetres warning (a 25.4x price error)" \
  "unit warning" \
  py_re docs/MODULES.md 'millimetres' 'units'

case_run 18 "STACK.md loses the Prisma 7 config change (first-migration P1012)" \
  "P1012" \
  py_re docs/STACK.md 'prisma\.config\.ts' 'schema.prisma'

# --- GitHub-side gates (they live in settings, so the doc is the only carrier) --
case_run 18 "the GitHub gating doc is deleted" \
  "nothing tells the owner how to make a red build block a merge" \
  rm -f docs/GITHUB.md

case_run 18 "GITHUB.md loses enforce_admins (the rule then skips the solo owner)" \
  "enforce_admins" \
  py_re docs/GITHUB.md 'enforce_admins' 'admins_exempt'

case_run 18 "the CI workflow loses its least-privilege permissions block" \
  "least-privilege permissions" \
  py_re .github/workflows/kit-check.yml '(?m)^permissions:' '# permissions removed:'

case_run 18 "CI stops running the selftest (checks could rot unnoticed)" \
  "no longer proves the checks can fail" \
  py_re .github/workflows/kit-check.yml 'kit-check-selftest' 'kit-check-disabled'

# --- STOP-8 and the module contract ----------------------------------------
case_run 20 "STOP-8 removed (stop rules become waivable by a tracked file)" \
  "lost STOP-8" \
  py_re CLAUDE.md 'STOP-8' 'STOP-X'

case_run 20 "the push waiver moves back into a tracked file" \
  "TRACKED file" \
  sh -c "printf -- '- standing confirmation for /perp-push is recorded here.\n' >> CLAUDE.md"

case_run 20 "the untracked marker stops being gitignored" \
  "not gitignored" \
  py_re .gitignore '(?m)^\.claude/\*\.local$' '# removed'

case_run 20 "/perp-feature stops filling the module contract" \
  "does not fill the module contract" \
  py_re .claude/skills/perp-feature/SKILL.md 'module contract' 'plan section'

case_run 20 "the feature template loses contract row 8 (data classification)" \
  "data classification" \
  py_re features/_TEMPLATE.md 'Data classification' 'Misc notes'

# --- the build path: retrofit-hostile things that must land in migration 1 ----
case_run 18 "/perp-build-core stops provisioning File.classification" \
  "has nothing to read" \
  py_re .claude/skills/perp-build-core/SKILL.md 'classification' 'category'

case_run 18 "/perp-build-core drops the SCALE-1 composite indexes" \
  "composite clientId indexes" \
  py_re .claude/skills/perp-build-core/SKILL.md 'SCALE-1' 'PERF-X'

case_run 18 "the RLS pooled-connection warning is lost (half-done RLS leaks)" \
  "pooled-connection warning" \
  py_re .claude/skills/perp-build-core/SKILL.md 'SET LOCAL' 'set the tenant'

case_run 18 "/perp-build-core emits no health endpoint the runbook curls" \
  "no health endpoint" \
  py_re .claude/skills/perp-build-core/SKILL.md 'api/health' 'api/status'

case_run 18 "DOMAIN_MODEL reverts to the boolean exportControlled" \
  "cannot express CUI" \
  py_re docs/DOMAIN_MODEL.md 'classification' 'exportControlled'

case_run 18 "the CI template stops writing scripts/gates.sh" \
  "would stop gating" \
  py_re .claude/skills/perp-setup-testing/SKILL.md 'gates\.sh' 'checks.sh'

case_run 18 "MONEY-4's test loses the two-connection requirement" \
  "one client serializes" \
  py_re testing-conventions.md 'two separate client instances' 'one client'

# --- rule IDs must resolve ---------------------------------------------------
case_run 21 "a rule ID is cited but has no index row" \
  "absent from CONTROLS.md" \
  sh -c "printf 'See MONEY-9 for the rounding rule.\n' >> docs/GLOSSARY.md"

case_run 21 "the rule index is deleted" \
  "lost its rule index" \
  py_re docs/CONTROLS.md '## The rule index' '## Assorted notes'

# --- navigation, the graph, and the adopter's delete decision ----------------
case_run 17 "MODULES.md's graph stops showing integrations attaching to the spine" \
  "attaching to the spine" \
  py_re docs/MODULES.md 'INTEGRATION MODULES' 'OTHER STUFF'

case_run 17 "the Toolpath -> Part Viewing edge is lost from the graph" \
  "easy to miss" \
  py_re docs/MODULES.md 'Toolpath \(DFM\) ─+▶ Part Viewing' 'Toolpath (DFM)'

case_run 17 "MODULES.md loses its table of contents" \
  "table of contents" \
  py_re docs/MODULES.md '## Contents' '## Notes'

case_run 18 "scripts/README.md is deleted (adopters must triage bash again)" \
  "left to triage" \
  rm -f scripts/README.md

case_run 18 "README again tells adopters to delete kit-check wholesale" \
  "delete kit-check wholesale" \
  sh -c "printf 'The workflow only guards the primer - delete it after adoption.\n' >> README.md"

# --- compliance rules must live where they get built --------------------------
case_run 17 "DOC-1 (released-revision immutability) vanishes from the module that builds it" \
  "absent from MODULES.md" \
  py_re docs/MODULES.md 'DOC-1' 'DOCX-1'

case_run 17 "the compliance acceptance tests are removed" \
  "cannot demonstrate" \
  py_re docs/MODULES.md 'Acceptance — how you prove each one' 'Notes'

case_run 17 "CUI-1's hard-edge caveat is deleted (the side doors close silently)" \
  "absent from MODULES.md" \
  py_re docs/MODULES.md 'CUI-1' 'EGRESS-X'

# --- graduation: prove each TRIGGER actually arms its rule --------------------
# kit-check can only confirm graduation.sh exists. These build a throwaway repo
# containing exactly one risk and assert the matching rule fires. A trigger that
# never fires is the "not built yet" status column all over again.

grad_case() {  # <name> <expected-substring> <setup commands as a shell string>
  local name="$1" expect="$2" setup="$3"
  local G="$W/grad"
  rm -rf "$G"; mkdir -p "$G/scripts" "$G/prisma" "$G/src/lib"
  cp "$ROOT/scripts/graduation.sh" "$G/scripts/"
  ( cd "$G" && eval "$setup" ) >/dev/null 2>&1
  local out rc
  out=$(cd "$G" && bash scripts/graduation.sh 2>&1); rc=$?
  if [ $rc -eq 0 ]; then
    echo "  ✗ trigger: $name — DID NOT ARM (graduation exited 0 with the risk present)"
    failed=$((failed+1)); return
  fi
  if ! printf '%s' "$out" | grep -qi -- "$expect"; then
    echo "  ~ trigger: $name — armed, but not for the stated rule"
    printf '%s' "$out" | grep '::error::' | sed 's/^/      /' | head -2
    failed=$((failed+1)); return
  fi
  echo "  ✓ trigger: $name"
  pass=$((pass+1))
}

echo
echo "graduation triggers (each must arm its rule the moment the risk exists):"

PKG='printf "{\"name\":\"x\",\"dependencies\":{\"next\":\"16.0.0\"}}
" > package.json; printf "{}" > package-lock.json; mkdir -p docs/runbooks; printf "# d
" > docs/runbooks/deploy.md; printf "# i
" > docs/runbooks/incident-response.md; printf "x" > a.test.ts; printf "{\"name\":\"x\",\"scripts\":{\"test\":\"v\"},\"dependencies\":{\"next\":\"16.0.0\"}}
" > package.json'

grad_case "a File model arms CUI-1 (export control)"   "classification"   "$PKG; printf 'model File { id String @id }
' > prisma/schema.prisma"

grad_case "an Invoice model arms MONEY-4 (concurrency tests)"   "concurrency test"   "$PKG; printf 'model Invoice { id String @id }
' > prisma/schema.prisma"

grad_case "clientId in the schema arms TENANT-1 (fail-closed mechanism)"   "fail-closed mechanism"   "$PKG; printf 'model P { id String @id  clientId String }
' > prisma/schema.prisma"

grad_case "a Float money column arms MONEY-1"   "integer minor units"   "$PKG; printf 'model P { id String @id  totalAmount Float }
' > prisma/schema.prisma"

grad_case "ControlledDocument arms DOC-1..5"   "has no test"   "$PKG; printf 'model ControlledDocument { id String @id }
' > prisma/schema.prisma"

grad_case "a fail-OPEN dev-auth guard arms SEC-2"   "FAILS OPEN"   "$PKG; printf 'const AUTH_MODE=1
if (process.env.NODE_ENV === %s && x) { throw new Error(\"refusing to start\") }
' \"'production'\" > src/lib/auth.ts"

grad_case "a portal route group arms A11Y-1"   "accessibility scan"   "$PKG; mkdir -p app/portal"

grad_case "a Dockerfile arms OPS-3 (error tracking)"   "error tracking"   "$PKG; printf 'FROM node:20
' > Dockerfile"

# --- the deploy scaffold: both gates and the post-deploy verification --------
case_run 18 "the deploy job stops depending on verify/build (a red build could deploy)" \
  "could deploy" \
  py_re .github/workflows/deploy.yml.template 'needs: \[build\]' 'if: always()'

case_run 18 "the production environment gate is removed (no human click)" \
  "human gate is gone" \
  py_re .github/workflows/deploy.yml.template 'environment: production' 'environment: none'

case_run 18 "the deploy stops verifying the app actually serves" \
  "exit code is not proof" \
  py_re .github/workflows/deploy.yml.template 'api/health' 'api/ping'

case_run 18 "the Dockerfile switches to npm install (lockfile becomes advisory)" \
  "PIN-2" \
  py_re docs/runbooks/Dockerfile.template 'npm ci' 'npm install'

case_run 18 "a deploy target block is dropped" \
  "lost the ECS target block" \
  py_re .github/workflows/deploy.yml.template 'ECS' 'XYZ'

# --- ITAR / DoD / AS9100 rails -----------------------------------------------
case_run 17 "the deemed-export rule vanishes (CUI-1 would gate services only)" \
  "deemed-export rule" \
  py_re docs/MODULES.md 'deemed export' 'normal transfer'

case_run 17 "/perp-build-core stops provisioning per-user export eligibility" \
  "per-user export-eligibility field" \
  py_re .claude/skills/perp-build-core/SKILL.md 'exportEligible' 'somethingElse'

case_run 17 "/perp-scope stops asking the foreign-person question" \
  "foreign-person question" \
  py_re .claude/skills/perp-scope/SKILL.md '(deemed export|foreign person)' 'ordinary access'

case_run 17 "the incident runbook loses the 72-hour DoD clock" \
  "72-hour DoD reporting clock" \
  py_re docs/runbooks/incident-response.template.md '72[ -]hours?' 'a while'

case_run 17 "AS9102 disappears (FirstArticle becomes a checkbox)" \
  "lost AS9102" \
  py_re docs/MODULES.md 'AS9102' 'the FAI standard'

case_run 17 "/perp-scope stops separating FCI from CUI" \
  "separates FCI from CUI" \
  py_re .claude/skills/perp-scope/SKILL.md 'FCI' 'controlled info'

# ------------------------------------------------------------------ coverage --
echo
echo "coverage: kit-check steps with no mutation case here"
all_checks=$(grep -oE '^echo "[0-9]+\.' scripts/kit-check.sh | grep -oE '[0-9]+' | sort -u)
covered=$(printf '%s\n' "${COVERED[@]}" | sort -u)
missing=$(comm -23 <(printf '%s\n' "$all_checks") <(printf '%s\n' "$covered") | sort -n | tr '\n' ' ')
if [ -n "${missing// /}" ]; then
  echo "  unproven: $missing"
  echo "  (not a failure — but each is a check nobody has shown can fire)"
else
  echo "  none — every check has at least one mutation case"
fi

echo
echo "selftest: $pass proven, $failed unproven-or-broken"
[ $failed -eq 0 ] || echo "::error::$failed kit-check assertion(s) could not be shown to fail"
exit $((failed > 0))
