# Backup & Restore Runbook (template)

<!--
Copy to docs/runbooks/backup-restore.md and fill in BEFORE the first real
client data exists — not "as the project matures." An ERP is the system of
record for someone's business; a backup that has never been restored is a
hope, not a backup.
-->

## The backup set — what "a backup" means here

A database dump alone is NOT a backup of this system. The set is:

1. **Database** — <TODO: engine, dump command, consistency mode>.
2. **Uploaded files** — the object-storage bucket (receipts, customer
   documents, signed contracts). <TODO: replication/versioning or sync-out
   mechanism. A restored DB full of file references that point at nothing
   is a partial loss event.>
3. **Secrets escrow** — a securely stored inventory of `.env` values and
   where each credential is re-issued from. <TODO: where this lives —
   password manager entry, sealed doc.>
4. **Audit log** — included in the DB unless stored separately. <TODO.>

## Schedule, retention, targets

- Frequency: <TODO: e.g. nightly full + hourly incremental>.
- Retention: <TODO: e.g. 30 daily, 12 monthly>.
- **RPO** (max acceptable data loss): <TODO: e.g. 1 hour>.
- **RTO** (max acceptable downtime to restore): <TODO: e.g. 4 hours>.
- Off-site: <TODO: destination, different provider/account than prod>.

## Encryption

Backups are encrypted at rest with a key stored **separately from the
backup destination** — an unencrypted off-site dump is the entire business
in one exfiltratable file. Key recovery is part of the restore rehearsal:
if the key lives only on the server that just died, you have no backups.
<TODO: key location + who can access it.>

## Restore procedure

1. <TODO: provision target, fetch latest backup set, decrypt.>
2. <TODO: restore DB; re-point/verify file storage; re-issue secrets.>
3. **Verify**: run a fixed verification query — e.g. count of clients,
   invoices, sum of outstanding balances — and compare against the last
   known-good figures. <TODO: the query and where known-good is recorded.>
4. <TODO: smoke-test both auth realms and one portal view.>

## Rehearsal & monitoring

- **Rehearse a full restore quarterly** — calendar it; record date + result
  below.
- **Dead-man's switch**: the backup job reports each successful run to a
  heartbeat monitor that alerts when a run is missed. A dead backup cron is
  the quietest failure in the system. <TODO: monitor + who is alerted.>

| Rehearsal date | Restored from | Verification result | Notes |
|---|---|---|---|
| — | — | — | — |
