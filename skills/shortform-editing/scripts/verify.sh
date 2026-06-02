#!/usr/bin/env bash
# verify.sh — assert a produced vertical short MP4 meets the export spec.
#
# Usage:
#   bash scripts/verify.sh path/to/out.mp4   # check one produced short
#   bash scripts/verify.sh path/to/dir       # scan dir for *.mp4
#   bash scripts/verify.sh                    # no target -> nothing to check, exit 0
#
# What it asserts (when ffprobe is available):
#   1. Video width  == 1080
#   2. Video height == 1920  (i.e. 9:16 vertical)
#   3. Video codec  == h264
#   4. Audio codec  == aac
#   5. Frame rate in {30, 60}
#   6. A sibling caption file (<name>.ass / <name>.srt, or any *.ass/*.srt next to
#      the mp4) exists and is non-empty.
#
# Fallback (no ffprobe): static check only — the target is an .mp4 file and a
# sibling .ass/.srt caption file exists and is non-empty. It cannot read codecs.
#
# Read-only: never writes, installs, or touches the network. Pure inspection.
# Exits 0 on a clean target AND on an empty/clean target (no false failure):
#   - no argument               -> "nothing to check", exit 0
#   - directory with no *.mp4    -> "nothing to check", exit 0
# Exits non-zero only when a real, probeable file breaks a rule.
#
# Portability: stock macOS bash 3.2. set -u on; set -e intentionally off.

set -u

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

failures=0
fail() { printf '%s\n' "${RED}FAIL: $1${RESET}"; failures=$((failures + 1)); }
warn() { printf '%s\n' "${YELLOW}WARN: $1${RESET}"; }
ok()   { printf '%s\n' "${GREEN}OK: $1${RESET}"; }

# --- collect targets -------------------------------------------------------
if [ "$#" -eq 0 ]; then
  printf '%s\n' "${YELLOW}Nothing to check (no MP4 path given). Pass an output .mp4 to verify.${RESET}"
  exit 0
fi

targets=""
for arg in "$@"; do
  if [ -d "$arg" ]; then
    for f in "$arg"/*.mp4 "$arg"/*.MP4; do
      [ -e "$f" ] && targets="${targets}${targets:+
}$f"
    done
  elif [ -f "$arg" ]; then
    targets="${targets}${targets:+
}$arg"
  else
    warn "Skipping '$arg' (not a file or directory)."
  fi
done

if [ -z "$targets" ]; then
  printf '%s\n' "${YELLOW}No .mp4 files found in the target(s). Nothing to check.${RESET}"
  exit 0
fi

HAVE_FFPROBE=0
command -v ffprobe >/dev/null 2>&1 && HAVE_FFPROBE=1
[ "$HAVE_FFPROBE" -eq 0 ] && warn "ffprobe not found — falling back to a static path/caption check (no codec inspection)."

# --- caption sibling check -------------------------------------------------
# A non-empty .ass or .srt next to the mp4 (same basename preferred, else any).
caption_for() {
  mp4="$1"
  dir=$(dirname "$mp4")
  base=$(basename "$mp4")
  stem="${base%.*}"
  for cand in "$dir/$stem.ass" "$dir/$stem.srt"; do
    if [ -s "$cand" ]; then printf '%s' "$cand"; return 0; fi
  done
  for cand in "$dir"/*.ass "$dir"/*.srt; do
    if [ -s "$cand" ]; then printf '%s' "$cand"; return 0; fi
  done
  return 1
}

# --- per-target checks -----------------------------------------------------
OLDIFS="$IFS"; IFS='
'
for mp4 in $targets; do
  IFS="$OLDIFS"
  printf '\n== %s ==\n' "$mp4"

  if [ "$HAVE_FFPROBE" -eq 1 ]; then
    W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width  -of csv=p=0 "$mp4" 2>/dev/null)
    H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$mp4" 2>/dev/null)
    VC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$mp4" 2>/dev/null)
    AC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$mp4" 2>/dev/null)
    FR=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$mp4" 2>/dev/null)

    [ "$W" = "1080" ] && ok "width 1080" || fail "width is '$W' (expected 1080)"
    [ "$H" = "1920" ] && ok "height 1920 (9:16)" || fail "height is '$H' (expected 1920)"
    [ "$VC" = "h264" ] && ok "video codec h264" || fail "video codec is '$VC' (expected h264)"
    [ "$AC" = "aac" ] && ok "audio codec aac" || fail "audio codec is '$AC' (expected aac)"

    # avg_frame_rate is a rational like 30/1 or 60000/1001; reduce to an integer fps.
    FPS=""
    case "$FR" in
      */*)
        num="${FR%%/*}"; den="${FR##*/}"
        if [ -n "$den" ] && [ "$den" != "0" ]; then
          FPS=$(awk -v n="$num" -v d="$den" 'BEGIN{printf "%d", (n/d)+0.5}')
        fi
        ;;
      *) FPS="$FR" ;;
    esac
    if [ "$FPS" = "30" ] || [ "$FPS" = "60" ]; then
      ok "frame rate ${FPS} fps"
    else
      fail "frame rate is '$FR' (~${FPS} fps; expected 30 or 60)"
    fi
  else
    case "$mp4" in
      *.mp4|*.MP4) ok "is an .mp4 file" ;;
      *) fail "not an .mp4 file: $mp4" ;;
    esac
  fi

  if cap=$(caption_for "$mp4"); then
    ok "caption file present and non-empty: $(basename "$cap")"
  else
    fail "no non-empty sibling .ass/.srt caption file next to $(basename "$mp4")"
  fi

  IFS='
'
done
IFS="$OLDIFS"

printf '\n'
if [ "$failures" -eq 0 ]; then
  ok "all checks passed"
  exit 0
else
  fail "$failures check(s) failed"
  exit 1
fi
