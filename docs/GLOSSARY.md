# Glossary — plain-language definitions

One line each, for the non-engineer reading these docs. Terms appear
throughout the primer without further explanation.

**Before the domain terms — the words you meet in the first five minutes:**

- **Claude Code** — Anthropic's AI coding assistant. It runs in a terminal window on your computer, reads the files in your project, and writes code. Paid subscription. This kit is a set of instruction files it reads.
- **Repo (repository)** — the folder holding your project, tracked by git so every change is recorded and reversible.
- **Commit / push** — *commit* saves a snapshot of your changes locally; *push* uploads them to a shared copy (e.g. GitHub). They are separate on purpose: committing is private, pushing is publishing.
- **Clone / fork** — *clone* copies someone's repository to your machine; *fork* makes your own copy on GitHub. Neither is how you adopt this kit — see README adoption step 1.
- **Terminal** — the text window where you type commands and Claude Code runs.
- **Skill / slash command** — a `/name` command you type in the chat that runs a pre-written playbook, like `/perp-scope`.
- **`<TODO>`** — a placeholder in these docs marking something only you can answer. Not all of them are yours to fill on day one; ask Claude which ones still need you.
- **Env var (environment variable)** — a setting passed to the app at run time rather than written in the code. Where secrets live.
- **Schema** — the shape of your database: which tables exist and what columns they have. "Schema-shaped decision" means changing it later requires migrating live data.
- **Prune** — delete the parts of this kit you don't need, on purpose, rather than carrying dead rules forward.
- **VPS (virtual private server)** — a rented Linux computer in a data centre. The kit's default place to run the app; you own patching it.
- **a11y** — shorthand for *accessibility* (a, then 11 letters, then y).
- **Guide / sensor** — a *guide* steers before the fact (a document, a skill); a *sensor* observes after it (a type check, a test, a grep). Guides are weak because following them is optional. `docs/CONTROLS.md` splits every rule this way.
- **Gate / drift signal** — a *gate* stops something: a red build blocks the merge. A *drift signal* is a number you watch and never fail on, because a hard threshold on it invites gaming (coverage is the classic). Promoting a drift signal to a gate is a mistake, not an upgrade.
- **Required status check / branch protection** — the GitHub setting that makes a red build actually block the merge button. Without it a failing check is only a red mark somebody can ignore (`docs/GITHUB.md`).
- **Mutation test** — deliberately breaking something to confirm the check that guards it goes red. `scripts/kit-check-selftest.sh` does this: a guardrail nobody has watched fail is not yet a guardrail.
- **Fail closed / fail open** — a *fail-closed* control refuses when it is unsure (safe); a *fail-open* one permits. A login guard that only blocks when it can positively confirm "production" fails open, because an unset setting lets it through.
- **Spine** — the parts of the system nothing works without: clients, projects, phases, tasks, time, invoices. Never optional (`docs/MODULES.md`).
- **Module** — a capability you can leave out entirely, like scheduling or doc control. Catalogued is not the same as planned.
- **Dimension** — something that cuts across everything and can never be an optional module: the customer portal, and your compliance posture. You do not "do the portal later"; every feature ships its portal face with it.
- **Pin / lockfile** — *pinning* means recording an exact version of a library ("7.10.0", not "^7"). The *lockfile* records the exact versions of everything, including libraries your libraries use. Together they stop an unrelated install from silently upgrading you.
- **Egress** — data leaving your network. The "egress trap" is about which outside services your files reach.
- **Rollup** — a number computed by adding up other rows (a project's total hours). Storing one creates a second source of truth, which is why the kit is strict about them.
- **Invariant** — a rule that must always hold, no matter what. The money rules in DOMAIN_MODEL are invariants.

**The regulatory acronyms** — Phase 3 of `/perp-scope` asks about these, and a wrong answer has legal consequences rather than just architectural ones:

- **ITAR / EAR** — US rules covering defense and export-restricted technical data. If a customer's drawings are covered, *who may see the file* and *where it may be stored* are legally constrained, not preferences. Defense subcontractors often qualify without realising.
- **CUI (controlled unclassified information)** — government information that isn't classified but must still be protected. Comes with contract clauses about how you store and handle it.
- **CMMC** — the US Department of Defense certification that proves you handle CUI properly. Affects access control, audit logs, encryption, and possibly where the system may run.
- **AS9100 / ISO 9001** — quality-management certifications (AS9100 is the aerospace one). They require controlled documents, records of what you inspected, and traceability.
- **HIPAA** — US rules for health information.
- **PCI** — the card-industry rules that apply if *you* store card numbers. The kit's answer is: don't — let a payment provider hold them.

**Domain terms:**

- **ERP** — the software that runs the business's operations: customers, jobs, hours, invoices, payments, in one system of record.
- **Tenant / multi-tenant** — one customer company's walled-off slice of the data. You are multi-tenant if more than one customer company will ever log into the portal. In this primer, **tenant = Client**.
- **POC** — point of contact: a person at a client company who can log into the portal.
- **Two auth realms** — staff and customers log in through completely separate systems; a staff login can never open a portal session or vice versa.
- **Magic link** — login via an emailed one-time link instead of a password.
- **SSO / IdP** — single sign-on: logging in via a company identity provider (Google Workspace, Microsoft Entra) instead of a local password.
- **IDOR** — insecure direct object reference: reaching someone else's record by changing an ID in the URL. The bug tenant isolation exists to prevent.
- **CSRF** — cross-site request forgery: a malicious site making your logged-in browser perform actions without your intent.
- **Webhook** — an automated message a provider (e.g. Stripe) POSTs to your server when something happens ("this invoice was paid"). Unauthenticated by default — must be signature-verified.
- **Idempotent** — safe to run twice with the same result; how you keep a retried webhook from applying a payment twice.
- **ORM** — the code layer that translates between your programming language and the database.
- **Migration** — a scripted, ordered change to the database's structure; how the schema evolves without losing live data.
- **State machine** — a value with a fixed set of states and allowed moves between them (draft → sent → paid), instead of loose true/false flags.
- **Discriminated union** — the code representation of a state machine: a type that is exactly one of several named shapes.
- **Parity** — the discipline that a number or behavior shown on both the internal app and the portal is computed by the same code and always matches.
- **Audit log** — the append-only record of who changed what, when, from what to what. The forensic memory of the ERP.
- **Minor units** — storing money as integer cents (1050 = $10.50) so arithmetic is exact; floats round wrong.
- **Billing atom** — the one unit of work your invoices are built from: a shipped part, a signed-off milestone, or a billed hour. Picking it is a schema decision, not a preference.
- **Contract manufacturing / per-part billing** — you invoice for units shipped and accepted, priced each or as a lot/package. **Milestones / fixed-price** — one price per job, invoiced on completion or at agreed stages. **Time-and-materials** — customer pays after the work, per hours billed. **Retainer / hour pool** — customer prepays a block of hours.
- **Deposit** — money taken before the work is earned (often a % at quote acceptance). Different from a retainer: a deposit prepays money, a retainer prepays hours. **Drawdown** — crediting what's already been paid against each later invoice, so nothing gets billed twice.
- **Change order** — a written, accepted revision to price or scope after work has started. The thing that prevents the end-of-job argument.
- **Inventory / stock** — material or goods you hold on the shelf and draw from. If you instead buy material per job as it comes in, you don't have inventory — you have job costs.
- **Dunning** — the follow-up sequence for getting overdue invoices paid.
- **RPO / RTO** — how much data you can afford to lose / how long you can afford to be down, when restoring from backup.
- **PSA** — professional-services automation: off-the-shelf software covering the clients → projects → time → invoices loop. The "buy" alternative in the build-vs-buy decision — search "professional services automation software" (the category containing tools like Accelo, Scoro, Avaza) to price it.
- **Greenfield / brownfield** — a brand-new empty repo vs an existing codebase with history and conventions already in place.
- **CI (continuous integration)** — a robot that runs your checks (tests, type check, build) automatically on every change pushed to the repo, and fails loudly when something breaks.
- **Type check** — a fast automated pass that catches mismatched code (wrong argument type, missing field) without running the app.
- **Coverage** — a report of which lines of code the tests actually exercised. A guide for finding untested logic, not a score to chase.
- **E2E (end-to-end) test** — a test that drives the real app in a browser the way a user would, as opposed to a unit test of one function.
- **Entity factory** — a test helper that mints realistic linked records (a client + a user + a project) so every test starts from plausible data.
- **Mock** — a stand-in for a real dependency (the email provider, the clock, the payment API) so tests run fast and predictable.
- **Pre-push hook** — a script git runs right before publishing your commits that blocks the push if the fast checks fail; the local mirror of CI.
- **Secret rotation** — replacing a leaked key with a new one at the provider and everywhere it is stored. Deleting the message or commit that leaked it is not enough — the old value is still out there.
- **Vertical slice** — one thin path built end-to-end (screen → logic → database) rather than one whole layer at a time.
- **STEP / IGES / STL** — CAD file formats. STEP and IGES carry exact engineering geometry (what customers send a machine shop); STL is just triangles (what 3D printers eat, and what browsers can display directly).
- **glTF / GLB** — the compact 3D format browsers render natively; GLB is its single-file form. CAD files get converted to GLB once so a phone on shop Wi-Fi can view a part.
- **Tessellation** — converting exact CAD geometry into triangles for display. Good enough for viewing; not for measuring.
- **OpenCascade (OCCT)** — the open-source engine that reads and converts CAD formats; the machinery behind the part-viewing pipeline in `docs/STACK.md`.
- **Outside processing** — sending parts to another shop for a step you don't do in-house (anodizing, plating, heat treat). Ordered with a vendor PO; the cost comes back into the job as an expense.
- **Traveler (router)** — the paper packet that physically follows parts across the shop floor: the job's routing steps plus drawings.
- **Work center** — a machine or station a routing step runs on (saw, CNC mill, deburr bench).
- **RFQ** — request for quote: what a customer sends you (or you send a supplier) to get a price.
- **Dispatch list** — per machine/station: the jobs that are ready to run, ordered by due date. The "what do I run next?" answer — a sorted query, not a scheduling engine.
- **APS (finite-capacity scheduling)** — software that plans work against real machine/people capacity. A whole product category; the reason the kit says "dates and dispatch list first, planning board maybe never".
- **Stack** — the set of programming tools an app is built with (language, framework, database). This kit's is decided: `docs/STACK.md`.
- **Next.js terms — App Router / route group / route handler / server action** — the framework's pieces: the App Router is its modern page system; a route group is a folder that gives one section (like the portal) its own layout and login; a route handler is a server endpoint (where this kit puts all data changes); a server action is an alternative the kit deliberately doesn't use for changes.
- **RSC (React Server Components)** — the App Router's way of splitting code between the server and the browser. Powerful, occasionally confusing — the reason stack rules are "pinned".
- **Serverless** — hosting where code runs in short bursts on demand instead of on an always-on server. Great for simple sites; wrong for this product, which needs an always-running background worker (see `docs/STACK.md` § Deployment).
- **Docker / container** — packaging the app plus everything it needs into one runnable unit, so it works the same on any machine. The kit's deploy shape is one such package running the web app, the worker, and the database together.
- **Worker (background jobs)** — the always-running process that does work not tied to a click: flipping invoices to overdue, sending digests, converting CAD files.
- **Presigned URL** — a temporary, expiring link that lets a browser fetch one file directly from storage without the file passing through the app server.
- **WASM (WebAssembly)** — a way to run heavyweight native code (like the OpenCascade CAD engine) inside JavaScript environments.
- **TOTP / MFA** — the six-digit authenticator-app code (TOTP) used as a second login factor (MFA) for staff accounts.
- **Monorepo** — one repository holding several packages or apps at once. It complicates tooling: every setup step has to say *which* package it applies to, and CI has to work out which packages a change actually affects.
- **UTC / DST** — UTC: the universal reference clock all timestamps are stored in. DST: the daylight-saving jumps that make local clocks shift — the reason "what day is it" needs one declared timezone.
