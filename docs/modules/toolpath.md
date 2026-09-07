# Toolpath (DFM analysis)

Design-for-manufacturability findings from an uploaded CAD part. Detail page for `docs/MODULES.md` § Toolpath.

> This is the long form. The one-paragraph summary, and the facts you
> cannot afford to miss, stay in `docs/MODULES.md` — this page is what
> you read when you actually build it.

---

**Status:** new. API at `developers.toolpath.com`.

A CAD-analysis service: it takes a part and returns
design-for-manufacturability information. **Verified against the live spec
on 2026-09-05** (`GET https://api.toolpath.com/v1/openapi.json`, Toolpath
Engine API v1.3.3) — pin the spec version you generate a client against,
because everything below is a fact about *that* version:

- **Paths**: `/v1/parts`, `/v1/parts/{id}`, `/v1/parts/{id}/features`,
  `/v1/holders`, `/v1/jobs`, `/v1/jobs/{id}`, `/v1/jobs/{id}/events`,
  `/v1/keys/validate`, `/health`.
- **Auth is an API key sent as a `Bearer` credential** (`type: http`,
  `scheme: bearer`) — not an `X-API-Key` header, which is the wrong guess a
  hand-rolled client makes first. Company scope, not OAuth.
- **`/v1/keys/validate` exists** — use it as the integration's health check
  so a dead key surfaces before a job does, not after.

⚠️ **Everything is millimetres and degrees.** The spec is explicit: all
dimensional values, in parts and in feature details, are in **mm**; all
angles in **degrees**; each part response repeats it in a `units` field. A
US shop quoting in inches that treats a DFM dimension as inches is out by
25.4×, silently, in a number that feeds a price. **Convert at the boundary,
store one unit, and assert the `units` field on every response** — this is
the same class of bug as an unlabelled timezone or a float dollar, and it
belongs in the same category of care (`MONEY-1`).

⚠️ **Never put the key in the browser.** CORS is configured per key, so a
key with allowed origins *will* work from client-side code — and a Bearer
credential in a client bundle is a leaked credential. Server-to-server
only, from the worker, with the key in the host's secret store
(`secure_coding.md` § 8). A key with no allowed origins is server-only by
construction; prefer that.

Why it fits this kit unusually well: **the same uploaded STEP file feeds
two async derivations off one pattern.** Part Viewing runs OCCT to GLB
for the viewer; Toolpath uploads and gets DFM back for the quote. Same
`File`, same queue shape, same pending/ready/failed states PORTAL_UX
already requires you to render. The second one is nearly free once the
first exists.

**There are no webhooks — but do not poll.** The spec declares an empty
`webhooks` section, so nothing calls you back. It *does* offer
**`GET /v1/jobs/{id}/events`, a server-sent event stream**: it sends the
current job immediately, then every subsequent status, progress or error
change while the connection stays open. Consume that from the worker rather
than looping on `GET /v1/jobs/{id}` — it is fewer requests, lower latency,
and it gives you progress rather than a binary done/not-done.

**Reconnection is the part to get right.** The spec says a dropped
connection means reconnecting to receive the latest snapshot before
resuming. So the worker still needs a give-up bound and a resume path, and
the job row still needs `pending / processing / ready / failed` — an
interrupted stream must not leave a part stuck in `processing` forever.
Either way this lives in the worker, never in a request handler waiting on
a third party.

Where the output lands: DFM findings attach to the `PartRevision` and
surface in **Estimates** — manufacturability feedback is quoting input,
which is the actual friction this removes.

⚠️ **The export-control gate is mandatory here.** Toolpath is a
third-party hosted service, and `docs/STACK.md` § Part viewing already
says flagged files are never sent to one. An export-controlled STEP file
must be refused at the uploader by the `mayReceiveControlledData` check
above — not filtered downstream, and not left to the operator to
remember.

**Open decision, don't default it:** is DFM output customer-visible?
Staff-only is the safe read — it's your cost intelligence. But a portal
that tells a customer "this pocket is unmachinable as drawn" before they
order is a real friction-remover. Decide it explicitly per the parity
rule; either answer is fine, silence isn't.
