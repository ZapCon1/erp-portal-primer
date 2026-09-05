# Domain Model — ERP Customer Portal

This is the **conceptual model** for a professional-services / job-shop ERP
that exposes a customer portal. It is deliberately de-branded and
stack-agnostic: entity names, relationships, and the invariants that make
the system correct. Treat it as a menu, not a mandate — prune to what your
business actually needs, then translate into your ORM schema.

**What's prunable and what isn't.** Prunable: entities tagged
*(optional)*, whole groups tagged *(optional — <who needs it>)*, and
feature tiers you don't need yet. **Never prunable**, however small the
shop: the Invariants section, CreditNote and sent-invoice immutability,
gap-free invoice numbering, the audit predicate, and tenant isolation —
these are what keep the books trustworthy. "We're tiny, we'll just edit
the invoice" is how append-only books stop being append-only.

**Map of this document (doubles as the prune map):**

| Section | Keep or prune? |
|---|---|
| The spine / Core entities | Keep — prune only individual *(optional)* entities |
| — Purchasing & routing *(optional — manufacturing)* | Prune if you never subcontract work out (`/perp-scope` asks) |
| — Part/PartRevision/FileDerivative *(optional — part viewing)* | Prune if customers never exchange CAD |
| Billing-model variants | Read once, keep your variant's paragraph |
| Scheduling | Keep the dates rung; the rest activates with routing |
| Invariants | **Never prune** |
| Scale notes | Keep |
| What to build first | Keep — your build order |

The golden rule that shapes everything: **two surfaces, one source of
truth.** Staff and customers see the same data through different doors; the
numbers must match. See `CLAUDE.md` § Parity.

---

## The spine: from lead to paid

```
Client ──< Project ──< Phase ──< Task ──< TimeEntry
   │           │          │         └──< Expense
   │           ├──< Estimate ──< ScopeItem
   │           └──< Invoice  ──< InvoiceLineItem ──< Payment
   ├──< ClientPoc (portal users)
   └──< (hours pool / retainer, optional)
```

A customer's work flows left to right:
**Estimate** (a quote) → accepted → becomes an active **Project** →
broken into **Phases** and **Tasks** → staff log **Time** and **Expenses**
against them → approved time rolls into an **Invoice** → customer pays.

---

## Core entities

### Tenancy & people

- **Client** — the customer company. **This is the tenancy boundary.** Every
  portal query filters by `clientId`. Carries: name, address, a short
  **client code**, billing/rate configuration, and any regulated-data flags.
- **ClientPoc** (point of contact) — a person at the client who logs into the
  portal. Has a **portal role** that maps to a permission level
  (e.g. primary→admin, accounting→billing-only, technical→project-only).
  One Client has many POCs.
- **User** (internal/staff) — an employee. Has a **staff role**
  (admin / manager / bookkeeper / member) plus optional granular permission
  overrides. Separate auth realm from POCs entirely.
- **CompanySettings** — one row, app-wide: the business's display name,
  address/contact block as it appears on documents, logo path, the
  **canonical timezone value** (the day-boundary *policy* is invariant 9
  and schema-shaped; the zone string itself lives here), default payment
  terms (net N → derives `Invoice.dueDate`), invoice-number prefix (the
  gap-free counter is its own locked row — never here), and the hour
  rounding increment. **Seeded from the `/perp-scope` answers**
  (SCOPE.md/BRAND.md) so the interview's facts become runtime data, not
  hardcoded strings. Boundary rule: things whose change means a
  migration (billing atom, datetime policy) are NOT settings; settings
  are values an owner may edit in the app — and edits to money-adjacent
  ones (terms, rounding) are audit-logged like any financial mutation
  (invariant 7).

### Work

- **Project** — the central unit of work for a Client. Has a **lifecycle
  state** (presale/quote → active → closing → complete → archived), a
  **code** (`{ClientCode}{YY}{##}`), a budget, and a computed **health**
  signal. May start as `presale` (just a quote) and convert to active on
  estimate acceptance.
- **Phase** — a stage of a project. Optionally typed (e.g. *off-site* design
  vs *on-site* install) — the type often drives scheduling and billing rules.
  Has a lead, dates, and its own budget slice.
- **Task** — a unit of assignable work inside a phase. Accrues time entries
  and may have subtasks/dependencies.
- **Expense** — a cost charged to a project/phase (materials, hardware,
  pass-through), billable or not.

