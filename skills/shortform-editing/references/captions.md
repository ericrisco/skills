# Captions — word timestamps, .ass karaoke, Remotion route

## Why word-level timestamps

Karaoke captions highlight one word at a time. That needs each word's start/end, not the segment's. Two sources:

| Tool | Word timing accuracy | Cost | When |
|---|---|---|---|
| faster-whisper `word_timestamps=True` | interpolated, drifts on boundaries | ~10% overhead, ~4x faster on GPU / 2x on CPU vs reference Whisper (CTranslate2) | quick, GPU-light, tolerant of small drift |
| WhisperX v3.8.5 (faster-whisper + wav2vec2 forced alignment) | **< 100 ms** | extra alignment pass | word-by-word highlight where the fill must land on the right word |

For karaoke, prefer WhisperX. Its forced alignment pins each word to the audio instead of interpolating.

## Install + run WhisperX

```bash
pip install whisperx
whisperx a.wav --model large-v3 --language en \
  --output_format json --highlight_words True --output_dir out/
```

This emits `out/a.json`. Shape (trimmed):

```json
{
  "segments": [
    {
      "start": 0.31, "end": 2.84, "text": " here is the thing",
      "words": [
        { "word": "here", "start": 0.31, "end": 0.52 },
        { "word": "is",   "start": 0.52, "end": 0.64 },
        { "word": "the",  "start": 0.64, "end": 0.78 },
        { "word": "thing","start": 0.78, "end": 1.10 }
      ]
    }
  ]
}
```

Each `words[i].start/end` is what drives the `.ass` `\k` timing and the Remotion token pages.

## .ass karaoke template

```text
[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Karaoke,Montserrat,64,&H00FFFFFF,&H0000FFFF,&H00000000,&H64000000,-1,0,0,0,100,100,0,0,1,5,2,5,80,80,640,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.31,0:00:01.10,Karaoke,,0,0,0,,{\k21}here {\k12}is {\k14}the {\k32}thing
```

- `\k<centiseconds>` per word = `(word.end - word.start) * 100`, rounded. The karaoke fill advances by that many centiseconds.
- `PrimaryColour` is the highlighted/active fill; `SecondaryColour` is the not-yet-spoken color.
- `Alignment 5` = centered middle. `MarginV 640` lifts the line off the bottom into the safe middle band.
- `Outline 5` + `Shadow 2` keep it legible on any background for sound-off viewing.

### Safe-zone math

Frame is `1080x1920`. Reserve the bottom ~15–20% (≈ 290–384 px) for platform UI and the right edge for the icon rail. Keep caption baselines inside the central ~80%: roughly **y from 384 to 1536**. A `MarginV` around `560–720` lands the line in the lower-middle of that band — high enough to clear the buttons, low enough to feel like a caption.

## Remotion route (when the repo is a Remotion project)

```tsx
import { createTikTokStyleCaptions, type Caption } from "@remotion/captions";

const captions: Caption[] = /* from convertToCaptions(whisperJson) */;

const { pages } = createTikTokStyleCaptions({
  captions,
  combineTokensWithinMilliseconds: 350, // low = word-by-word; 1200–2000 = phrase pages
});
```

- `combineTokensWithinMilliseconds` is the page-size dial: low (200–500 ms) → one word per page → word-by-word pop; high (1200–2000 ms) → a phrase per page.
- Per-page `durationMs` is available since v4.0.261.
- Style the rendered token in the composition, not here; keep it in the same safe middle band (`bottom: ~25%` of a `1080x1920` frame).

Do not build a Remotion project just to caption a one-off clip — that is `../remotion-video/SKILL.md`. Use this route only when the project already exists.
