# Profile — spec

## Profile photo

Users can upload a profile photo.

### Behavior

- A signed-in user can upload an image to set as their profile photo from their own profile settings.
- **Accepted formats:** PNG, JPEG, WebP, HEIC. Any other type (including SVG) is rejected. File type is validated by inspecting the actual byte signature / decoded content, **not** the filename extension or the client-supplied `Content-Type`.
- **Size limit:** maximum 5 MB per upload *on the wire*. Larger files are rejected before storage.
- **Decoded-dimension limit:** independently of byte size, the upload is rejected if its *decoded* dimensions exceed a sane ceiling (default **50 megapixels**, e.g. > ~8000×6000). This caps memory during re-encode and defeats decompression-bomb files (a tiny byte payload that decodes to gigapixels). The guard runs *before* the full decode/re-encode, never trusting declared dimensions.
- **Processing:** on accept, the image is re-encoded server-side to a normalized format (square crop to the user's chosen framing, then resized to a canonical max edge of 512 px and a 128 px thumbnail). Re-encoding also strips EXIF metadata (including GPS) and neutralizes any embedded active content.
- **Rate limit:** profile-photo uploads are rate-limited per user (default **10 uploads / hour**). Re-encoding is CPU-bound, so an unbounded endpoint is a denial-of-service and storage-churn vector; over-limit attempts return a clear, retry-after error and leave the current photo unchanged.
- **Replacing a photo:** uploading a new photo replaces the existing one; the prior stored object (and its thumbnail) is deleted, not orphaned. Stored objects use **immutable, unguessable keys** (no overwrite-in-place at a stable path), so the new photo is published as a fresh object and the swap is atomic from the reader's side. After the new object is committed, the CDN entry for the *old* object is invalidated (or the old key simply stops being referenced and ages out); the old object and its thumbnail are then deleted. If that delete fails, the new photo is still live and correct — the failed cleanup is retried by a background sweep, never blocking the user.
- **No photo / first run:** when a user has never uploaded a photo, the UI shows a generated default placeholder (e.g. initials avatar). A user may remove their photo, which reverts them to the placeholder.
- **Actors:** a user may change only their own photo. An admin may *remove* (but not replace) another user's photo for moderation; every admin removal is recorded in the audit log.
- **Storage:** photos are stored in the project's configured object store, served over the CDN, behind the same access rules as the rest of the user's profile data.

### Failure & recovery

- An upload that fails mid-transfer leaves the previous photo intact; the user sees a clear "upload failed, try again" message and can retry. No partial/corrupt object is ever made visible.
- A rejected file (wrong type, too large, undecodable) returns a specific, human-readable reason; the prior photo is unchanged.

### Acceptance criteria

- [ ] Accepts PNG, JPEG, WebP, HEIC; **rejects** SVG and all other types, validated by content signature not extension.
- [ ] Rejects any file larger than 5 MB on the wire with a clear message; the prior photo is unchanged.
- [ ] Rejects an image whose *decoded* dimensions exceed the megapixel ceiling (default 50 MP) before full decode; a decompression-bomb file (tiny bytes, gigapixel decode) is rejected, not processed.
- [ ] Per-user upload rate limit (default 10/hour) is enforced; over-limit uploads return a retry-after error and leave the current photo unchanged.
- [ ] Uploaded images are re-encoded server-side, EXIF/GPS stripped, normalized to 512 px + 128 px thumbnail.
- [ ] Replacing a photo writes a fresh immutable object, invalidates/retires the old CDN entry, and deletes the prior object and thumbnail (no orphans); a failed delete does not lose or corrupt the new photo and is swept later.
- [ ] A user with no photo sees a generated placeholder; removing a photo reverts to the placeholder.
- [ ] A user can change only their own photo; an admin can remove another user's photo and the removal is audit-logged.
- [ ] A failed/interrupted upload preserves the existing photo and surfaces a retry-able error.

## Out of scope

- Animated avatars (GIF/APNG/video), filters/effects, and AI-generated avatars.
- Photo cropping/editing UI beyond a single square-crop framing step.
- Admin *replacing* (vs. removing) another user's photo.
- Gravatar / third-party avatar import.
- Multiple photos or a photo gallery per profile.

## Clarifications

### 2026-06-02

- **Q: Which image formats are accepted, and how is the type validated?**
  Decision: PNG/JPEG/WebP/HEIC only; reject SVG; validate by byte signature, not extension/Content-Type.
  Why: SVG can carry executable script (stored-XSS vector); trusting the extension or client MIME is forgeable. Restricting to raster formats and sniffing content closes the upload as an attack surface. *(Default proposed in absence of a constitution — assumed unless you object.)*

- **Q: What is the maximum file size?**
  Decision: 5 MB, rejected pre-storage.
  Why: Large enough for any phone photo, small enough to bound storage/bandwidth and resist abuse. *(Default — confirm or set your real ceiling.)*

- **Q: When a user replaces their photo, what happens to the old file?**
  Decision: the prior object and thumbnail are deleted.
  Why: Orphaned blobs leak storage cost and create privacy debt (old faces lingering). Deleting on replace keeps storage and the data model honest.

- **Q: Who can change a user's photo?**
  Decision: only the user themselves; an admin may *remove* another user's photo (moderation), logged in the audit trail; admin replacement is out of scope.
  Why: Editing identity on someone's behalf is a trust/abuse risk; moderation needs takedown, not impersonation.

- **Q: What happens on no photo and on a failed upload?**
  Decision: generated placeholder when absent / removed; failed uploads keep the existing photo and offer retry.
  Why: Removes the empty-state and partial-write gaps that the original one-liner left silent.

- **Q: Is the image processed server-side?**
  Decision: yes — re-encode, square-crop to chosen framing, normalize to 512 px + 128 px thumbnail, strip EXIF/GPS.
  Why: Normalization fixes layout/perf; EXIF stripping prevents leaking the uploader's GPS location; re-encoding defangs malformed-image and embedded-content attacks.

### 2026-06-02 — second clarify pass (remaining taxonomy gaps before plan)

- **Q: Does the 5 MB byte limit actually bound what the server decodes?**
  Decision: No — add an independent *decoded-dimension* ceiling (default 50 MP), checked before full decode.
  Why: Byte size and decoded size are different axes. A few-KB PNG/WebP can decompress to gigapixels (a "decompression bomb") and OOM the re-encode worker. The on-the-wire cap doesn't catch this; a pixel cap does. *(Default ceiling — confirm or set your real one.)*

- **Q: Is the upload endpoint protected against abuse / DoS?**
  Decision: Yes — per-user rate limit, default 10 uploads/hour, over-limit returns a retry-after and leaves the photo unchanged.
  Why: Re-encoding is CPU-bound and writes/deletes storage objects; an unbounded endpoint is both a DoS and a storage-churn vector. This is a build-path decision (middleware/limiter), not cosmetic. *(Default rate — confirm or tune.)*

- **Q: "Deleted, not orphaned" — what about CDN cache, and what if the delete fails?**
  Decision: Use immutable unguessable object keys (no overwrite-in-place); publish the new object, invalidate/retire the old CDN entry, then delete the old object+thumbnail. A failed delete must not lose or corrupt the new photo — it is retried by a background sweep.
  Why: Overwrite-in-place at a stable path means readers can see a half-written object and the CDN can serve a stale/old face after replacement (a privacy issue). Immutable keys make the swap atomic for readers; decoupling cleanup from the user request means a storage hiccup degrades to "old blob lingers briefly," not "user lost their new photo." This closes the partial-write and stale-cache gaps the first pass left implicit.