### Estimation & contracts

- **Estimate** — a versioned quote for a project. Has a **status state
  machine** (draft → sent → accepted / declined / negotiating). Contains
  **ScopeItems** (line items with hours/price) and hard expenses.
  **Acceptance is the pivotal event**: it converts presale→active, allocates
  budget/hours, and — if your flow includes it — generates the first invoice.
  Decide once whether it does; either way the fan-out is atomic (invariant 6).
- **ScopeItem** — a line on an estimate (description, quantity, hours, rate).
  If you collect **deposits/down-payments**, the Estimate carries a
  `depositPercent`/`depositAmount` that feeds the acceptance fan-out —
  otherwise "generates the first invoice" has no defined amount.
- **Change order** — the near-universal job-shop reality: scope grows after
  acceptance. Model it as a **new estimate version against an active
  project** whose own acceptance increments budget/hours atomically
  (invariant 6 applies) and is audited — never as edits to the accepted
  estimate or hand-raised budget numbers.
- **Contract** *(optional)* — a signable document (PDF with placed signature
  fields), customer-signs then staff counter-signs.

### Time & money

- **TimeEntry** — hours logged by a staff user against a task/project. Carries
  `isBillable` and an **approval status** (draft → submitted → approved /
  rejected). **Only approved + billable entries count toward billed totals
  and budget burn** — this predicate must be applied identically everywhere.
  Decide your **minimum billing increment and rounding rule** (e.g. round
  up to 0.25h — at entry or at invoice, not both): every real shop bills in
  increments, and raw-minute billing that disagrees with the owner's paper
  invoices is a trust bug a customer finds first. One rule, defined once.
- **Timer** *(optional)* — an active clock-in record; on stop it produces a
  TimeEntry.
