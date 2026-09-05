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

## Dependency graph

```
                         ┌─────────────────┐
                         │      SPINE      │  clients · projects · phases
                         │  (never pruned) │  tasks · time · invoices
                         └────────┬────────┘  payments · audit
                                  │
     ┌──────────────┬─────────────┼──────────────┬───────────────┐
     │              │             │              │               │
Scheduling    Part Viewing   Purchasing &   Doc Control      Accounting
(dates +        (CAD /         Routing       (AS9100)        (AR depth)
 dispatch)      OpenCascade)      │              │               │
                     │            │              │               │
                     ├────────────┘              │               │
                     │  routing ops reference    │               │
                     │  part revisions           │               │
                     │                           │               │
                     └───────────────────────────┘               │
                        a drawing IS a controlled document       │
                                                                 │
Quality records (inspection · NCR · CAPA) ── pairs with Doc Control
Lot & serial traceability (schema-shaped; only if certified/contractual)
Cost build-up & job costing (feeds Estimates; only price reaches the portal)
Inventory (optional, later tier — never a first slice)            │
                                                                 │
── Integration modules (attach to the spine, own no entities) ────┘
Google Workspace / Microsoft 365 / Outlook  .  Payments
Transactional email (Resend / Postmark / SES) -- BLOCKS portal login until DNS verifies
Accounting sync (QuickBooks / Xero / Puzzle) ── pairs with Accounting
Toolpath (DFM) ─────────────────────────────── requires Part Viewing
File storage (Box · Dropbox · SharePoint · Drive) ── constrained by Doc
     Control (the app owns rev letters) and by the proxy-and-log rule
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
   spine plus two.

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

Rules that aren't negotiable if you're claiming AS9100:

- **Superseded revisions are retained, never deleted** — the same
  instinct as sent-invoice immutability.
- **Only released revisions are visible to non-approvers**, and drafts
  never render as current.
- **Every state transition is audit-logged**, including who approved.
- **Prints are stamped and logged.** An uncontrolled printed copy is the
  classic finding. If you render a PDF of a controlled document, stamp
  it with rev, print timestamp, and "uncontrolled when printed."
- **A drawing revision is a document revision.** If Part Viewing is also
  active, the two share `PartRevision` (see the dependency note).
- **If files live in Box/Dropbox/SharePoint, the app still owns the rev
  letter.** Their built-in version history is not your revision record —
  running both is the same second-source-of-truth failure, and it fails
  quietly: someone edits in place, the file changes, the rev letter
  doesn't move, and a controlled document is now uncontrolled. See
  § File storage.

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

- **Scrap and rework quantities must reconcile.** Qty ordered, qty scrapped,
  qty reworked and qty shipped are one arithmetic identity. If they drift,
  either the customer is billed for parts they didn't get or you eat parts
  you made — both are `MONEY-1` problems wearing a quality costume.
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

**Status:** new. The most-requested integration in a shop that already
lives in one of these, and the one with the most hidden consequences.

**The default is the kit's own storage** (S3-compatible, tenant-first
layout, `docs/STACK.md` § Part viewing). Using an outside service is a
deliberate trade, not an upgrade — make it knowingly.

**Three modes. Pick one and say which; they are not interchangeable.**

| Mode | What it means | Honest read |
|---|---|---|
| **Reference** | The file stays in Box/Dropbox. You store a pointer and a link. | Cheapest. The app never really has the file — no thumbnails, no CAD derivatives, no portal preview, and no audit of who opened it. |
| **Ingest** | On upload the file is copied into your storage; theirs is the drop-off. | **The recommended one.** Staff keep the folder habit they already have; the app owns the copy that matters. |
| **Two-way sync** | Both sides authoritative, changes propagate. | Two sources of truth for the same bytes, plus conflict resolution. Avoid unless someone insists and then argue once. |

**Four consequences people discover late:**

1. **Their permission model becomes your permission model.** The kit's
   tenancy rests on every portal query filtering by `clientId`, with
   files laid out tenant-first. Once the file lives in Box, *Box's*
   sharing settings decide who can read it — and one "anyone with the
   link" folder silently bypasses every auth wrapper you wrote. In
   Reference mode this is not a bug you can fix in your code. Ingest
   mode is partly why it's recommended.
2. **Audit stops at your boundary.** A download straight from Dropbox
   never reaches your audit log. For export-controlled files and for
   AS9100 records this defeats the requirement — `docs/STACK.md`
   § Part viewing already says controlled files get proxied through the
   app so the access is logged. That rule outranks the convenience.
3. **Doc control owns revisions — the storage service does not.** This
   is the collision worth planning for: Box, Dropbox, and SharePoint all
   keep their own version history, and Doc Control keeps rev letters
   with approval state. **Two version histories for one drawing is a
   second source of truth**, exactly like the `PartRevision` case above.
   The rule: the app owns `DocumentRevision`; the service is a dumb blob
   store whose native versioning is *not* the record. If someone edits
   in place in Dropbox and the rev letter doesn't move, your controlled
   document quietly became uncontrolled.
4. **Derivatives stay in your storage.** GLB previews and thumbnails are
   generated data the viewer loads by presigned URL — they belong beside
   your `FileDerivative` rows, not in the customer's Dropbox, whatever
   mode the original uses.

**Export-controlled and CUI**: the `mayReceiveControlledData` gate
applies unchanged. Commercial Box/Dropbox/Drive tenants are third-party
hosted services; some vendors offer government-community tiers, and
whether one satisfies your obligation is an assessor question, not a
marketing-page question (`docs/DEPLOYMENT_TARGETS.md` § The egress trap).

**Portal face:** none directly — customers keep using the portal's file
view, which is the point. The integration changes where staff put files,
not how customers get them. If a customer would end up in someone
else's Box, the design is wrong.

### Accounting sync — QuickBooks · Xero · Puzzle

Company scope. Pushes invoices, credit notes, and payments outward;
pulls payment status back. Two rules: **sent-invoice immutability still
holds** — the external system never rewrites an invoice in your app,
corrections flow through a CreditNote as they already do — and every
push carries an idempotency key, because a retried invoice post is a
duplicate in someone's books.

### Toolpath (DFM analysis)

**Status:** new. API at `developers.toolpath.com`.

A CAD-analysis service: it takes a part and returns
design-for-manufacturability information. **Verified against the live spec
on 2026-09-05** (`GET https://api.toolpath.com/v1/openapi.json`, Toolpath
Engine API v1.3.3) — pin the spec version you generate a client against,
because everything below is a fact about *that* version:

