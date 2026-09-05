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
- [ ] **`SEC-2` — dev-mode auth is off; both realms use real login, and the startup assertion is still in place.** Grep the auth module: the guard that refuses to boot the stub in production must not have been "temporarily" removed. This block previously had no security line at all, which is how a dev stub reaches production.
- [ ] **`A11Y-1` — the accessibility scan is wired and green**, and one keyboard-only pass through a portal view. Once any portal view exists, an unwired scan is `⊘ NOT CONFIGURED`, not `N/A` (`docs/CONTROLS.md`).
- [ ] **`OPS-3` — error tracking and the uptime check still reach a human.** Send one test alert; a monitoring integration that silently expired is indistinguishable from a quiet week.

## Periodically (check the date, not the box)

- [ ] Backup restore rehearsal within the last 90 days — see the rehearsal log in `backup-restore.md`. If stale, rehearse before releasing.
- [ ] Dependency audit clean at the scheduled (moderate) level, not just the CI gate (high) level.
- [ ] `/panel-review <major surface>` on anything that shipped substantially this cycle — before the release, not after the complaints.

## Kit hygiene (if you adopted the primer)

- [ ] New vocabulary this release is in `docs/GLOSSARY.md`.
- [ ] Any rule you changed was changed in its **canonical home** (DOMAIN_MODEL invariants / secure_coding / the owning skill) and restatements updated in the same commit.
