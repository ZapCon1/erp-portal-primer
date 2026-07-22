# <Feature Name>

<!--
Copy this to features/<feature-name>.md when you commit to building a
feature. The point of this doc is to think before coding and to leave a
durable record of decisions. Keep the Progress table honest — one row per
shipped phase, with the commit hash.
-->

## Summary

<One paragraph: what this feature is, who it's for, and why it's worth
building now. If it doesn't deliver value to a real user soon, reconsider.>

**Friction removed**: <one sentence — the concrete friction this kills,
and whose: internal (how work moves through the shop) or external (how
customers deal with you). "Customers stop calling for status." "No more
re-typing quotes into invoices." A feature that can't name its friction
is scope creep — the whole point of a custom ERP is friction removal.>

## Surfaces

<Which surfaces does this touch? 🛠 internal · 👤 portal · 🌐 public ·
📧 email channel. If it touches more than one, the SAME numbers/behavior
must match across them — see CLAUDE.md § Parity. Note here how you'll keep
them in sync (shared helper, shared component). If it touches 👤 or 🌐,
`docs/PORTAL_UX.md` applies — note the empty/loading/error states and any
accessibility considerations here.>

## Domain model changes

<New entities or fields. Reference docs/DOMAIN_MODEL.md. Call out any new
state machine, any new money/hours computation (and where its single source
of truth will live), and any new field that must be tenant-scoped.>

## Invariants & edge cases

<What must always be true? What are the 0 / 1 / N cases? What happens on
concurrent edits, on a failed payment, on a cross-tenant access attempt?
List the cases you'll turn into tests.>

## Security & audit

<Auth wrappers used. Tenant-isolation considerations (portal queries filter
by clientId). What writes to the audit log. Sensitive fields to exclude from
responses. See secure_coding.md.>

## Plan (phases)

1. **Phase 1 — <name>**: <what lands>
2. **Phase 2 — <name>**: <what lands>
3. **Phase 3 — <name>**: <what lands>

<Each phase should be independently shippable and reviewable. Money and
multi-surface features: ship both surfaces in the same phase/commit.>

## Progress

| Phase | Status | Commit | Notes |
|---|---|---|---|
| 1 — <name> | ⬜ not started | — | |
| 2 — <name> | ⬜ not started | — | |
| 3 — <name> | ⬜ not started | — | |

<Status: ⬜ not started · 🟡 in progress · ✅ shipped. Update as you go.
Record the **merge/squash commit on the default branch** (or the PR
number), not the feature-branch commit — squash-merge and rebase orphan
branch hashes, and this table is supposed to be the durable record.>

## Open questions

<Anything undecided. Resolve before the phase that depends on it.>
