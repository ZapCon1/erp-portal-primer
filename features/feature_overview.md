# Feature Overview

The living index of every feature in this project. One row per feature; each
non-trivial one gets its own `features/<name>.md` plan doc (from
`_TEMPLATE.md`). Keep this table current — it's the first place to look
before starting new work, to avoid overlapping an existing plan.

See `docs/FEATURE_CATALOG.md` for the full menu of features an ERP-with-portal
typically grows, with surface tags and sequencing advice. This file tracks
what *you* have actually built or planned.

## Conventions

**Maturity:**
- 🟢 **Mature** — built, tested, in active use
- 🟡 **Active** — recently shipped or in progress, still gaining polish
- 🟠 **Scaffolded** — schema/API exists, UI minimal or missing
- ⚪ **Planned** — on the roadmap, nothing built yet; create the plan doc via `/perp-feature` before building (the seed rows below ship without one)

**Surfaces:** 🛠 internal · 👤 portal · 🌐 public · 📧 email channel (see `docs/FEATURE_CATALOG.md` legend)

---

## Features

| Feature | Maturity | Surfaces | Plan doc | Notes |
|---|---|---|---|---|
| Clients & contacts | ⚪ Planned | 🛠 👤 | — | Tenancy root. Start here. |
| Auth (two realms) | ⚪ Planned | 🛠 👤 | — | Staff + customer portal login. |
| Settings | ⚪ Planned | 🛠 | — | CompanySettings page, seeded from the /perp-scope answers. Ships with the shell. |
| App shell & staff dashboard | ⚪ Planned | 🛠 | — | Side nav + staff home; first visible win, right after auth. |
| Projects, phases & tasks | ⚪ Planned | 🛠 👤 | — | The work spine. |
| Time tracking | ⚪ Planned | 🛠 | — | Log hours against tasks; billable flag. **Hours variant** — a per-part shop swaps this for shipments, a fixed-price shop for milestone sign-off. |
| Time approval | ⚪ Planned | 🛠 | — | The gate that decides what's billable. **Every billing model needs this row** — only the gate changes (hours approved / qty shipped + accepted / milestone signed off). |
| Invoicing | ⚪ Planned | 🛠 👤 | — | Generate from whatever your gate approved; includes `dueDate` + the daily overdue flip (Tier-0 twin row). Taking deposits? The drawdown rule lands here (DOMAIN_MODEL § Billing-model variants). |
| Audit log | ⚪ Planned | 🛠 | — | Wire in from day one. |

<!-- These seed rows mirror the Tier-0 table in docs/FEATURE_CATALOG.md
one-to-one — keep the two lists row-consistent (eat the parity dog food).
The seeds are DRAWN in the hours variant because a table has to pick one
vocabulary — that is not a recommendation. Milestone and per-part shops
swap the Time tracking/approval rows per DOMAIN_MODEL § Billing-model
variants — /perp-scope's doc-review pass proposes this from your billing
answer, and records your chosen first slice here. Add rows as you
plan/build; delete seed rows once they have real maturity and their own
plan docs, or fill in the Plan doc column as you create them. -->

## Recommended next plan docs

<As the project grows, keep a short prioritized list here of the features
most worth planning next — combining "actively in motion" with "would deliver
real value with a focused plan." See docs/FEATURE_CATALOG.md § Sequencing.>
