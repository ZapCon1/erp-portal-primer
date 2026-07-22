# Architecture

<!--
Rename this to ARCHITECTURE.md and fill it in once non-obvious wiring exists.
The goal: one section per thing that would surprise a new contributor (or
Claude) reading the code cold. Don't restate what the file layout already
shows — capture the *invisible* contracts. The headings below are the ones
that matter most for an ERP-with-portal; delete any that don't apply.
-->

## Two auth realms

<TODO: Describe the staff realm and the customer realm. For each: login
method (password / SSO / magic-link), session storage (cookie name, TTL),
and how a request is authenticated. State plainly that the two realms are
separate and a token from one is never accepted by the other.>

## Auth-wrapper composition

<TODO: Document your route guards and how they compose. The reference shape:

- `withAuth(handler)` — requires a logged-in staff user.
- `withPermission(perm, handler)` — staff user + a specific permission.
- `withPortalAuth(handler)` — requires a logged-in customer POC; injects the
  session's `clientId`.
- `withPortalPermission(perm, handler)` — POC + a portal permission.

Explain what each guarantees by the time the handler body runs, and the
anti-patterns to avoid (e.g. inspecting the framework response object by
type instead of using the wrapper's return contract).>

## Tenant isolation (the rule with no safety net)

<TODO: State it explicitly: every customer-portal data access filters by the
session `clientId`. There is no ORM-level guard. A portal query without a
tenant filter is a security bug. Cross-tenant access returns 404, not 403.
Note where the canonical example lives so contributors can copy it.>

## One data path, two doors (parity wiring)

<TODO: Show the pattern by which an internal route and a portal route serve
the same data from one shared helper — the helper computes the number, the
internal route wraps it in a staff guard, the portal route wraps it in a
tenant-checked guard. Point at one real example. This is what keeps the two
surfaces from drifting.>

## Server-only boundary

<TODO: How do you guarantee secrets / DB clients / server SDKs never end up
in a client bundle? Name the guard (e.g. a `server-only` import) and list the
modules that carry it, plus any modules that intentionally don't (utilities
shared with client components) and why that's safe.>

## Data layer / ORM lifecycle

<TODO: How the DB client is instantiated (singleton? per-request?), where
migrations live, codegen step (if any), and the dev vs prod database story.>

**Migration discipline (live financial data)** — <TODO: adopt and document:
(1) expand-migrate-contract for any column change (add new, backfill,
switch reads, drop old — never rename in place); (2) automatic backup
immediately before every production migration; (3) migrations run as an
explicit deploy step, never implicitly at boot; (4) destructive migrations
require a rehearsed rollback plan. An ERP's schema evolves under live
invoices — the first careless rename with no rollback story is how books
get corrupted.>

## Payments / webhooks routing (if applicable)

<TODO: If you take online payments: how the provider's webhook is verified
(signature), how a single webhook endpoint routes to the right handler
(by event type / metadata key — document the precedence order), and how
idempotency is handled so a retried webhook doesn't double-apply.>

## File storage (if applicable)

<TODO: Backend (S3 / Box / etc.), how per-client/per-project folders are
laid out, and how the portal exposes only the allowed subset to customers.>

## Background jobs / cron

The reference job list for this kind of app — keep what applies:
overdue-flip (sent→overdue at the due date, evaluated in the declared
business timezone — DOMAIN_MODEL invariant 9), budget/hours threshold
alerts, digest builder, report/export worker, backups, health
recalculation.

<TODO: For each job document: what triggers it; **missed-run semantics**
(skip vs catch-up — a single-VPS cron misses runs); **idempotency of
re-runs** (a retried digest job must not double-send email); and a
**dead-man's-switch heartbeat** that alerts when the job hasn't run on
schedule — mandatory for the backup job, which is the quietest failure in
the whole system. Note any job that recomputes a number the UI also
computes — that's a parity surface (DOMAIN_MODEL invariant 11).>

## Observability

<TODO: Where errors go (error tracker / Sentry-equivalent), where logs go,
and **what pages a human**. The rule: no swallowed failures — every
external call (email send, webhook processing, payment, file storage) logs
on failure, and critical paths alert. The audit log records what happened;
this section is about what *failed to* happen: a dead email sender means
invoices and magic links silently stop arriving, a failing webhook handler
means paid invoices stay unpaid. Include request-ID propagation
(secure_coding.md § 6) so a customer-reported error ref matches a log line.>

## Deployment topology (three surfaces, two realms)

<TODO: Which surfaces (internal 🛠 / portal 👤 / public 🌐) deploy together
and on what domains — same host, or portal.example.com split? Then the
cookie consequences: **cookie names and `domain` scoping per realm** —
host-only cookies unless there's a documented reason; the staff cookie must
never be domain-widened onto the public/marketing site, and the two realms'
cookies must be distinguishable by name. Wrong cookie scoping across
subdomains is how one realm's session leaks onto another surface.>

## Outbound email

<TODO: Provider, and the failure story — email is load-bearing here (the
portal's only auth channel, plus invoices/estimates): persist a **send log**
with provider status; consume **bounce/complaint webhooks**; give staff a
per-client email-history view and a "resend auth link" action; note
SPF/DKIM/DMARC setup. Per secure_coding.md § 9 the sender endpoint reports
success even when rate-limited — this log is the only place a failure is
visible at all.>

## Environment contract

<TODO: The required env vars and what breaks if each is missing. Point at the
startup check that fails loudly on a missing required var. Keep
`.env.example` in lockstep with this list.>
