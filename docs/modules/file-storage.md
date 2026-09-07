# File storage — Box · Dropbox · SharePoint/OneDrive · Google Drive

Detail page for `docs/MODULES.md` § File storage.

> This is the long form. The one-paragraph summary, and the facts you
> cannot afford to miss, stay in `docs/MODULES.md` — this page is what
> you read when you actually build it.

---

**Status:** new. The most-requested integration in a shop that already
lives in one of these, and the one with the most hidden consequences.

**The default is the kit's own storage** (S3-compatible, tenant-first
layout, `docs/STACK.md` § Part viewing). Using an outside service is a
deliberate trade, not an upgrade — make it knowingly.

**Three modes. Pick one and say which; they are not interchangeable.**

| Mode | What it means | Honest read |
|---|---|---|
| **Reference** | The file stays in Box/Dropbox. You store a pointer and a link. | Cheapest. The app never really has the file — no thumbnails, no CAD derivatives, no portal preview, and no audit of who opened it. |
| **Ingest** | On upload the file is copied into your storage; theirs is the drop-off. | **The recommended one.** Staff keep the folder habit they already have; the app owns the copy that matters. |
| **Two-way sync** | Both sides authoritative, changes propagate. | Two sources of truth for the same bytes, plus conflict resolution. Avoid unless someone insists and then argue once. |

**Four consequences people discover late:**

1. **Their permission model becomes your permission model.** The kit's
   tenancy rests on every portal query filtering by `clientId`, with
   files laid out tenant-first. Once the file lives in Box, *Box's*
   sharing settings decide who can read it — and one "anyone with the
   link" folder silently bypasses every auth wrapper you wrote. In
   Reference mode this is not a bug you can fix in your code. Ingest
   mode is partly why it's recommended.
2. **Audit stops at your boundary.** A download straight from Dropbox
   never reaches your audit log. For export-controlled files and for
   AS9100 records this defeats the requirement — `docs/STACK.md`
   § Part viewing already says controlled files get proxied through the
   app so the access is logged. That rule outranks the convenience.
3. **Doc control owns revisions — the storage service does not.** This
   is the collision worth planning for: Box, Dropbox, and SharePoint all
   keep their own version history, and Doc Control keeps rev letters
   with approval state. **Two version histories for one drawing is a
   second source of truth**, exactly like the `PartRevision` case above.
   The rule: the app owns `DocumentRevision`; the service is a dumb blob
   store whose native versioning is *not* the record. If someone edits
   in place in Dropbox and the rev letter doesn't move, your controlled
   document quietly became uncontrolled.
4. **Derivatives stay in your storage.** GLB previews and thumbnails are
   generated data the viewer loads by presigned URL — they belong beside
   your `FileDerivative` rows, not in the customer's Dropbox, whatever
   mode the original uses.

**Export-controlled and CUI**: the `mayReceiveControlledData` gate
applies unchanged. Commercial Box/Dropbox/Drive tenants are third-party
hosted services; some vendors offer government-community tiers, and
whether one satisfies your obligation is an assessor question, not a
marketing-page question (`docs/DEPLOYMENT_TARGETS.md` § The egress trap).

**Portal face:** none directly — customers keep using the portal's file
view, which is the point. The integration changes where staff put files,
not how customers get them. If a customer would end up in someone
else's Box, the design is wrong.
