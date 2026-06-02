# Captions pipeline — Whisper.cpp → toCaptions → createTikTokStyleCaptions

The captions layer is built once on a Node server (transcribe + convert) and then
consumed by a composition at render time. The native `@remotion/captions` package
shipped in Remotion **v4.0.216** — the same release that deprecated the old
`convertToCaptions()` helper in favor of `toCaptions()`. This file holds the full
install, the transcribe step, and the token-highlight renderer component referenced
from `SKILL.md`.

## 1. Install Whisper.cpp and a model

`@remotion/install-whisper-cpp` downloads the Whisper.cpp binary and a model. The
`medium.en` model is ~1.5 GB — download it **once** to a cached path and reuse it.
Never commit it to git.

```ts
// scripts/install-whisper.ts  (run with: npx tsx scripts/install-whisper.ts)
import { installWhisperCpp, downloadWhisperModel } from "@remotion/install-whisper-cpp";
import path from "node:path";

const to = path.join(process.cwd(), "whisper.cpp"); // .gitignore this dir

await installWhisperCpp({ to, version: "1.5.5" });
await downloadWhisperModel({ folder: to, model: "medium.en" });
```

```gitignore
# .gitignore
whisper.cpp/
```

## 2. Transcribe audio to captions

The audio must be 16 kHz WAV for Whisper.cpp. Convert with ffmpeg, then transcribe,
then `toCaptions()` turns the Whisper token stream into a `Caption[]` with
per-token start/end timestamps.

```ts
// scripts/transcribe.ts
import { transcribe, toCaptions } from "@remotion/install-whisper-cpp";
import path from "node:path";
import { execSync } from "node:child_process";

const whisperPath = path.join(process.cwd(), "whisper.cpp");
const src = "public/voiceover.mp4";
const wav = "public/voiceover.wav";

// Whisper.cpp wants 16kHz mono WAV
execSync(`npx remotion ffmpeg -i ${src} -ar 16000 ${wav} -y`);

const whisperOutput = await transcribe({
  inputPath: wav,
  whisperPath,
  model: "medium.en",
  tokenLevelTimestamps: true, // required for word-by-word
});

const { captions } = toCaptions({ whisperCppOutput: whisperOutput });
// persist captions.json next to the composition
import { writeFileSync } from "node:fs";
writeFileSync("public/captions.json", JSON.stringify(captions, null, 2));
```

On a pre-v4.0.216 Remotion you will only have the legacy `convertToCaptions()` (from
`@remotion/install-whisper-cpp/convert-to-captions`) — it produces the same
`Caption[]` but is deprecated; prefer `toCaptions()` on any current version. A
`Caption` is roughly `{ text, startMs, endMs, timestampMs, confidence }`.

## 3. Segment into pages

`@remotion/captions` `createTikTokStyleCaptions()` groups tokens into "pages" — the
chunks that appear on screen together. The `combineTokensWithinMilliseconds` value is
the page-size dial:

- **~200 ms** → roughly one word per page → word-by-word pop (TikTok energy).
- **~1200 ms** → a phrase per page → calmer, more readable.

```ts
import { createTikTokStyleCaptions } from "@remotion/captions";

const { pages } = createTikTokStyleCaptions({
  captions,                              // the Caption[] from step 2
  combineTokensWithinMilliseconds: 1200, // phrase pages; drop to ~200 for word-by-word
});
```

## 4. The caption renderer component

Render the current page and highlight the active token by comparing each token's
timestamp against the current time in ms (`frame / fps * 1000`).

```tsx
// src/Captions.tsx
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import type { TikTokPage } from "@remotion/captions";

export const Captions: React.FC<{ pages: TikTokPage[] }> = ({ pages }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const nowMs = (frame / fps) * 1000;

  const page = pages.find((p) => nowMs >= p.startMs && nowMs < p.startMs + p.durInMs());
  if (!page) return null;

  return (
    <AbsoluteFill
      style={{
        justifyContent: "flex-end",
        alignItems: "center",
        // safe zone: keep text clear of the platform UI margins
        paddingBottom: 320,
        paddingLeft: 80,
        paddingRight: 80,
      }}
    >
      <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: "0 16px" }}>
        {page.tokens.map((t, i) => {
          const active = nowMs >= t.fromMs && nowMs < t.toMs;
          return (
            <span
              key={i}
              style={{
                fontFamily: "Inter, sans-serif",
                fontWeight: 800,
                fontSize: 72,
                color: active ? "#FFE600" : "white",
                // high-contrast stroke so it survives a bright background
                WebkitTextStroke: "8px black",
                paintOrder: "stroke fill",
                transform: active ? "scale(1.06)" : "scale(1)",
              }}
            >
              {t.text}
            </span>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
```

Mount it as the top layer of the composition, above the video and b-roll:

```tsx
<AbsoluteFill>
  <OffthreadVideo src={staticFile("voiceover.mp4")} />
  {/* ...b-roll sequences... */}
  <Captions pages={pages} />
</AbsoluteFill>
```

## Styling and safe-zone notes

- **High contrast + a thick stroke or box.** Captions must read on a bright phone
  outdoors; a thin font with no stroke vanishes over light footage.
- **Respect safe zones.** Keep caption text clear of the bottom and right-rail
  platform UI. For 1080×1920 vertical, a ~320 px bottom inset keeps text above the
  caption/CTA bar.
- **One highlight color, consistent.** The active-token color is a brand decision;
  pick one and reuse it — flicker between colors reads as a glitch.
- **Page size matches format.** Word-by-word for high-energy shorts; phrase pages for
  explainers where the viewer is reading, not just feeling rhythm.
