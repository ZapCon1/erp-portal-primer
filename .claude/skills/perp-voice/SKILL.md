---
name: perp-voice
description: Make the system write like its owner instead of like AI — customer emails, portal microcopy, empty states, estimate and invoice notes. Seeds a voice profile (docs/VOICE.md) from the answers already typed during /perp-scope, so no extra interview is needed. Use when writing any customer-facing prose, when the user says copy "sounds like a robot" or "doesn't sound like us", or to calibrate/correct the profile.
---

# Voice — make it sound like the shop, not like software

Every ERP built from this kit starts from the same templates. Without
this skill they all *talk* the same way too: the same cheerful empty
states, the same "We've received your request!", the same em-dashed
politeness. A customer can tell. The shop owner can definitely tell —
it's their name on the email.

The fix is that the owner already wrote several paragraphs in their own
voice during `/perp-scope`, answering questions about their business.
**Those answers are writing samples.** This skill turns them into a
profile and applies it to every word the system says to a customer.

The single source of truth is **`docs/VOICE.md`**. It sits beside
`docs/SCOPE.md` and `docs/BRAND.md` as a per-project artifact — the kit
ships the method, never a profile.

## Where voice applies — and where it must not

**Applies** (customer- and staff-facing prose):

- transactional email bodies (estimate sent, invoice due, magic link)
- portal microcopy: empty states, confirmations, help text, FAQ
- estimate/invoice notes, terms blurbs, pre-canned note blocks
- dashboard tile labels and any sentence a person reads for meaning

**Never applies** — these outrank voice, always:

- **Security semantics.** `secure_coding.md` and `PORTAL_UX.md` § "Error
  copy mirrors the security semantics" govern error text. A cross-tenant
  404 stays a flat 404; no amount of shop personality may hint that
  another customer's record exists.
- **Accessibility.** Labels, `aria-*`, alt text, form errors, and focus
  order follow `docs/PORTAL_UX.md`. A screen-reader label is a
  functional string, not a place for charm.
- **Money, dates, legal.** Amounts, tax lines, payment terms, due dates,
  and anything a lawyer or an accountant would read verbatim. Voice may
  shape the sentence *around* the number; it never restates the number.
- **The request-ID pattern** (`secure_coding.md` § 6) and other
  contracts a support process depends on.

When voice and any of the above disagree, the above wins and you say so
in one line rather than quietly splitting the difference.

## Mode selection

- **Seed** — `docs/VOICE.md` doesn't exist yet: derive it from the
  interview answers (below). This is the normal path, run automatically
  by `/perp-scope`.
- **Write** — asked to produce customer-facing copy: read the profile,
  draft for substance, then the voice pass and the AI-tell strip.
