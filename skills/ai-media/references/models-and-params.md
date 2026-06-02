# Models & params — current map (2026-06)

Fast-staling reference. Verify endpoint ids and limits on the provider catalog before a final run. Call mechanics live in `../fal/SKILL.md` and `../replicate/SKILL.md`.

## TTS — ElevenLabs

SDK: `elevenlabs` (Python). Auth: `ELEVENLABS_API_KEY`. Call:

```python
client.text_to_speech.convert(
    text=...,
    voice_id=...,
    model_id=...,
    output_format=...,
)
```

### Model tiers

| model_id | Profile | Latency | Use |
|----------|---------|---------|-----|
| `eleven_v3` | most expressive, highest quality | higher | hero final VO, emotional delivery — **verify availability first** |
| `eleven_multilingual_v2` | high quality, nuanced, multilingual | medium | default for final VO (always-available) |
| `eleven_flash_v2_5` | ultra-low ~75 ms latency | ~75 ms | real-time, batch, scale, drafts |

**`eleven_v3` availability caveat.** v3 shipped to the API in *alpha* (elevenlabs.io/blog/eleven-v3-alpha-now-available-in-the-api, 2025-08-20) and now appears in `/docs/overview/models`, but the `text_to_speech.convert` API reference still documents the default as `eleven_multilingual_v2` and does not enumerate `eleven_v3` as a guaranteed value on that endpoint. Do not hardcode `model_id="eleven_v3"` for a production pass without first confirming it returns from `GET /v1/models` for your key (or test-calling once). Default to `eleven_multilingual_v2` when in doubt — it is the safe always-available hero tier.

### output_format — `codec_samplerate_bitrate`

| Code | Meaning |
|------|---------|
| `mp3_44100_128` | MP3, 44.1 kHz, 128 kbps — good master default |
| `mp3_22050_32` | MP3, 22.05 kHz, 32 kbps — small/drafts only |
| (others) | PCM / µ-law variants per docs |

Match the sample rate to your assembly master rate. Do not resample at mux time.

### Cost

Billed per character/token. ~0.5–1 credit/char on Flash/Turbo lines. **TTS** API pricing dropped up to 55% on 2026-05-07 (updated 2026-05-27) — the primary blog quotes Flash on Creator going $0.11→$0.05 per 1,000 tokens; Multilingual v2/v3 is roughly double Flash per character. This is the TTS figure; the Music API cut was a separate up-to-50% (see Music section). **Point-in-time as of 2026-06-02 — re-verify on elevenlabs.io/pricing/api before quoting a budget.** Levers: shorter scripts, Flash for drafts/scale.

## Image-to-video

Resolution is no longer the differentiator — every serious model hits 1080p or native 4K. The binding constraint is **per-generation duration (~5–15 s, model-dependent)**: long pieces = clip per scene + concat. Durations below are each vendor's own published figure as of 2026-06 (citations in Sources) — they move with releases, so confirm on the catalog before a final run.

| Model | Duration / generation | Aspect / max res | Control | Native audio | Open-source | Pick when |
|-------|-----------------------|------------------|---------|--------------|-------------|-----------|
| Google **Veo 3.1** | **8 s** | 16:9 & 9:16, 720p/1080p/4K | high | **yes** (synced 48 kHz dialogue/SFX) | no | need synced spoken dialogue/SFX |
| **Kling 3.0** | **up to 15 s** | 4K | strong identity/temporal, lip-sync | no | no | identity consistency across scenes; longest single take |
| **Runway Gen-4.5** | **2–10 s** | flexible | **best** — motion brushes, camera control, reference image | no | no | precise motion/camera control |
| **MiniMax Hailuo 02** | **6 s or 10 s** (1080p caps at 6 s) | 768p / 1080p | medium | no | no | cost-sensitive 1080p |
| **Wan 2.6** | **up to 15 s** | up to 1080p | first/last-frame control, A/V sync | no (sync) | **yes** (Apache 2.0) | self-host / open-source |

