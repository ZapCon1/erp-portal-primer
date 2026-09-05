# Deployment targets — one shape, many substrates

`docs/STACK.md` § Deployment pins the **shape**: a long-running web
process, a long-running worker process, and Postgres. This file maps
that shape onto the places you might actually run it — a VPS, a PaaS,
AWS, AWS GovCloud, Azure, GCP — and says what changes and what doesn't.

**Canonical scope** (per `CLAUDE.md` § Architecture): substrate
choice, the per-target mapping, and the compliance-driven constraints on
it. The deploy *shape* and the never-serverless pin stay canonical in
STACK.md; the executable steps stay in
`docs/runbooks/deploy.template.md`. This file is the bridge between
them.

---

## What the pin does and doesn't say

The pin is **not** "run it on a cheap VPS forever." It's:

> one image, two long-running processes, a real Postgres, and exactly
> one process running migrations.

Anything that satisfies that satisfies the pin. So, to end an argument
before it starts:

| Runtime | Honors the pin? | Why |
|---|---|---|
| Docker on a VPS (Coolify, plain compose) | ✅ Yes | The baseline |
| Railway · Render · Fly.io | ✅ Yes | Long-running containers, managed Postgres |
| **AWS ECS Fargate** | ✅ Yes | "Serverless" in AWS marketing means *no EC2 to patch* — the container still runs continuously. This is not Lambda. |
| **AWS App Runner** | ⚠️ Web only | **Web only.** It requires an HTTP listener and allocates CPU only while a request is in flight, so a pg-boss polling loop starves between requests — the same failure as Cloud Run. Put the worker on ECS/Fargate. |
| **Azure Container Apps** · Container Instances | ✅ Yes | Same: long-running containers |
| **Google Cloud Run** | ⚠️ Web only | Fine for web; the **worker needs care** — see the GCP note below |
| AWS Lambda · Vercel · Cloudflare Workers | ❌ No | Request-scoped. No long-running worker, no job queue, and CAD/PDF work doesn't fit the timeout. The full argument lives in STACK.md § Deployment; don't relitigate it. |

**The word "serverless" is doing two different jobs in this industry.**
The pin rejects *request-scoped functions*, not *managed infrastructure*.
Fargate is managed infrastructure running a normal Node process, which is
exactly what this app needs.

---

## The four things every target must map

Porting between substrates is mechanical if you keep these four separate.
Any target that can answer all four can run this app.

| # | Concern | VPS baseline | What it becomes on a cloud |
|---|---|---|---|
| 1 | **Compute** — web + worker, same image, different commands | two compose services | two ECS services · two Container Apps · on GCP, one Cloud Run service **plus a worker pool or GCE instance** (not two Cloud Run services — see the matrix) |
| 2 | **Postgres** | a compose service on the same box | managed (RDS · Azure Database for PostgreSQL · Cloud SQL) |
| 3 | **Object storage** — originals, GLB derivatives, PDFs | a volume or MinIO | S3 · Blob Storage · GCS |
| 4 | **Secrets** — injected at runtime, never in the image | host `.env` | Secrets Manager · Key Vault · Secret Manager |

Two rules survive every substrate, because they're where the outages come
from:

- **Exactly one process runs migrations**, as a one-shot that must exit 0
  before web and worker start. `prisma migrate deploy` takes a Postgres
  advisory lock, so two racing tasks do not interleave migrations — the
  real failure is the second task blocking on the lock until it times out
  and the deploy reporting a failure nobody can reproduce. Horizontal
  scaling makes it more likely, not less. **The construct differs per
  target, and "it exits 0" needs an actual mechanism:**

  | Target | One-shot construct | How you know it exited 0 |
  |---|---|---|
  | Docker compose | a `migrate` service | `depends_on: { condition: service_completed_successfully }` — the only one that blocks for free |
  | ECS / Fargate | a standalone task, **not** a service container | `aws ecs run-task` then `aws ecs wait tasks-stopped`, then read the container exit code |
  | Azure Container Apps | a Job | the job's completion status |
  | Cloud Run | a Cloud Run **Job** | the execution's status |
  | Render · Railway | the pre-deploy command | the platform aborts the deploy on non-zero |
  | Fly.io | `release_command` | the deploy aborts on non-zero |
  | On-prem | whatever runs it — write it down | must be scripted, not a person remembering |
