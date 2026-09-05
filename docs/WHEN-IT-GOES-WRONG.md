# When it goes wrong

This page is for **you**, not for the AI. No jargon. If a word here is new,
`docs/GLOSSARY.md` has it in one line.

You are building a real system with an assistant that is fast, confident,
and sometimes wrong. That combination is fine — as long as you can tell when
it is going badly and you can always get back. That is all this page is.

---

## The one habit that makes everything else recoverable

**Commit early, commit often.** A commit is a save point. It costs seconds
and it is the difference between "undo that" and "start again".

Type `/perp-commit` whenever something works — before trying anything new,
before any change you are unsure about, at the end of a session. You do not
need to understand git to do this. Committing is private and local;
publishing is a separate step (`/perp-push`), so nothing goes public by
accident.

If you only remember one thing on this page: **commit when it works.**

---

## Warning signs — stop and reset the conversation

None of these mean the project is broken. They all mean *this stretch* has
gone sideways, and pushing on will cost you an evening.

| What you notice | What it usually means | Do this |
|---|---|---|
| The same error keeps coming back with a slightly different fix each time | It is guessing | Say: *"stop — explain what is actually wrong in plain language before changing anything else"* |
| You have been on one problem for more than an hour | Sunk cost | Stop. `/perp-status`, commit what works, come back to it |
| "Almost there" three times in a row | It does not know either | Ask: *"what specifically is still broken?"* |
| Tests started passing right after the tests were edited | It may have weakened the test instead of fixing the code | Ask: *"did you change any test to make it pass? show me"* — this is `STOP-2` and it should never happen |
| You cannot say what changed in the last hour | You have lost the thread | `/perp-status`, then commit or undo |
| It is changing files you never mentioned | Scope creep | *"only do what I asked — put the rest in a list"* |
| It offers to "just rebuild" something that used to work | Almost always the wrong trade | Say no. Ask what specifically broke |
| You are being asked to paste a password or key into the chat | **Never do this** | See Secrets below |

**The reset phrase, when you are lost:**

> "Stop. In plain language: what were we doing, what is broken now, and what
> are my two simplest options?"

You are allowed to say that any time. It is not rude and it is not a
failure — it is the fastest route out of a hole.

---

## Rabbit holes — the expensive ones, in order

1. **Perfecting the first screen.** It only has to be good enough to use.
   Ship the slice, then improve.
2. **Building the thing you find interesting instead of the thing that
   hurts.** Your scope document names one friction. Everything competes with
   that.
3. **Chasing a version upgrade you did not need.** If it works, pin it and
   move on (`docs/CONTROLS.md` § Idiom churn).
4. **Adding a module because it was on a list.** The catalogue is a menu, not
   a plan. Most shops need the core plus two.
5. **Rewriting instead of finishing.** A rewrite feels like progress and
   produces none.

A useful question before any new piece of work: **"which friction from my
scope document does this remove?"** If there is no answer, it is a rabbit
hole wearing a good idea's coat.

---

## Undo — what you can and cannot get back

**Easy to undo** (ask for it in these words):

- *"Undo the last change"* — files go back to the last save point.
- *"Take us back to the last commit"* — everything since your last save,
  gone deliberately.
- *"Reset the sample data"* — demo rows only. ⚠️ Ask it to confirm it will
  **not** touch anything you typed in yourself.

**Hard or impossible to undo** — expect to be asked to confirm first:

- **Deleting real data.** Backups are the only route back. This is why the
  restore rehearsal exists before real customer data lands.
- **A database change that drops or renames a column.** The code goes back;
  the data does not.
- **Anything already published** (`/perp-push`). Publishing is not deletion-
  proof: assume anything pushed can have been seen.
- **A secret that has been exposed.** Deleting it does not fix it. See below.

---

## Secrets — the one thing to be strict about

A secret is a password, an API key, or anything that would let someone act
as you. Rules, no exceptions:

- **Never paste one into the chat**, not even "just to test it". Anything in
  the conversation should be assumed to be recorded somewhere.
- **Never let one be committed.** `/perp-commit` checks, but do not rely on
  it as your only defence.
- **If one does get exposed — including into the chat — it is burned.**
  Deleting the message does not help. It must be replaced at the source
  (`secure_coding.md` § 8 has the steps). Say so immediately; it is a
  five-minute fix and an expensive silence.

---

## Before you show anyone outside the shop

The system starts with **no login at all** so you can build without
plumbing — that is deliberate, and there is a permanent yellow banner
saying so.

⚠️ **While that banner is showing, anyone who reaches the app is you.**
Never put it on the public internet, never show it to a customer over a
public link. The go-live list in `docs/CONTROLS.md` is what turns that off,
and real login on both doors is the first line of it.

---

## When you genuinely are stuck

In order:

1. **`/perp-status`** — what changed, what is open, anything risky.
2. **`/perp-check`** — runs the checks and reports honestly, including what
   is *not* configured. It will not pretend something passed.
3. **Commit what works**, so the stuck part is isolated.
4. **Ask for the plain-language version.** *"Explain what is broken as if I
   do not know what a database is."* If the explanation does not make sense
   to you, it is not a good explanation.
5. **Walk away for an hour.** The failure mode this page exists to prevent
   is a five-hour evening, and it always starts with "one more try".
