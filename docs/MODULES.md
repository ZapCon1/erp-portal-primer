# Modules — what's separable, what isn't

`docs/FEATURE_CATALOG.md` is the menu of *features*. This is the map of
**boundaries**: which groups of features form a removable unit, what each
one depends on, and what it costs to leave one out. A module is a unit
you can decline without breaking the system.

**Canonical scope of this file** (per `CLAUDE.md` § Architecture):
module boundaries, dependencies, and activation. It does **not** restate
domain rules (`docs/DOMAIN_MODEL.md` § Invariants), security semantics
(`secure_coding.md`), or stack pins (`docs/STACK.md`) — it points at
them. When a module is activated, its entity sketches here graduate into
DOMAIN_MODEL, which then wins.

---

## The four layers

| Layer | What it is | Removable? |
|---|---|---|
| **Spine** | clients, projects, phases, tasks, time, invoices, payments, audit, auth, tenancy | **No.** Tier 0. Everything depends on it; it depends on nothing. |
| **Capability modules** | Own entities, own screens, a face on **both surfaces** | Yes — that's the point. |
| **Integration modules** | No domain entities of their own. They sync the spine with an outside system. | Yes, and independently of each other. |
| **Dimensions** | portal surface · parity · tenancy · audit · voice · **compliance posture** | **Never modules.** They cut across every module at once. |

### Why dimensions are not modules

This is the distinction the whole file exists to protect, and it's the
one people get wrong first.

**The portal is a dimension.** If the portal were a module, then
Scheduling's customer-facing promised-date view would have to live
either inside Scheduling or inside Portal — and both answers are wrong.
It lives in Scheduling, rendered onto the portal surface, computed by
the same `lib/` helper staff use. `CLAUDE.md` § Parity states the rule
directly: *the portal is a dimension, not a phase.* Every capability
module ships its portal face in the same phase as its staff face, or
documents why it has none.

**Compliance posture is a dimension.** ITAR/EAR export control and
CMMC/CUI handling are not features you build once; they're constraints
every module answers to — which files may be viewed, which data may
leave your network, what gets audit-logged, how long records are kept.
Doc control (AS9100) *is* a module because it has entities and screens.
"CMMC" is not, because it's a property of all of them. See
§ Compliance posture below.

---

## Contents