- **Rewrite** — existing copy sounds wrong ("this doesn't sound like
  us"): diff it against the profile, fix, and feed the correction back.
- **Calibrate** — the owner wants a richer profile than the interview
  gave: run the enrichment prompts.

## Seeding from the interview (no extra questions)

`/perp-scope` collects long free-text answers: what the business does,
how a job flows, what's most painful, what customers find annoying, what
they wish they had. That is several hundred words the owner typed
unprompted, in their register, about their own work. It is better voice
data than any writing exercise, because they weren't performing.

To seed:

1. Read `docs/SCOPE.md`, and `docs/SCOPE.draft.md` if it still exists —
   **the draft is more valuable**, because it holds answers closer to
   verbatim, before summarizing smoothed them out. Prefer raw answer
   text over your own paraphrase of it, always.
2. Extract observable habits only — things you can point at in the text:
   sentence length and how much it varies, contractions, capitalization
   at the start of a line, comma density, dashes, exclamation points,
   profanity, trade vocabulary and abbreviations, how they refer to
   customers ("customers", "clients", "the guys at Acme"), whether they
   write in fragments.
3. Write `docs/VOICE.md` using the structure below. Tag every rule
   `observed` — nothing is `confirmed` until the owner says so.
4. **Show it to them and say where it came from.** One short message:
   the profile exists, it was derived from how they answered the
   interview, here are the three or four most notable rules, what's
   wrong with it? Never build a voice profile from someone's words
   without telling them you did.
5. Their corrections are the highest-grade data. Re-tag corrected rules
   `confirmed` and date them.

**Thin data is normal.** An express-mode interview yields maybe two
paragraphs. Write the profile anyway, mark it thin, and note in
`docs/VOICE.md` § Open that the AI-tell strip is doing most of the work
until more samples exist. A thin profile plus the strip list still beats
default AI prose by a wide margin.

## Enrichment prompts (optional, only if asked)

One at a time, plain conversation, 2-6 sentences each. Save each answer
verbatim — typos and all — to `docs/voice-samples/NNN-slug.md` with the
prompt and date in a one-line header. Pick prompts for registers the
profile lacks:

- The email you'd send a customer whose job is running a week late.
- How you'd explain what you make to someone outside the industry.
- A note to a customer whose invoice is 30 days overdue.
- The reply to a customer asking for a rush job you can't fit.
- How you'd tell a customer their quote went up after a scope change.

Notice these are all real ERP moments. Every sample doubles as source
material for copy the system will actually need.

## Write / Rewrite protocol

1. Read `docs/VOICE.md`. Thin? Say so once, then do the job anyway.
2. Draft for **substance and correctness first** — the right facts, the
   right states, the security and a11y rules from PORTAL_UX. Voice is a
   pass over correct copy, never a substitute for it.
3. **Voice pass** — rewrite against the profile: rhythm, punctuation
   habits, vocabulary, greetings and sign-offs, formality, how long a
   paragraph runs.
4. **AI-tell strip** — mandatory, even with an empty profile.
5. Check it against the "never applies" list. Anything in those
   categories reverts to the canonical wording.

## Feedback loop (always on)

Whenever the owner edits, corrects, or reacts to generated copy — "we'd
never say that", a reworded button, a rewritten email sent back — diff
their version against yours, update `docs/VOICE.md` with what the diff
teaches, mark it `confirmed` with the date, and save any full rewrite to
`docs/voice-samples/`. A correction that evaporates into the
conversation will be re-made next week as the same mistake.

## docs/VOICE.md structure

A checklist to execute, not an essay:

- **Hard rules (confirmed)** — stated outright by the owner. Never violate.
- **Punctuation & mechanics** — dashes, commas, capitalization, exclamation points, emoji, ellipses.
- **Rhythm & shape** — sentence-length mix, paragraph length, openings, closings, fragments.
- **Vocabulary** — words they use; words they'd never use; what they call a job, a customer, a quote. **This overlaps the shop vocabulary in SCOPE.md — SCOPE.md wins on entity names** (if they call it a "job", the schema and UI say job); VOICE.md governs the prose around it.
- **Register map** — how the voice shifts: customer email vs internal note vs portal button vs overdue notice.
- **Sign-offs & greetings** — exact strings, including the boring ones.
- **Provenance** — which answer or sample each rule came from, with date and a confidence tag (`confirmed` / `observed` / `guess`).
- **Open** — what's still unknown, and whether the profile is thin.

## AI-tell strip list

Remove or rewrite ALL of these **unless the profile shows the owner
actually does them** — that caveat is the whole point, because some
people really do write in threes and really do love an exclamation
point:

- Em dashes and en dashes as punctuation. Most people type a comma, a period, or parentheses. Check the interview answers for what they actually use before assuming.
- "It's not just X, it's Y" and other contrast-pivot constructions.
- Rule-of-three as a reflex: triple adjectives, three parallel clauses, three-item lists where two or four would be truer.
- Perfectly parallel structure across consecutive sentences or bullets.
- Every paragraph the same length. Real writing is lumpy.
- Stock AI vocabulary: delve, leverage, robust, seamless, streamline, elevate, unlock, empower, game-changer, landscape, journey, dive into, navigate (metaphorical), crucial, comprehensive, holistic, synergy, cutting-edge, "in today's fast-paced world".
- Throat-clearing: "It's worth noting that", "Importantly,", "That said,", "In essence".
- Tidy-bow endings: "In conclusion", a summary restating what was just said, an inspirational closer.
- Overformatted output — headers and bullets where a person would write two sentences. Default to prose under ~150 words.
- Title Case Headings and colon-titles ("Invoicing: Why It Matters").
- Fake enthusiasm: "Great question!", "I'd be happy to", "We're excited to".
- Writerly aphorisms and quotable twist phrases. If a line sounds like a pull quote, say it plainer; the fact carries it.
- Faux-candor filler: "honestly", "let's be real".
- Suspiciously flawless grammar in a casual register, when the profile shows lowercase starts or loose punctuation.

**Trade voices are blunt.** Shop owners, contractors, and machinists
often write shorter and flatter than the AI default, with no warmth
padding. Copy that reads polite and corporate is usually wrong for
them even when nothing on this list appears in it.

## Notes

- **Project-scoped by design.** The profile belongs to this business and lives in this repo. If a maintainer also keeps a personal voice skill at the user level, this one wins for anything the ERP says to a customer — the ERP speaks as the shop, not as whoever is at the keyboard.
- BRAND.md's tone adjectives (from the company website, if `/perp-scope` fetched one) are an **input** to VOICE.md, not a peer. Marketing-site tone is what an agency wrote; the interview answers are what the owner actually types. When they disagree, trust the interview and note the conflict.
- Parity applies to words too: the same event described on both surfaces should read consistently. `/perp-review-parity` covers the numbers; a voice mismatch between staff and portal copy is the same class of bug, one severity lower.
