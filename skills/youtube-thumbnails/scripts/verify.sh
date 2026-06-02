#!/usr/bin/env bash
# verify.sh — check YouTube thumbnail image files against the hard, objective spec.
# Read-only. Judges the spec, never taste. Exits 0 on a clean/empty target.
#
# Checks per image: 1280x720, 16:9, size < 2 MB, format in {jpg, png}.
# Tooling preference: sips (macOS) -> ImageMagick identify -> file (+ byte size).
# If no image tooling is available, prints a clear SKIP and exits 0 (no false fail).
#
# Usage:
#   scripts/verify.sh                 # scan ./ for *.jpg/*.jpeg/*.png
#   scripts/verify.sh path/to/img.jpg # check one or more files
#   scripts/verify.sh path/to/dir/    # scan a directory

set -uo pipefail

MAX_BYTES=$((2 * 1024 * 1024)) # 2 MB
WANT_W=1280
WANT_H=720

fail=0
checked=0

have() { command -v "$1" >/dev/null 2>&1; }

# Collect target files from args (files or dirs); default to current dir.
collect() {
  local args=("$@")
  [ "${#args[@]}" -eq 0 ] && args=(".")
  local p
  for p in "${args[@]}"; do
    if [ -d "$p" ]; then
      find "$p" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null
    elif [ -f "$p" ]; then
      printf '%s\n' "$p"
    else
      echo "WARN: no such file or directory: $p" >&2
    fi
  done
}

# Echo "WIDTHxHEIGHT" for a file, or empty if undetermined.
dimensions() {
  local f="$1" out
  if have sips; then
    out=$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null)
    local w h
    w=$(printf '%s\n' "$out" | awk '/pixelWidth/{print $2}')
    h=$(printf '%s\n' "$out" | awk '/pixelHeight/{print $2}')
    [ -n "$w" ] && [ -n "$h" ] && { printf '%sx%s' "$w" "$h"; return; }
  fi
  if have identify; then
    out=$(identify -format '%wx%h' "$f" 2>/dev/null)
    [ -n "$out" ] && { printf '%s' "$out"; return; }
  fi
  printf ''
}

byte_size() {
  local f="$1"
  if stat -f%z "$f" >/dev/null 2>&1; then stat -f%z "$f"; else stat -c%s "$f" 2>/dev/null; fi
}

ext_ok() {
  case "${1##*.}" in
    [jJ][pP][gG]|[jJ][pP][eE][gG]|[pP][nN][gG]) return 0 ;;
    *) return 1 ;;
  esac
}

# Tooling gate: if we cannot read dimensions at all, skip cleanly.
if ! have sips && ! have identify; then
  echo "SKIP: no image tooling (sips or ImageMagick 'identify') found; cannot verify dimensions."
  echo "      Install ImageMagick or run on macOS to enable dimension/ratio checks."
  exit 0
fi

while IFS= read -r f; do
  [ -z "$f" ] && continue
  checked=$((checked + 1))
  errs=()

  ext_ok "$f" || errs+=("format must be jpg/png")

  bytes=$(byte_size "$f")
  if [ -n "${bytes:-}" ] && [ "$bytes" -ge "$MAX_BYTES" ]; then
    errs+=("size ${bytes}B >= 2MB")
  fi

  dim=$(dimensions "$f")
  if [ -z "$dim" ]; then
    errs+=("could not read dimensions")
  else
    w=${dim%x*}; h=${dim#*x}
    if [ "$w" != "$WANT_W" ] || [ "$h" != "$WANT_H" ]; then
      errs+=("dimensions ${dim}, want ${WANT_W}x${WANT_H}")
    fi
    # 16:9 check (independent of exact size): w*9 == h*16
    if [ -n "$w" ] && [ -n "$h" ] && [ $((w * 9)) -ne $((h * 16)) ]; then
      errs+=("aspect ratio not 16:9 (${dim})")
    fi
  fi

  if [ "${#errs[@]}" -eq 0 ]; then
    echo "PASS  $f  (${dim:-?}, ${bytes:-?}B)"
  else
    fail=1
    echo "FAIL  $f"
    for e in "${errs[@]}"; do echo "        - $e"; done
  fi
done < <(collect "$@")

if [ "$checked" -eq 0 ]; then
  echo "OK: no thumbnail images found to check."
  exit 0
fi

if [ "$fail" -ne 0 ]; then
  echo "Some thumbnails failed the hard spec."
  exit 1
fi

echo "All $checked thumbnail(s) meet the hard spec."
exit 0
