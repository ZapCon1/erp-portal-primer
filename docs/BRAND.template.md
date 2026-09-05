# Brand — <TODO: company display name>

_Written by `/perp-scope` Phase 6, or filled by hand. `/perp-build-core`
reads this file, so it always exists — **with the defaults below in force
and labelled as such** when no brand was collected. A shop with no website
and no logo still gets a coherent app._

## Name

- **Display name** (invoices, portal header, emails): <TODO>
- **Legal name**, if different and needed on documents: <TODO>

## Logo

- **File**: <TODO: path in repo, or "none — wordmark set in the display name">
- **Dark background variant**: <TODO: path, or "none — reverse the wordmark">

## Palette

Fill the accent only; the neutrals and semantic colors come from
`docs/PORTAL_UX.md` § Default tokens and should not be re-decided per
project.

| Role | Hex | Contrast checked |
|---|---|---|
| Primary accent (sidebar, active states, primary buttons) | <TODO — default `#1B5FB0`> | <TODO: ratio on white> |
| Accent for **text** (if the brand hex fails 4.5:1) | <TODO: darkened variant, or "same"> | <TODO> |

⚠️ **Two hexes, on purpose.** A brand color that looks right on a button
often fails contrast as text. Record both — the brand hex for fills, the
accessible variant for anything a person reads (`docs/PORTAL_UX.md`
§ Accessibility baseline). If the interview extracted colors from a website,
note which is which rather than assuming one works everywhere.

## Tone

- **How the business sounds** (three adjectives from the interview, or
  observed from their site): <TODO>
- Customer-facing prose runs through `/perp-voice`; this section is the
  starting point, `docs/VOICE.md` is the living profile.

## Status

- [ ] Brand collected from the owner (website, logo, or stated preference)
- [ ] Running on defaults — **no brand collected yet.** Swapping one hex
      later is a five-minute change because everything else is tokens.
