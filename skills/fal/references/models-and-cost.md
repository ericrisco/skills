# Models & cost

How to find a fal endpoint, what its schema is, and what it costs. fal hosts hundreds of model endpoints across three modalities; you call them by id.

## Finding an endpoint id and its schema

1. Browse the fal model gallery; each model page shows its **endpoint id** (e.g. `fal-ai/flux/dev`), an input schema, an output schema, and a **pricing tab**.
2. The endpoint id is what you pass to `subscribe` / `submit` / `run`.
3. The input schema tells you required fields (`prompt`, `image_url`, `duration`, …) and the optional spend knobs.
4. Sub-paths select a variant — e.g. `fal-ai/flux/dev` vs `fal-ai/flux/dev/image-to-image`.

## Model-family map (2026)

| Modality | Family | Example endpoints | Typical input |
| --- | --- | --- | --- |
| Image | FLUX | `fal-ai/flux/dev`, `fal-ai/flux-pro` | prompt, size, steps |
| Image | Seedream | `fal-ai/bytedance/seedream/v4` | prompt, num_images |
| Image | Stable Diffusion | `fal-ai/stable-diffusion-v35-large` | prompt, steps |
| Video | Veo | `fal-ai/veo3` | prompt, duration |
| Video | Wan | `fal-ai/wan-2.5` | prompt, duration, image_url |
| Video | Kling / Hailuo | `fal-ai/kling-video/...`, `fal-ai/minimax/hailuo-...` | prompt, duration |
| Audio | TTS | text-to-speech endpoints | text, voice |
| Audio | Music | music-generation endpoints | prompt, duration |

Endpoint ids shift as model versions ship — always confirm the id on the model page.

## Pricing-unit cheatsheet

Pricing is per-model and per-unit; the unit varies. Read the model page's pricing tab every time.

| Unit | Modality | 2026 example (accessed 2026-06-02) |
| --- | --- | --- |
| Per image | image | Seedream V4 ~`$0.03`/image |
| Per second of output | video | Wan 2.5 ~`$0.05`/s; Veo 3 ~`$0.4`/s |
| Per megapixel | some image models | varies by model |
| GPU-hour | fal-served compute | A100 40GB `$0.99`/h, H100 80GB `$1.89`/h (2026-05-13) |

**Batch inference is 50% of the serverless price** — use it for offline bulk where latency does not matter.

## Spend-control knobs by modality

| Modality | Knobs that cut cost | Note |
| --- | --- | --- |
| Image | `num_inference_steps`, resolution / megapixels, `num_images` | fewer steps + smaller output = cheaper, usually fine |
| Video | `duration`, fps, resolution | per-second pricing scales linearly with duration |
| Audio | output length / duration | longer audio = more compute |

## Worked estimates

- 500 Seedream V4 images at ~$0.03 ≈ **$15** serverless; ≈ **$7.50** on the batch path.
- A 10-second Veo 3 clip at ~$0.4/s ≈ **$4**; the same length on Wan 2.5 at ~$0.05/s ≈ **$0.50**.

Cost moves with the unit and the model. Re-derive the estimate from the pricing tab before committing to a loop.
