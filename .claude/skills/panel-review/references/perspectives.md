# Perspective briefs

Each spawned agent should read its own section, then review the scope through that lens across **both** axes — UX/UI surface and feature depth/correctness — and run the Depth & Correctness checklist from SKILL.md. Stay in character: the value is the distinct mindset, not 16 generic reviews. Cite evidence (`file:line` or a reproduced behavior); label suspected vs confirmed; name what's *missing*, not just what's wrong.

---

## 1. New user — "What is this? What do I click first?"
- **UX/UI**: First-run and empty states. Is the primary action obvious within 5 seconds? Is there orientation, or are you dropped into a wall of controls? What does the screen look like with zero data?
- **Depth**: Does onboarding actually set up a working state, or leave dead ends (a button that needs config that isn't explained)? Does the "getting started" path reach a real outcome?
- **Good finding**: "New org lands on /dashboard with 6 empty widgets and no next-step CTA — the only path forward (create a client) is unlabeled in the sidebar. `DashboardContent.tsx:40`."

## 2. Non-technical user — "I don't understand half these words."
- **UX/UI**: Jargon, internal codenames, unexplained acronyms, ambiguous labels. Would a domain outsider know what "phase", "off-site lead", "retainer pooled hours" mean?
- **Depth**: Do tooltips/help text exist where the concept is load-bearing? Are error messages human ("we couldn't reach your calendar — reconnect it") or codes?
- **Good finding**: "Portal shows 'preflight checklist' and 'closeout signoff' with no explanation; a customer won't know these are required steps."

## 3. Power user / expert — "Why is this so slow? Let me do it my way."
- **UX/UI**: Keyboard support, bulk actions, defaults that fight you, clicks-per-task on the 100th repetition. Can they skip the hand-holding?
- **Depth**: Are there bulk/API/automation paths, or is everything one-at-a-time? Do filters/sorts persist? Is there an undo?
- **Good finding**: "Scheduling 12 weekly check-ins means submitting 12 separate requests — no recurrence, no duplicate. Power users will do it in their own calendar and bypass the app."

## 4. Prospective customer — "Why buy this instead of an alternative?"
- **UX/UI**: Is the differentiated value visible, or buried? Does the headline feature look as good as a competitor's screenshot?
- **Depth**: Is the marquee feature actually deep, or a thin veneer over a manual process? Where would a trial user hit "oh, it doesn't actually do that"?
- **Good finding**: "The 'calendar integration' selling point is a manually-pasted link field — a trial user expecting real sync churns on day one."

## 5. Prospective investor — "Can this become a real business?"
- **UX/UI**: Does it look like a product or an internal tool? Signals of scale/polish.
- **Depth**: Defensibility, moat, data/network effects, the gap between what's demoed and what's built. Is the roadmap real or a wish list? Is core infra (auth, billing, multi-tenancy) solid or duct tape?
- **Good finding**: "Multi-tenancy relies on every query manually filtering clientId with no ORM safety net — one missed filter is a cross-tenant breach; this is a diligence red flag, not just a bug."

## 6. Business owner — "Will this make money without consuming my life?"
- **UX/UI**: Does daily operation require constant babysitting? How much manual reconciliation?
- **Depth**: Where does the product create work instead of removing it? Hidden operational tax (manual calendar adds, manual invoice matching, manual reminders). Does it scale past the owner's personal attention?
- **Good finding**: "Every accepted meeting must be manually re-added to the real calendar — the feature creates an extra step rather than removing one."

## 7. Support technician — "How many emails will this generate?"
- **UX/UI**: The top confusion points that become tickets. Anything ambiguous, silent, or easy to get wrong.
- **Depth**: Silent failures (action appears to succeed but didn't), missing confirmations, states with no recovery path, things only an admin can unstick. Each is a recurring ticket.
- **Good finding**: "If the host has no connected calendar, scheduling silently produces no invite and the customer just never gets it — a guaranteed 'where's my meeting?' ticket with no in-app signal."

## 8. Salesperson — "Can I explain this in 30 seconds?"
- **UX/UI**: Is there a crisp demo path that shows value fast, or does the demo wander?
- **Depth**: Does the 30-second story survive contact with the real feature, or does it require "ignore that part for now"? Gap between pitch and product.
- **Good finding**: "The pitch is 'request a meeting and we handle it' but the demo requires the rep to manually pick a time and paste a Zoom link — the story breaks mid-demo."

## 9. Competitor — "Where are they vulnerable?"
- **UX/UI**: The embarrassing rough edges a competitor would screenshot.
- **Depth**: The shallowest features (easiest to out-build), missing table-stakes, integration gaps, the feature that's all label and no substance. Where would a competitor say "they don't really do X"?
- **Good finding**: "Timezone handling is naive wall-clock — any competitor serving multi-region customers wins the head-to-head the moment a demo crosses a timezone."

## 10. QA tester — "How do I break it?"
- **UX/UI**: Inconsistent states, stale data after an action, double-submit, back-button weirdness.
- **Depth**: Adversarial inputs and sequences — empty/huge values, concurrent edits in two tabs, out-of-order state transitions (decline→schedule), DST boundaries, leap days, the action that half-completes. Reproduce, don't theorize.
- **Good finding**: "Reset-to-pending leaves respondedById/respondedAt populated, so a 'pending' request still shows 'Responded by Sam' — confirmed at `route.ts:93`."

## 11. Security reviewer — "How could someone abuse this?"
- **UX/UI**: What's exposed that shouldn't be (IDs, other tenants' data in dropdowns, error messages that leak existence).
- **Depth**: AuthZ on every endpoint, multi-tenant isolation, IDOR, injection, token storage, over-broad scopes, SSRF via user-supplied URLs (meeting links!), data sent to third parties. Trace who can call what with whose data.
- **Good finding**: "The meeting-link field is rendered as an href with no scheme validation — `javascript:` or credential-phishing URLs reach staff and customers unfiltered."

## 12. Accessibility reviewer — "Can everyone actually use it?"
- **UX/UI**: Keyboard navigation, focus traps in modals, color-only signaling (status chips and badges are the usual offenders), contrast, alt text, screen-reader labels, target sizes.
- **Depth**: Are dynamic updates announced? Do custom controls (toggles, dropdowns) have proper roles? Is anything *only* operable by mouse or *only* distinguishable by color?
- **Good finding**: "Invoice status is signaled by chip background color only (green paid / red overdue) — a colorblind bookkeeper can't tell them apart. Add the status word or a ✓/⚠ glyph as the non-color signal."
- **Project baseline**: if the repo declares an accessibility baseline (e.g. `docs/PORTAL_UX.md` — required states, keyboard rules, no color-only signaling), audit against it explicitly and cite the sections it violates — don't invent a parallel standard.

## 13. Performance engineer — "Will this still work with 10,000 users?"
- **UX/UI**: Perceived speed, loading states, jank on large lists.
- **Depth**: N+1 queries, missing indexes, unbounded fetches, per-render external API calls, work that should be batched/cached/paginated, synchronous calls in a request path that should be background. What's O(n) per user that becomes O(n²) at scale?
- **Good finding**: "Availability fetch calls the Google API live on every host-change with no cache; a busy week + frequent host switching hammers the quota and adds seconds of latency."

## 14. Operations / DevOps — "Can we deploy and monitor this without heroics?"
- **UX/UI**: n/a — focus on operability.
- **Depth**: Migrations (and whether deploy docs mention them), required env/secrets and what happens when they're missing, feature flags, observability (are failures logged/alerted or swallowed?), rollback safety, build/runtime resource cost, background jobs and their failure modes.
- **Good finding**: "Schema adds columns but nothing in the deploy path runs `prisma db push`; a deploy without it 500s on first write. And calendar-push failures are console.error only — no alert, so a broken integration is invisible in prod."

## 15. Designer / UX — "Is this visually obvious and consistent?"
- **UX/UI**: Visual hierarchy, alignment, spacing, consistency with the rest of the app (does this modal match the others?), affordances, state feedback, responsive behavior.
- **Depth**: Is the design system actually reused or re-implemented? Do the same concepts look the same across surfaces (internal vs portal parity)? Is the primary action visually primary?
- **Good finding**: "This schedule modal re-implements buttons/inputs instead of the shared components used elsewhere — drift in padding and focus rings; and the portal twin looks different from the internal one."

## 16. Future maintainer — "Will we hate ourselves in two years?"
- **UX/UI**: n/a — focus on the code's future cost.
- **Depth**: Duplication (two near-identical components — which is dead?), untested critical paths, magic values, missing types, comments that lie, docs that drift from code, abstractions that leak, the thing everyone's afraid to touch. What will rot, and what's already rotting?
- **Good finding**: "Two near-identical meeting components exist; one is imported nowhere (dead) — a parity hazard where a fix lands in the wrong copy. Delete the dead one. `MeetingRequestsSection.tsx` (unreferenced)."

---

## Reusing the convergence

When you synthesize, notice which findings several perspectives independently hit — that convergence is the strongest signal of a real, high-priority problem. A timezone gap caught by Competitor + QA + Customer + Maintainer at once is not four findings; it's one critical finding with four witnesses.
