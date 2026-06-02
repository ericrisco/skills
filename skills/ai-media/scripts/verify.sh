#!/usr/bin/env bash
# verify.sh — lint an emitted ai-media assembly pipeline (read-only).
#
# Checks, over *.sh shell scripts in a target dir:
#   1. ffmpeg assembly applies `loudnorm` somewhere (mastering present).
#   2. multi-scene jobs conform (scale/fps/re-encode) before `concat`, rather
#      than `-c copy`-concatenating mismatched clips.
#   3. a final muxed .mp4 output target is named.
#   4. if a final .mp4 exists AND ffprobe is available, it carries both a
#      video and an audio stream.
#
# Lint + optional ffprobe presence check — never renders, never writes.
# Exits 0 on an empty/clean target (no false failure).
#
# Usage: scripts/verify.sh [TARGET_DIR]   (default: .)

set -uo pipefail

TARGET="${1:-.}"
fail=0
warn=0

note()  { printf '  %s\n' "$*"; }
bad()   { printf 'FAIL: %s\n' "$*"; fail=1; }
soft()  { printf 'WARN: %s\n' "$*"; warn=1; }

if [ ! -d "$TARGET" ]; then
  echo "verify.sh: target dir not found: $TARGET"
  exit 1
fi

# Collect candidate pipeline scripts that actually invoke ffmpeg.
scripts=()
while IFS= read -r f; do
  if grep -lq 'ffmpeg' "$f" 2>/dev/null; then
    scripts+=("$f")
  fi
done < <(find "$TARGET" -type f -name '*.sh' 2>/dev/null)

if [ "${#scripts[@]}" -eq 0 ]; then
  echo "verify.sh: no ffmpeg pipeline scripts found under $TARGET — nothing to lint."
  exit 0
fi

echo "Linting ${#scripts[@]} pipeline script(s) under $TARGET"

for s in "${scripts[@]}"; do
  echo "- $s"

  # 1. loudnorm mastering present.
  if grep -Eq 'loudnorm' "$s"; then
    note "loudnorm present (mastering ok)"
  else
    bad "no 'loudnorm' — audio is not loudness-normalized before final mux ($s)"
  fi

  # 2. conform-before-concat for multi-scene jobs.
  if grep -Eq 'concat' "$s"; then
    if grep -Eq '(scale=|fps=|setsar=|concat=n=)' "$s"; then
      note "concat conforms clips (scale/fps/setsar or concat filter) — ok"
    elif grep -Eq 'concat[^=]*-c[: ]*v?[: ]*copy|-c copy' "$s"; then
      bad "uses concat with '-c copy' but no scale/fps/setsar conform — mismatched clips will desync ($s)"
    else
      soft "concat present but conform step not detected — confirm clips share codec/res/fps ($s)"
    fi
  fi

  # 3. a final .mp4 output target is named.
  if grep -Eq '[A-Za-z0-9_./-]+\.mp4' "$s"; then
    note "final .mp4 output target named — ok"
  else
    bad "no '.mp4' output target named in the pipeline ($s)"
  fi
done

# 4. optional ffprobe stream check on any rendered .mp4.
if command -v ffprobe >/dev/null 2>&1; then
  while IFS= read -r mp4; do
    streams="$(ffprobe -v error -show_entries stream=codec_type \
      -of default=nw=1:nk=1 "$mp4" 2>/dev/null)"
    has_v=0; has_a=0
    echo "$streams" | grep -q '^video$' && has_v=1
    echo "$streams" | grep -q '^audio$' && has_a=1
    if [ "$has_v" -eq 1 ] && [ "$has_a" -eq 1 ]; then
      note "ffprobe: $mp4 has both video + audio — ok"
    else
      bad "ffprobe: $mp4 missing $( [ $has_v -eq 0 ] && echo 'video' ) $( [ $has_a -eq 0 ] && echo 'audio' ) stream"
    fi
  done < <(find "$TARGET" -type f -name '*.mp4' 2>/dev/null)
else
  echo "(ffprobe not installed — skipping rendered-MP4 stream check)"
fi

if [ "$fail" -ne 0 ]; then
  echo "verify.sh: FAILED"
  exit 1
fi
if [ "$warn" -ne 0 ]; then
  echo "verify.sh: passed with warnings"
  exit 0
fi
echo "verify.sh: OK"
exit 0
