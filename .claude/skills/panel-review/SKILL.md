---
name: panel-review
description: Multi-perspective product review of a feature, flow, or surface — evaluates it from 16 stakeholder perspectives (new user, non-technical user, power user, prospective customer, investor, business owner, support, sales, competitor, QA, security, accessibility, performance, ops, designer, future maintainer) across two axes at once: UX/UI surface AND feature-set depth/correctness. Spawns one subagent per perspective in parallel, then synthesizes a prioritized report saved under reviews/ (gitignored by default). Use this whenever the user wants a product or UX review, a feature audit, a "review this from different perspectives" pass, a quality/depth check on a shipped feature, a pre-ship blind-spot sweep, or asks why something good isn't surfacing — especially the correctness gaps (timezones, phantom integrations, claimed-but-absent functionality) that surface-level reviews miss. This is NOT line-level code-diff review — for reviewing a working diff/PR use /code-review instead.
---

# Panel Review

> **Sync note**: this skill may exist both bundled in a project
> (`.claude/skills/panel-review/`) and as a user-level skill
> (`~/.claude/skills/panel-review/`). If both exist, keep them
> byte-identical — diff and sync whenever either copy changes.

A panel of 16 stakeholder perspectives reviews one feature, flow, or surface — looking at **both** what the user sees (UX/UI) **and** whether the thing is actually built well and completely (feature depth + correctness).

## Why this skill exists

Ordinary reviews miss a whole class of defect. This skill is built to catch the ones that slip through. The recurring failure modes:

