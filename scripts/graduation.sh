#!/usr/bin/env bash
# Dormant rules that WAKE UP when your app does.
#
# WHY THIS EXISTS
# ---------------
# A primer has no application, so a whole class of rule cannot be enforced in
# it: DOC-1 needs a database constraint, CUI-2 needs a file read to audit,
# MONEY-4 needs an invoice counter. docs/CONTROLS.md marks those "not built
# yet" — which is honest, and which is exactly how a rule quietly never gets
# built. Nobody re-reads a status column.
#
# So each dormant rule gets a TRIGGER: a detectable fact about your repo that
# means the rule now applies. Before the trigger it reports "dormant" and
# passes. From the moment the trigger fires it is a GATE, and a missing
# requirement fails the build.
#
# The point: you never have to remember to turn a rule on. Adding a File model
# arms the export-control rules. Adding an invoice counter arms the
# concurrency tests. The rule arrives when the risk does.
#
# Run: bash scripts/graduation.sh
# CI:  add it next to scripts/gates.sh — see scripts/README.md.
#
# Every rule ID here resolves in docs/CONTROLS.md § The rule index.

set -uo pipefail

fail=0
armed=0
dormant=0

err()     { echo "::error::$1"; fail=1; }
armed()   { armed=$((armed+1)); echo "  ARMED    $1"; }
sleeping(){ dormant=$((dormant+1)); echo "  dormant  $1"; }

# --- trigger detection -------------------------------------------------------
# Each is a fact about the repo, not a promise about it.

has_app=0;    [ -f package.json ] && has_app=1
schema=$(ls prisma/schema.prisma 2>/dev/null | head -1)
[ -n "$schema" ] || schema=$(find . -name 'schema.prisma' -not -path '*/node_modules/*' 2>/dev/null | head -1)

srcdirs=""
for d in src app lib components; do [ -d "$d" ] && srcdirs="$srcdirs $d"; done

grep_src() { [ -n "$srcdirs" ] && grep -rqi "$1" $srcdirs --include='*.ts' --include='*.tsx' 2>/dev/null; }
grep_schema() { [ -n "$schema" ] && grep -qi "$1" "$schema" 2>/dev/null; }

has_tenant=0;  grep_schema 'clientId'                     && has_tenant=1
has_file=0;    grep_schema 'model File'                   && has_file=1
has_doc=0;     grep_schema 'model \(ControlledDocument\|DocumentRevision\)' && has_doc=1
has_qual=0;    grep_schema 'model \(Nonconformance\|Inspection\)'           && has_qual=1
has_invoice=0; grep_schema 'model Invoice'                && has_invoice=1
has_auth=0;    grep_src 'AUTH_MODE'                       && has_auth=1
has_portal=0
for d in app/portal src/app/portal app/\(portal\); do [ -d "$d" ] && has_portal=1; done

echo "graduation: rules that arm themselves as your app grows"
echo

# =============================================================================
echo "you have an application (package.json)"
if [ "$has_app" = "0" ]; then
  sleeping "everything below - no package.json yet, so nothing has been built"
  echo
  echo "Nothing is armed. That is correct for a repo with no application."
  echo "These rules arm themselves; you do not have to remember them."
  exit 0
fi

armed "TEST-*, DEP-1, PIN-1/2, OPS-1"

