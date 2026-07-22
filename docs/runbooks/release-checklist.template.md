# Release Checklist — <TODO: your company>

> Copy to `release-checklist.md` before go-live (Bootstrap checklist).
> Run top to bottom before every release. Keep it under a page — a
> checklist nobody finishes protects nothing.

## Every release

- [ ] `/perp-check` — full verification suite green (no `⊘ NOT CONFIGURED` lines you can't explain).
- [ ] `/perp-review-parity` — **the signature audit for this kind of app**: broad sweep, or scoped to the concepts this release touched. Any drift between the internal app and the portal blocks the release.
- [ ] Feature docs current — the Progress table of every `features/<name>.md` this release touched has the shipping commit hash. (`/perp-status` flags stale ones.)
- [ ] One-sided surface changes justified — anything shipped to only one of internal-app/portal has the gap noted and a follow-up opened (CLAUDE.md § Parity).
- [ ] Migrations rehearsed — any schema migration in this release was run against a restored copy of production data, not just dev fixtures (ARCHITECTURE.md § migrations).

## Periodically (check the date, not the box)

- [ ] Backup restore rehearsal within the last 90 days — see the rehearsal log in `backup-restore.md`. If stale, rehearse before releasing.
- [ ] Dependency audit clean at the scheduled (moderate) level, not just the CI gate (high) level.
- [ ] `/panel-review <major surface>` on anything that shipped substantially this cycle — before the release, not after the complaints.

## Kit hygiene (if you adopted the primer)

- [ ] New vocabulary this release is in `docs/GLOSSARY.md`.
- [ ] Any rule you changed was changed in its **canonical home** (DOMAIN_MODEL invariants / secure_coding / the owning skill) and restatements updated in the same commit.
