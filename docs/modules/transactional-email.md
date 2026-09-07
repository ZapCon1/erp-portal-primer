# Transactional email (Resend · Postmark · SES)

Detail page for `docs/MODULES.md` § Transactional email.

> This is the long form. The one-paragraph summary, and the facts you
> cannot afford to miss, stay in `docs/MODULES.md` — this page is what
> you read when you actually build it.

---

**Start this on day one, before you need it.** Not because email is hard,
but because it has the longest lead time of anything in the kit, and it
**blocks the portal**: customer login is a magic link, so until mail
actually arrives, no customer can get in. Domain verification means adding
DNS records and waiting for propagation — minutes if you are lucky, a day if
your DNS lives somewhere awkward. Every other setup step is under your
control; this one is not.

**Setup, in the order that avoids being blocked:**

1. **Pick a provider** — Resend (the kit's default, pairs with React Email
   for typed, previewable templates), Postmark, or SES if you are already in
   AWS and want mail in-partition (`docs/DEPLOYMENT_TARGETS.md` § The egress
   trap). All three are equivalent for this app; do not spend a day choosing.
2. **Start domain verification immediately.** You will add **SPF**, **DKIM**
   and ideally **DMARC** records for a subdomain you send from —
   `mail.yourshop.com` keeps your main domain's sending reputation separate
   from your website's. Do this on day one even if you will not send for
   weeks.
3. **Do not wait for it to build anything.** In dev the mailer writes the
   message to the console, magic-link URL included, so you can log in as a
   customer with no provider configured at all. That fallback is what keeps
   DNS off the critical path.
4. **Verify before go-live**, not before development: send one real magic
   link to a real inbox, and check it does not land in spam.

**The rules that matter once it is live:**

- **The dev fallback must be unable to run in production**, the same way the
  auth stub cannot (`SEC-2`). A mailer that silently logs instead of sending
  is worse than one that errors: invoices and magic links stop arriving and
  nothing tells you.
- **Every send is logged, and a failure alerts a human** (`OPS-3`,
  `CLAUDE.md` § No Swallowed Failures). A dead sender means invoices and
  logins silently stop, and you find out when a customer calls — which is
  the friction this whole system exists to remove.
- **Handle bounces and complaints.** Sending repeatedly to a dead address
  wrecks your sender reputation and takes the working addresses down with
  it. Keep a suppression list; a hard bounce marks the contact and surfaces
  on the client record so a human fixes it.
- **Magic-link mail follows `secure_coding.md` § 13** — short expiry, one
  active link, and remember that mail-security scanners pre-fetch links, so
  a link must not be consumed by a bot's GET.
- **Email is an egress path.** An invoice PDF or a job-status mail carries
  your content to a third party. If Phase 3 said ITAR or CUI that matters
  directly: keep controlled data out of bodies and attachments, or send
  in-partition (`CUI-1`).
- **Customer-facing copy runs through `/perp-voice`** — auth, money and
  legal strings excepted. Email is where the shop's voice reaches the
  customer most often.

**Portal face:** none, but the *effects* are portal-visible — a customer
whose magic link never arrives experiences it as "the portal is broken".
Give the login page a "didn't get it? request a new link" path and the
request-ID pattern from `secure_coding.md` § 6.
