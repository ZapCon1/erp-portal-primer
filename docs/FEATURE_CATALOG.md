# Feature Catalog — ERP Customer Portal

A menu of features a professional-services / job-shop ERP-with-portal tends
to grow, grouped by domain and tagged with the **surface(s)** they touch.
This is a planning aid, not a checklist — most businesses need maybe a third
of it. Pick a vertical slice, ship it end-to-end, then come back.

**Surfaces:** 🛠 internal staff app · 👤 customer portal · 🌐 public/marketing · 📧 email (outbound channel — not an interactive surface; parity rules don't apply to it) · **A→B** means the flow originates on surface A and lands on B (e.g. 👤→🛠 a portal request handled by staff)

For each feature you decide to build, create a `features/<name>.md` from
`features/_TEMPLATE.md` and track phases there.

**Rows group into modules.** This table is the menu; `docs/MODULES.md` is
the boundary map over it — which rows form a removable unit, what each
unit depends on, and which concerns (the portal surface, compliance
posture) are *dimensions* that can never be a module. Read it before
committing to anything below marked **[module]**.

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
| **Full data export** | 🛠 | One command that writes every table an owner would need to leave — clients, contacts, jobs, phases, tasks, time, expenses, invoices, payments, credit notes, audit log — to CSV or JSON. **This is Tier 0 on purpose.** The realistic failure of a self-built ERP is not "it doesn't work", it's "I ran out of evenings in month four" — and that decision gets made when the owner is exhausted, with real customer data already inside. Every product the README tells you to consider buying ships an export button; yours must too, and it must exist *before* the first real record does. See README § If you want out. |

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
| Promised dates & dispatch list **[module]** | 🛠 👤 | The scheduling middle tier that answers "when will my job be done?": a `promisedDate` on every project (schema-shaped — decide it early), a per-work-center **dispatch list** (operations ready to run, ordered by due date — a query over routing statuses, not an engine), and the portal showing promised date + current step via the same shared helper staff use. Machine shops: the dispatch list groups by your **equipment** (WorkCenter — `/perp-feature`'s interview collects the machine list). `/perp-scope` proposes this proactively when a manufacturer says they promise dates. See DOMAIN_MODEL § Scheduling. Boundary: `docs/MODULES.md` § Scheduling. |
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
| Cost build-up & job costing **[module]** | 🛠 | The number *behind* the price. A ScopeItem carries a quoted price; this adds what it was built from — material + setup + cycle time × rate + outside processing + burden, with a markup that produces the price — plus **quantity breaks** (a 500-piece price is not 5× the 100-piece price) and, once time and expenses land, **estimated vs actual per job** so the next quote is better than the last. **Cost and price are two numbers with one formula each** (`MONEY-1`); only price is ever shown on the portal. Without this, "did we make money on that job?" has no answer and quoting stays a spreadsheet. Boundary: `docs/MODULES.md` § Cost build-up. |
| DFM analysis (Toolpath) **[module]** | 🛠 (👤?) | Send an uploaded CAD part to Toolpath's API, get design-for-manufacturability findings back, attach them to the part revision and surface them in the estimate. **Requires Part viewing** — it reuses the same file and the same async-derivation pattern (upload, then consume the server-sent event stream at /v1/jobs/{id}/events — no webhooks, and do not poll). API-key auth, OpenAPI spec at `/v1/openapi.json`. **Export-controlled files must never be sent** — the gate is structural, see `docs/MODULES.md` § Toolpath. Whether customers see DFM output is an explicit decision, not a default. |

## Time, billing & money

| Feature | Surfaces | Notes |
|---|---|---|
| Deposits & progress billing | 🛠 👤 | Money taken before the work is done: a deposit or % at estimate acceptance, or progress payments as the job runs. The deposit is an invoice like any other — what makes it its own feature is the **drawdown**: every later invoice must credit what's already been paid, in one formula, on both surfaces (DOMAIN_MODEL invariant 10 — nothing billed twice). Applies to every billing model; not a retainer (a retainer prepays *hours*, a deposit prepays *money*). |
| Retainers / hour blocks | 👤 🛠 | Pre-purchased hours pool with expiration + low-balance alerts. **Only if customers literally prepay hours** — if they prepay money against a fixed price, that's Deposits & progress billing instead. See DOMAIN_MODEL's three retainer rules before building. |
| Inventory / stock **[module]** | 🛠 | On-hand quantities for raw material, consumables, or finished goods, with receipts in and issues out to jobs. **Only for shops that hold stock** — buying material per job is already covered by Expenses and vendor POs, and needs none of this. A known ERP tarpit: it drags in units of measure, locations, counts, valuation, and reconciliation, each of which is a second source of truth for a number. Never a first slice. Start at the smallest honest version — an on-hand quantity per material that job issues decrement — and only add valuation when someone needs it for costing. Boundary: `docs/MODULES.md` § Inventory. |
| Budget & hours alerts | 🛠 📧 | Threshold alerts (e.g. 50/75/90%) + expiry warnings. |
| Payment reminders / dunning | 🛠 📧 | Overdue-flip job (needs `Invoice.dueDate` + the declared timezone) + reminder schedule. Tier-0 invoicing without this means manual collections — chasing receivables is half of what an ERP earns its keep doing. **The minimum viable piece belongs with Tier-0**: `dueDate` + declared timezone + a daily overdue-status flip is one small job; the full reminder schedule can wait, invisible receivables can't. |
| Online payments | 👤 | Card/ACH via a payments provider; **webhook** marks invoices paid. |
| Purchasing / outside processing **[module]** | 🛠 📧 | Vendor POs to suppliers (anodize, plate, heat treat, outside machining): line items pair a part + process + qty, per-year PO numbering (locked counter — same invariant as invoices), status draft → sent → partially-received → received, receiving tracked per line. Costs flow into the project as Expenses. See DOMAIN_MODEL § Purchasing & routing. Boundary: `docs/MODULES.md` § Purchasing. |
| Job routing & travelers | 🛠 | Ordered operations per job (work center or outsourced via a vendor-PO line), each with a status — where every job physically is, at a glance. The **traveler** is the printed packet (routing + drawings) that follows parts across the floor. Start as display + status tracking; scheduling/capacity is a much later tier. |
| Document packets | 🛠 👤 | One merged PDF from a cover document plus per-part attachments — a vendor PO + each part's process spec, or a quote + drawings. Regenerate the cover on every print (no stale numbers); skip parts without attachments silently. |
| Pre-canned notes | 🛠 | Reusable text blocks (terms & conditions, handling instructions) attached to estimates, invoices, and vendor POs in a chosen order. One table, referenced by every document renderer. |
| Shipping labels | 🛠 | On-demand label PDFs per job/PO line (part, process, qty), with free-form quantity splitting (500 → 200/200/100). Generated, not stored. |
| Part viewing (CAD) **[module]** | 👤 🛠 | Customers and staff view uploaded CAD models (STEP/IGES/STL) in the browser. On upload, a background job tessellates to a compressed GLB stored beside the original; the file page embeds a three.js viewer, lists show thumbnails, with explicit "preview pending" / "conversion failed — download original" states (PORTAL_UX.md). Tenant-scoped like every file; export-controlled files additionally gated by the ITAR flag with every view audit-logged. STL views out of the box; STEP/IGES activates when the OCCT worker is enabled. Architecture + provision-now hooks: `docs/STACK.md` § Part viewing. Deferred: measurement, assembly trees, PMI/GD&T, drawing markup, revision diff. |
| Expenses & receipts | 🛠 | Costs charged to projects, billable pass-through, receipt uploads. |
| Reports & exports | 🛠 | Utilization / revenue / time; PDF + spreadsheet export; scheduled email. |
| Receivables & statements **[module]** | 🛠 👤 | AR depth beyond Tier-0 invoicing: aging buckets, customer statements, credit hold, payment application and deposit drawdown, job costing rollups. **The general ledger stays external** — your app is the AR sub-ledger of record, QuickBooks/Xero/Puzzle owns the books. Double-entry in-app makes every number computable two ways (invariant 2). Parity-sensitive: the customer sees their own aging from the same helper staff use. Boundary: `docs/MODULES.md` § Accounting. |
| Accounting sync **[module]** | 🛠 | Push invoices, credit notes, and payments to QuickBooks/Xero/Puzzle instead of re-keying; pull payment status back. Sent-invoice immutability still holds — the external system never rewrites your invoice; corrections go through a CreditNote. Idempotency key on every push, or a retry duplicates an invoice in someone's books. Boundary: `docs/MODULES.md` § Accounting sync. |

*(Surfaces: 🛠 internal staff app · 👤 customer portal · 🌐 public · 📧 email)*

## Quality & compliance

| Feature | Surfaces | Notes |
|---|---|---|
| Document control (AS9100) **[module]** | 🛠 👤 | Controlled documents with revision states (`draft → in-review → released → superseded → obsolete`), approvals required before release, a distribution list that gets acknowledged, and obsolete copies that can't be mistaken for current. Superseded revisions are **retained, never deleted**; every transition is audit-logged; rendered PDFs are stamped "uncontrolled when printed." Portal face: customers see **released** revisions shared with them — specs, certs of conformance, quality clauses. If Part viewing is also active, a drawing revision **is** a document revision — share `PartRevision`, don't keep two rev letters. Entities + rules: `docs/MODULES.md` § Doc Control. |
| Quality records (inspection · NCR · CAPA) **[module]** | 🛠 👤 | The records an auditor asks for that document control does *not* cover: an **inspection result** tied to a job and quantity, a **nonconformance** with a disposition (use-as-is / rework / scrap / return), a **corrective action** that closes with evidence, **gage calibration** due-dates, and **first-article** records. Scrap and rework quantities must reconcile against qty-ordered and qty-shipped, or your billing and your parts count disagree. Portal face: the customer sees a cert of conformance and their own FAI, never your internal NCRs. Boundary: `docs/MODULES.md` § Quality records. |
| Lot & serial traceability **[module]** | 🛠 👤 | Material heat/lot number at receipt → the job it was issued to → the operations it passed → the shipment it left on. This is what "traceability" means to an aerospace auditor, and it is a schema-shaped decision: retrofitting a lot column onto live jobs means backfilling data nobody recorded. **Only if your customers or your certification require it** — most job shops do not need it, and it touches every table it appears in. Boundary: `docs/MODULES.md` § Quality records. |
| Compliance posture (ITAR/EAR · CMMC/CUI) | — | **Not a feature — a dimension.** A data classification (unrestricted · export-controlled · CUI) read by every module and every integration, plus audit retention, MFA for privileged access, encryption at rest, sanitization on delete, and egress control. Handling CUI can constrain your hosting choice — settle it with your assessor before go-live, not after (`docs/MODULES.md` § Compliance posture). |

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
| External calendar sync **[module]** | 🛠 | Google/Outlook OAuth sync. Boundary: `docs/MODULES.md` § Google Workspace. |
| PTO tracking | 🛠 | Feeds the scheduler's availability. |
| Certifications / skills | 🛠 | Track expirations; match staff to work. |

*(Surfaces: 🛠 internal staff app · 👤 customer portal · 🌐 public · 📧 email)*

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
| File storage integration **[module]** | 🛠 | Keep using **Box · Dropbox · SharePoint/OneDrive · Google Drive** instead of (or alongside) the kit's own storage. Three modes, and you must pick one: **reference** (link only — no previews, no CAD derivatives, no audit of who opened it), **ingest** (recommended — staff keep their folder habit, the app owns the copy that matters), or **two-way sync** (two sources of truth for the same bytes; avoid). Consequences: their sharing settings become your access control, downloads straight from the service never reach your audit log, **doc control's rev letter beats the service's own version history**, and derivatives always stay in your storage. Controlled files stay proxied through the app. See `docs/MODULES.md` § File storage. |
| Integration scaffold **[module]** | 🛠 | **Build once, before the second integration.** One `IntegrationConnection` (provider, scope `company`/`user`/`client`, encrypted credentials, granted scopes, token expiry, `lastSyncAt`, `lastError`), one sync-job pattern with idempotency keys, one loud-failure path, one OAuth flow. Carries `mayReceiveControlledData` — default **false** — so "never send export-controlled files to a third party" is a check the uploader runs, not a paragraph someone remembers. Google, Outlook, QuickBooks/Xero/Puzzle, Toolpath, and payments all ride on it. See `docs/MODULES.md` § The shared scaffold. |
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
| Quoting takes hours per job, and most quotes don't land | Estimates & scope (versioned) | You're paying for every quote whether it lands or not — the fastest money in the shop is the quote you don't redo |
| Opens the customer's model to estimate cut time | DFM analysis (Toolpath) + Part viewing (CAD) | The model you already have can tell you what's expensive to cut before you price it — build-vs-plug-in is a later call |
| Runs on spreadsheets / paper / an ERP they want to leave | (not a feature — a migration) Scope the data that has to come over | Open jobs, customers, and history don't move themselves; plan it as work, not a detail |
| Nobody records hours against jobs today | (not a feature — a behavior change) Time tracking | The screen is easy; getting people to fill it in is the actual project |
| Files already live in Box / Dropbox / SharePoint / Drive, and the team likes it there | File storage integration (ingest mode) | Nobody should have to change where they drop files — but the system needs its own copy of the ones that matter |
| Certified **and** files live in a cloud drive | File storage integration + Document control, with the rev-letter rule stated | Dropbox keeps versions, your auditor asks for revisions — those aren't the same thing, and only one of them can be the record |
| Ships physical parts | Shipping labels + Document packets | What goes in the box is a document problem, and it repeats every shipment |
| Sends certs of conformance / material certs with parts | Document packets (+ Document control if certified) | Certs that ship with parts are controlled records, not attachments |
| Certified, and the auditor asks for inspection or nonconformance records | Quality records (inspection · NCR · CAPA) | Controlled documents are half of AS9100 — the other half is proving what you inspected and what you did when it failed |
| Customers require material certs traced to a heat/lot number | Lot & serial traceability | That trace has to exist in the schema from the first job; it cannot be reconstructed later |
| Quotes are built in a spreadsheet from material + cycle time + markup | Cost build-up & job costing | The price is the output; the system should hold the inputs, so next year's quote starts from what actually happened |
| "I don't know which jobs made money" | Cost build-up & job costing | Estimated vs actual is the only thing that makes the next quote better than the last |
| AS9100 / ISO certified, or chasing certification | Document control | Your auditor asks who approved rev C and who was told about it — that's a table, not a folder |
| "We got written up for uncontrolled prints / old revisions on the floor" | Document control | The finding is that a printed copy outlived its revision; stamped prints and acknowledgments are the fix |
| DoD work / CUI / CMMC in the pipeline | (not a feature — a posture) Compliance posture | CUI changes who may see files, what leaves your network, and possibly where this can run |
| Spends real time estimating machining cost from customer models | DFM analysis (Toolpath) + Part viewing | The model you already store can tell you what's expensive to cut before you quote it |
| Re-keys invoices into QuickBooks / Xero / Puzzle by hand | Accounting sync | You're typing the same invoice twice and reconciling the difference |
| "I don't know who owes us what without opening the accounting software" | Receivables & statements | Aging belongs where the invoices are, and your customer should see their own |
| Lives in Google Calendar or Outlook | External calendar sync + Integration scaffold | Deadlines the system knows about should appear where you already look |
| Second integration of any kind on the roadmap | Integration scaffold | Build the credential, retry, and failure-alert path once — the second one is where the drift starts |

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
