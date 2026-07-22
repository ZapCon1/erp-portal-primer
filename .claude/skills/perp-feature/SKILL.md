---
name: perp-feature
description: Scaffold features/<name>.md from the template and register it in the feature index
argument-hint: <feature name>
---

# Feature

Scaffold a new feature plan doc and register it in the feature index. This
is the deterministic version of the "every non-trivial feature gets a
`features/<name>.md`" rule in `CLAUDE.md` — run it the moment you commit to
building something, before writing code.

`$ARGUMENTS` is the feature name (e.g. `/perp-feature invoicing` or
`/perp-feature online payments`).

## Steps

1. **Derive the slug.** Lowercase the feature name, replace spaces/punctuation
   with single hyphens (e.g. "Online Payments" → `online-payments`). The file
   will be `features/<slug>.md`.

2. **Check for overlap first.** List `features/*.md` and read the titles /
   summaries. If an existing doc already covers this scope, STOP and tell the
   user — ask whether to extend that doc instead of creating a duplicate.
   This is the "check for existing similar files first" rule; don't skip it.

3. **Feature interview — only when the feature touches an external
   service.** File management/exchange, online payments, email/digests,
   CAD viewing, accounting sync, and similar features depend on a
   provider choice that `/perp-scope` deliberately does NOT collect
   (scope asks capabilities; providers are decided here, at the last
   responsible moment). Ask **one question at a time** (never batched),
   in plain language, and only what this feature needs — usually 1–3
   questions:
   - **Files**: SCOPE.md § The shop floor may already record where
     files live today (Dropbox/Box/Drive/NAS — the interview asks);
     confirm it rather than re-asking. The decision here: keep that
     service (integrate) vs the kit's default (S3-compatible,
     `docs/STACK.md`) with a migration step in the plan. An existing
     service the shop pays for and trusts often wins. § 17 rules apply
     either way.
   - **Payments**: "Do you already have a Stripe/Square/etc. account, or
     is online payment brand new?"
   - **Email**: "Does the shop send from a domain you control?"
   - **CAD**: "What file types do customers actually send you?" (STL
     views day one; STEP/IGES needs the converter — STACK.md § Part
     viewing.)
   - **Scheduling / dispatch / routing**: "What machines or stations
     does work flow through, in order? Which one is the bottleneck?"
     — the answers become the WorkCenter seed list (DOMAIN_MODEL
     § Purchasing & routing) the dispatch list groups by.
   Record the answers in the plan doc's Summary/Decisions area — the
   provider pick, whether it matches or deviates from the STACK.md
   default row, and any existing-service migration implications. Skip
   this step entirely for features with no external service (a
   dashboard, an approval flow).

4. **Create the doc.** Copy `features/_TEMPLATE.md` to `features/<slug>.md`
   and fill in what you already know from the conversation:
   - Replace the `# <Feature Name>` heading with the real name.
   - Fill the **Summary** with a one-paragraph description of the feature.
   - Fill **Surfaces** with the surfaces it touches (🛠 internal · 👤 portal ·
     🌐 public) and, if more than one, how you'll keep them in parity.
     Check SCOPE.md § The portal — if customers see this concept, the
     portal surface is in scope *now*, not later.
   - Draft the **Plan (phases)** and seed the **Progress** table rows with
     status ⬜ not started. **Phases interleave surfaces**: a phase that
     ships a portal-visible concept ships its portal face in the same
     phase (quote created internally + quote visible to the customer =
     one phase, one commit). "Portal" is never its own phase at the end
     of the plan — that structure guarantees drift and violates
     CLAUDE.md § Parity's ship-both-sides rule.
   - Leave sections you genuinely don't know yet as the template's prompts
     rather than inventing detail — but make a real first pass; don't hand
     back an empty template.

5. **Register it in the index.** Add a row to the table in
   `features/feature_overview.md`: feature name, maturity ⚪ Planned, the
   surfaces, the plan-doc filename, and a one-line note. Keep the table
   sorted the way it already is.

6. **Report.** Tell the user the path of the new doc and summarize the phase
   plan you drafted. Invite them to refine the plan before any code is
   written.

## Notes

- If `features/` or `features/_TEMPLATE.md` doesn't exist yet, create the
  directory and tell the user the template is missing (copy it from the
  primer or write a minimal one) — don't silently skip the structure.
- Do NOT start implementing the feature in this command. This command only
  produces the plan doc. Implementation happens afterward, one phase = one
  commit referenced by hash in the Progress table.
- If `$ARGUMENTS` is empty, ask for the feature name instead of guessing.