- **Paths**: `/v1/parts`, `/v1/parts/{id}`, `/v1/parts/{id}/features`,
  `/v1/holders`, `/v1/jobs`, `/v1/jobs/{id}`, `/v1/jobs/{id}/events`,
  `/v1/keys/validate`, `/health`.
- **Auth is an API key sent as a `Bearer` credential** (`type: http`,
  `scheme: bearer`) — not an `X-API-Key` header, which is the wrong guess a
  hand-rolled client makes first. Company scope, not OAuth.
- **`/v1/keys/validate` exists** — use it as the integration's health check
  so a dead key surfaces before a job does, not after.

⚠️ **Everything is millimetres and degrees.** The spec is explicit: all
dimensional values, in parts and in feature details, are in **mm**; all
angles in **degrees**; each part response repeats it in a `units` field. A
US shop quoting in inches that treats a DFM dimension as inches is out by
25.4×, silently, in a number that feeds a price. **Convert at the boundary,
store one unit, and assert the `units` field on every response** — this is
the same class of bug as an unlabelled timezone or a float dollar, and it
belongs in the same category of care (`MONEY-1`).

⚠️ **Never put the key in the browser.** CORS is configured per key, so a
key with allowed origins *will* work from client-side code — and a Bearer
credential in a client bundle is a leaked credential. Server-to-server
only, from the worker, with the key in the host's secret store
(`secure_coding.md` § 8). A key with no allowed origins is server-only by
construction; prefer that.

Why it fits this kit unusually well: **the same uploaded STEP file feeds
two async derivations off one pattern.** Part Viewing runs OCCT to GLB
for the viewer; Toolpath uploads and gets DFM back for the quote. Same
`File`, same queue shape, same pending/ready/failed states PORTAL_UX
already requires you to render. The second one is nearly free once the
first exists.

**There are no webhooks — but do not poll.** The spec declares an empty
`webhooks` section, so nothing calls you back. It *does* offer
**`GET /v1/jobs/{id}/events`, a server-sent event stream**: it sends the
current job immediately, then every subsequent status, progress or error
change while the connection stays open. Consume that from the worker rather
than looping on `GET /v1/jobs/{id}` — it is fewer requests, lower latency,
and it gives you progress rather than a binary done/not-done.

**Reconnection is the part to get right.** The spec says a dropped
connection means reconnecting to receive the latest snapshot before
resuming. So the worker still needs a give-up bound and a resume path, and
the job row still needs `pending / processing / ready / failed` — an
interrupted stream must not leave a part stuck in `processing` forever.
Either way this lives in the worker, never in a request handler waiting on
a third party.

Where the output lands: DFM findings attach to the `PartRevision` and
surface in **Estimates** — manufacturability feedback is quoting input,
which is the actual friction this removes.

⚠️ **The export-control gate is mandatory here.** Toolpath is a
third-party hosted service, and `docs/STACK.md` § Part viewing already
says flagged files are never sent to one. An export-controlled STEP file
must be refused at the uploader by the `mayReceiveControlledData` check
above — not filtered downstream, and not left to the operator to
remember.