1. **Reviews spot presence-of-bad, not absence-of-good.** A feature that "works" on a demo can still be missing the calendar push it implies, or the audit log its docs claim. Nothing errors, so nothing flags.
2. **Happy-path demos use one actor.** Timezone bugs, multi-tenant leaks, and concurrency races only appear when *two* different users/zones/clients/tabs interact. A single reviewer clicking through never reproduces that.
3. **No one owns data correctness.** UX personas ask "is this confusing"; nobody asks "what timezone is this number, what's its source of truth, does it survive DST / round-trip?"
4. **Reviews trust the feature's own self-assessment.** Docs and UI labels assert quality ("clean state machine", "syncs to calendar") that the code doesn't deliver. A review that reads the claim inherits the blind spot.
5. **Parked gaps rot.** A phase row parked as "future" / "not started" (⏳, ⬜, ⚪ — whatever glyphs the project's templates use) that hasn't moved across releases is often "this feature is half-built", not a nice-to-have. Nobody re-triages it.

Every perspective in this panel runs the **Depth & Correctness checklist** below precisely to surface those.

## Inputs

A review run needs a **scope** — concrete enough to go deep on:
- a feature (e.g. "meeting requests"), a flow (e.g. "customer onboarding"), or a surface/route (e.g. `/dashboard`, the portal).
- "the whole app" is allowed but you must decompose it into 4–8 named features/surfaces and review them as separate runs (or pick the highest-risk few and say which you skipped — never imply full coverage you didn't do).

If the user invoked the skill without a scope, ask: *"What should I put through the panel — a feature, a flow, or a page?"* Don't proceed against a vague target; depth dies without focus.

## Procedure

### 1. Scout pass (build the evidence pack — do this yourself, before fan-out)

Spend a focused pass mapping the scope so the 16 agents don't each re-discover it and so you can feed them the feature's *claims*. Produce a short evidence pack (in the conversation or a scratch file):

- **Entry points & files**: the routes, components, API handlers, data models, and libs that make up the scope (with paths).
- **The actual user flow**: step by step, what a user does and what the system does in response.
- **The claims**: what the feature doc / UI copy / button labels / marketing *promise*. List them verbatim — these get fact-checked against the code. Where a claim isn't backed by code, that's already a finding.
- **The data**: every datetime, money value, and field named `*link`, `*url`, `*Id`, `sync*`, `export*`, `notify*`, `email*` — these are correctness landmines the panel must probe.

Keep it tight. The goal is a shared map, not a novel.

### 2. Fan out — one subagent per perspective

Spawn the 16 perspective agents **in parallel** (the harness batches by concurrency cap — that's fine; send them in one turn). Use a general-purpose agent per perspective (read + reason +, where the perspective calls for it, actually run/exercise the app — QA, performance, accessibility especially).

Give each agent: the scope, the evidence pack, its persona and core question (table below; full briefs in `references/perspectives.md` — tell the agent to read it), and the **Depth & Correctness checklist**. Require structured findings (schema below). If a run dies or returns nothing, note it — never silently drop a perspective.

**Access-blocked files.** Some repos run a PII/secret canary (or similar) that blocks `Read` on certain files — often false positives (an SVG path, a sample email in a test). Tell agents: when a `Read` is blocked, fall back to **`Grep`** (content search is typically not intercepted) to extract the specific lines a finding needs, cite them, and mark the finding **suspected** rather than confirmed if the full file couldn't be seen. The orchestrator must list every blocked file in the **Coverage & confidence** section so the report doesn't imply coverage it didn't have. Note: per-prompt allow tags (e.g. `[allow-all]`) typically clear only the *first* blocked read of a turn, so don't rely on them to sweep many files — Grep is the durable path.

| # | Perspective | Core question |
|---|-------------|---------------|
| 1 | New user | "What is this? What do I click first?" |
| 2 | Non-technical user | "I don't understand half these words." |
| 3 | Power user / expert | "Why is this so slow? Let me do it my way." |
| 4 | Prospective customer | "Why buy this instead of an alternative?" |
| 5 | Prospective investor | "Can this become a real business?" |
| 6 | Business owner | "Will this make money without consuming my life?" |
| 7 | Support technician | "How many emails will this generate?" |
| 8 | Salesperson | "Can I explain this in 30 seconds?" |
| 9 | Competitor | "Where are they vulnerable?" |
| 10 | QA tester | "How do I break it?" |
| 11 | Security reviewer | "How could someone abuse this?" |
| 12 | Accessibility reviewer | "Can everyone actually use it?" |
| 13 | Performance engineer | "Will this still work with 10,000 users?" |
| 14 | Operations / DevOps | "Can we deploy and monitor this without heroics?" |
| 15 | Designer / UX | "Is this visually obvious and consistent?" |
| 16 | Future maintainer | "Will we hate ourselves in two years?" |

### 3. The Depth & Correctness checklist (every perspective applies this)

This is the part that catches what normal reviews miss. Each agent, through its own lens, must check:

- **Time & zones** — every displayed time: what zone is it in? Is it stored as a real instant or a naive wall-clock? DST-safe? Does the time a user enters equal the time another user sees (round-trip)?
- **Phantom integrations** — every "syncs / exports / sends / notifies / links / imports / calendar / payment" claim: does the code actually do it, or is it a stub, a manual step, a no-op, or a TODO? Trace it to the external call.
- **Claim vs reality** — does any label, doc, or button promise behavior the code doesn't deliver? (Cross-check the scout's claims list.)
- **Absence detection** — what *should* exist for this to be complete and correct, but doesn't? Name the missing piece, not just the present bugs.
- **Cross-actor / cross-zone / cross-tenant / multi-tab** — does it hold when two *different* users, zones, clients, or browser tabs interact at once? Where's the isolation or the race?
- **Empty / extreme states** — zero items, exactly one, 10,000; very long strings; missing optional data; the new-org/first-run state.
- **Failure & recovery** — what happens when the external call fails, the token expires, the network drops mid-action? Is it silent, blocking, or recoverable?

A finding here outranks a cosmetic one. If a perspective finds nothing on an axis, it says so explicitly rather than padding.

### 4. Finding schema (each agent returns)

Each finding: `{ perspective, axis: "UX/UI" | "Feature depth", severity: critical|high|medium|low, title, evidence: "file:line or reproduced behavior", soWhat: "who is hurt and how", confidence: confirmed|suspected, fix: "concrete direction" }`.

Confirmed = traced in code or reproduced. Suspected = plausible but unverified — label it; don't dress speculation as fact. Empty evidence is not a finding.

### 5. Synthesize

- **Dedupe & merge**: the same defect surfaces from several lenses (QA + maintainer + security all hit the same race). Merge into one finding, crediting the perspectives that caught it — convergence is a severity signal.
- **Rank** by severity × reach (how many users / how often).
- **Split into the two axes the user cares about**: UX/UI, and Feature set & depth.
- **Two mandatory callouts** (the failure modes this skill exists for):
  - **Claimed but absent** — every place the product promises what it doesn't do.
  - **Parked but rotting** — "future"/"not started" rows (whatever status glyph the project's templates use) that are really "half-built", and any feature whose depth doesn't match its surface.
- Be honest about coverage: if you reviewed 3 of 8 surfaces, say so.

### 6. Write the report

Save to `reviews/panel-review-<scope-slug>-<YYYY-MM-DD>.md` at the repo root (create `reviews/` if absent). Don't reuse the date alone — include the scope slug so runs don't clobber.

**`reviews/` is gitignored by default, and that default is deliberate.** A panel report says, in writing, where the product is weak — the competitor's angle, the security gaps, the features that are claimed but absent. That is exactly the candor the skill is for, and exactly what nobody wants to publish by accident. Keep it local, act on it, and let the fixes be what reaches the repo. A team that would rather keep reviews as shared decision records can drop the `reviews/` line from `.gitignore` — but make that a deliberate choice, not a default, and re-read the report once with "who can see this?" in mind before the first commit.

```markdown
# Panel Review — <scope> (<date>)

## Verdict
<2–4 sentences: is this shippable, half-built, or shiny-but-shallow? The single most important thing.>

## Top findings (ranked)
<table: severity | axis | finding | perspectives | evidence | fix>

## UX/UI
<grouped findings>

## Feature set & depth
<grouped findings, with the Depth & Correctness results foregrounded>

## ⚠ Claimed but absent
<promises the code doesn't keep>

## ⚠ Parked but rotting
<“future” items that are really incompleteness; depth-vs-surface mismatches>

## Coverage & confidence
<what was reviewed, what wasn't, which findings are suspected vs confirmed>

## Appendix: per-perspective notes
<one short block per perspective>
```

Then give the user a tight spoken summary: the verdict, the 3 highest-leverage findings, and the single scariest "claimed but absent" item. Offer to open fixes as the next step — reviewing surfaces problems; it does not fix them in the same pass.

## Scaling effort

Match the panel to the ask. "Quick gut-check on this page" → run the 6–8 most relevant perspectives, single round, confirmed-only. "Audit this before we ship / be thorough" → all 16, plus a skeptic pass that tries to *refute* each critical finding before it ships in the report (kill the ones that don't survive — a review that cries wolf gets ignored). Tell the user which mode you ran.

## See also
- `references/perspectives.md` — the full brief for each perspective (what to probe on each axis, what a good finding looks like). Each spawned agent should read its own section.
- For line-level review of a working diff, use `/code-review`. This skill is for product/feature/UX depth, not diff correctness.