- **The worker is not the web process scaled to two.** If your platform's
  autoscaler can run N copies of the container, the worker must be a
  *separate* service with its own concurrency, or you get N overdue-invoice
  flips a night. pg-boss will cope with concurrent consumers; your
  once-a-day jobs will not.

---

## Target matrix

| Target | Best when | Postgres | Watch out for |
|---|---|---|---|
| **VPS + Docker** (Hetzner, DO droplet, Coolify) | Default. One shop, no compliance regime. | Container or managed | You own patching and backups — `backup-restore.md` isn't optional |
| **PaaS** (Railway, Render, Fly.io) | You'd rather pay than operate | Managed add-on | Worker must be its own service, not a second web replica |
| **AWS commercial** (ECS Fargate + RDS + S3) | You're already in AWS, or need to be for a customer | RDS | Cost is mostly RDS + NAT gateway, not compute; VPC/IAM is the real learning curve |
| **AWS GovCloud** | **CUI / ITAR data — see below** | RDS in GovCloud | Separate account, separate partition, service gaps, materially higher cost |
| **Azure Container Apps** | Microsoft shop, or Azure Government for CUI | Azure Database for PostgreSQL | Container Apps scale-to-zero will stop your worker — pin min replicas to 1 |
| **Google Cloud Run** | Prefer GCP | Cloud SQL | ⚠️ Cloud Run is request-driven. The web service is a clean fit; the **worker is not** — use a Cloud Run *worker pool* / always-on instance, or put the worker on GCE. Don't discover this after the first missed nightly job. |
| **On-prem / colo** | You already have a rack, or CUI makes cloud paperwork worse than a server room | Self-hosted | Backups off-site, and someone owns the hardware |

**Cost honesty**, in the spirit of STACK.md § Honest costs: the VPS
baseline is genuinely $10–20/month. Any managed cloud is a large multiple
of that once you count managed Postgres, egress, and a NAT gateway —
and GovCloud is a further multiple on top. Price your actual shape before
committing; none of these numbers should be taken from a doc.

---

## AWS GovCloud

This is the target that exists for one reason: **you handle CUI or
export-controlled technical data** and your customer or contract requires
a compliant environment. If that's not you, GovCloud is a large amount of
cost and friction with no benefit — use commercial AWS or the VPS.

### What actually differs from commercial AWS

Not a region flag. A separate cloud:

- **Separate account and separate credentials.** GovCloud accounts are
  provisioned alongside a commercial account but have their own sign-in,
  their own IAM, and their own console URL. Commercial keys do not work.
- **Different ARN partition** — `arn:aws-us-gov:` rather than `arn:aws:`.
  Anything that string-builds an ARN, or any tool that assumes the
  commercial partition, breaks. This is the single most common porting
  bug.
- **Regions are `us-gov-west-1` and `us-gov-east-1`** only.
- **Access is vetted.** Accounts require a screening process tied to
  export-control eligibility, and access is restricted to US persons.
  Plan lead time; this is not a signup form.
- **Service parity lags.** Newer services and newer features arrive later
  or not at all. Verify every service you depend on is present in your
  GovCloud region *before* designing around it — the answer changes over
  time, so check current documentation rather than trusting this list.

### What GovCloud does and does not buy you

⚠️ **GovCloud is necessary, not sufficient.** This is the most expensive
misunderstanding available here. Running in GovCloud does not make you
compliant — it gives you an environment where compliance is *achievable*.
You still own the controls, a system security plan, a POA&M for the gaps,
and evidence. The provider's compliance covers the provider's layer; the
application, its access control, its audit retention, and its people are
yours. Under the shared-responsibility split, everything this kit's
`secure_coding.md` talks about lands on your side of the line.

Treat the specifics as a conversation with your assessor, not a lookup:
which baseline applies, what equivalency your contract requires, and what
your DFARS 7012 obligations are (including incident reporting timelines
and media preservation) are contract- and assessment-specific, and the
requirements move. This file's job is to tell you the question exists
early enough to matter — before go-live, not after.

### The egress trap — the part people miss