Endpoint ids: look up the current model slug on the fal model catalog or the Replicate model catalog (both rails carry Veo/Kling/Wan/Hailuo; TTS and music endpoints also on fal). The slugs change — do not hardcode from memory.

## Music / score

Costs are per-minute and plan-dependent — approximate and fast-staling, verify on the vendor pricing page.

| Model | Cost (approx as of 2026-06, verify) | Licensing | Duration / control |
|-------|-------------------------------------|-----------|--------------------|
| **ElevenLabs Music v2** (announced 2026-05-26, upd 2026-05-31) | per-minute, ~$0.15–0.50/min depending on plan/source; Music v1/v2 API pricing cut up to 50% at launch (Creative self-serve up to ~40%) — distinct from the 55% *TTS* cut | vendor states trained **only on licensed data, cleared for commercial use** (Believe collaboration named in the launch post; Merlin/Kobalt not specifically cited there) — cleanest commercial story | genre-switch mid-track |
| **Suno v5** | plan-based | usage rights on paid plans post Nov-2025 label settlements (rights, not copyright ownership) | vendor blind-test benchmark, ELO ~1293 (v5, 2025-09) |
| **Udio** | $30/mo Pro plan (commercial rights); **no official public API** as of this window — third-party gateways only | UMG-licensed platform announced for 2026 | — |

**Confirm commercial rights before shipping.** Terms differ per model and per plan. ElevenLabs Music v2 is the safe default for ads/commercial output and is the only one of the three with a first-party API — do not plan a programmatic pipeline around Udio.

The ElevenLabs Music per-minute dollar rate spread (a primary `/pricing/api` render showed ~$0.15/min; aggregators report ~$0.50/min) is exactly why this number is a verify-on-catalog range, not a hardcoded fact.

## Sources

Primary vendor docs first; aggregators only where a primary page is JS-gated and the figure is corroborated across several.

- **TTS (ElevenLabs):** github.com/elevenlabs/elevenlabs-python README; elevenlabs.io/docs/api-reference/text-to-speech/convert (default `eleven_multilingual_v2`, no enumerated `eleven_v3`); elevenlabs.io/docs/overview/models (lists `eleven_v3`); elevenlabs.io/blog/eleven-v3-alpha-now-available-in-the-api (v3 shipped *alpha*, 2025-08-20). (accessed 2026-06-02)
- **TTS pricing:** elevenlabs.io/blog/weve-lowered-api-agents-pricing-and-introduced-pay-as-you-go (up-to-55% TTS cut, Flash Creator $0.11→$0.05/1k tokens, 2026-05-07 upd 2026-05-27); elevenlabs.io/pricing/api. (accessed 2026-06-02)
- **Image-to-video (per-vendor durations):** Veo 3.1 — deepmind.google/models/veo (8 s, up to 4K, native 48 kHz audio; released 2025-10-14). Kling 3.0 — ir.kuaishou.com Kling 3.0 launch release (up to 15 s; 10 s was the 2.6 ceiling). Runway Gen-4.5 — help.runwayml.com "Creating with Gen-4.5" (2–10 s). MiniMax Hailuo 02 — replicate.com/minimax/hailuo-02 + minimax.io news (6 s/10 s, 768p/1080p, 1080p caps at 6 s). Wan 2.6 — alibabacloud.com Wan2.6 announcement (up to 15 s, A/V sync, Apache 2.0). (accessed 2026-06-02)
- **Music:** elevenlabs.io/blog/introducing-music-v2 (2026-05-26 upd 2026-05-31; trained only on licensed data, Believe collaboration; Music API cut up to 50% / Creative ~40%); elevenlabs.io/pricing/api + help.elevenlabs.io "How much does Eleven Music cost" (per-minute billing; dollar rate plan-dependent, ~$0.15–0.50/min spread across primary vs aggregator). Suno v5 ELO ~1293 — Suno-published blind-test benchmark (v5, 2025-09). Udio — udio.com/pricing ($30/mo Pro, commercial rights; no first-party API). (accessed 2026-06-02)
- **Delivery rails:** fal.ai model catalog; replicate.com model catalog. (accessed 2026-06-02)
