# ffmpeg pipeline — silence cut, beat snap, encode, verify

The reproducible cut path in full. Every command writes to a *new* file; the source `in.mp4` is never overwritten.

## 1. Extract audio for transcription

```bash
ffmpeg -i in.mp4 -vn -ac 1 -ar 16000 a.wav
```

Mono 16 kHz is the Whisper input contract. Keep `in.mp4` for the actual cut — the `.wav` is only for transcription and silence detection.

## 2. Detect silence

```bash
# Speech (talking head): trim gaps longer than 0.3s below -25 dB
ffmpeg -i in.mp4 -af silencedetect=noise=-25dB:d=0.3 -f null - 2> silence.log

# Music bed: looser, so you don't chop quiet passages
ffmpeg -i in.mp4 -af silencedetect=noise=-40dB:d=1 -f null - 2> silence_music.log
```

`silence.log` contains lines like:

```text
[silencedetect @ 0x...] silence_start: 4.213
[silencedetect @ 0x...] silence_end: 5.087 | silence_duration: 0.874
```

## 3. Invert silent ranges into keep-ranges and cut BOTH streams

`silenceremove` alone is audio-only and desyncs picture. Build keep-ranges and apply a `select`/`aselect` graph so the same time windows are dropped from video and audio together.

```bash
#!/usr/bin/env bash
# build_cut.sh — parse silence.log, emit a keep-only filtergraph, cut both streams.
set -euo pipefail
SRC="${1:-in.mp4}"; LOG="${2:-silence.log}"; OUT="${3:-tightened.mp4}"

# Pull starts/ends in order; pair them into [silence_start, silence_end] gaps.
starts=$(grep -o 'silence_start: [0-9.]*' "$LOG" | awk '{print $2}')
ends=$(grep -o 'silence_end: [0-9.]*'   "$LOG" | awk '{print $2}')

# Keep-ranges = the complement of the silent gaps over [0, duration].
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$SRC")

# Compose: keep from 0 to first silence_start, then from each silence_end to next start, ... to DUR.
python3 - "$DUR" <<'PY' > keep.txt
import sys
dur = float(sys.argv[1])
starts = [float(x) for x in open("starts.tmp").read().split()] if False else None
PY
# (In practice generate keep.txt as "start end" pairs; see the note below.)
```

The practical, dependency-light version: write `starts`/`ends` to temp files, pair them in `awk` into `keep_start keep_end` pairs, then assemble a `between(t,s,e)` expression:

```bash
# keep.txt holds one "S E" pair per kept segment.
sel=$(awk '{printf "between(t,%s,%s)+", $1, $2}' keep.txt | sed 's/+$//')

ffmpeg -i "$SRC" \
  -vf "select='${sel}',setpts=N/FRAME_RATE/TB" \
  -af "aselect='${sel}',asetpts=N/SR/STB" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k "$OUT"
```

`setpts`/`asetpts` re-stamp the surviving frames so there are no gaps — without them the kept pieces keep their original timestamps and the player stalls.

**Trim+concat alternative** (cleaner for a handful of cuts): emit one `trim`/`atrim` pair per keep-range, then `concat=n=<k>:v=1:a=1`. Use this when you have < ~10 segments; the `select` expression is better for many small gaps.

## 4. Beat grid

```bash
python3 -c "import librosa; y,sr=librosa.load('music.wav'); \
_,b=librosa.beat.beat_track(y=y,sr=sr,units='time'); print(*b,sep='\n')" > beats.txt
```

`beats.txt` is beat times in seconds. Snap each cut/zoom keyframe to the nearest line. aubio (`aubiotrack music.wav`) is an alternative; CapCut places the same markers on the waveform automatically.

## 5. Burn captions

```bash
ffmpeg -i tightened.mp4 -vf "ass=captions.ass" -c:a copy captioned.mp4
```

Use `ass=` (not `subtitles=`) when the file is `.ass` so styling/karaoke is honored. `-c:a copy` keeps audio untouched — re-encoding here is wasted work since the encode happens at export.

## 6. Export — per-platform encode

Universal master (plays everywhere):

```bash
ffmpeg -i captioned.mp4 \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1" \
  -c:v libx264 -profile:v high -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart out.mp4
```

Per-platform bitrate (add `-b:v` / `-maxrate` / `-bufsize`):

| Platform | `-b:v` | `-maxrate` | `-bufsize` |
|---|---|---|---|
| TikTok | 3M | 4M | 6M |
| Instagram Reels | 4M | 4.5M | 8M |
| YouTube Shorts 1080p | 12M | 15M | 24M |

60 fps for high-motion: `-r 60`. Keep the universal master under ~250 MB and it is safe on all three.

## 7. ffprobe assertions

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,codec_name,avg_frame_rate -of default=nw=1 out.mp4
ffprobe -v error -select_streams a:0 \
  -show_entries stream=codec_name,sample_rate,channels -of default=nw=1 out.mp4
```

Expect: video `width=1080 height=1920 codec_name=h264 avg_frame_rate=30/1` (or `60/1`); audio `codec_name=aac sample_rate=48000`.

## Troubleshooting

- **Audio leads/lags video after the cut.** You re-stamped one stream but not the other — both `setpts=N/FRAME_RATE/TB` and `asetpts=N/SR/STB` must be present.
- **Slow progressive drift across a long clip.** Variable frame rate source; normalize with `-vsync cfr -r 30` on the source before cutting.
- **Plays in VLC but stalls in a browser/upload preview.** Missing `-movflags +faststart`; the moov atom is at the end. Re-mux: `ffmpeg -i out.mp4 -c copy -movflags +faststart fixed.mp4`.
- **Captions show but unstyled.** You used `subtitles=` on an `.ass` file; switch to `ass=`.