⚠️ **Hosting in GovCloud does nothing if your data leaves through a side
door.** Every one of these is a commercial-cloud service that will
happily accept CUI you didn't mean to send:

| Side door | The problem |
|---|---|
| **Transactional email** | An invoice PDF or a job status email sent through a commercial provider (Resend, Postmark, SendGrid) carries your content to a commercial service. Use SES in-partition, or keep CUI out of email bodies and attachments entirely. |
| **Third-party analysis APIs** | **Toolpath is exactly this** — `docs/MODULES.md` § Toolpath already gates it with `mayReceiveControlledData`, default false. GovCloud hosting doesn't change that gate; it makes it more load-bearing. |
| **Error tracking / APM** | Sentry-class tools capture request payloads and stack locals. A CUI field in an error report is an exfiltration you paid a vendor to perform. Self-host, or scrub aggressively. |
| **Cloud file storage** | Box, Dropbox, SharePoint, Drive — the integration in `docs/MODULES.md` § File storage. A commercial tenant is a commercial service holding your drawings, and a download straight from it never reaches your audit log either. Some vendors offer government-community tiers; whether one satisfies your obligation is an assessor question. |
| **CDN / image hosts** | A presigned URL to a commercial CDN puts the file on commercial infrastructure. |
| **Alerting and paging** | PagerDuty, Opsgenie, Slack and hosted log aggregators all carry request context out of the partition — and this one bites hardest, because `docs/CONTROLS.md` § Go-live gates *requires* an alert that reaches a human. Resolve it in-partition rather than skipping monitoring: CloudWatch alarms → SNS in `us-gov-*` is the concrete compliant path. "Self-host Sentry" is a one-clause answer to a problem that costs a one-person shop weeks. |
| **LLM and AI tooling** | Including the coding assistant. Source code is usually fine; a CUI drawing or a customer's controlled spec pasted into a prompt is not. `secure_coding.md` § 8's instinct applies. |

The structural defense is the one already in the kit: **one data
classification, one predicate, checked at every egress point.**
`docs/MODULES.md` § Compliance posture is the canonical description; the
integration scaffold's `mayReceiveControlledData` is its enforcement.

### Azure Government · GCP Assured Workloads

The same story with different nouns: a separate sovereign environment,
restricted personnel, service gaps, and the same shared-responsibility
split. If you're already committed to Microsoft or Google, the equivalent
exists; the decision framework below doesn't change.

---

## Choosing — a decision ladder

Work down. Stop at the first line that's true.

1. **Do you handle CUI or export-controlled technical data today, under a
   contract that specifies an environment?** → GovCloud (or Azure
   Government), and talk to your assessor before you build. Also consider
   on-prem: for a small shop, a server you physically control can be less
   paperwork than a cloud attestation.
2. **Might you, within a year?** → Don't pre-build GovCloud. *Do* build
   the data classification and the egress gate now
   (`docs/MODULES.md` § Compliance posture) — those are cheap today and
   expensive to retrofit, which is the whole reason they're provisioned
   early. Substrate can move later; a schema without a classification
   column can't.
3. **Does a customer contractually require a specific cloud?** → That
   cloud, commercial tier.
4. **Otherwise** → the VPS. It's the pinned default because it's the right
   answer for most shops running this, and moving off it later is a
   week, not a rewrite — that's what the four-concern mapping above buys
   you.

**The kit's position:** substrate is the *last* decision, not the first.
Nothing above Tier 0 in `docs/FEATURE_CATALOG.md` cares where it runs, and
a shop that picks GovCloud before it has an invoice has optimized the
wrong end of the problem.

---

## What to fill in the runbook

`docs/runbooks/deploy.template.md` § "your host specifics" is the slot
this file feeds. Whichever target you pick, that runbook must end up
naming:

- the image registry and how CI pushes to it (in-partition for GovCloud —
  ECR in `us-gov-*`, not your commercial ECR)
- how the **one-shot migration** runs, and how you know it exited 0
- where secrets come from, and who can read them
- where Postgres backups go, and the date of the last **rehearsed
  restore** (`backup-restore.md` — `/perp-status` checks this goes stale)
- the rollback command and the previous image tag
- who gets paged, and where to look — `incident-response.md` Scenario 4

A target isn't adopted until those six lines are filled in for it.
