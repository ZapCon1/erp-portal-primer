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

echo "1. every /perp-* reference resolves to a shipped skill (living docs only)"
for name in $(grep -rhoE '/perp-[a-z-]+' --include='*.md' . | sed 's|^/||' | sort -u); do
  refs=$(grep -rlE "/$name" --include='*.md' . | grep -vE "$HIST_EXCLUDE" || true)
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

echo "4. no step-count restatements (counts drift; reference the skill count-free)"
grep -rniE '(five|six|seven|5|6|7) steps' --include='*.md' . | grep -vE "$HIST_EXCLUDE" && err "a step count is restated in prose"

echo "5. no maintainer-facing TODO ships in adopter docs"
grep -rn '<TODO: maintainer' --include='*.md' . && err "maintainer TODO shipped"

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
grep -rhoE '(STACK|DOMAIN_MODEL|PORTAL_UX)\.md § [A-Za-z][A-Za-z -]+' --include='*.md' . | sort -u | while read -r ref; do
  file="docs/$(echo "$ref" | cut -d' ' -f1)"; heading=$(echo "$ref" | sed 's/^[^§]*§ //' | sed 's/ *$//')
  grep -qiF "$heading" "$file" || echo "::warning::anchor may not resolve: $ref"
done

echo "exit: $fail"
exit $fail
