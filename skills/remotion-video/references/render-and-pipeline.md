# Render and pipeline — silence removal, render flags, CI, verification

This file holds the upstream silence pass, the full render flag matrix, headless/CI
render, and `ffprobe` verification referenced from `SKILL.md`.

## Silence removal (upstream, before Remotion)

The silence pass edits the **source asset**, not a composition. Run it first so every
downstream frame number already reflects the tightened timeline.

### auto-editor

`auto-editor` is a Python + ffmpeg engine. **pip distribution is stale/discontinued
— install via the official binary or `pipx`, not `pip install`.**

```bash
pipx install auto-editor        # or grab the official binary from auto-editor.com
```

First pass — cut dead space by audio loudness:

```bash
auto-editor input.mp4 \
  --margin 0.2s \                  # pad each kept region so cuts don't clip speech
  --edit audio:threshold=4% \      # loudness floor below which a region is "silence"
  -o tightened.mp4
```

Other useful flags:

- `--cut-out 0,30` — force-remove a frame/time range regardless of loudness.
- `--export premiere` — emit an EDL/XML for an NLE re-import instead of a rendered file
  (also `resolve`, `final-cut-pro`, `shotcut`).
- `--edit motion:threshold=2%` — cut by visual stillness instead of audio.

### ffmpeg fallback (no auto-editor)

Detect silence to inspect where the gaps are:

```bash
ffmpeg -i input.mp4 -af silencedetect=noise=-30dB:d=0.5 -f null - 2>&1 | grep silence_
```

Remove silence inline with the `silenceremove` filter (trim leading + internal gaps):

```bash
ffmpeg -i input.mp4 \
  -af "silenceremove=start_periods=1:start_duration=0.3:start_threshold=-30dB:\
detection=peak,silenceremove=stop_periods=-1:stop_duration=0.3:stop_threshold=-30dB" \
  tightened.mp4
```

`silenceremove` is bluntter than `auto-editor` (it does not pad cuts the same way),
so prefer `auto-editor` when available and treat ffmpeg as the no-dependency fallback.

## Render flag matrix

```bash
npx remotion render <CompositionId> [out/video.mp4] [flags]
```

Omit `<CompositionId>` for an interactive picker. Config lives in `remotion.config.ts`
via `@remotion/cli/config`; CLI flags override the config file.

```ts
// remotion.config.ts
import { Config } from "@remotion/cli/config";
Config.setConcurrency(8);             // parallel render workers
Config.setCodec("h264");
Config.setPixelFormat("yuv420p");     // yuv444p / yuva444p10le for higher-fidelity / alpha
```

| Goal | Flags |
|---|---|
| Web / YouTube default | `--codec=h264` (default) |
| Smaller file, same quality | `--codec=h265` |
| Edit-grade master with alpha | `--codec=prores --prores-profile=4444 --pixel-format=yuva444p10le --image-format=png` |
| Looping preview / web-alpha | `--codec=vp8` or `--codec=gif` |
| Region test (cheap validation) | `--frames=0-45` |
| Higher quality (h264/h265) | `--crf=18` (lower CRF = higher quality, bigger file) |
| Throughput | `--concurrency=8` |

**Region test before every full render:** `npx remotion render MyVideo out/test.mp4
--frames=0-45`. A full render of a minutes-long composition is expensive; a region
test surfaces a broken layer in seconds.

## Deterministic output

- Drive all animation off `useCurrentFrame()`; never `Date.now()` or unseeded
  `Math.random()` — frames render in parallel and on re-render, so non-frame inputs
  produce different pixels. Use Remotion's `random(seed)` when you need noise.
- Pin `fps` + `width` + `height` on `<Composition>` and leave them. Changing fps after
  durations are written silently shifts every frame count.
- Same input + same code → byte-comparable frames. That is the artifact contract this
  skill verifies.

## Headless / CI render

CI has no display and no Whisper model cached, so:

1. Cache the Whisper model between runs (it is ~1.5 GB; do not re-download each run,
   do not commit it).
2. Install ffmpeg (or rely on `npx remotion ffmpeg`).
3. Run the render headless and fail the job if the output is empty or has no video
   stream.

```bash
npm ci
npx remotion render MyVideo out/video.mp4 --concurrency=4
test -s out/video.mp4 || { echo "empty render"; exit 1; }
ffprobe -v error -select_streams v:0 -show_entries stream=codec_type,width,height \
  -of csv=p=0 out/video.mp4
```

## ffprobe verification

Confirm the render is a real video with the dimensions/fps you expect:

```bash
# video stream present + dimensions
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,codec_name \
  -of default=noprint_wrappers=1 out/video.mp4

# duration in seconds
ffprobe -v error -show_entries format=duration -of csv=p=0 out/video.mp4
```

`r_frame_rate` reports as a fraction (`30/1` = 30 fps). If `ffprobe` reports no video
stream, zero dimensions, or the file is empty, the render failed regardless of exit
code — that is exactly what `scripts/verify.sh` asserts.
