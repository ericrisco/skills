# Specs, safe zones & tooling

All facts dated 2026-06-02 (vidIQ Shorts specs; Sprout Social social-video specs;
YouTube Help three-minute Shorts; OpusClip ideal-length data — vendor-reported,
directional; Reap state-of-clipping-tools 2026). CapCut capability numbers are
sourced to CapCut's own product pages (capcut.com/tools/text-to-speech,
accessed 2026-06-02), not to secondary marketing blogs.

## Per-platform spec table

One master export covers all three. Differences are length ceilings and the
Shorts-shelf rule, not the container.

| Spec | Reels | Shorts | TikTok |
|---|---|---|---|
| Aspect ratio | 9:16 | 9:16 | 9:16 |
| Resolution | 1080×1920 | 1080×1920 | 1080×1920 |
| Container | MP4 | MP4 | MP4 |
| Codec | H.264 + AAC | H.264 + AAC | H.264 + AAC |
| Frame rate | 30 or 60 fps | 30 or 60 fps | 30 or 60 fps |
| Max length | up to 3 min | 3 min (180s, since 15 Oct 2024) | up to 10 min |
| Surfacing rule | — | must stay vertical/square to hit the Shorts shelf | — |

**Length-allowed ≠ length-wanted.** The retention sweet spot is 15–30s (vendors
report high completion in this band); past ~45s drop-off is steep regardless of
the ceiling. Use the ceiling only when the content genuinely needs it and
escalates the whole way.

## Safe zones

Platform UI overlays (caption rail, profile, like/share/comment column, progress
bar) sit on top of your frame. Keep all on-screen text and the CTA inside the
safe zone or the UI eats them.

Working margins on a 1080×1920 frame (treat as a conservative default; platforms
shift their chrome, so verify on a real device before final export):

| Edge | Keep text out of | Why |
|---|---|---|
| Bottom | ~250–320 px | Caption/handle bar + progress bar live here |
| Right | ~140–180 px | Like / comment / share / sound column |
| Top | ~120–160 px | Search / status / sometimes account chrome |
| Left | ~50–80 px | Minor; safest gutter |

Practical rule: **compose the hook text and CTA in the centre-upper third.** It
clears every platform's chrome and is where the eye lands first.

## Export / repurposing checklist

- [ ] 9:16, 1080×1920, MP4, H.264 + AAC, 30 or 60 fps (one master).
- [ ] Captions burned in (not a sidecar `.srt`) — survives muted autoplay and
      re-uploads.
- [ ] All text/CTA inside the safe zones above.
- [ ] Runtime in the 15–30s sweet spot unless content justifies more.
- [ ] Loop seam intact: last frame match-cuts to the first.
- [ ] Hook frame is the most arresting still (it's the thumbnail-in-motion).
- [ ] No platform watermark baked in (a TikTok watermark gets demoted on
      Reels/Shorts) — export clean, add per-platform branding if needed.

## Tool capability snapshot (2026)

The tool executes; your script + EDS is the brief. None of these invent your
hook or loop seam.

| Tool | What it does well | Hand it |
|---|---|---|
| CapCut 2026 AI Suite | one-click auto-edit, multilingual captions, hundreds of TTS voices (CapCut's own TTS page lists 200+ AI voices, accessed 2026-06-02), AI avatars (faceless) | script + EDS as the cut/caption brief |
| OpusClip / Reap / Vizard | long video → clip candidates with auto-captions | the source long video + your extraction picks |
| Submagic | caption styling / animated captions | a cut video + the caption style spec |

**Watch-out:** algorithms now demote obvious low-effort AI clips (raw auto-cut +
generic TTS + stock B-roll with no structure). The script structure — a hook that
survives second 3, a loop that earns a replay — is what separates a clip from
filler. Let the tool do the labour, not the thinking.