# TEST-* — a test command that runs, and something for it to run
if grep -q '"test"' package.json; then
  find . \( -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.spec.ts' \) \
       -not -path '*/node_modules/*' 2>/dev/null | grep -q . \
    || err "TEST-*: a test script exists but there are no test files for it to run"
else
  err "TEST-*: no test script in package.json. /perp-setup-testing wires one"
fi

# DEP-1 / PIN-1 / PIN-2
[ -f package-lock.json ] || [ -f pnpm-lock.yaml ] || [ -f yarn.lock ] \
  || err "PIN-2: no lockfile committed - the pins are advisory without it"
if grep -qE '"(next|prisma|@prisma/client|better-auth|pg-boss)": *"[\^~]' package.json 2>/dev/null; then
  err "PIN-1: a load-bearing dependency uses ^ or ~ - pin it exactly"
fi

# OPS-1 — the runbooks stop being optional once something can be deployed
for rb in deploy incident-response; do
  if [ ! -f "docs/runbooks/$rb.md" ]; then
    err "OPS-1: docs/runbooks/$rb.md does not exist. The first outage is not when to write it"
  elif grep -q '<TODO' "docs/runbooks/$rb.md" 2>/dev/null; then
    err "OPS-1: docs/runbooks/$rb.md still has <TODO> markers but is a live runbook"
  fi
done

# =============================================================================
echo
echo "you have auth code (AUTH_MODE appears in source)"
if [ "$has_auth" = "1" ]; then
  armed "SEC-2 - the dev-auth stub must be unable to boot outside development"
  grep_src 'refusing to start' \
    || err "SEC-2: no startup assertion refusing the dev-auth stub outside development"
  if grep -rq "NODE_ENV === 'production' &&" $srcdirs --include='*.ts' 2>/dev/null; then
    err "SEC-2: the dev-auth guard FAILS OPEN - predicated on NODE_ENV==='production', so an unset or misspelled NODE_ENV boots the stub. Assert development positively instead"
  fi
else
  sleeping "SEC-2 - no auth module yet"
fi

# =============================================================================
echo
echo "your schema has tenant-scoped models (clientId)"
if [ "$has_tenant" = "1" ]; then
  armed "TENANT-1, SCALE-1"
  grep -qi '\$extends\|row level security\|ENABLE ROW LEVEL' "$schema" prisma/*.ts lib/*.ts 2>/dev/null \
    || err "TENANT-1: no fail-closed mechanism found (a Prisma client extension requiring a tenant argument, or RLS). Discipline is not the control - a query that forgets the filter must be unable to succeed"
  grep -q '@@index(\[clientId' "$schema" 2>/dev/null \
    || err "SCALE-1: no composite (clientId, ...) index in the schema. Adding one later is a migration against live data"
else
  sleeping "TENANT-1, SCALE-1 - no clientId in the schema yet"
fi

# =============================================================================
echo
echo "your schema stores money"
if [ -n "$schema" ] && grep -qiE '(amount|total|price|cost|rate|subtotal)' "$schema" 2>/dev/null; then
  armed "MONEY-1"
  if grep -qiE '(amount|total|price|subtotal)[A-Za-z]* +(Float|Decimal)' "$schema" 2>/dev/null; then
    err "MONEY-1: a money column is Float or Decimal. Money is integer minor units in an integer column - JS has no decimal type"
  fi
else
  sleeping "MONEY-1 - no money columns yet"
fi

# =============================================================================
echo
echo "you have an Invoice model"
if [ "$has_invoice" = "1" ]; then
  armed "MONEY-4 - the integrity constructs need concurrency tests"
  find . -name '*concurren*' -not -path '*/node_modules/*' 2>/dev/null | grep -q . \
    || err "MONEY-4: no concurrency test found. A single-threaded numbering test passes against a completely broken counter - see testing-conventions.md § Integrity constructs"
else
  sleeping "MONEY-4 - no Invoice model yet"
fi

# =============================================================================
echo
echo "you store files"
if [ "$has_file" = "1" ]; then
  armed "CUI-1, CUI-2 - export control and CUI apply the moment files exist"
  grep -qi 'classification' "$schema" 2>/dev/null \
    || err "CUI-1: File has no classification field. Retrofitting it means classifying live files by hand, from memory - add it now even if you have no regulated data"
  grep -qi 'mayReceiveControlledData' "$schema" 2>/dev/null \
    || err "CUI-1: no mayReceiveControlledData on the integration/provider model - the egress gate has nothing to read"
else
  sleeping "CUI-1, CUI-2 - no File model yet"
fi

# =============================================================================
echo
echo "you have controlled documents"
if [ "$has_doc" = "1" ]; then
  armed "DOC-1..DOC-5 - you are claiming AS9100 document control"
  for pair in "immutab:DOC-1 (a released revision cannot be edited in place)" \
              "approv:DOC-2 (release requires every named approval)" \
              "supersed:DOC-3 (superseded revisions are retained, never deleted)" \
              "uncontrolled when printed:DOC-4 (prints are stamped)"; do
    pat=${pair%%:*}; label=${pair#*:}
    grep -rqi "$pat" . --include='*.test.ts' --include='*.spec.ts' \
        --exclude-dir=node_modules 2>/dev/null \
      || err "$label has no test. docs/MODULES.md § Doc Control names the exact test for each"
  done
else
  sleeping "DOC-1..5 - no ControlledDocument/DocumentRevision models yet"
fi

# =============================================================================
echo
echo "you record quality data"
if [ "$has_qual" = "1" ]; then
  armed "QUAL-1 - quantities must reconcile"
  grep -rqi 'scrap\|reconcil' . --include='*.test.ts' --exclude-dir=node_modules 2>/dev/null \
    || err "QUAL-1: no test asserting ordered = shipped + scrapped + reworked-out. A drift here bills a customer for parts they never got"
else
  sleeping "QUAL-1 - no quality models yet"
fi

# =============================================================================
echo
echo "you have a customer portal surface"
if [ "$has_portal" = "1" ]; then
  armed "A11Y-1, PARITY-1 - a customer can now reach this"
  grep -rq 'pa11y\|axe' .github/workflows/ 2>/dev/null \
    || err "A11Y-1: a portal view exists but no accessibility scan is wired in CI. /perp-setup-testing left the step commented out for exactly this moment"
  grep -rqi 'tenant\|clientId' . --include='*.test.ts' --exclude-dir=node_modules 2>/dev/null \
    || err "TENANT-1: a portal exists with no tenant-isolation test. Every portal route test asserts a cross-tenant request returns 404"
else
  sleeping "A11Y-1 - no portal routes yet"
fi

# =============================================================================
echo
echo "you can deploy (a Dockerfile or compose file exists)"
if [ -f Dockerfile ] || ls docker-compose*.y*ml >/dev/null 2>&1; then
  armed "OPS-3, GH-6 - something can now reach production"
  grep -rqi 'sentry\|rollbar\|bugsnag\|otel\|opentelemetry' . \
       --include='*.ts' --include='*.json' --exclude-dir=node_modules 2>/dev/null \
    || err "OPS-3: no error tracking found. The audit log says what happened; this says what failed to happen - and you find out from a customer otherwise"
  echo "  NOTE     GH-6: a deploy gate lives in GitHub's settings, which no check here can see."
  echo "           Confirm the production environment has a required reviewer (docs/GITHUB.md)."
else
  sleeping "OPS-3 - nothing deployable yet"
fi

# =============================================================================
echo
echo "armed: $armed   dormant: $dormant"
if [ "$fail" = "0" ]; then
  echo "Every armed rule is satisfied. Dormant rules will arm themselves."
else
  echo "::error::a rule that just became applicable is not satisfied - see above"
fi
exit $fail
