#!/usr/bin/env bash
#
# verify.sh — mechanical reach-killer lint for a drafted LinkedIn post.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free checks over ONE draft post file (.txt / .md) you point
#   it at. It catches the four mechanical things that throttle reach — NOT
#   judgment (whether the hook pulls or the CTA is answerable lives in the eval):
#     1. Hook length: the first text block (up to the first blank line) is over
#        ~210 chars -> warn (the mobile feed truncates ~150–210 chars before
#        'see more'; an over-long hook line either truncates mid-clause or buries
#        the payoff-seed).
#     2. Body link: any http:// or https:// in the draft -> FAIL (a body link
#        costs ~60% of reach; the 'link in first comment' workaround is also
#        penalized as of early 2026 — put the URL nowhere).
#     3. Dead CTA: a banned low-effort CTA ('thoughts?', 'agree?',
#        'let me know below', 'what do you think?', 'drop a comment') -> warn
#        (these get a like, not a comment; comments weigh ~15x).
#     4. Wall of text: a paragraph block with > 3 sentence-enders (. ! ?) and no
#        blank-line break inside it -> warn (walls tank dwell ~40% vs. broken copy).
#
#   Only #2 is a hard failure. Everything else is a warning. A clean OR empty/
#   missing-content file exits 0 — never a false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh draft.md                 # warnings + the hard link check
#   ./verify.sh draft.md --hook 150      # tighten the hook char ceiling
#   ./verify.sh draft.md --strict        # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/missing-content file
#   1  a hard failure (a body link) — or any warning under --strict
#   2  bad usage (no file given, or file does not exist)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays, no bc.

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

usage() { sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
HOOK_MAX=210
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --hook) HOOK_MAX="${2:-210}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

if [ -z "$FILE" ]; then
  printf '%sno draft file given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  ok "empty file — nothing to check"
  exit 0
fi

printf 'linkedin-content verify — %s (hook ceiling=%s chars)\n\n' "$FILE" "$HOOK_MAX"

# --- 1. hook length (first non-empty block up to the first blank line) --------
# Skip a leading YAML/front-matter fence if present, then take the first block.
HOOK_BLOCK="$(awk '
  BEGIN { infm=0; started=0; done=0 }
  NR==1 && $0 ~ /^---[[:space:]]*$/ { infm=1; next }
  infm==1 && $0 ~ /^---[[:space:]]*$/ { infm=0; next }
  infm==1 { next }
  done==1 { next }
  /^[[:space:]]*$/ { if (started==1) { done=1 }; next }
  { started=1; print }
' "$FILE")"
HOOK_LEN="$(printf '%s' "$HOOK_BLOCK" | tr -d '\n' | wc -m | tr -d '[:space:]')"
HOOK_LEN="${HOOK_LEN:-0}"
if [ "$HOOK_LEN" -gt "$HOOK_MAX" ]; then
  warn "hook block is ~${HOOK_LEN} chars (over the ${HOOK_MAX}-char ceiling) — it truncates or buries the payoff before 'see more'"
else
  ok "hook block ~${HOOK_LEN} chars (<= ${HOOK_MAX})"
fi

# --- 2. body link (hard) ------------------------------------------------------
if grep -Eiq 'https?://' "$FILE"; then
  LINKS="$(grep -Eio 'https?://[^[:space:]]+' "$FILE" | sort -u | head -3 | tr '\n' ' ')"
  fail "link in body: ${LINKS}— a body link costs ~60% reach and 'link in first comment' is now penalized too; remove it"
else
  ok "no http(s) link in body"
fi

# --- 3. dead CTAs -------------------------------------------------------------
DEAD='thoughts\?|agree\?|let me know below|what do you think\?|drop a comment'
HITS="$(grep -Eio "$DEAD" "$FILE" 2>/dev/null | sort -u || true)"
if [ -n "$HITS" ]; then
  while IFS= read -r h; do
    [ -n "$h" ] && warn "dead CTA present: \"$h\" — ask what only the reader can answer (comments weigh ~15x likes)"
  done <<EOF
$HITS
EOF
else
  ok "no dead CTAs"
fi

# --- 4. wall of text (a block with >3 sentence-enders and no inner break) -----
WALLS="$(awk '
  BEGIN { RS=""; n=0 }
  {
    # count sentence-enders in this blank-line-delimited block
    s = gsub(/[.!?]+/, "&")
    if (s > 3) { n++; print "block " n " has " s " sentences with no line break" }
  }
' "$FILE")"
if [ -n "$WALLS" ]; then
  while IFS= read -r w; do
    [ -n "$w" ] && warn "wall of text: $w — split into 1–2 sentence paragraphs (walls cut dwell ~40%)"
  done <<EOF
$WALLS
EOF
else
  ok "no wall-of-text blocks"
fi

# --- summary ------------------------------------------------------------------
printf '\n'
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