**Open decision, don't default it:** is DFM output customer-visible?
Staff-only is the safe read — it's your cost intelligence. But a portal
that tells a customer "this pocket is unmachinable as drawn" before they
order is a real friction-remover. Decide it explicitly per the parity
rule; either answer is fine, silence isn't.

### Payments

Already in the catalog. Webhook-driven — `secure_coding.md` § 16 governs
it, and the handler re-fetches the amount from the provider rather than
trusting the payload.

### Transactional email (Resend · Postmark · SES)

**Start this on day one, before you need it.** Not because email is hard,
but because it has the longest lead time of anything in the kit, and it
**blocks the portal**: customer login is a magic link, so until mail
actually arrives, no customer can get in. Domain verification means adding
DNS records and waiting for propagation — minutes if you are lucky, a day if
your DNS lives somewhere awkward. Every other setup step is under your
control; this one is not.

**Setup, in the order that avoids being blocked:**

1. **Pick a provider** — Resend (the kit's default, pairs with React Email
   for typed, previewable templates), Postmark, or SES if you are already in
   AWS and want mail in-partition (`docs/DEPLOYMENT_TARGETS.md` § The egress
   trap). All three are equivalent for this app; do not spend a day choosing.
2. **Start domain verification immediately.** You will add **SPF**, **DKIM**
   and ideally **DMARC** records for a subdomain you send from —
   `mail.yourshop.com` keeps your main domain's sending reputation separate
   from your website's. Do this on day one even if you will not send for
   weeks.
3. **Do not wait for it to build anything.** In dev the mailer writes the
   message to the console, magic-link URL included, so you can log in as a
   customer with no provider configured at all. That fallback is what keeps
   DNS off the critical path.
4. **Verify before go-live**, not before development: send one real magic
   link to a real inbox, and check it does not land in spam.

**The rules that matter once it is live:**

- **The dev fallback must be unable to run in production**, the same way the
  auth stub cannot (`SEC-2`). A mailer that silently logs instead of sending
  is worse than one that errors: invoices and magic links stop arriving and
  nothing tells you.
- **Every send is logged, and a failure alerts a human** (`OPS-3`,
  `CLAUDE.md` § No Swallowed Failures). A dead sender means invoices and
  logins silently stop, and you find out when a customer calls — which is
  the friction this whole system exists to remove.
- **Handle bounces and complaints.** Sending repeatedly to a dead address
  wrecks your sender reputation and takes the working addresses down with
  it. Keep a suppression list; a hard bounce marks the contact and surfaces
  on the client record so a human fixes it.
- **Magic-link mail follows `secure_coding.md` § 13** — short expiry, one
  active link, and remember that mail-security scanners pre-fetch links, so
  a link must not be consumed by a bot's GET.
- **Email is an egress path.** An invoice PDF or a job-status mail carries
  your content to a third party. If Phase 3 said ITAR or CUI that matters
  directly: keep controlled data out of bodies and attachments, or send
  in-partition (`CUI-1`).
- **Customer-facing copy runs through `/perp-voice`** — auth, money and
  legal strings excepted. Email is where the shop's voice reaches the
  customer most often.

**Portal face:** none, but the *effects* are portal-visible — a customer
whose magic link never arrives experiences it as "the portal is broken".
Give the login page a "didn't get it? request a new link" path and the
request-ID pattern from `secure_coding.md` § 6.

## Compliance posture (a dimension, not a module)

This sits alongside the ITAR/EAR question `CLAUDE.md` § What It Is
already asks. Both regimes reduce to the same three questions, asked of
**every** module: who may see this, may it leave the network, and what
do we keep.

**Data classification** generalizes the existing `File.exportControlled`
flag into a classification the whole system reads: unrestricted ·
export-controlled (ITAR/EAR) · CUI (CMMC). One field, checked in one
predicate, honored by every module and every integration.

What CMMC adds beyond what the kit already does — and it already does a
fair amount of it (append-only audit log, tenant isolation, the
incident-response runbook, encrypted secrets):

- **Audit records themselves must be protected and retained**, not just
  written. The retention period is a decision, not a default.
- **MFA for privileged access**, and session lock. This lands on the
  real-login gate that's already a before-go-live item.
- **Media protection** — encryption at rest, and sanitization on delete
  rather than a soft-delete flag.
- **Egress control** — CUI reaching an unapproved third party is the
  same structural gate as ITAR, which is why it's one field and one
  check.

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
them. The defense is the one already specified above: one
classification, one predicate, checked at every egress point, with the
integration scaffold's `mayReceiveControlledData` as its enforcement.

**AS9100 is different in kind:** it wants controlled documents,
traceability, and records — which is why doc control earns module status
and CMMC doesn't.
