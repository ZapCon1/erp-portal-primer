# `scripts/` — what to keep after you adopt this kit

**Short answer: keep it, and delete only the checks listed below as the primer's own bookkeeping.** Earlier
versions of this kit told you three different things in four places ("delete
it after adoption", "keep the half that's yours", "delete scripts/"). The
overwhelmingly likely outcome was deleting all of it, which silently removed
the only thing enforcing the discipline the rest of the kit argues for —
including the check that stops panel reports containing your client margins
from being committed.

## The two files

| File | What it is |
|---|---|
| `kit-check.sh` | The consistency checks. Some are the primer's own bookkeeping; most bind **your** repo forever. |
| `graduation.sh` | **Keep this one.** Dormant rules that arm themselves as your app grows — adding a `File` model turns on the export-control rules, adding an `Invoice` turns on the concurrency tests. In a repo with no application it reports "dormant" and passes. |
| `kit-check-selftest.sh` | Proves the checks can actually fail, by breaking things on a copy and asserting each check goes red. **Keep this whichever way you go** — a guardrail nobody has seen fail is not a guardrail. |

## Checks that are the primer's own bookkeeping — safe to delete

These only make sense while this repo *is* the kit. Delete the numbered
blocks from `kit-check.sh`, and their matching cases from the selftest.

| # | Check | Why it stops applying |
|---|---|---|
| 3 | README version matches CHANGELOG | That's the kit's release stamp, not yours |
| 10 | `MODULES.md` registered | Once you've pruned the module catalogue to what you build |
| 11 | `[module]` catalog rows link into the boundary map | Same |
| 12 | `DEPLOYMENT_TARGETS.md` registered | Once you've picked a target and deleted the matrix |
| 16 | "the panel-review fixes stay fixed" | Receipts for findings against the kit, not your app |
| 17 | Compliance guardrails present | **Only if you have no regulated data.** If you touch ITAR/EAR or CUI, this is one of the most valuable checks here — keep it |
| 18 | Setup path stays painless | Adoption-time concerns; the Prisma and DNS warnings stop mattering once you are running |
| 21 | Rule IDs resolve in the index | Keep it if you keep the rule IDs; delete it if you strip them |

## Checks that bind YOUR repo — keep these

Not the kit's discipline. Yours.

| # | Check | What it catches in your repo |
|---|---|---|
| 1 | `/perp-*` references resolve | A doc pointing at a skill you deleted |
| 2 | Skill frontmatter matches its directory | A renamed skill that silently stops loading |
| 4 | No count restatements in prose | "Check four things" followed by five bullets — this rots constantly |
| 5 | No `<TODO>` in a live runbook (`OPS-1`) | A deploy runbook promoted to real with holes still in it |
| 6 | Stack pins mirrored | `CLAUDE.md` drifting from `STACK.md` |
| 7 | `CLAUDE.md` byte budget | **Yours is the one that will grow.** Past the cap, the model stops reliably reading your own rules |
| 8 | Every `features/*.md` registered | The `/perp-feature` workflow, enforced |
| 9 | `§` anchors resolve | A cross-reference to a heading someone renamed |
| 13 | Auto-scope hook valid | Only until you're scoped; then delete it |
| 14 | `reviews/` gitignored | **A data-leak guard.** Panel reports name your weaknesses and quote your numbers |
| 15 | `SEC-2` receipts | The dev-auth stub is the highest-consequence rule in the kit |
| 19 | `PIN-*` and the stack review stamp | An upgrade that removes a command you depend on |
| 20 | `STOP-*` rules intact and not inverted | The rules protecting you from the assistant, including `STOP-8` |

## Wire it into CI

`kit-check.sh` running locally catches nothing if nobody runs it. Add both
to the `ci.yml` that `/perp-setup-testing` writes:

```yaml
      - run: bash scripts/kit-check.sh
      - run: bash scripts/kit-check-selftest.sh
      - run: bash scripts/graduation.sh
```

Then make CI a **required status check** so a red run blocks the merge —
otherwise GitHub leaves the merge button green next to the failure
(`docs/GITHUB.md`, `GH-1`).

## Renamed the skills?

If you renamed `perp-*` to something else, update the prefix in check 1 and
in the skill paths throughout. The checks are greps; they are meant to be
read and edited, not treated as a black box.

## The rule that keeps this file honest

**Every new claim a release adds gets its check added in the same commit,
and a mutation case in the selftest proving that check can fail.** A check
with no mutation case is a check nobody has shown can fire — the kit shipped
four of those once, then eleven more in the release that fixed them.