- [The four layers](#the-four-layers) — spine · capability · integration · dimensions
- [Dependency graph](#dependency-graph)
- [The module contract](#the-module-contract) — the 11 declarations every module answers
- [Capability modules](#capability-modules)
- [Integration modules](#integration-modules)
- [Dimensions](#dimensions) — the portal, and the compliance posture

**If you read one section, read [The module contract](#the-module-contract).**
It governs every module here; the long integration sections below are
reference material you reach for when you build one.

---

## Dependency graph

Arrows point **from** the dependent thing **to** what it needs.

```
                         ┌─────────────────┐
                         │      SPINE      │  clients · projects · phases
                         │  (never pruned) │  tasks · time · invoices
                         └────────┬────────┘  payments · audit
                                  │
      ┌───────────┬───────────┬───┴───────┬───────────┬───────────┐
      │           │           │           │           │           │
 Scheduling  Part Viewing Purchasing   Doc Control Accounting  Quality
 (dates +      (CAD /     & Routing     (AS9100)   (AR depth)  records
  dispatch)  OpenCascade)     │             │                  (NCR/CAPA)
                  ▲           │             │                      │
                  │           │             │                      ▼
                  ├───────────┘             │              (pairs with
                  │  routing operations     │               Doc Control)
                  │  reference part revs    │
                  │                         │
                  └─────────────────────────┘
                    a drawing IS a controlled document
                    (they share PartRevision)

  Also hanging off the SPINE, with no cross-module edges:
      Lot & serial traceability   (schema-shaped; only if certified/contractual)
      Cost build-up & job costing (feeds Estimates; only price reaches the portal)
      Inventory                   (later tier — never a first slice)

  ┌──────────────────────────────────────────────────────────────────────┐
  │  INTEGRATION MODULES — attach to the SPINE, own no entities          │
  └──────────────────────────────────────────────────────────────────────┘
      Google Workspace / Microsoft 365 / Outlook
      Payments
      Transactional email (Resend / Postmark / SES)
            └─ BLOCKS portal login until DNS verifies. Start it day one.
      Accounting sync (QuickBooks / Xero / Puzzle) ──▶ Accounting
      Toolpath (DFM) ──────────────────────────────▶ Part Viewing
      File storage (Box · Dropbox · SharePoint · Drive) ──▶ Doc Control
            └─ constrained by it: the app owns rev letters, and flagged
               files follow the proxy-and-log rule
```

Two dependencies are load-bearing and easy to miss:

- **Toolpath requires Part Viewing.** It consumes the same uploaded CAD
  file and attaches its output to the same `PartRevision`. Without that
  module there's nothing to send and nowhere to put the answer.
- **Doc Control and Part Viewing overlap on drawings.** A released
  drawing revision is simultaneously a viewable file and a controlled
  document. Build either alone; if you build both, they share
  `PartRevision` rather than each keeping its own revision letter. Two
  revision letters for one drawing is a second source of truth.

---

## Inert by default

**A module in this file is not a plan to build it.** The kit's standing
warning applies with extra force here: an organized menu is still a
menu, and a module list is very good at looking like a build list.

1. **Nothing is active until `/perp-scope` activates it.** The trade
   signals in `docs/FEATURE_CATALOG.md` § Trade signals are the
   activation mechanism — an interview answer proposes a module, with
   the reason attached, and the owner picks.
2. **One module at a time, shipped end-to-end**, both surfaces, before
   the next is started.
3. **A module with no named friction is scope creep** (`docs/SCOPE.md`
   § The friction). "We might need doc control someday" is not a
   friction; "our AS9100 auditor writes us up for uncontrolled prints"
   is.
4. **Declining a module is the default answer.** Most shops need the
   spine plus two or three in the first months. The trade-signal table
   proposes more than that for most shops — that is the menu doing its
   job, not a build order. Modules are inert until you pick one.

---

## The module contract

Every capability module declares these before any code.
`/perp-feature` scaffolds the plan doc; this is what its Design section
must answer.

| # | Declaration | Why it's mandatory |
|---|---|---|
| 1 | **Depends on** — spine always, plus any module | Catches the Toolpath / Part-Viewing class of hidden coupling |
| 2 | **Entities added** | They graduate into DOMAIN_MODEL on activation; the doc is canonical afterward |
| 3 | **Both surfaces** — the 🛠 face *and* the 👤 face, or an explicit "no portal face, because…" | Parity gets enforced at the boundary instead of discovered at release |
| 4 | **Shared helpers** — every number the module computes, named once | Invariant 2: one source of truth per number |
| 5 | **Background jobs** — queue names, concurrency, timeout | Whole-history and fan-out work never runs in a request handler |
| 6 | **Settings** it adds to `CompanySettings` or the integration toggles | Interview facts become editable runtime data, not hardcoded strings |
| 7 | **Audit events** it writes | Invariant 7 predicate; mechanics in `secure_coding.md` § 7 |
| 8 | **Data classification** — does it touch export-controlled or CUI data, and may any of it leave your network? | The most expensive thing on this list to retrofit. Default answer: no |
| 9 | **Trade signal** that should activate it | Keeps the catalog's proposal engine current |
| 10 | **Prune cost** — what breaks if it's removed later | An honest module can be removed; if it can't, it was spine |
| 11 | **Indexes and expected row growth** — the composite `(clientId, <primary filter>)` index on every table it adds, and which of its lists need a cursor | `SCALE-1`/`SCALE-2`. The moment the tables are designed is the moment these cost nothing; afterwards they are a migration against live data |

---

## Capability modules

### Scheduling

**Status:** partly specified — `docs/DOMAIN_MODEL.md` § Scheduling.

Three rungs, and the kit is opinionated about stopping early: a
`promisedDate` on every project (schema-shaped — decide it on day one),
a per-work-center **dispatch list** (a query over routing statuses, not
an engine), and only much later a capacity-aware board. The board is APS
territory and deliberately deferred. Portal face: promised date plus
current step, from the same helper staff use.

### Part Viewing (CAD / OpenCascade)

**Status:** fully specified — `docs/STACK.md` § Part viewing.

Nothing new is needed here. This module is a boundary drawn around
architecture that already exists in the stack record: occt-import-js
(OpenCascade as WASM, so no native deps in the image) tessellating to
GLB, compressed with gltfpack, on its own queue at concurrency 1 with a
timeout and a file-size cap; `FileDerivative` rows carrying
pending/ready/failed as first-class portal states; export-controlled
files gated identically on original and derivative.

### Purchasing & Routing

**Status:** specified — `docs/DOMAIN_MODEL.md` § Purchasing & routing.

Vendor POs for outside processing, ordered operations per job,
travelers. Activated by "we send work out." Its per-year PO counter is
the same locked-counter construct invoices use, and carries the same
mandatory test (`docs/STACK.md` § Integrity).

### Doc Control (AS9100)

**Status:** new — entity sketch below.

The module that makes documents *controlled*: a current released
revision, an approval that happened before release, a distribution list
that was acknowledged, and obsolete copies that can't be mistaken for
current.

Entity sketch (graduates into DOMAIN_MODEL on activation):

- **ControlledDocument** — number, title, type (procedure · work
  instruction · form · spec · drawing), owner, retention policy.
- **DocumentRevision** — rev letter, state (`draft` → `in-review` →
  `released` → `superseded` → `obsolete`), effective date, supersedes,
  change reason. A discriminated union, not booleans.
- **Approval** — required role, approver, signed-at. Release is blocked
  until every required approval is present.
- **Acknowledgment** — who must read a revision, who did, when. This is
  the row an auditor asks for.

Rules that aren't negotiable if you're claiming AS9100. **Each carries its
rule ID** — `docs/CONTROLS.md` § The rule index is the canonical list, and
these are the same rules stated where they get built:

- **`DOC-1` A released revision is immutable.** Editing a released rev in
  place is how a controlled document quietly becomes uncontrolled — the
  file changed, the rev letter didn't, and everyone downstream is working
  from something that no longer exists. A change means a **new revision**,
  never an edit. Enforce it the way sent invoices are enforced: an
  app-level hook **and** a database constraint, because the app is not the
  only thing that can write to the database.
- **`DOC-2` Release requires every named approval.** Blocked in the state
  machine: `draft → in-review → released` cannot skip, and the approval
  rows must exist before the transition commits.
- **`DOC-3` Superseded revisions are retained, never deleted.** Delete is
  *refused*, not soft-flagged. An auditor asks for rev B after rev C
  shipped.
- **`DOC-4` Prints are stamped and logged.** An uncontrolled printed copy
  is the classic finding. Any rendered PDF carries rev, print timestamp,
  and "uncontrolled when printed."
- **`DOC-5` The app owns the rev letter.** If files live in
  Box/Dropbox/SharePoint, their built-in version history is **not** your
  revision record — running both is a second-source-of-truth failure that
  fails quietly: someone edits in place, the file changes, the rev letter
  doesn't move, and a controlled document is now uncontrolled. See
  § File storage.
- **Only released revisions are visible to non-approvers**, and drafts
  never render as current.
- **Every state transition is audit-logged**, including who approved
  (`AUDIT-1`).
- **A drawing revision is a document revision.** If Part Viewing is also
  active, the two share `PartRevision` (see the dependency note).

#### Acceptance — how you prove each one

A compliance rule you cannot demonstrate is a compliance rule you do not
have. Each of these is one test, and they are the evidence an assessor
asks for:

| Rule | The test that proves it |
|---|---|
| `DOC-1` | Update a financial-equivalent field on a **released** revision **through a raw connection outside the ORM** — the database must reject it. Going through the app only proves the app. |
| `DOC-2` | Attempt `in-review → released` with one required approval missing; assert it is refused and no revision row changed state. |
| `DOC-3` | Attempt to delete a superseded revision; assert refusal, and that it is still readable afterwards. |
| `DOC-4` | Render a controlled document to PDF and assert the output contains the rev, a timestamp, and the uncontrolled-when-printed stamp. |
| `DOC-5` | Change the file out-of-band in the storage provider; assert the app's rev letter did **not** move and the mismatch surfaces somewhere a human sees it. |

Write these when you build the module, not before go-live. `DOC-1` and
`DOC-5` are the two that are near-impossible to retrofit honestly, because
by then live documents already carry the wrong history.

Portal face: customers see **released** revisions of documents shared
with them — specs, certs of conformance, quality clauses — filtered by
the same tenant predicate as files, and never drafts.

### Quality records (inspection · NCR · CAPA)

**Status:** new. **Doc control is half of AS9100; this is the other half.**
A shop with controlled documents but no nonconformance record fails its
first audit on the part nobody wrote down.

Entity sketch: **Inspection** (job, operation, quantity checked, result,
inspector) · **Nonconformance** with a disposition (`use-as-is` · `rework` ·
`scrap` · `return-to-vendor`) — a discriminated union, not a flag ·
**CorrectiveAction** that closes with evidence and a date · **Gage** with a
calibration due date that goes overdue on the declared timezone like any
other date · **FirstArticle** tied to a part revision.

Two rules that matter beyond quality:

- **`QUAL-1` Scrap and rework quantities must reconcile.** Qty ordered, qty
  scrapped, qty reworked and qty shipped are **one arithmetic identity**:
  `ordered = shipped + scrapped + reworked-out`. If they drift, either the
  customer is billed for parts they didn't get or you eat parts you made —
  both are `MONEY-1` problems wearing a quality costume.
  **Acceptance:** one test asserting the identity holds after every
  disposition path (use-as-is, rework, scrap, return-to-vendor), including
  a partial-quantity disposition — that is where it actually breaks.
- **`QUAL-2` A first article is a document set, not a checkbox.** The
  aerospace standard for it is **AS9102**, and it expects specific forms:
  part/assembly identification, the raw material and special-process
  certifications, and — the one that catches people — **every drawing
  characteristic numbered ("ballooned") and individually reported with its
  measured result**. So `FirstArticle` is not a boolean on a job; it is a
  parent record with a row per characteristic. Model it that way from the
  start, because rebuilding it later means re-ballooning drawings by hand.
  A first article is also re-triggered by change: a new revision, a process
  change, a lapse in production, or a new source.
  **Acceptance:** create an FAI, add characteristics, and assert it cannot
  be marked complete while any characteristic is unreported.
- **`QUAL-3` Counterfeit parts have to be designed out.** AS9100 expects a
  documented approach, and the software half is concrete: purchase from an
  approved source list, **capture the certificate of conformance and mill
  or test certs as files against the receipt** (not in a filing cabinet),
  and keep the lot/heat number linked from receipt through to the shipped
  part — which is the same chain `Lot & serial traceability` builds. If you
  buy from a broker rather than the mill or a franchised distributor, the
  standard expects extra verification; record which source type each
  receipt came from so that question is answerable later.
  **Acceptance:** assert a receipt cannot be closed without its cert file
  attached when the material is flagged as traceable.
- **Portal face is deliberately asymmetric.** Customers see the cert of
  conformance and their own first-article record. They do **not** see your
  internal NCRs — that's your scrap rate. This is the one place the parity
  rule is answered with "no portal face, and here's why."

### Lot & serial traceability

**Status:** new, and **schema-shaped** — it changes columns on tables you
already have, so retrofitting means backfilling data nobody recorded.

The chain an aerospace auditor actually asks for: **material receipt (heat
or lot number) → the job it was issued to → the operations it passed → the
shipment it left on.** Each link is a foreign key that has to exist from the
first migration.

**Most shops do not need this.** Require it only if a customer contract or
your certification does. `docs/MODULES.md` § Inert by default applies with
extra force: this one is expensive to carry and impossible to add cheaply,
which is exactly the combination that makes it a decision rather than a
default.

### Cost build-up & job costing

**Status:** new. Quoting is where a job shop makes or loses its money, and
the kit previously modelled only the price the customer sees.

**Cost and price are two different numbers, each with one formula**
(`MONEY-1`, invariant 2). The build-up — material + setup + cycle × rate +
outside processing + burden — produces a cost; a markup produces the price.
Quantity breaks are a property of the build-up, not a discount table bolted
on after.

- **Only price crosses to the portal.** Cost, burden and margin are
  internal, and the who-sees-what answer from `/perp-scope` Phase 1 decides
  whether they're visible to all staff.
- **Estimated vs actual is the payoff.** Once TimeEntry and Expense exist,
  the same job carries what you thought it would cost and what it did. That
  comparison is the only mechanism by which next year's quotes get better.
- Depends on nothing but the spine; pairs naturally with Purchasing (outside
  processing is a cost line) and with DFM analysis (which estimates cycle
  time from the model).

### Accounting (AR depth)

**Status:** new — the boundary is the important part.

**Your app is the sub-ledger of record for accounts receivable. The
general ledger stays in QuickBooks / Xero / Puzzle.** That line is the
whole design. The app owns *what was billed and what came in*; the
accounting package owns *how it's booked*. Double-entry inside the app
would make every number computable two ways, which is exactly what
invariant 2 forbids.

In scope: aging buckets, customer statements, credit hold, collections
workflow (the full dunning schedule the catalog defers), payment
application and drawdown against deposits, job costing rollups.

Out of scope, deliberately: chart of accounts, journal entries,
double-entry, AP, financial statements. Those are the sync target's job.

Portal face: a customer sees their own aging and statement — the same
numbers staff see, from the same helper. This is a parity-sensitive
module; run `/perp-review-parity` before every release that touches it.

### Inventory

**Status:** catalog row, with a standing warning. Never a first slice.
Start at "an on-hand quantity per material that job issues decrement"
and add valuation only when someone needs it for costing.

---

## Integration modules

### The shared scaffold — build this once

Every integration below needs the same things. Building them per
integration is how you end up with four different retry behaviors and
one silent failure.

**`IntegrationConnection`** — provider, **scope** (`company` · `user` ·
`client`; QuickBooks is company-wide, a Google Calendar is per-staff-
user, and that difference is structural), owner, status, encrypted
credentials, granted scopes, token expiry, `lastSyncAt`, `lastError`.

**`mayReceiveControlledData`** — a hard boolean on every provider
record, **defaulting to false**. This is the structural form of a rule
already written in `docs/STACK.md` § Part viewing: export-controlled
files are *never* sent to third-party hosted services. Making it a field
the uploader checks — rather than a paragraph someone remembers — is the
difference between a policy and a control.

The rest of the scaffold:

1. **Credential handling** — encrypted at rest under a key separate from
   the database, never returned in any API response (`secure_coding.md`
   § "Sensitive fields in responses"), OAuth state parameter for CSRF,
   redirect URIs allowlisted, token refresh in the worker and never in a
   request handler.
2. **Sync as a background job** — per-provider queue, with an
   idempotency key on every outbound write so a retry can't double-post
   an invoice.
3. **Failure is loud** — `lastError` on the connection, an
   operator-visible banner, and a human alerted on repeated failure. A
   sync that quietly stops is the swallowed-failure class the kit
   forbids (`CLAUDE.md` § No Swallowed Failures).
4. **Audit vs. observability, correctly split** — credential grant,
   revoke, and scope change are business events and go to the **audit
   log**; a timed-out HTTP call is **observability**. Don't cross them.

### Google Workspace · Microsoft 365 / Outlook

Calendar sync (task deadlines, on-site phases, PTO), and optionally
send-as mail. Per-**user** scope, OAuth. Staff-side; no portal face,
because customers don't get your calendar. File storage in Drive or
SharePoint is a different module — see below.

### File storage — Box · Dropbox · SharePoint/OneDrive · Google Drive

Keep using **Box · Dropbox · SharePoint/OneDrive · Google Drive** instead of,
or alongside, the kit's own storage. **Three modes, and you must pick one:**
*reference* (link only), **ingest (recommended)**, or *two-way sync* (two
sources of truth for the same bytes — avoid).

The consequences that decide the mode:

- Their sharing settings become **your access control**.
- A download straight from the service **never reaches your audit log**
  (`CUI-2`).
- **Doc control's rev letter beats the service's own version history**
  (`DOC-5`) — running both is a second-source-of-truth failure that fails
  quietly.
- Controlled files stay **proxied through the app**; derivatives always live
  in your storage.

📄 **Full detail: [`docs/modules/file-storage.md`](modules/file-storage.md)** —
the three modes compared, per-vendor notes, and the ingest pipeline.

### Accounting sync — QuickBooks · Xero · Puzzle

Company scope. Pushes invoices, credit notes, and payments outward;
pulls payment status back. Two rules: **sent-invoice immutability still
holds** — the external system never rewrites an invoice in your app,
corrections flow through a CreditNote as they already do — and every
push carries an idempotency key, because a retried invoice post is a
duplicate in someone's books.

### Toolpath (DFM analysis)

Send an uploaded CAD part to Toolpath's API, get design-for-manufacturability
findings back, attach them to the part revision, surface them in the estimate.
**Requires Part Viewing** — it reuses the same file and the same
async-derivation pattern.

Three facts that are expensive to learn late, kept here on purpose:

- ⚠️ **Everything is millimetres and degrees.** A US shop reading a DFM
  dimension as inches is out by 25.4× — in a number that feeds a price.
- **No webhooks, but do not poll**: consume the server-sent event stream at
  `/v1/jobs/{id}/events`.
- Auth is a **Bearer** credential, and CORS is per-key — never put the key in
  a browser.

**Export-controlled and CUI files must never be sent** (`CUI-1`); the gate is
structural, at the uploader, not a reminder.

📄 **Full detail: [`docs/modules/toolpath.md`](modules/toolpath.md)** — endpoints,
the derivation pipeline, error handling, and what to do when the API changes.

### Payments

Already in the catalog. Webhook-driven — `secure_coding.md` § 16 governs
it, and the handler re-fetches the amount from the provider rather than
trusting the payload.

### Transactional email (Resend · Postmark · SES)

Resend (default) · Postmark · SES. Auth, estimates, invoices, alerts.

**Start this on day one, before you need it.** It has the longest lead time
of anything in the kit and it **blocks the portal**: customer login is a
magic link, so until mail actually arrives, no customer can get in. Domain
verification means DNS records and propagation — minutes if you are lucky, a
day if your DNS lives somewhere awkward.

- In dev the mailer writes the message to the console, **magic link included**,
  so DNS never blocks development.
- **The dev fallback must be unable to run in production**, the same way the
  auth stub cannot (`SEC-2`). A mailer that silently logs instead of sending
  is worse than one that errors.
- Email is an **egress path** — an invoice PDF carries your content to a third
  party (`CUI-1`).

📄 **Full detail: [`docs/modules/transactional-email.md`](modules/transactional-email.md)**
— provider setup order, SPF/DKIM/DMARC, bounces and suppression, and the
portal-side failure the customer actually experiences.

## Compliance posture (a dimension, not a module)

This sits alongside the ITAR/EAR question `CLAUDE.md` § What It Is
already asks. Both regimes reduce to the same three questions, asked of
**every** module: who may see this, may it leave the network, and what
do we keep.

**Data classification** is the field the whole system reads:
`File.classification` — unrestricted · export-controlled (ITAR/EAR) · CUI
(CMMC). It supersedes the older boolean `exportControlled`, which could not
tell CUI from export-controlled. `/perp-build-core` provisions it in the
first migration **even when the answer is "no regulated data"**, because
retrofitting it means classifying live files by hand, from memory.

What CMMC adds beyond what the kit already does — and it already does a
fair amount of it (append-only audit log, tenant isolation, the
incident-response runbook, encrypted secrets). **Each carries its rule ID**;
`docs/CONTROLS.md` § The rule index is canonical:

- **`CUI-1` Egress control** — flagged data never reaches an unapproved
  third party. One classification, one predicate, checked at the uploader.
  CUI and ITAR are the same structural gate, which is why it is one field
  and one check. **Read the limits below — this predicate does not reach
  everything people assume it does.**
- **`CUI-2` Every access to a flagged file is audit-logged**, including the
  issuance of a presigned URL — which is a bearer credential the object
  store serves *without telling your app*. For flagged files, proxy through
  the app; that is the only compliant shape, not an alternative to one.
- **`CUI-6` Access to controlled technical data is gated on the *person*, not
  only their role.** This is the one most small shops miss, and it is
  architectural. Under ITAR, releasing technical data to a **foreign person
  is an export** — including an employee standing in your shop in Ohio. It
  has a name, a **deemed export**, and it needs a license *before* the
  release, not after. "US person" means a citizen, a lawful permanent
  resident (green card), or a protected individual; a work visa is **not**
  enough. So the system needs a per-user eligibility attribute, checked
  wherever controlled data is *rendered*, alongside the existing tenant and
  role checks. It applies to **three doors people forget**: a staff login
  for a foreign-national machinist, a portal login for a customer's foreign
  contact, and an offshore contractor with database or repository access.
  Provision the field in the first migration — retrofitting it means
  auditing every past view of every drawing, from logs you may not have kept.
- **`CUI-7` Markings survive the system.** A document that arrives marked
  (CUI, export-controlled, a distribution statement) must still carry that
  marking when your app renders it, exports it, or emails it. A portal that
  strips a marking has produced an unmarked copy of controlled data, and a
  PDF export is the usual culprit. Pairs with `DOC-4`'s print stamp.
- **`CUI-3` Audit records are protected and retained**, not merely written.
  The retention period is a decision, not a default. Write it down and
  assert it is set.
- **`CUI-4` MFA for privileged access**, and session lock. Lands on the
  real-login gate (`SEC-2`) that is already a before-go-live item.
- **`CUI-5` Media protection** — encryption at rest, and **sanitization on
  delete** rather than a soft-delete flag: the row *and* the stored object.

#### Acceptance — how you prove each one

| Rule | The test that proves it |
|---|---|
| `CUI-1` | Flag a file, then attempt to send it to an integration whose `mayReceiveControlledData` is false; assert refusal **at the uploader**, and that nothing left the process. |
| `CUI-2` | Read a flagged file two ways — through the app, and by issuing a presigned URL; assert an audit row exists for **both**, the second recording issuance. |
| `CUI-6` | Mark a user ineligible, then request a controlled file **through every surface that renders it** — staff view, portal view, PDF export, email attachment. Assert refusal on each, plus an audit row for the attempt. A test that only covers the API misses the render path, which is where the release actually happens. |
| `CUI-7` | Round-trip a marked document: ingest, render, export, email. Assert the marking text is present at every step. |
| `CUI-3` | Assert the retention setting is present and non-default, and that an audit row cannot be updated or deleted through the app. |
| `CUI-4` | Assert a privileged route refuses a session without a second factor. |
| `CUI-5` | Delete a flagged file; assert the row is gone **and** the stored object is gone — not flagged, gone. |

⚠️ **`CUI-1` gates *services*; `CUI-6` gates *people*.** Different controls,
neither substituting for the other. A perfectly configured egress gate still
lets an ineligible employee open the drawing on screen — and that is the
export.

⚠️ **The hard edge of `CUI-1`.** It gates deliberate, app-initiated
transfers of a classified file to a registered provider — Toolpath, hosted
converters, email attachments, storage sync. It **cannot** reach three
paths people assume it does, and each needs its own control:

- **Error tracking** — an SDK auto-captures request payloads and stack
  locals. There is no uploader and no connection record in that path.
  Scrub at `beforeSend`, or self-host.
- **CDNs and presigned URLs** — infrastructure the object store serves
  directly. The app-proxy path in `CUI-2` is the answer.
- **LLM and assistant tooling** — it reads the repo on the owner's machine,
  entirely outside the app. The only control is the rule in
  `docs/WHEN-IT-GOES-WRONG.md`: never open a controlled drawing or spec in
  the repo the assistant reads.

⚠️ **The one that can invalidate a hosting decision.** Handling CUI in a
cloud service generally pulls in FedRAMP-Moderate-equivalency
expectations under the DFARS 7012 safeguarding clause — a serious
constraint on where this runs, and `docs/STACK.md` § Deployment assumes
a self-hosted Docker stack on a small VPS by default. Self-hosting can
be the *easier* answer here, but it's a decision to make deliberately
and early. `docs/DEPLOYMENT_TARGETS.md` § AWS GovCloud covers the
compliant substrates (GovCloud, Azure Government, on-prem), what they do
and **don't** buy you, and the decision ladder. Confirm the current
requirement with your assessor rather than with either file; the rules
move, and getting it wrong is expensive after go-live, not before.

⚠️ **Egress is the half people miss.** A compliant host does nothing if
the data leaves through a side door — transactional email, error
tracking, a CDN, an LLM tool, or a third-party analysis API like
Toolpath. `docs/DEPLOYMENT_TARGETS.md` § The egress trap enumerates
them. The primary defense is one classification and one predicate checked
at every egress point, enforced by the integration scaffold's
`mayReceiveControlledData` — **plus the three side doors it cannot reach**,
each with its own control (see the hard edge of `CUI-1` above). A predicate
that covers most paths and is described as covering all of them is how a
side door stays open.

**AS9100 is different in kind:** it wants controlled documents,
traceability, and records — which is why doc control earns module status
and CMMC doesn't.
