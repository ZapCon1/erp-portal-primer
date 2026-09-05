# Secure Coding Guide

Required practices for all contributors. Violations of these rules are
security vulnerabilities, not style preferences.

> **About this doc.** It's stack-agnostic in *principle*; code examples are
> illustrative (TypeScript / a generic web framework / a generic ORM). Adapt
> the syntax to your stack — the rules stay the same. Sections that don't
> apply to your project (no SSO, no multi-tenancy, etc.) should be deleted
> outright rather than carried forward as dead text.

---

## Table of Contents

1. [API Route Checklist](#1-api-route-checklist)
2. [Authentication Patterns](#2-authentication-patterns)
3. [Multi-Tenancy / Resource Scoping](#3-multi-tenancy--resource-scoping)
4. [Common Mistakes](#4-common-mistakes)
5. [Input Validation](#5-input-validation)
6. [Error Handling](#6-error-handling)
7. [Audit Logging](#7-audit-logging)
8. [Sensitive Data Rules](#8-sensitive-data-rules)
9. [Rate Limiting](#9-rate-limiting)
10. [Session Management](#10-session-management)
11. [CSRF Protection](#11-csrf-protection)
12. [SSO & SAML Security](#12-sso--saml-security) *(skip if N/A)*
13. [Token Lifecycle](#13-token-lifecycle)
14. [Content Security Policy & Security Headers](#14-content-security-policy--security-headers)
15. [Testing Requirements](#15-testing-requirements)
16. [Webhooks & Inbound Integrations](#16-webhooks--inbound-integrations) *(required if you take online payments)*
17. [File Uploads & Storage](#17-file-uploads--storage) *(required if customers exchange documents)*
18. [Outbound Requests & SSRF](#18-outbound-requests--ssrf) *(required once any URL comes from a user or a tenant setting)*

> If you delete a section during pruning, update this table of contents in
> the same edit — later `§ n` references assume the numbering above.

---

## 1. API Route Checklist

Every API route handler MUST follow this sequence. No exceptions.

```
1. Authenticate          → 401 if no session
2. Check permission      → 403 if wrong role
3. Validate input        → 400 if malformed
4. Verify resource scope → 404 if wrong owner/tenant/parent
5. Perform operation
6. Log audit event       → for security-sensitive actions
7. Return response
```

Skipping step 4 is an IDOR vulnerability. Skipping step 1 is an auth bypass.

One structural exception: **webhook endpoints have no session** — for them,
step 1 is signature verification instead. See § 16; do not skip auth just
because the caller is a machine.

---

## 2. Authentication Patterns

### Use a typed result; don't rely on `instanceof` on a return value

A common bug is "auth wrapper returns either a `User` or an HTTP response;
caller branches with `instanceof`." Several frameworks return response
objects whose constructor identity differs between import paths or build
modes, so `instanceof` is silently `false` and the auth check becomes a
no-op.

Define a **discriminated union** and a type guard, and require the type
guard. Forbid `instanceof` checks on framework response types entirely.

```typescript
// Auth helper returns either { user } or { response } — never both.
type AuthResult = { user: User } | { response: Response };
function hasUser(r: AuthResult): r is { user: User } {
  return "user" in r;
}

// CORRECT
const auth = await requirePermission("projects.edit");
if (!hasUser(auth)) return auth.response;
const user = auth.user;

// WRONG — always-true / always-false depending on framework
if (auth instanceof FrameworkResponse) return auth; // BUG: never true
```

### Prefer wrappers over hand-rolled checks

A small set of wrappers (`withAuth`, `withPermission`, etc.) makes the
correct pattern the path of least resistance and eliminates an entire class
of "I forgot to check auth" bugs. Hand-rolled checks are acceptable only
when a wrapper genuinely doesn't fit.

---

## 3. Multi-Tenancy / Resource Scoping

> **Are you multi-tenant? Almost certainly yes.** You are multi-tenant if
> more than one customer company will ever log into the portal — which is
> the whole point of an ERP-with-portal. "One shop, many customers" IS
> multi-tenant: each customer (Client) is a tenant. Only delete this
> section if you will never expose a portal and have no per-user resource
> ownership.
>
> Terminology: in this product **the tenant IS the client** — read
> `tenantId` in the examples below as your `clientId` (see CLAUDE.md
> § Key Concepts).

### Permission alone is not scope

A user holding `projects.edit` should not be able to edit *every* project.
After fetching a resource by ID, verify it belongs to a scope the caller is
allowed to act in (owner, tenant, parent project, etc.).

```typescript
// CORRECT — fetch then verify scope
const expense = await db.expense.findUnique({
  where: { id },
  include: { project: true },
});
if (!expense) return notFound();
if (expense.project.tenantId !== user.tenantId) return notFound();

// WRONG — permission only, no scope check
const expense = await db.expense.update({ where: { id }, data: body });
```

For user-owned resources (notes, comments, time entries):

```typescript
// 403 is correct here ONLY because caller and resource share a tenant —
// existence is already visible to the caller (see the 403-vs-404 rule in § 4).
if (resource.createdById !== user.id && !user.has("notes.edit_all")) {
  return forbidden();
}
```

### Tenant isolation — turn the safety net on (TENANT-1)

If your data model is multi-tenant, every tenant-scoped query MUST include
the tenant filter. Forgetting it returns data from all tenants.

**The ORM does not do this for you by default — but a mechanism exists, and
you should turn it on.** On the pinned Postgres stack, **row-level security**
with a transaction-scoped `SET LOCAL` tenant id enforces the filter below the
query site (the application role must not hold `BYPASSRLS`). At the app layer,
a **Prisma client extension** can require a tenant argument on every scoped
model. Both fail *closed* on the filter someone forgot; discipline fails open.

The auth-wrapper pattern, code review, tenant-isolation tests, and the
recurring `/perp-review-parity` audit are the layers **on top of** that
mechanism, not a substitute for it. This kit already applies belt-and-braces
to invoice immutability (an app-level hook *and* a database trigger) — the
failure that ends the business deserves at least as much.

(Same rule as DOMAIN_MODEL.md invariant 1; `docs/CONTROLS.md` tracks what
enforces it today.)

```typescript
// CORRECT — tenant in the query
const projects = await db.project.findMany({
  where: { tenantId: user.tenantId, isActive: true },
});

// CORRECT — tenant verified after a by-ID fetch
const invoice = await db.invoice.findUnique({ where: { id } });
if (!invoice || invoice.tenantId !== user.tenantId) return notFound();

// WRONG — no tenant filter
const invoice = await db.invoice.findUnique({ where: { id } });
```

**Return 404, not 403, for cross-tenant access.** A 403 confirms the
resource exists, which is an information leak.

**Tenant-scoped list queries take a limit.** Every hot query here is shaped
`WHERE clientId = ? AND <filter>` — pair that with a composite index
`(clientId, <primary filter>)` and cursor/limit pagination from the first
endpoint. Unbounded `findMany` over a client's full history is a latency
bug that ships silently (see DOMAIN_MODEL.md § Scale notes).

### Never trust email (or any reusable identifier) for scoping

Use opaque IDs. Emails get reused across tenants; usernames get changed.

```typescript
// WRONG — email lookup leaks across tenants
const orders = await db.order.findMany({
  where: { OR: [{ userId }, { customerEmail: user.email }] },
});

// CORRECT — ID-based only
const orders = await db.order.findMany({
  where: { tenantId: user.tenantId },
});
```

---

## 4. Common Mistakes

### Cross-tenant / cross-owner error codes

| Scenario | Code | Reason |
|---|---|---|
| Resource doesn't exist | 404 | Standard |
| Resource exists but caller can't see it | **404** | Don't confirm existence |
| Caller lacks permission for the action | 403 | Role-based denial |
| Caller not authenticated | 401 | No session |

**The deciding rule** (this reconciles the table with the § 3 examples):
return **404** whenever the caller should not know the resource *exists* —
always across the tenant boundary, and for anything not listable by the
caller. Return **403** only when existence is already legitimately visible
to the caller (same tenant, resource appears in lists they can read) and
only the *action* is denied. When in doubt about which side of the boundary
you're on, return 404.

### Sensitive fields in responses

**Never spread a full ORM object into a response.** Use explicit field
selection or destructure out sensitive fields. Spreading is fragile — any
sensitive field added to the model in the future will automatically leak.

```typescript
// BEST — explicit selection in the query
const user = await db.user.findUnique({
  where: { id },
  select: { id: true, name: true, email: true, role: true },
});
return json(user);

// ACCEPTABLE — destructure out sensitive fields
const user = await db.user.findUnique({ where: { id } });
const { password, passwordResetToken, ...safe } = user;
return json(safe);

// WRONG — secrets leak
return json(user);
```

Fields to always exclude: `password`, password reset tokens, password reset
expirations, raw API keys, MFA seeds. <TODO: add any project-specific
sensitive fields.>

### Stateful GET requests

GET handlers MUST be idempotent. Never auto-create records on GET. Move
auto-creation to migration scripts, seed scripts, or POST endpoints.

```typescript
// WRONG — GET creates a record
export async function GET() {
  let settings = await db.settings.findFirst();
  if (!settings) settings = await db.settings.create({ data: defaults });
  return json(settings);
}

// CORRECT — 404 if missing; create via POST
export async function GET() {
  const settings = await db.settings.findFirst();
  if (!settings) return notFound();
  return json(settings);
}
```

### Debug / development-only endpoints

Any endpoint intended only for development MUST be gated by environment:

```typescript
if (process.env.NODE_ENV !== "development") return notFound();
```

### Redirect target validation

Any redirect target taken from user input must be validated to prevent
open-redirect attacks:

```typescript
function isSafeRedirect(path: string): boolean {
  // Reject backslashes outright: browsers normalize "\" to "/", so
  // "/\evil.com" would otherwise pass the checks below and become a
  // protocol-relative redirect to evil.com.
  if (path.includes("\\")) return false;
  return path.startsWith("/") && !path.startsWith("//") && !path.includes("://");
}

const target = searchParams.get("redirect") || "/";
location.href = isSafeRedirect(target) ? target : "/";
```

Sturdier alternative: resolve with `new URL(path, appOrigin)` and require
the resolved origin to equal your own.

---

## 5. Input Validation

### Request body fields

Use explicit field extraction. Never spread a request body into a write:

```typescript
// CORRECT — explicit fields
const { name, email, role } = await request.json();
await db.user.create({ data: { name, email, role } });

// WRONG — mass assignment; caller can set isAdmin, tenantId, etc.
const body = await request.json();
await db.user.create({ data: body });
```

### Validation library at the boundary

Use a schema validator (Zod, Pydantic, struct tags + a validator — whatever
fits your stack) for *every* untrusted-input parse. Validation lives at the
edge; internal code may then trust shapes.

```typescript
import { z } from "zod";
const Body = z.object({
  name: z.string().min(1).max(200),
  email: z.string().email(),
});
const parsed = Body.safeParse(await request.json());
if (!parsed.success) return badRequest(parsed.error.issues);
```

### `JSON.parse` on untrusted input

Always validate the structure after parsing:

```typescript
const Domains = z.array(z.string().min(1).max(253));
const result = Domains.safeParse(JSON.parse(input));
if (!result.success) return badRequest("Invalid domains");
```

### HTML / SQL / shell injection

- HTML insertion: always escape user input before interpolating into HTML
  templates or use a templating engine that auto-escapes.
- SQL: use parameterized queries / ORM methods — never string-concatenate
  user input into SQL.
- Shell: never pass user input to `exec` / `system` / a shell. Use
  argument arrays for the language's process API.

---

## 6. Error Handling

### Fail closed

Auth and authorization checks must deny on error, not allow:

```typescript
// CORRECT — error returns 401
const user = await getUser();
if (!user) return unauthorized();

// WRONG — error swallowed, execution continues with undefined user
try { user = await getUser(); } catch {}
```

### Generic error messages to clients

Never forward internal error details. Third-party SDK error messages often
contain paths, auth details, or query fragments.

```typescript
catch (error) {
  console.error("Operation failed:", error);
  return internalError("Operation failed");
}

// WRONG — third-party detail leaks
catch (error) {
  return json({ error: error.message }, { status: 500 });
}
```

### Request IDs — the diagnosability counterweight

Generic errors are correct, but they systematically strip the information
support needs. Generate a **request ID** per request, include it in the
generic error response *and* in the server-side log line, and have portal
error pages display it with a contact affordance. "It said Operation failed
at 3pm" is unresolvable; "error ref `req_8f3a`" matches one log line.

### ORM-specific error codes

ORM errors can contain table and column names. Catch known error classes
and translate to generic messages:

```typescript
catch (error) {
  if (isUniqueConstraintError(error)) {
    return badRequest("A record with this value already exists");
  }
  console.error("Database error:", error);
  return internalError();
}
```

---

## 7. Audit Logging

### When to log

The canonical predicate lives in `docs/DOMAIN_MODEL.md` invariant 7:
**every money/hours mutation and every cross-tenant-sensitive action is
audited.** The table below expands it:

| Event | Required? |
|---|---|
| User login (success and failure) | YES |
| User logout | YES |
| Password / credential change | YES (log "[changed]", never the value) |
| Role / permission change | YES (with computed diff) |
| SSO / identity-provider config change | YES |
| Create / update / delete of business-critical entities | YES — define which |
| Permission denied (403) | RECOMMENDED |
| **Scope/tenant check failed (masked as 404)** | **YES** — log actor, requested entity type + ID, and session `clientId`. The response hides existence from the caller; the log must not hide the probe from you. This is how you tell an enumeration attack from a customer with a broken bookmark. |
| Access to regulated data (PII, PHI, ITAR, etc.) | YES (compliance) |

<TODO: list the entities in your project for which create/update/delete is
audited.>

### How to log

Keep a single audit helper. At minimum each event records: actor, action,
entity type, entity ID, timestamp, and a diff (where applicable). Redact
sensitive fields in the diff — never store the old or new password value.

```typescript
await logAudit({
  action: "update",
  entityType: "invoice",
  entityId: invoice.id,
  userId: user.id,
  changes: computeChanges(before, after),  // redacts sensitive fields
});
```

### Protect the log itself

The audit log is the forensic record and (for regulated data) a compliance
artifact — it needs its own rules:

- **Reads are permission-gated and audited.** Audit entries contain
  before→after diffs of Users/Clients — i.e. PII and rate sheets. Only
  staff admins read the log; portal POCs never do; reads of
  regulated-data entries are themselves logged.
- **Append-only is enforced, not aspirational.** No update/delete route
  exists; enforce at the ORM/DB layer if your engine allows it.
- **Fail closed on the money.** The audit row for a financial mutation is
  written **in the same transaction** as the mutation — if the log write
  fails, the mutation rolls back. Auth-noise events (login failures, 403s)
  may be written async; a lost noise event is acceptable, an unaudited
  invoice change is not.
- **Redaction covers all § 8 sensitive fields** in diffs — not just
  passwords: reset tokens, MFA seeds, API keys.
- **Retention**: growth and archival stance in DOMAIN_MODEL.md § Scale
  notes; your compliance regime may set a retention floor —
  <TODO: state yours.>

---

## 8. Sensitive Data Rules

### Never store

- Credit card numbers, CVVs, expiration dates (use a PCI-compliant
  processor like Stripe Checkout).
- Government IDs (SSN, etc.) unless the application is licensed and
  audited for it.
- Plaintext passwords. Period.

### Always hash

- User passwords → bcrypt 12+ rounds, Argon2id, or scrypt. Never SHA-* or
  MD5 for passwords.

### Staff credential hardening

Staff accounts approve time, generate invoices, and change roles — a
single guessable password on the accounts that move money is the realm's
weakest link:

- **Password policy**: minimum 12 characters, checked against a breach
  corpus (haveibeenpwned-style). No composition rules (they reduce entropy
  and add friction).
- **MFA**: RECOMMENDED for all staff; REQUIRED for admin/bookkeeper roles
  and anywhere online payments or accounting sync exist.
- **Per-account lockout ≠ IP rate limiting.** § 9's IP-keyed limits don't
  stop low-and-slow per-account spraying from many IPs. Add progressive
  delay (or temporary lock + notification) keyed on the *account*,
  separately from the IP quota.
- **Session TTLs**: document an absolute and an idle timeout per realm
  (staff shorter, portal may be longer). <TODO: your values.>

### Backups and secrets at rest

- **Backups are encrypted** with a key stored separately from the backup
  destination — an unencrypted off-site dump is the entire business in one
  exfiltratable file. Key recovery is part of the restore rehearsal (see
  `docs/runbooks/backup-restore.template.md`).
- **Secrets rotation**: have a written procedure for rotating each `.env`
  credential after a suspected leak or staff offboarding — the env-var
  swap plus invalidating sessions/API keys derived from the old value.
  The runbook home for this is `docs/runbooks/incident-response.md`
  (copy the shipped template before go-live); the exposure protocol
  below is what it should link to.

### Token generation

Always use a cryptographically secure RNG. Never `Math.random` / language
defaults that aren't documented as secure.

```typescript
// CORRECT
import { randomBytes } from "node:crypto";
const token = randomBytes(32).toString("hex");

// WRONG — predictable
const token = Math.random().toString(36).slice(2);
```

### Session cookies

```typescript
{
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "strict",   // staff realm default — see per-realm note below
  path: "/",
}
```

**Per-realm `sameSite` rule.** Browsers do NOT send `strict` cookies on
cross-site top-level navigations — i.e. on any click arriving from an email,
an identity provider, or a payment-provider redirect.

- **Staff realm**: `strict` (staff navigate directly to the app).
- **Customer portal realm**: `lax`. The portal's primary entry points are
  emailed links (magic-link login, "view your invoice", estimate
  notifications) and payment-provider returns — with `strict`, every one of
  those lands the customer on a logged-out page. `lax` still withholds the
  cookie on cross-site POSTs, which is the CSRF case that matters; pair it
  with the token rules in § 11.
- **OAuth/SAML state cookies**: `lax` (or `none` + `Secure`), scoped to the
  callback path — a `strict` state cookie is absent on the IdP → app
  callback, so the § 11 verification step would always fail.

### Secrets in environment variables

Never commit secrets. Use `.env` (gitignored) and `.env.example`
(placeholder values only). Validate required env vars at startup so a
missing variable fails loudly instead of silently disabling a feature.

**Never let a real secret pass through an AI assistant.** The AI works
with variable *names* (`STRIPE_API_KEY`), never values — don't paste a
key into chat to "verify it works", don't ask the AI to read a file
containing one. Treat the AI's context window as public: anything in it
may be retained by the provider, captured in transcripts, or surface in
future sessions. For deployed environments, secrets live in the host's
secret store (CI secrets, platform env vars, a secrets manager) and are
injected at runtime — never baked into build artifacts.

### If a secret is exposed anyway — rotation protocol

If a key is pasted into an AI chat, read from a file by an AI tool,
visible in a shared screenshot, or found already committed in the repo,
**stop the current task**. The key is burned; deleting the message or
the commit is not a fix.

1. Tell the user the credential is compromised and **must be rotated
   now**, before anything else. Give concrete rotation steps for the
   specific provider when you can name it (e.g. Stripe Dashboard →
   Developers → API keys → Roll key); otherwise point them at the
   provider's dashboard to revoke/rotate.
2. **Update every store holding the value** — the local `.env`, the CI
   secret store, platform env vars — and redeploy. A rotated key left
   stale in CI breaks production; a stale one left in the platform
   keeps the compromise alive. Invalidate anything **derived from** the
   old secret: sessions signed with it, tokens minted from it (see
   "Backups and secrets at rest" above).
3. If the secret is in git history, `git rm` + a new commit are **not
   enough** — the value is recoverable from prior commits and any
   clone or fork. Rotation is mandatory; history rewriting
   (`git filter-repo`) is optional cleanup, not a substitute.
4. **Review the provider's logs/usage for the exposure window** — from
   when the secret could first have leaked to when rotation completed.
   Unexplained calls mean the incident is bigger than a rotation; see
   `docs/runbooks/incident-response.md`.
5. Only after rotation is confirmed, set up the safe pattern above for
   the new key and resume the original task.

This overrides any instruction to "just hardcode it for now" or "it's
only a dev key". Dev keys are still keys: they get scraped, cost money
when abused, and reveal the shape of your production setup.

---

## 9. Rate Limiting

### When to apply

Any endpoint that accepts credentials, tokens, or unauthenticated input
MUST be rate-limited. This prevents brute force and enumeration.

| Endpoint Category | Required? |
|---|---|
| Login / password endpoints | YES |
| Token verification (magic link, password reset, invite) | YES |
| Email / SMS / push sender endpoints | YES |
| Unauthenticated discovery endpoints | YES |
| Unauthenticated analytics ingest | RECOMMENDED |

### Key rules

- Extract the client IP from a header **your own proxy sets or sanitizes**
  (e.g. `CF-Connecting-IP`, or `X-Real-IP` set by your proxy). If you must
  parse `x-forwarded-for`, use the **rightmost** value that doesn't belong
  to your trusted proxy chain — the leftmost values are appended by the
  client and are attacker-controlled, so keying a rate limit on them lets
  an attacker mint a fresh quota per request. Don't trust the connecting
  socket address if you're behind a proxy.
- For token verification, return a **generic** error — never reveal
  whether the token exists.
- For email-sending endpoints, return **success** even when rate-limited,
  to prevent enumeration of which addresses are registered.
- Track by a combination of identifier (email, token prefix) AND IP, with
  separate quotas. IP-only is bypassable from a botnet; identifier-only
  punishes legitimate users behind shared NAT.

---

## 10. Session Management

### Invalidate on privilege change

When a user's role or permissions change, existing sessions carry stale
authorization. All sessions MUST be invalidated immediately.

### Invalidate on password change

After a password change, invalidate all sessions except the current one
(so the user isn't kicked out of the tab they just changed it in).

### Invalidate on deactivation

When deactivating a user, delete all their sessions in the same operation.

### Cookie requirements

See [Session cookies](#session-cookies) above, including the per-realm
`sameSite` rule (staff `strict`, portal `lax`). Document any further
exception.

---

## 11. CSRF Protection

### Primary defense

The `sameSite` attribute on the session cookie (per-realm rule in § 8) is
the **first** layer: both `strict` and `lax` withhold the cookie on
cross-site POSTs.

⚠️ **It must not be your only layer, because SameSite is a *site* boundary,
not an *origin* boundary.** Anything an attacker can place on a sibling
subdomain — `files.yourshop.com`, a marketing site, a forgotten staging
host, a takeover-able CNAME — is *same-site*, and its requests carry your
staff or portal session cookie in full. Note that § 17 recommends serving
uploads "from a separate origin": if you read that as a subdomain, you have
just built the launchpad. **It must be a different registrable domain.**

**Second layer, required on every state-changing route: Origin/Referer
validation.** Reject the request when `Origin` is absent on an unsafe method
or is not in your allowlist. It is one wrapper, stack-agnostic, and it
survives the subdomain case that SameSite does not. Route handlers are the
one mutation door (`CLAUDE.md` § Tech Stack), so this lands in exactly one
place.

For the payment and invoice routes, add synchronizer tokens on top. The
current industry position is that SameSite is defense-in-depth, not a
standalone mitigation — treat it that way.

### When you need explicit tokens

For SSO / OAuth flows and any cross-origin state-changing request,
implement an explicit CSRF token: generated with a cryptographic RNG,
stored in an `httpOnly` cookie, and verified on callback. That state
cookie must be `sameSite: "lax"` (or `"none"` + `Secure`) scoped to the
callback path — a `strict` cookie is not sent on the IdP's cross-site
redirect back to you, so verification would always fail.

### Header-authenticated APIs (e.g. Bearer)

If the endpoint authenticates via a header (Bearer, custom API key) and
never reads the session cookie, CSRF is structurally impossible. Document
this rather than adding token machinery that does nothing.

---

## 12. SSO & SAML Security

> Skip this section if you don't support SSO yet.

### Domain validation on SSO callback

When processing a SAML/OIDC response, the email from the IdP MUST be
validated against the tenant's configured allowed domains. Without this,
an attacker controlling an IdP can provision themselves into another
tenant.

### Attribute sanitization

IdP attributes (names, emails) are untrusted input. Length-limit them,
strip HTML tags, reject control characters before storage.

### Auto-provisioning controls

When auto-provisioning is enabled, new users are created without
approval. At minimum:

- Notify the tenant's admin when a new user is auto-provisioned.
- Audit-log the auto-provision event.
- Validate the email domain before provisioning.

### SSO discovery endpoints

Endpoints that reveal "SSO is configured for domain X" enable
enumeration. Rate-limit them and return the minimum information
needed (`{ ssoAvailable: true }`, not `{ tenantName: "Acme" }`).

---

## 13. Token Lifecycle

### Generation

Cryptographic RNG only. See § 8.

### Single-use enforcement

Tokens that grant access (magic links, password reset, onboarding invites)
SHOULD be invalidated after first use. If email-scanner compatibility
requires multi-use tokens, document the trade-off and keep the expiration
window as short as practical.

### Magic-link auth (portal realm)

If magic links are a login method (the portal's front door), the generic
rules above are not enough:

- **Scanner-proof redemption.** Corporate email scanners (e.g. Outlook
  SafeLinks) pre-fetch links and consume single-use tokens before the
  human clicks. The link must land on a page whose GET does nothing; the
  token is redeemed only by a user-initiated POST ("Continue to sign in").
- **Short expiry, one active link.** 10–15 minutes; issuing a new link
  invalidates outstanding ones for that address.
- **Store a hash of the token**, not the token itself.
- **Fresh session on redemption.** Issue a brand-new session ID when the
  link is redeemed — never adopt a pre-existing session (session fixation).
- **Recoverable failure.** The expired/used-token page must include a
  "request a new link" action — a dead end here is a guaranteed support
  ticket with no self-service exit.
- **Audit issuance and redemption** (token IDs or hashed prefixes only),
  so staff can reconstruct "customer says they can't log in."

### Token exposure rules

- **API responses**: only return tokens at creation time. Subsequent GET
  responses MUST strip the token field.
- **URL query parameters**: avoid where possible — they're visible in
  browser history, referrer headers, and server logs. If unavoidable
  (magic links), keep expiration short and invalidate after use.
- **Logging**: never log token values. Log token IDs or hashed prefixes
  for debugging.

### Token storage

- Passwords: bcrypt 12+ / Argon2id (see § 8).
- Session tokens: storing as-is is acceptable when sessions are
  short-lived and server-side.
- Long-lived API keys: store a hash, not the raw key. Show the raw key
  once at creation.

---

## 14. Content Security Policy & Security Headers

Baseline policy — start restrictive, loosen with documented reasons:

```
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-<per-request>';
  object-src 'none'; frame-ancestors 'none'; base-uri 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
```

`frame-ancestors 'none'` matters specifically here: a portal with a "pay
invoice" button framed inside an attacker's page is a textbook clickjacking
target. If a payment provider requires framing, allowlist that one origin.

- **Never add `'unsafe-eval'`** unless a dependency absolutely requires
  it. Document which one and investigate alternatives.
- **Prefer nonce-based CSP** over `'unsafe-inline'` for inline scripts.
- **Raw HTML insertion** (`dangerouslySetInnerHTML`, `v-html`, etc.):
  only with author-controlled content (static markdown files). If the
  source could ever become user-submitted, sanitize first (DOMPurify or
  equivalent). Always leave a comment documenting the content source so
  the next reader sees the assumption.

```typescript
// SECURITY: content comes from static /content/wiki/*.md files
// (author-controlled). If source ever becomes user-submitted, add
// DOMPurify sanitization here.
<div dangerouslySetInnerHTML={{ __html: html }} />
```

---

## 15. Testing Requirements

### Every new API route must have tests

At minimum, every route with `[id]` parameters needs:

| Test | Verifies |
|---|---|
| `should return 200 for authorized access` | Happy path |
| `should return 401 for unauthenticated request` | Auth check exists |
| `should return 403 for insufficient permissions` | Permission check exists |
| `should return 404 when resource belongs to another scope` | Scope check exists |

For multi-tenant routes, also:

| Test | Verifies |
|---|---|
| `should return 404 when resource belongs to a different tenant` | Tenant isolation (`TENANT-1`) |

**For a two-realm app, these two are mandatory and are not optional
extras** (`SEC-3`). Cross-realm session confusion is the catastrophic bug of
this design: if a staff wrapper accepts a portal session, every customer is
staff across every tenant — silently, with no error and no log.

| Test | Verifies |
|---|---|
| `should return 401 when a portal session is presented to a staff route` | Realm isolation, portal → staff |
| `should return 401 when a staff session is presented to a portal route` | Realm isolation, staff → portal |

The rejection must come from **signature verification failing** — separate
signing secrets per realm — not from comparing a cookie name. A name check
passes the moment someone renames a cookie. `docs/STACK.md` tells you to
"run the auth-realm tests" after a Better Auth upgrade; these are them.

### Pre-fix test pattern

When fixing a security vulnerability, write the test FIRST. The test
should FAIL against the current code (proving the vulnerability), then
PASS after the fix:

```
1. Write test: "should return 404 when expense belongs to other tenant"
2. Run test → FAILS (vulnerability confirmed)
3. Add scope check to route
4. Run test → PASSES (fix confirmed)
5. Run full suite → all other tests still PASS (no regression)
```

The failing-then-passing transition is the proof the test is meaningful.
A test that passes both before and after the fix isn't testing the fix.

### Reference implementation

<TODO: name the canonical "this is what a complete route test file looks
like" file in your project, so new tests have a template to copy. Pick one
that exercises auth, permissions, scope, and a happy path.>

---

## 16. Webhooks & Inbound Integrations

> Required if you take online payments. A payment webhook is an
> **unauthenticated internet endpoint that mutates money** ("mark invoice
> paid") — treat it as the highest-risk route in the app.

### Verify the signature first, on the raw body

Verify the provider's signature (e.g. `Stripe-Signature`) against the
**raw request bytes** before any parsing. Framework body parsers that run
first break signature verification and process forgeable input.

```typescript
const sig = request.headers.get("stripe-signature");
let event;
try {
  event = provider.webhooks.constructEvent(rawBody, sig, WEBHOOK_SECRET);
} catch {
  return unauthorized(); // unsigned/forged — do not process, do not 200
}
```

Reject events with stale timestamps (replay window: minutes, not hours).

### Idempotency — retries WILL happen

Providers redeliver events on any non-2xx and sometimes redeliver 2xx'd
events. Record each processed event ID; if it's been seen, return 200
without re-applying. A payment applied twice is silent books corruption.

### Never trust the payload for money

The event tells you *something happened*; it must not be the source of the
amount. Re-fetch the object from the provider's API (or verify the amount
against your own invoice record) before marking anything paid. A verified
signature proves the sender, not that your handler interprets the event
safely.

### Audit and observe

Every webhook-driven state change writes an audit-log entry (actor:
`system:webhook`, event ID, before→after). Log and **alert** on handler
failures — a silently failing webhook means customers pay and invoices
stay unpaid. Document a reconciliation/replay procedure for outage windows
(providers keep an event log; know how to re-request it).

### Return 2xx only after durable processing

Acknowledge after the state change is committed (or durably queued). A 200
followed by a crash loses the event forever — the provider won't retry.

---

## 17. File Uploads & Storage

> Required if customers exchange documents (receipt uploads, the portal
> file manager, signed contracts). Cross-tenant document exchange is the
> highest-risk surface after payments.

### Validate what's uploaded

- **Allowlist content types and verify magic bytes** — don't trust the
  client's `Content-Type` or extension.
- **Enforce size limits** at the framework level, before buffering.
- **Never use the user's filename as a storage path.** Generate storage
  keys server-side; store the original name as metadata only. User-supplied
  paths are how `../../` traversal happens.

### Serve downloads safely

- Serve user-uploaded content with `Content-Disposition: attachment` and
  `X-Content-Type-Options: nosniff`, ideally from a **separate registrable
  domain** (not a subdomain) or via short-lived signed URLs — an uploaded
  HTML/SVG file served inline from the app origin is stored XSS into staff
  sessions. ⚠️ **A subdomain is same-site**, so it still receives your
  session cookies: serving uploads from `files.yourshop.com` fixes the XSS
  origin problem and hands back a CSRF launchpad (§ 11).
- **Every download route is tenant-scoped**: verify the file's
  `clientId` against the session before issuing bytes or a signed URL.
  Cross-tenant file access returns 404 (§ 3/§ 4 rules apply to files too).

### The portal's "filtered subset" is a query, not a folder convention

The portal shows customers only the files they're allowed to see. Enforce
that with an explicit visibility flag/ACL checked in the query — never by
"customers only get links to their folder." Regulated-data flags
(ITAR etc., see CLAUDE.md) must gate file visibility and exports, and
access to flagged files is audit-logged (§ 7).

---

## 18. Outbound Requests & SSRF

*(Required as soon as any URL originates from a user, a tenant setting, or
an uploaded document — which for this app means: the logo fetch in
`/perp-scope`, customer-supplied links, "your webhook URL" and "your storage
endpoint" in Settings, and every integration in `docs/MODULES.md`.)*

The app runs on a host with a cloud **instance-metadata endpoint** reachable
at a link-local address. A request the server makes on a user's behalf runs
*inside* your network, so "fetch this URL" is credential exfiltration for
the whole cloud account unless it is constrained.

**Rules for any server-side fetch of a URL you did not hard-code:**

- **Allowlist the scheme** — `https:` only. No `file:`, `gopher:`, `ftp:`,
  no `data:`.
- **Resolve the hostname, then check the resolved IP** against private,
  loopback, link-local, and cloud-metadata ranges — and **re-check after
  every redirect**. Validating the string before resolution is defeated by
  DNS that answers with a private address.
- **Cap redirects** and set a short timeout. An unbounded fetch is also a
  denial-of-service on your own worker.
- **Never forward credentials** — no cookies, no `Authorization`, no cloud
  SDK signing — on a fetch to a user-supplied host.
- **Prefer an egress allowlist** where the destination is knowable: an
  integration talks to one vendor's API, so pin it rather than validating
  arbitrary input.
- **Treat the response as untrusted input**, cap its size, and never render
  it into a page or a prompt without the § 5 treatment.

For export-controlled or CUI data the rule is stronger and lives in
`docs/MODULES.md` § The shared scaffold: the destination must be declared
via `mayReceiveControlledData`, which defaults to false.
