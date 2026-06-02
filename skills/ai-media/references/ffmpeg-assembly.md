# ffmpeg assembly cookbook

Branch-specific to the assembly step. Every operation here is deterministic — same inputs, same output. Lock generation first; this is the glue.

## Mux: audio file onto a video

Map the video from input 0 and the audio from input 1, copy the video stream (no re-encode), trim to the shorter of the two:

```bash
ffmpeg -i scene.mp4 -i vo.mp3 \
  -map 0:v -map 1:a -c:v copy -c:a aac -shortest out.mp4
```

- `-map 0:v -map 1:a` — pick exactly the streams you want; without it ffmpeg guesses.
- `-c:v copy` — never re-encode video you do not need to touch.
- `-shortest` — stops at the shorter input. Watch this: if the VO is longer than the clip, the tail is cut. Pad the video or trim the VO deliberately.

## Two-pass loudnorm (ITU-R BS.1770)

Pass 1 measures, pass 2 applies with the measured values. Targets: **-14 LUFS** social/streaming, **-16 LUFS** podcast-style VO. Always set a true-peak ceiling (`TP=-1.5`).

```bash
# pass 1 — read the JSON block it prints to stderr
ffmpeg -i input.wav -af loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json -f null -
```

Copy `input_i`, `input_tp`, `input_lra`, `input_thresh`, `target_offset` into pass 2:

```bash
ffmpeg -i input.wav -af \
  loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=-20.1:measured_TP=-4.2:measured_LRA=6.0:measured_thresh=-30.8:offset=0.5:linear=true \
  -ar 48000 output.wav
```

Normalize **each track before mixing**, then loudnorm the final mix once more. One-pass loudnorm is acceptable for quick drafts; two-pass is the accurate path. `slhck/ffmpeg-normalize` wraps this if you want it scripted.

## Duck music under the VO — sidechaincompress

The music (carrier) is keyed by the VO (sidechain): when the voice plays, the compressor pulls the music down; when it stops, the music recovers. This emulates a DAW ducking automation without manual keyframes.

```bash
ffmpeg -i vo.wav -i music.wav -filter_complex "
  [1:a][0:a]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=300[ducked];
  [0:a][ducked]amix=inputs=2:duration=longest:dropout_transition=0[aout]
" -map "[aout]" -c:a aac mix.m4a
```

Tuning:
- `threshold` — how loud the VO must be to trigger ducking (lower = more sensitive).
- `ratio` — how hard the music drops (8 = strong).
- `attack` (ms) — how fast it ducks; keep small so the music dips immediately.
- `release` (ms) — how slowly it recovers; 300–500 avoids pumping.

### Static fallback (no sidechain)

When you do not need dynamic ducking, just fix the music low under a full-length VO:

```bash
ffmpeg -i vo.wav -i music.wav -filter_complex \
  "[1:a]volume=0.3[m];[0:a][m]amix=inputs=2:duration=longest[aout]" \
  -map "[aout]" mix.m4a
```

`amix` averages levels and can lower perceived loudness — re-run loudnorm on the result.

## Concat scenes

### Demuxer (fast, no re-encode) — only for identical codec/res/fps/SAR

```bash
printf "file '%s'\n" s1.mp4 s2.mp4 s3.mp4 > list.txt
ffmpeg -f concat -safe 0 -i list.txt -c copy joined.mp4
```

If clips differ in any of codec/resolution/fps/SAR, this produces desync or a broken stream. Conform first.

### Concat filter (re-encode) — for mismatched clips

Scale + set fps + normalize SAR per input, then concat:

```bash
ffmpeg -i s1.mp4 -i s2.mp4 -i s3.mp4 -filter_complex "
  [0:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30,setsar=1[v0];
  [1:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30,setsar=1[v1];
  [2:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30,setsar=1[v2];
  [v0][v1][v2]concat=n=3:v=1:a=0[v]
" -map "[v]" -r 30 joined.mp4
```

## Conforming — the gotchas

- **SAR/DAR mismatch** — clips with different sample aspect ratios concat to skewed frames. `setsar=1` on every input.
- **fps mismatch** — `fps=30` (or your target) on every input; otherwise concat timing drifts.
- **Resolution** — `scale=...:force_original_aspect_ratio=decrease` + `pad` letterboxes without distortion. Plain `scale=W:H` stretches.

## Burn captions / subtitles

```bash
ffmpeg -i joined.mp4 -vf "subtitles=captions.srt:force_style='FontSize=24,PrimaryColour=&H00FFFFFF'" \
  -c:a copy captioned.mp4
```

Burned-in (hardsub) for social where soft subs are ignored. Use `-c:s mov_text` to mux a soft subtitle track instead when the player supports it.

## Pitfalls checklist

- `-shortest` silently truncates — confirm which input is shorter and whether that is intended.
- Audio sample-rate mismatch → ffmpeg resamples and may shift level; set `-ar 48000` consistently.
- `-c copy`-concat across mismatched clips → desync/corruption; conform first.
- `amix` lowers perceived loudness → loudnorm the result.
- Forgetting `setsar=1` → skewed frames after concat.

## Sources

- mux.com "combine audio and video with FFmpeg" / FFmpeg mixing guide; cloudinary FFmpeg add-audio guide. (accessed 2026-06-02)
- legacistudios.com FFmpeg mixing/ducking guide. (accessed 2026-06-02)
- slhck/ffmpeg-normalize; ffmpeg loudnorm & concat docs. (accessed 2026-06-02)
