# Image model reference (Replicate)

Verified 2026-06-02. **Slugs and parameter names drift.** Treat this table as a starting point and
confirm the exact input schema and allowed values on the model page (`replicate.com/<owner>/<model>`)
before relying on a parameter. Pricing figures are order-of-magnitude upstream rates; Replicate may
mark up — re-check the model page before quoting a number.

---

## google/nano-banana-2 — Gemini 3.1 Flash Image

Google's fast image generation + editing model (announced 2026-02-26): Pro-level quality at Flash
speed and price. Best default for editing and multi-image composition.

Identity corroboration (two independent sources, since the slug and "Gemini 3.1 Flash Image" tie are
load-bearing for the whole skill): the live Replicate model page `replicate.com/google/nano-banana-2`
(fetched 2026-06-02) states verbatim "Nano Banana 2 is Google's latest image generation model, built
on Gemini 3.1 Flash Image" — confirming both the slug and the underlying model. This matches the
2026-02-26 google blog announcement and the Google Cloud model docs
(`docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/3-1-flash-image`). If the model
page no longer resolves or names a different base model, treat the slug below as drifted and re-verify.

Inputs:
- `prompt` — string, prose (see prompt shape).
- `image_input` — array of up to **14** reference images for editing/composition. Each entry is a
  file/Buffer (auto-uploaded), an `https://` URL string, or a `data:` URI string.
- `aspect_ratio` — one of: `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`,
  `match_input_image`. (The model page's prose mentions extreme `1:4`/`4:1`/`1:8`/`8:1` ratios as
  "new", but the formal aspect-ratio spec lists only the set above — treat the extremes as unconfirmed
  and verify on the model page before using one.)
- `output_format` — `jpg` (default) or `png`.
- `output_resolution` — `512px`, `1K` (default), `2K`, `4K`.

Prompt shape: prose, `[Subject] + [Action] + [Location/context] + [Composition] + [Style]`. Edits are
conversational ("Remove X. Keep everything else identical."). Text: literal string in quotes + named
font; can translate text.

Cost (relative tiers, not exact dollars): per-image price climbs with resolution — `512px` cheapest
→ `1K` (default) → `2K` → `4K` dearest, with the high tiers costing several times the low tier.
Resolution dominates cost. As of the 2026-06-02 fetch the model page `replicate.com/google/nano-banana-2`
shows **no fixed per-image dollar block** — this skill deliberately states tiers, not dollars, because
the only exact figures circulating are on non-authoritative aggregators. Read the live "Pricing" block
on the model page (authoritative) before quoting any number; do not lift a dollar figure from a blog.

Pick when: editing an existing image, merging multiple references, or rendering text in a layout.

---

## google/nano-banana-pro — Gemini 3 Pro Image

Higher-quality sibling of NB2 for hard compositions and maximum fidelity.

Inputs: same shape as nano-banana-2 (`prompt`, `image_input`, `aspect_ratio`, `output_format`,
`output_resolution`) — confirm exact set on the model page.

Cost: roughly **2x** NB2 at the same resolution (relative tier only, not an exact dollar figure —
confirm on the model page's live pricing block; do not quote a per-image dollar amount from a blog).

Pick when: NB2 genuinely can't nail the composition/quality and the budget allows. Not the default.

---

## black-forest-labs/flux-1.1-pro

Flux flagship with strong control over style, lighting, and composition.

Inputs (confirm on model page):
- `prompt` — dense single-paragraph description.
- `aspect_ratio` and/or `width` / `height`.
- `seed` — integer for reproducibility.
- `output_format` — `jpg` / `png` / `webp` depending on the model.

Prompt shape: one rich paragraph weighting subject + lighting + lens. Thin prompts get auto-filled.

Pick when: dense photoreal with fine control of light/lens; A/B prompt iteration via fixed `seed`.

---

## black-forest-labs/flux-dev

Open-weight Flux for general text-to-image; supports `seed`, `aspect_ratio`/`width`/`height`,
`output_format`, and `num_outputs` where applicable. Streaming-capable in the JS client.

Pick when: a balance of quality and cost without the Pro premium.

---

## black-forest-labs/flux-schnell

Fastest, cheapest Flux; listed as sync-optimized in the JS client README.

Pick when: rapid draft loops and previews. Render finals on a higher-quality model.

---

## openai/gpt-image-1 (OpenAI on Replicate)

OpenAI's image model exposed on Replicate. Follows complex instructions and renders readable text
well; usable as an editor. **Requires an OpenAI key wired into the Replicate model.**

Prompt shape: instructional brief with explicit constraints (layout, stroke, spacing, labels).

Pick when: strict instruction-following or crisp readable text matters more than photoreal style.

---

## bytedance/seedream-4 — Seedream 4.0

Unified text-to-image + editing; up to 4K; multi-reference and batch/sequential generation. (Seedream
4.5 exists upstream — check the model page for the current Replicate version.)

Inputs (confirm exact names on the model page): `prompt`, `size` (resolution), `image_input`
(references), `max_images` / `sequential_image_generation` for batches, `seed`.

Prompt shape: state the references and their relationship; ask for the batch count explicitly.

Pick when: you need up-to-4K output or a coherent batch/sequence from references.

---

## Slug allowlist (used by scripts/verify.sh)

```text
google/nano-banana-2
google/nano-banana-pro
black-forest-labs/flux-1.1-pro
black-forest-labs/flux-dev
black-forest-labs/flux-schnell
openai/gpt-image-1
bytedance/seedream-4
```
