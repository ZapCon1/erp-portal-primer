# Feature Catalog — ERP Customer Portal

A menu of features a professional-services / job-shop ERP-with-portal tends
to grow, grouped by domain and tagged with the **surface(s)** they touch.
This is a planning aid, not a checklist — most businesses need maybe a third
of it. Pick a vertical slice, ship it end-to-end, then come back.

**Surfaces:** 🛠 internal staff app · 👤 customer portal · 🌐 public/marketing · 📧 email (outbound channel — not an interactive surface; parity rules don't apply to it) · **A→B** means the flow originates on surface A and lands on B (e.g. 👤→🛠 a portal request handled by staff)

For each feature you decide to build, create a `features/<name>.md` from
`features/_TEMPLATE.md` and track phases there.

---

## Tier 0 — the minimum viable ERP (build this first)

| Feature | Surfaces | What it is |
|---|---|---|
| **Clients & contacts** | 🛠 👤 | Client records + POCs with portal roles. The tenancy root. |
| **Auth (two realms)** | 🛠 👤 | Staff login (password/SSO) + customer portal login (magic-link/SSO). |
| **Settings** | 🛠 | One page, one `CompanySettings` row (DOMAIN_MODEL § Tenancy & people): company name/address/logo as they print on documents, canonical timezone, default payment terms, rounding increment. **Seeded from your `/perp-scope` answers** — the interview's facts become editable runtime data instead of hardcoded strings. Ships with the app shell; money-adjacent edits are audit-logged. |
| **App shell & staff dashboard** | 🛠 | The frame everything hangs on — side nav + the staff home ("what needs me today?"). **The lead tile is your pain point**: whatever answer `/perp-scope` recorded as the reason you wanted this system, if it's a trackable status/number, it goes top-left — the rest are the universal staples (jobs in motion, unapproved time, overdue invoices). **Build the shell right after auth**: it's the first thing anyone can see and click, the demo surface, and the momentum-keeper for a solo build. Tiles ship as honest empty states (PORTAL_UX required-states rule) and light up with real numbers as each slice lands — every number via the one shared helper (Parity applies the day a tile reaches the portal). |
| **Projects, phases & tasks** | 🛠 👤 | The work spine. Portal view is read-only. |
| **Time tracking** | 🛠 | Log hours against tasks; billable flag. |
| **Time approval** | 🛠 | Submit → approve/reject. Gate that decides what's billable. |
| **Invoicing** | 🛠 👤 | Generate invoices from approved time + expenses; customer views/downloads. **Includes `dueDate` + the daily overdue-status flip** (needs the declared timezone) — billing correctly while receivables go invisible defeats the point; the full reminder schedule stays in the later dunning row. |
| **Audit log** | 🛠 | Append-only trail. Wire it in from day one, not later. |

This is a coherent product on its own: quote work informally, run it, bill it,
let the customer see it.

---

## Client lifecycle

| Feature | Surfaces | Notes |
|---|---|---|
| Onboarding (invite flow) | 🌐→🛠 | Magic-link invite → customer self-onboards → provisions Client + POCs + folders. |
| Rate tiers / billing config | 🛠 | Per-client rates by service level. |
| Partner / referral program | 🛠 👤 🌐 | Attribution for inbound referrals. Skip unless you have a channel. |
| RFQ / customer requests | 👤→🛠 | Customers submit quote/scope/budget questions from the portal. |

## Project execution

| Feature | Surfaces | Notes |
|---|---|---|
| Promised dates & dispatch list | 🛠 👤 | The scheduling middle tier that answers "when will my job be done?": a `promisedDate` on every project (schema-shaped — decide it early), a per-work-center **dispatch list** (operations ready to run, ordered by due date — a query over routing statuses, not an engine), and the portal showing promised date + current step via the same shared helper staff use. Machine shops: the dispatch list groups by your **equipment** (WorkCenter — `/perp-feature`'s interview collects the machine list). `/perp-scope` proposes this proactively when a manufacturer says they promise dates. See DOMAIN_MODEL § Scheduling. |
| Scheduling / planning board | 🛠 | Capacity-aware drag-drop of phases across staff + PTO. **APS territory — deliberately deferred**: build promised dates + the dispatch list first, and revisit this only when that demonstrably isn't enough (DOMAIN_MODEL § Scheduling). |
| Project health scoring | 🛠 👤 | Computed signal (budget % + timeline + progress). One formula, both surfaces. |
| Closeout / sign-off checklists | 🛠 👤 | Customer signs off on completion. |
| Parts / sub-items | 🛠 | Track components within a project, each with its own files. |
| Project templates | 🛠 | Clone a standard project structure. |
| Recurring tasks | 🛠 | Scheduler for repeating work. |

## Estimation & contracts

| Feature | Surfaces | Notes |
|---|---|---|
| Estimates & scope | 🛠 👤 | Versioned quotes; accept/decline/negotiate; acceptance fans out (see DOMAIN_MODEL invariant 6). |
| Contracts & e-signatures | 🛠 👤 | Placed-field PDF signing, customer + counter-sign. |

## Time, billing & money

| Feature | Surfaces | Notes |
|---|---|---|
| Deposits & progress billing | 🛠 👤 | Money taken before the work is done: a deposit or % at estimate acceptance, or progress payments as the job runs. The deposit is an invoice like any other — what makes it its own feature is the **drawdown**: every later invoice must credit what's already been paid, in one formula, on both surfaces (DOMAIN_MODEL invariant 10 — nothing billed twice). Applies to every billing model; not a retainer (a retainer prepays *hours*, a deposit prepays *money*). |
| Retainers / hour blocks | 👤 🛠 | Pre-purchased hours pool with expiration + low-balance alerts. **Only if customers literally prepay hours** — if they prepay money against a fixed price, that's Deposits & progress billing instead. See DOMAIN_MODEL's three retainer rules before building. |
| Inventory / stock | 🛠 | On-hand quantities for raw material, consumables, or finished goods, with receipts in and issues out to jobs. **Only for shops that hold stock** — buying material per job is already covered by Expenses and vendor POs, and needs none of this. A known ERP tarpit: it drags in units of measure, locations, counts, valuation, and reconciliation, each of which is a second source of truth for a number. Never a first slice. Start at the smallest honest version — an on-hand quantity per material that job issues decrement — and only add valuation when someone needs it for costing. |
| Budget & hours alerts | 🛠 📧 | Threshold alerts (e.g. 50/75/90%) + expiry warnings. |
| Payment reminders / dunning | 🛠 📧 | Overdue-flip job (needs `Invoice.dueDate` + the declared timezone) + reminder schedule. Tier-0 invoicing without this means manual collections — chasing receivables is half of what an ERP earns its keep doing. **The minimum viable piece belongs with Tier-0**: `dueDate` + declared timezone + a daily overdue-status flip is one small job; the full reminder schedule can wait, invisible receivables can't. |
| Online payments | 👤 | Card/ACH via a payments provider; **webhook** marks invoices paid. |
| Purchasing / outside processing | 🛠 📧 | Vendor POs to suppliers (anodize, plate, heat treat, outside machining): line items pair a part + process + qty, per-year PO numbering (locked counter — same invariant as invoices), status draft → sent → partially-received → received, receiving tracked per line. Costs flow into the project as Expenses. See DOMAIN_MODEL § Purchasing & routing. |
| Job routing & travelers | 🛠 | Ordered operations per job (work center or outsourced via a vendor-PO line), each with a status — where every job physically is, at a glance. The **traveler** is the printed packet (routing + drawings) that follows parts across the floor. Start as display + status tracking; scheduling/capacity is a much later tier. |
| Document packets | 🛠 👤 | One merged PDF from a cover document plus per-part attachments — a vendor PO + each part's process spec, or a quote + drawings. Regenerate the cover on every print (no stale numbers); skip parts without attachments silently. |
| Pre-canned notes | 🛠 | Reusable text blocks (terms & conditions, handling instructions) attached to estimates, invoices, and vendor POs in a chosen order. One table, referenced by every document renderer. |
| Shipping labels | 🛠 | On-demand label PDFs per job/PO line (part, process, qty), with free-form quantity splitting (500 → 200/200/100). Generated, not stored. |
| Part viewing (CAD) | 👤 🛠 | Customers and staff view uploaded CAD models (STEP/IGES/STL) in the browser. On upload, a background job tessellates to a compressed GLB stored beside the original; the file page embeds a three.js viewer, lists show thumbnails, with explicit "preview pending" / "conversion failed — download original" states (PORTAL_UX.md). Tenant-scoped like every file; export-controlled files additionally gated by the ITAR flag with every view audit-logged. STL views out of the box; STEP/IGES activates when the OCCT worker is enabled. Architecture + provision-now hooks: `docs/STACK.md` § Part viewing. Deferred: measurement, assembly trees, PMI/GD&T, drawing markup, revision diff. |
| Expenses & receipts | 🛠 | Costs charged to projects, billable pass-through, receipt uploads. |
| Reports & exports | 🛠 | Utilization / revenue / time; PDF + spreadsheet export; scheduled email. |
| Accounting sync | 🛠 | Push invoices to QuickBooks/Xero instead of re-keying. |

## Communication

| Feature | Surfaces | Notes |
|---|---|---|
| Notifications | 🛠 👤 | In-app bell, unread counts, type-routed. Mirror to both surfaces. |
| Transactional email | 📧 | Auth, estimates, invoices, alerts. The bare minimum is auth email. |
| Chat / messaging | 🛠 👤 | Per-project/client threads. Heavy to build well — defer unless central. |
| Digest emails | 📧 | Daily/weekly roll-up of unread activity. |

## People & calendar (internal)

| Feature | Surfaces | Notes |
|---|---|---|
| Team & permissions | 🛠 | Staff roles + granular permission overrides. |
| Calendar | 🛠 | Task deadlines, on-site phases, PTO in one view. |
| External calendar sync | 🛠 | Google/Outlook OAuth sync. |
| PTO tracking | 🛠 | Feeds the scheduler's availability. |
| Certifications / skills | 🛠 | Track expirations; match staff to work. |

## Portal-specific

| Feature | Surfaces | Notes |
|---|---|---|
| Portal dashboard | 👤 | Single customer view: open invoices, items needing action, project status. |
| File manager | 👤 | Customer sees a **filtered** subset of project files; can request more. |
| Help / FAQ | 👤 | Self-serve articles — at minimum: login troubleshooting (expired magic links, "request a new link") and who to contact, with the request-ID pattern from `secure_coding.md` § 6. |
| Portal settings | 👤 | POC profile, notification prefs, alert thresholds. |

## Marketing / public (optional)

| Feature | Surfaces | Notes |
|---|---|---|
| Marketing site | 🌐 | Public pages; the portal login is the bridge from public to authed. |
| Knowledge base / wiki | 🌐 | Public articles. |
| Tokenized downloads | 🌐 👤 | Trackable links for spec sheets / case studies. |

## Operations

| Feature | Surfaces | Notes |
|---|---|---|
| System settings | 🛠 | Company info, invoice numbering, payment terms, integration toggles. |
| Backups | 🛠 | Automated + off-site + **rehearsed restore**. Non-negotiable for an ERP. |
| Admin / back-office hub | 🛠 | Finance dashboards, debt/aging, internal tooling. |

---

## Trade signals — proposals the interview implies

`/perp-scope`'s doc-review pass reads this table: when an interview
answer matches a signal, the feature gets activated in the index and
**proposed with the reason attached** ("you said you promise dates —
this is the feature that tracks them"). Propose, don't push; the owner
picks.

**This is a living list** — the whole point is that it grows: every
field test that surfaces a new "they said X, they'll need Y" link adds
a row here, and no skill text changes. Keep the Why column in the
shop's language; it becomes the proposal sentence.

| Signal (what they said) | Propose | Why (say it back to them) |
|---|---|---|
| Customers call/email asking "where's my job?" | Portal dashboard + promised dates | Every status call is friction on both sides — the portal answers it before they ask |
| Customers pay by check / payment arrives slowly | Online payments | The check in the mail is the slowest step in your cash flow |
| Manufacturer + "yes, I promise delivery dates" | Promised dates & dispatch list | You promise dates — this tracks them, and tells the floor what to run next on which machine |
| Customers send drawings / models / part files | Part viewing (CAD) | Your customers could open their own parts in the portal instead of emailing files back and forth |
| Sends work out (plating, anodize, heat treat) | Purchasing / outside processing + Job routing & travelers | Work you send out needs POs, and jobs that move need a traveler |
| Takes deposits / prepayment on jobs | Deposits & progress billing + Online payments | A deposit is easiest to collect the moment they accept the quote — and every invoice after it has to credit what you already took |
| Customers prepay blocks of hours | Retainers / hour blocks | That's a retainer — it needs a balance the customer can see |
| Prices per part, per unit, or per lot/release | (billing atom — DOMAIN_MODEL § Billing-model variants) + Shipping labels | Your invoice follows what shipped, not hours worked, so partial shipments have to bill exactly once |
| One price per job, paid at agreed points | (billing atom — milestones) + Closeout / sign-off checklists | You get paid when a stage is signed off, so sign-off is the event the system has to capture |
| Bills more than one way depending on the customer | (billing atom — pick the common case) | Build around how you bill most jobs; the exception becomes a variant, not a second system |
| Scope changes mid-job / "we argue about the price" | Estimates & scope (versioned) + Closeout / sign-off checklists | A change order the customer accepted in writing is the argument you don't have later |
| Holds raw material, consumables, or finished goods on the shelf | Inventory / stock | You draw from stock rather than buying per job — but this is a later tier, not your first build |
| Buys material per job as it comes in | (nothing — Expenses covers it) | Material bought for a job is just a cost on that job; you don't need inventory |
| Pain point involves chasing payment | Payment reminders / dunning | The overdue flip is Tier-0; automatic reminders are the next step your pain points at |
| Recurring / maintenance-contract work | Recurring tasks + Project templates | Repeating work shouldn't be re-entered by hand |
| On-site + off-site work mentioned | Phase types (see DOMAIN_MODEL § Work) | Site work usually bills and schedules differently than shop work |
| Defense / aerospace / export-restricted customers | (not a feature — a posture) ITAR gating per § What It Is + file audit logging | Your files carry export-controlled data; visibility and audit rules change |

## Sequencing advice

- **Each row is a `features/<name>.md` plan doc** when you commit to it. Don't
  plan the whole table up front.
- **Money features compound risk.** Estimates → invoicing → retainers →
  payments each multiply the number of places a total is computed. Lock down
  the "one formula per number" rule (DOMAIN_MODEL invariant 2) and run
  `/perp-review-parity` *before* adding the next money feature, not after.
- **The portal doubles your surface area.** Every feature you expose to
  customers is a second place the same logic runs. Budget for parity work in
  every estimate.
- **Whole-history work runs out-of-band.** Anything that aggregates across
  a client's full history or fans out email — reports, exports, digests,
  threshold alerts — is a background job, never a request handler. A
  utilization report over three years of time entries rendered to PDF in a
  route is a timeout waiting for real data.
- **Defer the heavy social features** (chat, digests, scheduling whiteboards)
  until the transactional core is solid. They're large and they're rarely
  what wins the customer.
