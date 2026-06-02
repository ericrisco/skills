#!/usr/bin/env bash
#
# verify.sh — static lint for Replicate image-generation code (read-only, network-free).
#
# WHAT IT DOES (never edits, runs code, or calls the API)
#   Points at a directory of emitted code (default: current dir) and statically
#   checks the things that are mechanically wrong about a Replicate image call:
#     1. Image model slugs -> every replicate.run("<slug>") / predictions.create
#        model:/version: "<slug>" must be in the known image-slug allowlist
#        (the slugs in references/models.md). An unknown slug is a HARD failure
#        (likely a typo or a hallucinated model).
#     2. aspect_ratio literals -> every aspect_ratio: "<v>" must be in the
#        nano-banana allowed set (or match_input_image). HARD failure otherwise.
#     3. output_resolution literals -> must be one of 512px,1K,2K,4K. HARD fail.
#     4. Bare-path image inputs -> an image_input array element that is a quoted
#        relative path ("./x.png" / "x.jpg") rather than a variable/URL/data:
#        URI warns (clients upload files/Buffers, not path strings).
#
#   A dir with no matching code (nothing to check) exits 0 — never a false fail.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                 # check current directory, recursively
#   ./verify.sh path/to/dir     # check a specific dir
#   ./verify.sh dir --strict    # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, warnings-only (without --strict), or nothing to check
#   1  a hard failure (unknown slug / bad aspect_ratio / bad resolution),
#      or any warning under --strict
#   2  bad usage (target dir does not exist)
#
# Runs on stock macOS bash 3.2.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

DIR="."
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --strict) STRICT=1; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) DIR="$1"; shift ;;
  esac
done

if [ ! -d "$DIR" ]; then
  printf '%starget dir not found: %s%s\n' "$RED" "$DIR" "$NC" >&2; exit 2
fi

printf 'replicate-images verify — %s\n\n' "$DIR"

# Known image slugs (from references/models.md). Space-padded for whole-token match.
ALLOWED_SLUGS=" google/nano-banana-2 google/nano-banana-pro black-forest-labs/flux-1.1-pro black-forest-labs/flux-dev black-forest-labs/flux-schnell openai/gpt-image-1 bytedance/seedream-4 "
# nano-banana aspect_ratio allowed set + match_input_image (the spec list on the model page;
# extreme 1:4/4:1/1:8/8:1 are unconfirmed in that spec, so they are intentionally NOT allowed here).
ALLOWED_AR=" 1:1 2:3 3:2 3:4 4:3 4:5 5:4 9:16 16:9 21:9 match_input_image "
# output_resolution allowed set.
ALLOWED_RES=" 512px 1K 2K 4K "

# Collect candidate source files (skip references/models.md itself: it lists the allowlist as prose).
SRC="$(find "$DIR" \( -name '*.js' -o -name '*.mjs' -o -name '*.ts' -o -name '*.py' \) 2>/dev/null || true)"

checked_anything=0

# --- 1. model slugs -----------------------------------------------------------
SLUGS="$(printf '%s\n' "$SRC" | while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  grep -hoE '(replicate\.run|model|version)[^"'"'"']*["'"'"'][a-z0-9._-]+/[a-z0-9._-]+["'"'"']' "$f" 2>/dev/null \
    | grep -oE '["'"'"'][a-z0-9._-]+/[a-z0-9._-]+["'"'"']' \
    | tr -d '"'"'"''
done | sort -u || true)"

if [ -n "$SLUGS" ]; then
  checked_anything=1
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    case "$ALLOWED_SLUGS" in
      *" $s "*) ok "model slug ok: $s" ;;
      *) fail "unknown image model slug: '$s' (not in references/models.md allowlist)" ;;
    esac
  done <<EOF
$SLUGS
EOF
fi

# --- 2. aspect_ratio literals -------------------------------------------------
ARS="$(printf '%s\n' "$SRC" | while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  grep -hoE 'aspect_ratio["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']+["'"'"']' "$f" 2>/dev/null \
    | grep -oE '["'"'"'][^"'"'"']+["'"'"']$' | tr -d '"'"'"''
done | sort -u || true)"

if [ -n "$ARS" ]; then
  checked_anything=1
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    case "$ALLOWED_AR" in
      *" $a "*) ok "aspect_ratio ok: $a" ;;
      *) fail "aspect_ratio '$a' not in the nano-banana allowed set" ;;
    esac
  done <<EOF
$ARS
EOF
fi

# --- 3. output_resolution literals --------------------------------------------
RESS="$(printf '%s\n' "$SRC" | while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  grep -hoE 'output_resolution["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']+["'"'"']' "$f" 2>/dev/null \
    | grep -oE '["'"'"'][^"'"'"']+["'"'"']$' | tr -d '"'"'"''
done | sort -u || true)"

if [ -n "$RESS" ]; then
  checked_anything=1
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    case "$ALLOWED_RES" in
      *" $r "*) ok "output_resolution ok: $r" ;;
      *) fail "output_resolution '$r' not in {512px,1K,2K,4K}" ;;
    esac
  done <<EOF
$RESS
EOF
fi

# --- 4. bare-path image_input warning -----------------------------------------
BAREPATH="$(printf '%s\n' "$SRC" | while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  # image_input on the same line containing a quoted relative path with an image extension
  grep -nE 'image_input' "$f" 2>/dev/null \
    | grep -E '["'"'"'](\./|\.\./)?[A-Za-z0-9._/-]+\.(png|jpg|jpeg|webp|gif)["'"'"']' \
    | grep -vE 'https?://|data:' \
    | sed "s|^|$f:|"
done || true)"

if [ -n "$BAREPATH" ]; then
  checked_anything=1
  while IFS= read -r line; do
    [ -n "$line" ] && warn "possible bare-path image input: ${line} — read the file (readFile/Buffer) or pass a URL/data: URI"
  done <<EOF
$BAREPATH
EOF
fi

# --- summary ------------------------------------------------------------------
printf '\n'
if [ "$checked_anything" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
  ok "nothing to check in $DIR"
  exit 0
fi
if [ "$fail_count" -gt 0 ]; then
  printf '%s%d hard failure(s), %d warning(s)%s\n' "$RED" "$fail_count" "$warn_count" "$NC"
  exit 1
fi
if [ "$warn_count" -gt 0 ]; then
  if [ "$STRICT" -eq 1 ]; then
    printf '%s%d warning(s) — failing under --strict%s\n' "$YELLOW" "$warn_count" "$NC"
    exit 1
  fi
  printf '%s%d warning(s), 0 hard failures%s\n' "$YELLOW" "$warn_count" "$NC"
  exit 0
fi
printf '%sall checks passed%s\n' "$GREEN" "$NC"
exit 0
