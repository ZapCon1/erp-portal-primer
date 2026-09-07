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

> **If you hold DoD CUI, read Scenario 2's 72-hour clock now, not later.**
> It has a prerequisite (a DIBNet certificate) that takes weeks to obtain.

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

### ⏱ If you hold DoD CUI: the 72-hour clock (`CUI-8`)

**Only if a DoD contract flowed the DFARS 7012 safeguarding clause down to
you.** If it did, a cyber incident affecting covered defense information —
or your ability to perform on the contract — must be reported to DoD
**within 72 hours of discovery**, through **DIBNet**
(`https://dibnet.dod.mil`). The clock starts at *discovery*, not at
confirmation, and it runs while you are still working out what happened.

Three things that make this survivable, and all three must be done
**before** an incident:

- [ ] **Get the DoD-approved medium assurance certificate now.** DIBNet
      reporting requires one, and obtaining it takes days to weeks. A shop
      that starts the certificate process during the 72 hours will miss
      the deadline. <TODO: certificate obtained? date / holder>
- [ ] **Name who files it** and their backup. <TODO: name>
- [ ] **Preserve and protect the images.** The clause expects you to keep
      affected media and related monitoring data for **90 days** so DoD can
      request it. That conflicts with the instinct to wipe and rebuild —
      snapshot first, rebuild second.

⚠️ Reporting is **not** an admission of fault, and reporting late is far
worse than reporting an incident that turns out to be minor. If in doubt,
report. <TODO: confirm current requirements with your contracting officer —
this is a summary written to make you act in time, not legal advice.>

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
