# The Stack — decision record

_Reviewed: 2026-09-05 — the ecosystem claims below (library maturity,
versions, CLI shapes) rot faster than principles. `PIN-5` in
`docs/CONTROLS.md` now enforces this stamp: a warning past 90 days, a
failure past 180. Last re-verify found two breaking Prisma changes in one
afternoon — see § Getting a database._

**Not a developer?** You don't need this file — the choice is already
made, and `/perp-scope` confirms it in one plain question. This
document exists for developers, and for future-you deciding whether to
deviate.

The primer is **opinionated**: it selects one default stack instead of
staying stack-agnostic, because the target adopter — a small company,
often one AI-assisted developer — is better served by a decided path
than a menu. This document records what was chosen, why, and what to do
if you deviate.

## The default stack

**Next.js (App Router) + TypeScript + Prisma + PostgreSQL**, deployed
as a plain long-running Node server — **explicitly not serverless** —
one Docker compose (web + pg-boss worker + Postgres) on a small VPS or
PaaS.

Per-concern picks — exactly one library per problem. This table IS the
"batteries" for this stack: adopters follow it instead of choosing.

| Concern | Pick | Notes |
|---|---|---|
| Framework | Next.js, **App Router only** | conventions pinned in CLAUDE.md § Tech Stack — see § Pinned conventions below |
| Language | TypeScript, strict | the compiler is the hallucination net for AI-assisted work |
| Database | PostgreSQL | the gold standard at this ceiling |
| ORM / migrations | Prisma (`prisma migrate`; hand-edited SQL migrations for triggers/constraints the DSL can't express) | see § Integrity below — this is a rule, not a footnote. **Pin it exactly, like Better Auth: no `^`, lockfile committed.** ⚠️ Verified 2026-09-05: `npm install prisma` installs whatever the **`latest` dist-tag** points at, and that was an **8.0.0 release candidate** with a restructured CLI — no `generate`, no `validate`, no `migrate dev`. That breaks `/perp-check`'s codegen step, the CI template and the deploy runbook simultaneously, and it happens on a clean install with no warning. Run `npm view prisma dist-tags` before pinning and take the newest **stable** (`prev` was 7.10.0 when this was checked). |
| Validation | Zod at every boundary | pairs with react-hook-form on forms |
| Staff auth | Better Auth instance #1 — email/password + `twoFactor` (TOTP) | **pin = exact version in package.json (no `^`), lockfile committed**; upgrade only deliberately: read the changelog for session/cookie/plugin changes → bump in a branch → run the auth-realm tests. Conservative fallback: hand-rolled DB sessions (the Lucia sessions guide pattern — lucia-auth.com — ~300 lines, fully owned) |
| Portal auth | Better Auth instance #2 — `magicLink` plugin | separate cookie names, separate session tables, **and a separate signing secret per realm** (two env vars — never share signing material across realms). Two instances in one app is off the library's happy path: expect per-instance table remapping (e.g. `staff_session` vs `portal_session` via model mapping) and two handler mount paths. If the remapping fights your pinned version, the hand-rolled fallback is the simpler road to two realms |
| Payments | official `stripe` SDK; raw-body webhook route + `constructEvent`; processed-events table for idempotency | exactly the `secure_coding.md` § 16 pattern |
| Email | Resend SDK + React Email (typed, previewable templates) | Postmark equally fine |
| Files / S3 | `@aws-sdk/client-s3` + `s3-request-presigner` | works on S3/R2/B2/MinIO. **Presigned uploads bypass the framework, so § 17's checks move**: constrain the presigned POST policy (size + content-type), and a post-upload verification job (magic bytes, size) flips the file visible only after it passes. Presigned GETs default to minutes-long TTLs, not hours |
| Background jobs | pg-boss (Postgres-native, SKIP LOCKED, built-in cron) | no Redis. **Payloads carry entity IDs only** — the worker re-fetches through the same `lib/` helpers and tenancy predicates; queue/archive rows sit outside every visibility gate, so they must never hold customer data. Wire `onFailed`/dead-letter events to the same alert channel as webhook failures (a page someone must visit is not an alert), and set archive retention explicitly |
| PDF invoices | `@react-pdf/renderer` — invoices as typed React components sharing the same money/number helpers as both web surfaces | parity at the PDF layer; fallback for pixel-perfect letterhead: Playwright's Chromium rendering HTML→PDF in the worker |
| UI | Tailwind + shadcn/ui; react-hook-form + Zod resolver | highest LLM fluency of any component approach. **A11y baseline is `docs/PORTAL_UX.md`**: shadcn/Radix gives keyboard+roles out of the box, but components are *copied into your repo* — treat aria/focus attributes as load-bearing when editing copies (the compiler can't see them), and you own focus-visible styles and contrast in Tailwind |
| Dates | store UTC instants; `date-fns` + `@date-fns/tz` for the canonical-timezone day-boundary logic | DOMAIN_MODEL invariant 9 |
| Part viewing | occt-import-js (OpenCascade WASM, runs in Node) in the pg-boss worker → GLB; three.js/`<model-viewer>` client | see § Part viewing |
| Testing | Vitest + Playwright with merged coverage | `/perp-setup-testing` wires Vitest, factories, CI, and the pre-push hook; Playwright + merged coverage is the follow-on in `docs/TESTING-PIPELINE.md` |

## Pinned conventions (the churn defense)

The panel's strongest argument *against* this stack was idiom churn and
training-data contamination. The defense is pinning — these lines also
live in CLAUDE.md § Tech Stack so Claude reads them every session:

- **App Router only.** No Pages Router idioms, ever. If Claude emits
  `getServerSideProps` or Pages-style API routes, that's drift — reject
  it.
- **Route handlers are the one mutation door.** Every mutation goes
  through a route handler wrapped by the auth helpers — that's where
  the wrapper composition, 404-not-403 tenancy, request IDs, Zod
  validation, and same-transaction audit writes all live
  (`secure_coding.md` § 1–7). Server actions are **not used for
  mutations** until `secure_coding.md` maps every one of those rules
  onto them — a mixed mutation layer, half outside the security
  checklist, is exactly what an AI-assisted codebase drifts into.
- **`import 'server-only'`** at the top of every module that touches
  the DB or secrets. This makes a client-bundle import a build error —
  the kit's server-boundary rule, enforced by the compiler.
- **Two route groups, one lib**: `(app)/` for staff, `portal/` for
  customers — separate root layouts, separate cookies, separate
  middleware *routing*; all business logic in shared `lib/`, called by
  both. This is CLAUDE.md § Parity as directory structure.
  **Middleware is defense-in-depth, never the auth boundary** — auth is
  enforced by the per-route wrappers (`secure_coding.md` § 2); a
  middleware-only check is one framework bug or one missed matcher away
  from an open portal (the Next.js middleware-bypass CVE class).
- **The deploy target is pinned** (standalone Docker, § Deployment).
  When any tutorial, tool, or model suggests Vercel/serverless, the
  answer is no — see § Deployment for why.

## Getting a database, and the two Prisma gotchas

**Verified by running the adoption flow on 2026-09-05.** Both of these stop
a new adopter cold, and neither is guessable.

### You need a Postgres before `/perp-build-core` will run

It refuses to start without one, on purpose — SQLite cannot express the
integrity constructs below. Pick whichever is true of your machine:

| If you have | Do this | Notes |
|---|---|---|
| Docker | `docker run -d --name pg -e POSTGRES_PASSWORD=devpw -p 5432:5432 postgres:17` | Simplest. Stop it with `docker stop pg`. |
| Nothing, and you'd rather not install | Download EDB's **binaries-only zip** (not the installer), unzip it, `initdb -D pgdata`, `pg_ctl -D pgdata -o "-p 55432" start` | No service, no admin rights, no PATH change. Delete the folder to undo it. This is what a locked-down shop laptop can do. |
| A managed Postgres already | Point `DATABASE_URL` at it | Use a *non-production* database. |
| Windows and you want it permanent | `winget install PostgreSQL.PostgreSQL.17` | Installs a service on 5432 that starts at boot. |

**Use a non-standard port if 5432 might be taken** — check first
(`Get-NetTCPConnection -LocalPort 5432` on Windows), because a port clash
surfaces as a confusing connection error rather than "something else is
here".

### Gotcha 1 — `latest` may be a release candidate

`npm install prisma` installs whatever the **`latest` dist-tag** points at,
and on 2026-09-05 that was an **8.0 release candidate** whose CLI has no
`generate`, no `validate` and no `migrate dev`. That breaks `/perp-check`'s
codegen step, the CI workflow and the deploy runbook at once, on a clean
install, with no warning. **Run `npm view prisma dist-tags`, take the newest
stable, and pin it exactly** (no `^`), lockfile committed — the same
treatment Better Auth already gets.

### Gotcha 2 — Prisma 7 moved the connection string out of the schema

`url = env("DATABASE_URL")` inside `datasource db { }` is **rejected** from
Prisma 7 onward. The connection now lives in `prisma.config.ts` at the repo
root:

```ts
import 'dotenv/config'
import { defineConfig, env } from 'prisma/config'

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations' },
  datasource: { url: env('DATABASE_URL') },
})
```

and the schema block keeps only the provider:

```prisma
datasource db {
  provider = "postgresql"
}
```

At runtime the client takes an **adapter** rather than reading the schema:

```ts
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL })
export const db = new PrismaClient({ adapter })
```

Most tutorials and most training data still show the old shape, which is
exactly the idiom-churn tax § Honest costs warns about — here it costs a
confusing `P1012` on your first migration.

## Integrity (the below-the-ORM defense)

The panel's second Django argument: Prisma's DSL can't express the
money-critical constructs, so they drop to raw SQL. True — so they are
**rules with owners**, not improvisations:

- **Money is integer minor units** in `Int`/`BigInt` columns.
  JavaScript has no native decimal — this discipline is load-bearing
  (CLAUDE.md § Money & Hours); `Prisma.Decimal` only where fractional
  rates are unavoidable.
- **Gap-free invoice (and vendor-PO) numbering**: a counters row locked
  with `SELECT ... FOR UPDATE` via `$queryRaw` inside an interactive
  `prisma.$transaction`. Never `MAX()+1`.
- **Invoice immutability, belt and braces**: app-level via a Prisma
  `$extends` audit hook, AND a Postgres **trigger** (hand-edited SQL
  migration) that rejects UPDATEs to the *financial columns* — line
  items, amounts, invoice number, issue date — once status leaves
  `draft`, while still allowing the status-machine transitions
  (sent→paid, sent→overdue, paidAt). A blanket `REVOKE UPDATE` would
  block the app's own legitimate transitions and, on the default
  single-role Prisma setup, is a no-op anyway (the runtime role owns
  the table). If you want REVOKE-level protection, the prerequisite is
  a **runtime DB role distinct from the migration/owner role** (Prisma
  supports this via `directUrl` for migrations) with column-level
  `GRANT UPDATE (status, paid_at)` — otherwise rely on the trigger.
- **Jobs are enqueued transactionally or via an outbox.** `boss.send()`
  next to (not inside) a `prisma.$transaction` splits: a rolled-back
  acceptance still fires its job (ghost invoice/email), a committed
  upload can miss its conversion job. Either insert the job row within
  the same transaction (raw insert into pg-boss's job table /
  `boss.insert` on a shared connection) or write an outbox row
  in-transaction and let the worker drain it. This is an integrity rule,
  not a nicety — DOMAIN_MODEL invariant 6 (atomic acceptance fan-out)
  depends on it.
- Every one of these raw-SQL spots is exactly where the type system
  can't catch an LLM mistake — **each gets a dedicated test** (the
  invariant tests in DOMAIN_MODEL § Invariants; testing is the net
  here).

## How it was decided

An advocate/judge panel scored six candidate stacks (2026-07-03).
Weights: AI-assistability 25%, small-team ease 25%, ecosystem fit 20%,
integrity 10%, CAD 10%, hiring 10%.

| Candidate | SMB judge | Integrity judge | AI judge | Aggregate |
|---|---|---|---|---|
| Django + HTMX + PostgreSQL | 88 | 88 | 83 | 259 |
| **Next.js + TypeScript + Prisma + Postgres** | 82 | 82 | **84** | 248 |
| Rails 8 + Hotwire + Postgres | 83 | 84 | 81 | 248 |
| Laravel + Livewire/Filament + Postgres | 84 | 82 | 77 | 243 |
| ASP.NET Core + Blazor + EF Core | 79 | 79 | 79 | 237 |
| SvelteKit + Drizzle + Postgres | 77 | 79 | 78 | 234 |

**The decision is a documented override of the aggregate.** The panel's
aggregate favored Django; the maintainer selected the runner-up, siding
with the AI-development judge, on the judgment that the primer's
ultimate users tilt the real weights further toward that lens than the
panel's 25% captured:

- **The kit's users build AI-first.** The compile-time hallucination
  net (TypeScript + Prisma's generated client turning wrong-field/wrong-
  shape errors into build failures) protects the exact workflow every
  adopter of a Claude Code kit lives in — the cheapest correction loop
  in AI-assisted work, applied to money-bearing code.
- **Kit alignment is real**: the primer was extracted from a Next.js
  production ERP; `TESTING-PIPELINE.md` and the testing conventions are
  native to this stack — proven material, not rewrites.
- **CAD is one language end-to-end**: occt-import-js runs in the worker
  and (as a fallback) the browser; the panel's CAD specialist rated the
  Node path most natural.
- The two arguments Django won on — idiom churn and below-the-ORM
  integrity — are mitigated by design above (§ Pinned conventions,
  § Integrity) rather than ignored.

Was the outcome ever in doubt? Fair question — kit alignment predated
the panel, so state the falsification condition plainly: the panel's
job was to test whether that path dependence should be *overridden*,
and it survived by one point on the AI lens. **Had Django swept all
three judges, the kit would have been rewritten for Django** — the
v0.7.0 release history shows exactly that willingness, since the kit
shipped Django as the default for several hours on the panel's
aggregate before the override.

Django remains the documented second choice for adopters who weigh
batteries and idiom stability higher — the panel report records its
full case.

## Deployment

The deployment shape is dictated by the product, not the stack: **a web
process + a worker process + Postgres**. Concretely: `next build` with
`output: 'standalone'` yields a self-contained Node server; one Docker
compose runs it beside a pg-boss worker process and Postgres on a
$10–20 VPS (Coolify, plain Docker) or a Railway/Render-class PaaS. One
language, one image, two processes (same image, different commands).
The executable version — compose skeleton, the **`prisma migrate
deploy` one-shot step that runs before web/worker start** (exactly one
process runs migrations; two racing from the same image is the classic
first outage), env injection, healthchecks, rollback — is
`docs/runbooks/deploy.template.md`; copy it before go-live. Choosing
the Playwright-Chromium PDF fallback changes the image materially
(hundreds of MB + system libs) — keep it out of the base image unless
you actually need it.

**Why not serverless / Vercel?** This is the most tempting wrong turn
on this stack — the ecosystem's tutorials and the training corpus both
push it, which is precisely why the target is pinned:

- An ERP needs a **long-running worker** — overdue-invoice flips,
  digests, budget alerts, STEP→GLB conversion. Serverless functions
  don't hold a job queue; bolting on external cron/queue services is
  exactly the ops surface a one-person team can't carry.
- **PDF generation and CAD conversion are slow and memory-hungry** —
  function-timeout and cold-start territory.
- **Postgres is a server anyway** (plus connection pooling if functions
  hammer it), so "no servers" has already leaked before the app ships.
- When Claude (or a tutorial) suggests deploying to Vercel, the pinned
  answer is no. If your product were portal-light and job-free, managed
  serverless would genuinely win — a custom ERP is nearly the opposite
  of that profile.

**The pin is a shape, not a vendor.** "Never serverless" rejects
*request-scoped functions* (Lambda, Vercel, Workers) — not managed
container platforms. ECS Fargate and Azure Container Apps run a normal
long-running Node process and honor the pin fully; AWS's marketing use
of "serverless" for Fargate means *no EC2 to patch*, which is a
different claim. `docs/DEPLOYMENT_TARGETS.md` maps this shape onto every
substrate worth considering — VPS, PaaS, AWS, **AWS GovCloud**, Azure,
GCP (where Cloud Run's request-driven model needs care for the worker) —
plus the CUI/ITAR constraints that can decide the question for you.

Deploy runbook: `docs/runbooks/` (bootstrap checklist schedules it).

## Honest costs (know them going in)

(a) **The upgrade treadmill is real, and it does not wait for you to be ready.** While testing the adoption flow on 2026-09-05 a clean `npm install prisma` pulled an 8.0.0 **release candidate**, because that is where Prisma's `latest` tag pointed — a restructured CLI that breaks three of this kit's own commands at once. Pin every load-bearing library to an exact version and check `dist-tags` before bumping; `latest` is not a promise of stability. More generally, churn here is
structural: the per-concern table's
independently-versioned libraries plus a framework with a documented
history of breaking transitions (Pages→App Router, async request APIs,
caching semantics). Budget periodic migration work — it has a row in
README § Operating cadence; the one-library-per-concern table keeps it
bounded, not zero. (b) **RSC (React Server Components — the App
Router's split of code between server and browser) / caching drift**:
even with pinned conventions, App Router mental-model mistakes happen —
review data-fetching and caching code with extra care. (c) **The raw-SQL integrity
spots** (§ Integrity) sit outside the type net — they carry mandatory
tests. (d) **No native decimal** — integer-cents is discipline, and the
discipline is load-bearing. (e) **Better Auth is young** (v1.0 late
2024) — pin the version, review changelogs before upgrading, and know
the hand-rolled-sessions fallback exists. (f) **pg-boss has no
dashboard** — build the minimal jobs admin page before the first
background job matters. (g) **Serverless gravity** (§ Deployment) —
the ecosystem will keep suggesting the wrong deploy target; the pin is
permanent.

## Part viewing (the OpenCascade provision)

Adopters who are machine shops / contract manufacturers will want
customers and staff to **view CAD parts in the browser**. The decided
architecture (per the panel's CAD specialist):

**Server-side conversion, once per file revision.** On upload, a
pg-boss job converts STEP/IGES → **GLB** using **occt-import-js**
(OpenCascade compiled to WASM — runs identically in Node, and being
pure WASM adds **no native deps to the Docker image**), then compresses
it with **gltfpack (meshopt)** — the compression step is what produces
the small tablet-friendly file; uncompressed tessellation output can
rival the source STEP's size. Pick and record a tessellation deflection
(the quality/size/RAM knob). The derivative lands in S3 beside the
original; the portal embeds **`<model-viewer>` as the default viewer**
(built-in keyboard controls and aria support — a bare three.js canvas
is invisible to screen readers; if you use three.js directly, you owe
equivalent keyboard controls), loading via presigned URL. The viewer
always carries an **accessible name (part + revision)** and a
**persistent "download original" link** beside it — the
conversion-failed link is the degraded case of an always-present
control, and it's also the screen-reader path. STL renders directly
with no conversion.

**Run conversion on its own pg-boss queue, concurrency 1, with a
per-job timeout and a file-size cap.** OCCT tessellation of a big
assembly holds hundreds of MB for minutes; on the recommended small
VPS, an uncapped batch of uploads OOMs the worker that also runs the
overdue-invoice flip — the silent-failure class the kit forbids. Heavy
CAD volume is the trigger to split a second worker container (one line
in the compose file).

**Provision now (cheap hooks, expensive to retrofit)** — these are in
the domain model:

1. **Schema**: `File.kind` ('model'|'drawing'|'document'),
   `File.contentHash`, `File.classification` (enum: `unrestricted |
   export-controlled | cui`); optional
   **Part → PartRevision → FileAttachment** so "the model for rev C" is
   a query, not a filename convention; a **FileDerivative** table
   (fileId, type 'gltf'|'thumbnail', storageKey,
   status pending/processing/ready/failed, error, sourceContentHash).
   A derivative is a cached rollup in the DOMAIN_MODEL invariant-11
   sense — regenerate when `sourceContentHash` drifts; the portal treats
   status ≠ ready as a first-class "preview pending / conversion failed"
   state per PORTAL_UX.md.
2. **Storage layout, tenant-first**:
   `{clientId}/{projectId}/files/{fileId}/original/{filename}` and
   `.../derived/model.glb` + `thumb.png` — derivatives inherit the
   original's access predicate by construction.
3. **Job hook**: reserve pg-boss job type `file.derive-preview`,
   emitted on upload; ship it as a stub (STL → ready immediately;
   STEP/IGES → "converter not configured") so enabling the OCCT worker
   later touches zero upload code.
4. **ITAR/export control**: the derived GLB **is** the same
   export-controlled technical data as the source STEP. The
   `classification` field gates original and every derivative
   identically; flagged files are **never** sent to third-party hosted
   converters. For the audit trail, remember a presigned URL is a
   bearer credential S3 serves without telling your app — so for
   flagged files, **proxy the download through the app** (bytes via
   the route handler, logged per request), or issue single-use
   URLs with single-digit-minute TTLs and log the *issuance* as the
   access event, re-issued per view. Thumbnail renders of flagged
   files are logged once per list-view/session, not per image fetch —
   decide it explicitly or implementers will silently skip it.

**Deferred deliberately**: the OCCT conversion worker wiring itself,
measurement tools, assembly trees, PMI/GD&T, drawing markup, revision
visual diff.

## If you deviate

The principles hold on any stack — the invariants, parity, tenancy, and
security rules are language-neutral. If you swap the stack, you own:
rewriting the testing examples (`testing-conventions.md` §  Mechanics),
refilling `/perp-check`'s commands, re-answering the per-concern table
above for your ecosystem, and the CAD conversion piece (Python has the
strongest OCCT bindings — cascadio/pythonocc; Ruby/PHP/.NET need a
containerized converter sidecar). Record what you chose in CLAUDE.md
§ Tech Stack and note the deviation here. **The panel's aggregate
winner was Django + HTMX + PostgreSQL** — if you prefer batteries and
decade-stable idioms over the compile-time net, that's the documented
second path, and the panel report carries its full case (free admin,
first-party everything, trigger-level audit, WeasyPrint PDFs,
django-q2 jobs, cascadio for CAD).
