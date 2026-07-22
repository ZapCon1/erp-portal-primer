# Incident Response — <TODO: your company>

> Copy to `incident-response.md` **before go-live** (Bootstrap checklist).
> This is deliberately short: in an incident nobody reads long documents.
> One page, four scenarios, names and phone numbers filled in.

**First move in every scenario: write down the time.** You will need the
timeline later, and memory is the first casualty.

## Who

| Role | Name | Reach them via |
|---|---|---|
| Incident lead (decides) | <TODO> | <TODO> |
| Technical responder | <TODO> | <TODO> |
| Client communication | <TODO> | <TODO> |

## Scenario 1 — a secret leaked

(Pasted into a chat/AI tool, committed, visible in a screenshot, or a
provider alert.) Follow `secure_coding.md` § 8 "If a secret is exposed
anyway — rotation protocol" **to the letter**: rotate at the provider →
update every store (.env, CI secrets, platform env) and redeploy →
invalidate derived sessions/tokens → review provider logs for the
exposure window. The key is burned the moment it leaked; deleting the
message or commit is not a fix.

## Scenario 2 — suspected breach / cross-tenant leak

1. Preserve evidence: snapshot logs and the audit log **before** touching anything.
2. Close the door: disable the affected route/account/token. Prefer
   turning one thing off over hot-patching under pressure.
3. Read the audit log to establish scope: which tenants, which records,
   what window. (This is why the audit log is non-negotiable.)
4. Decide notification: <TODO: your legal/contractual notification
   obligations per client contract and jurisdiction — decide NOW, not
   during the incident.>

## Scenario 3 — data loss / corruption

Go directly to `docs/runbooks/backup-restore.md` and follow the restore
procedure. Do not attempt manual repair of financial records first —
a restore plus replayed changes beats hand-edited books that no longer
match the audit log.

## Scenario 4 — the app is down

1. <TODO: where to look first — host status page, error tracker, logs.>
2. <TODO: how to roll back the last deploy.>
3. If down more than <TODO: N minutes>, tell clients: <TODO: canned
   message + channel>. Silence costs more trust than the outage.

## Afterwards (within a week, every scenario)

Write five sentences: what happened, when it was noticed, what closed
it, what it cost, what change prevents a repeat. File it in this
directory next to this runbook. Skipping the writeup is how the same
incident happens twice.