- **Invoice** — a bill to a Client, generated from approved time + expenses.
  Has a **status state machine** (draft → sent → paid / overdue / void),
  line items, and payments. Outstanding balance = total − sum(payments):
  **one helper, used everywhere.** To be legally an invoice in most
  jurisdictions it also needs: an **invoice number** (sequential, gap-free,
  immutable once sent — voided invoices keep their number), an **issue
  date**, a **due date / payment terms** (the due date is what derives
  `overdue` — nothing can flip sent→overdue without one), and **tax**
  (per-line rate + a rounding rule defined once — per line item vs per
  total is a legally material choice; <TODO: your jurisdiction's rules>).
- **InvoiceLineItem** / **Payment** — the breakdown and the receipts.
  **Payment has its own state machine**: pending → settled / failed /
  reversed. "Paid" is provisional until settlement — an ACH return or
  chargeback reverses a payment *days after* the webhook fired, so derive
  the invoice's displayed status from **settled** payments via the one
  shared balance helper, and support a **partially-paid** presentation
  (the balance formula already implies partial payments exist).
- **CreditNote** — the correction mechanism. Sent invoices are immutable;
  refunds, write-offs, discounts-after-the-fact, and billing-error
  corrections are issued as credit notes against the invoice, never as
  edits. Keeps the books append-only and the audit trail honest.
- **Hours pool / Retainer** *(optional)* — pre-purchased hour blocks at the
  Client level, often with an expiration and low-balance alerts. If you
  bill straight time-and-materials, skip this entirely on day one.
  If you DO keep it, three rules are non-negotiable, because expiring
  prepaid hours is the highest-emotion dispute in retainer billing:
  (1) **expiry disposition** — unused expired hours are forfeited, rolled,
  or refunded; pick one, put it in the agreement, encode it;
  (2) **draw-down order** across overlapping blocks (typically FIFO by
  expiry), defined once;
  (3) **portal visibility** — the customer always sees balance, expiry
  date, and per-entry drill-down. Hours must never just vanish one morning.
  Add `retainer-balance` to your `/perp-review-parity` concept list.

### Purchasing & routing *(optional — manufacturing)*

Job shops send work OUT as well as billing it: anodizing, plating, heat
treat, outside machining. This group is the vendor-facing mirror of the
customer spine — prune it if you never subcontract.

- **Supplier** — the vendor-side counterpart of Client: name, contact,
  and their own folder/thread of documents. Not a tenant — suppliers
  never log in (if one ever needs a portal, they become a scoped realm
  like customers, not a backdoor).
- **VendorPO** — a purchase order sent to a Supplier. Has its own
  **status state machine** (draft → sent → partially-received →
  received / cancelled) and its own **numbering sequence**
  (e.g. `PO-{YYYY}-{NNN}`), separate from invoice numbers but generated
  the same way as the Invoice entity's gap-free numbering rule above: a
  locked counter row, never `MAX()+1` — the concurrent-creation race is
  identical.
- **VendorPOLineItem** — pairs a **part + outsourced process + quantity**
  (+ optional unit cost, expected date). Received quantity is tracked
  per line; "partially-received" falls out of qty-received < qty-ordered
  — the mirror image of the parts-billing predicate in § Billing-model
  variants.
- **WorkCenter (equipment)** — the machines and stations work flows
  through: name ("Haas VF-2", "deburr bench", "anodize — outside"),
  active flag, and later whatever capacity facts scheduling earns.
  Operations run *on* a work center; the **dispatch list groups by it**
  (§ Scheduling). For a machine shop this is how the owner thinks about
  their floor — `/perp-feature`'s interview enumerates the actual
  machines when scheduling/routing gets planned.
- **Operation / Routing** — the ordered steps a job travels through:
  sequence number, name ("saw", "CNC mill", "deburr", "anodize — send
  out"), a work center or an `outsourced` link to a VendorPOLineItem,
  and a status (pending → in-progress → done). A Phase can carry a
  routing; the **traveler** — the paper packet that follows the parts
  across the shop floor — is just the routing plus the part drawings,
  printed (see Document packets in FEATURE_CATALOG). Start with
  routing as *display + status tracking*; scheduling/capacity is a
  much later tier.
- **PreCannedNote** *(optional)* — reusable text blocks (terms,
  handling instructions) attached to outgoing documents (estimates,
  invoices, vendor POs) in a chosen order. One table, referenced
  everywhere a document renders.

Outside-processing costs feed the project like any other **Expense**
(billable pass-through or absorbed) — don't invent a second cost path.

### Communication & records

- **AuditLog** — append-only trail of create/update/delete/login/send/accept
  actions. **Every money/hours mutation and every cross-tenant-sensitive
  action writes one.** Non-negotiable for an ERP.
- **Notification** — in-app alerts (time approvals, estimate responses,
  invoice events). Mirrored to both surfaces.
- **Chat / Messages** *(optional)* — per-project or per-client threads shared
  between staff and customer.
- **File / Document** *(optional)* — documents exchanged with the customer;
  the portal shows a **filtered subset** the client is allowed to see.
  Carries `kind` ('model' | 'drawing' | 'document'), `contentHash`, and
  `exportControlled` — the ITAR/EAR flag gates the original **and every
  derivative** identically, and each view/download of a flagged file is
  audit-logged (`secure_coding.md` § 17).
- **Part → PartRevision → FileAttachment** *(optional — manufacturing)* —
  part number, revision letter/date, and the files attached to each
  revision, so "the model for rev C" is a query, not a filename
  convention. See `docs/STACK.md` § Part viewing.
- **FileDerivative** *(optional — part viewing)* — (fileId, type
  'gltf' | 'thumbnail', storageKey, status pending/processing/ready/
  failed, error, sourceContentHash). A derivative is a cached rollup in
  the invariant-11 sense: regenerated when `sourceContentHash` drifts,
  and the portal renders status ≠ ready as a first-class "preview
  pending / conversion failed" state per PORTAL_UX.md.


---

## Billing-model variants — swapping the billing atom

The entities above are drawn with the **hours** spine (TimeEntry as the
billing input) because a doc has to pick one vocabulary to be concrete
in — **that is a drafting choice, not a recommendation, and hours is not
the most common answer**. Plenty of shops never bill an hour in their
lives. If your business bills differently, you don't discard the model —
you **swap the billing atom and keep the predicate discipline**. Every
variant has: one atomic unit of billable value, one gating predicate that
decides when a unit becomes invoiceable, and one everywhere-identical
formula for "how much is left". The invariants below apply unchanged to
all three; only the vocabulary moves.

| | Parts (contract manufacturing) | Milestones (fixed-price) | Hours (time & materials) |
|---|---|---|---|
| Billing atom | shipped-and-accepted quantity | signed-off milestone | approved TimeEntry |
| Gating predicate | qty shipped ∧ accepted, minus qty already invoiced | milestone accepted by customer | `approved && isBillable` |
| "Remaining" number | qty on order − qty shipped | milestones / % complete | hours-remaining |
| Portal shows | job status, shipments, drawings | milestone status + schedule | hours used vs budget |

**Deposits cut across all three** — money taken before the atom is
earned. A deposit is not a billing model and not a retainer (a retainer
prepays *hours*; a deposit prepays *money* against whatever your atom
is). It adds one rule, not a variant: every invoice after the deposit
credits what's already been paid, computed by **one drawdown helper**
used on both surfaces. That is invariant 10 — nothing billed twice —
applied to prepayment. Get it wrong and the customer's balance and
yours disagree, which is the single most trust-destroying number in the
system.

**Milestones** (design studios, fixed-bid consultancies): a milestone is a
**Phase with a customer sign-off event** — it already has dates, a lead,
and a budget slice; sign-off is the state transition that triggers its
invoice. TimeEntry demotes to optional internal cost tracking (or prune
it, with Timer, retainers, and the rounding rule). Deposits and change
orders matter *more* here — scope changes on a fixed price are where the
disputes live. The predicate "only approved+billable hours count" becomes
"only signed-off milestones are invoiceable" — same rule, one place,
applied identically on both surfaces.

**Parts** (machine shops, contract manufacturers): Estimate is the quote
against an RFQ — **ScopeItem already carries description / quantity /
rate**; it becomes part number + revision + qty + unit price. Project is
the job/PO; Phase is an operation or lot/release. Add one entity —
**Shipment/Delivery** — and the predicate becomes: *invoiceable qty per
line = shipped-and-accepted qty − already-invoiced qty* (invariant 10,
nothing billed twice, is exactly this rule under partial shipments).
TimeEntry survives only for shop-floor labor costing; Expense already
covers materials. Two sections get **more** load-bearing, not less: the
regulated-data question in CLAUDE.md § What It Is (ITAR/EAR gating of
portal file visibility — the files are drawings) and `secure_coding.md`
§ 17 (file exchange).

**When adopting a variant**: answer CLAUDE.md's Billing model Key Concept
`<TODO>` with the variant name, prune the hours machinery you don't need
(the never-prune list above still holds), and rename the
`/perp-review-parity` concepts to your vocabulary — `milestones-remaining`
or `qty-shipped-vs-invoiced` instead of `hours-remaining`. Once your
schema exists, it is authoritative over this doc; update the doc in the
same commit.

---

## Scheduling — build the dates, defer the board

"When will my job be done?" is the most common customer question, and
full-blown scheduling is the most common ERP tarpit. The ladder, in
order:

- **Now (schema-shaped, one of the three Day-1 decisions)**: a
  `promisedDate` / `dueDate` on Project (optionally per
  Phase/Operation). One column — but it anchors the portal's most-asked
  number, overdue awareness (invariant 9 governs the day boundary), and
  every rung below. Deciding it late means migrating live data.
- **Next (a query, not an engine)**: the **dispatch list** — per work
  center, the operations whose predecessors are done, ordered by due
  date. Applies **if you kept the Operation/Routing group** (§
  Purchasing & routing); services shops get "current step" from Phase
  status instead. It needs no new entities — but note it is the kit's
  one hot **cross-tenant staff query**, shaped
  `(workCenterId, status, dueDate)`: index for it (or denormalize
  `dueDate` onto Operation) from the first migration — see Scale notes.
- **Portal**: promised date + current routing step ("in anodizing, due
  back Thursday"), computed by the **same shared helper** staff see —
  this is a parity surface like any other number.
- **Deferred deliberately**: capacity/finite scheduling, drag-drop
  planning boards, PTO-aware auto-assignment. That is APS — a product
  category, not a feature. Revisit only when the dispatch list
  demonstrably isn't enough; most shops at this ceiling never get there.

---

## Invariants — the rules that keep it correct

These are the things that, if violated, produce silent data corruption or
trust-destroying bugs. Encode them as tests.

1. **Tenant isolation.** No portal read or write ever touches a row whose
   `clientId` differs from the session's client. Cross-tenant access returns
   **404**, never 403 (don't confirm the row exists). There is no ORM-level
   safety net — it is enforced by the auth wrapper and by `/perp-review-parity`.

2. **One formula per number.** Budget %, hours-remaining, invoice balance,
   project health — each is computed by exactly one shared helper. The
   internal app and the portal both call it. Two formulas = a parity bug.

3. **Approved + billable only.** Whatever predicate decides which time/expenses
   count toward a customer's bill or budget burn, it is defined once and
   applied identically in every rollup (project page, client page, invoice
   generation, reports).

4. **MONEY-1 — money is exact.** Store as **integer minor units** in an integer column. A decimal type is acceptable only for fractional *rates*, never for stored amounts (`docs/STACK.md` § Pinned conventions is canonical for the column type). Never
   float. Rounding rules (if any) are defined once.

5. **State machines, not booleans.** Estimate/invoice/project/phase statuses
   are enums with explicit allowed transitions. Guard the transitions; don't
   let arbitrary status writes through.

6. **Acceptance fans out atomically.** Whichever effects your acceptance
   flow includes — presale→active, budget allocation, and the first invoice
   *if your flow generates one* — commit in one transaction: all happen or
   none does. Decide up front whether acceptance generates an invoice and
   make it unconditional either way; "sometimes" is not a state a test can
   pin down.

7. **Every money/hours mutation and every cross-tenant-sensitive action is
   audited.** Who, what, before→after, when. This is the canonical audit
   predicate — `CLAUDE.md` and `secure_coding.md` § 7 restate it and defer
   to this line.

8. **Two auth realms stay separate.** A staff session can never authenticate
   a portal request and vice-versa. Different cookies, different validation.

9. **Datetimes are UTC instants; day boundaries have one owner.** Store all
   timestamps as UTC. Every day-boundary rule — invoice overdue,
   promised-date lateness ("this job slips tomorrow"), "hours
   this week", budget-threshold alerts, digest windows — evaluates in ONE
   declared timezone (company-wide or per-client; pick and document). A
   time a user enters must round-trip to the same instant another user
   sees. Note: parity review cannot catch zone bugs — both surfaces can
   share one helper and still show a Tokyo customer "overdue" while staff
   see "sent" — so this is a schema-level decision, not a display detail.

10. **Nothing is billed twice.** Every billable TimeEntry/Expense records
    which invoice line consumed it (`invoiceLineItemId` or `billedAt`), set
    in the same transaction as invoice generation. Generation selects only
    approved + billable + **unbilled** inputs; once invoiced, an entry is
    immutable — corrections go through a credit/rebill, never an edit.

11. **A stored number is a second source of truth — treat it like one.**
    Invariant 2 pushes rollups (budget burn, balance, health) toward
    compute-on-read; at tens of thousands of time entries that becomes a
    latency problem, and the tempting fix — caching or storing the number —
    recreates the exact parity bug this document exists to prevent. A
    materialized/cached rollup is permitted only when: (a) it is **written
    by the same shared helper** that computes the live value, (b) it is
    recomputed **in the same transaction** as any mutation of its inputs
    (or explicitly flagged eventually-consistent with a stated staleness
    bound), and (c) a **parity test asserts stored == recomputed** for a
    fixture. Background jobs that recompute UI numbers are parity surfaces
    — `/perp-review-parity`'s matrix must include the stored column.

### Scale notes — cheap now, expensive later

- **Composite indexes**: tenancy makes every portal/tenant query shaped
  `WHERE clientId = ? AND <status/date filter>` — give every table carrying
  `clientId` a composite index `(clientId, <primary filter>)` from the
  first migration. The one hot exception is the **dispatch list**
  (§ Scheduling), a cross-tenant staff query: index Operation
  `(workCenterId, status, dueDate)` — or denormalize `dueDate` onto
  Operation — from the first migration too.
- **Pagination**: list endpoints returning unbounded collections (time
  entries, audit log, portal invoices) take a limit from day one — cursor
  preferred. A customer with three years of history is not an edge case;
  it's a customer.
- **AuditLog growth**: it is the hottest, largest table by design, and
  login-failure events let the internet grow it. Write financial-mutation
  entries in the same transaction as the mutation (fail closed); auth-noise
  events (login failure, 403) may be async. Index `(entityType, entityId)`
  for entity-history lookups, `(clientId, createdAt)` for tenant-scoped
  timelines (portal audit trail, per-client export — the composite-index
  rule above applies to this table too), and `(createdAt)` for retention
  sweeps; state a retention/archival stance
  (<TODO: e.g. partition or archive beyond N years — also your compliance
  retention floor>).
- **Whole-history aggregation** (reports, exports, digests) runs as a
  background job, never in a request handler.

---

## What to build first (don't build the whole menu)

The audience has little to no software experience. The build order is
designed around one principle: **the owner interacts with their app on
day one — the goal is for it to feel like magic** — without ever
compromising the security spine.

### Phase One — the core skeleton, in one pass (`/perp-build-core`)

Straight after `/perp-scope`, build the ENTIRE core skeleton before any
plumbing conversation:

- **Both shells**: staff side nav + portal frame, both dashboards (the
  staff lead tile is the interview's pain point; the universal staples
  — jobs in motion, unapproved time, overdue invoices — around it), and
  the Settings page pre-filled from the interview (name, logo,
  timezone, terms).
- **The spine's screens, in the shop's vocabulary, with working
  create/edit** — clients, and jobs/projects/quotes/parts as SCOPE.md
  names them: list + detail views with **every list's obvious "+ New"
  button functional** (basic CRUD is usability, not business logic —
  the owner adds a *real* customer on day one). **The pain-point
  feature is a first-class nav destination with its own page** — the
  dashboard's lead tile is its doorway, not its home (pain =
  scheduling → a Schedule page: jobs by promised date, even in
  skeleton form). Schema carries `promisedDate`/`dueDate` from this
  first migration (§ Scheduling). Money math, approvals, and
  generation stay in Phase Two.
- **Helper banners on every screen, both surfaces** — a dismissible
  one-liner per view: what this screen is, the one action to try, and
  where the skeleton ends ("invoices are view-only for now"). One
  shared component; it onboards the customer later, and on day one it
  teaches the owner the app they're building.
- **Portal faces of everything SCOPE.md says customers see**, rendered
  from the same shared helpers (invariant 2 — parity from birth).
- **Sample data, clearly labeled SAMPLE** — a fake client, a fake job,
  a fake quote in their vocabulary — so every screen is alive and
  clickable, never a wall of empty states. One command deletes it all.
- **Dev-mode sessions instead of login screens** — the rule below.
- Finish by **running the app and handing over the URL**: "click
  around — what should we make real first?" (one question, then
  listen).

**The dev-mode auth rule — what makes skipping login safe:** Phase One
ships no login UI, but the **real auth wrappers guard every route from
the first route** — dev mode only stubs the *session* behind them (one
fake staff user; one fake portal POC carrying a real `clientId`, so
tenant filtering is exercised by the very first portal query). A
permanent **"DEV MODE — no login"** banner shows on every page while
active. Real login (both realms) is a hard gate **before anyone but
the owner touches the app, and always before go-live** — cheap to add
precisely because the wrappers were always there. NEVER acceptable,
dev mode or not: a route without a wrapper, a portal query without a
tenant filter, or dev mode surviving into a deployed app.

### Phase Two — make it real, one ask at a time

Driven by what the owner asks for next; the value order is usually:

1. **The money flow for your billing variant** — hours shops: TimeEntry
   + approval; milestone shops: sign-off events; parts shops: Shipment
   + the invoiceable-qty predicate (§ Billing-model variants).
2. **Invoice generation** from the variant's approved inputs — with
   `dueDate` and the daily **overdue-status flip** (invariant 9's
   declared timezone). Billing correctly while receivables go invisible
   defeats the point.
3. **Audit log** — the helper lands with the first real money mutation,
   not after (invariant 7; Tier-0: "from day one, not later"). Clicking
   sample data needs no trail; the first real edit does.
4. **Real login, both realms** — at the gate above, at the latest.
5. Then payments, files, part viewing, purchasing — as scoped.

**There is no "portal step."** The portal is a *dimension* of every
slice, not a follow-up: as each feature lands, its portal face — scoped
by SCOPE.md § The portal — ships **in the same phase**. Build quoting?
The customer views (and maybe accepts) the quote in the same slice.
This is CLAUDE.md § Parity as a build cadence — an agent proposing "now
let's start the customer portal" as a separate project has misread the
plan.

Everything else in `FEATURE_CATALOG.md` — estimates, retainers, chat,
the dispatch list and planning boards, purchasing & routing/travelers,
CAD part viewing, contracts, reporting, SSO, partner programs — is an
enhancement layered on this spine. Add them when a real user is waiting
for them, each with its own `features/<name>.md` plan doc.
