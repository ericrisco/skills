#!/usr/bin/env bash
#
# verify.sh — static linter for a `linkedin-carousels` slide-by-slide spec.
#
# WHAT IT DOES (read-only; never edits a file)
#   Network-free static checks over a produced carousel spec (markdown/text):
#     1. HARD  no cover slide is labeled (cover / slide 1 marker).
#     2. HARD  no CTA closer with an explicit ask verb (follow/comment/save/share/visit/subscribe).
#     3. HARD  no portrait/square canvas named (1080x1350 or 1080x1080).
#     4. HARD  no type floor named (28 or larger) AND/OR no "PDF" export target.
#     5. HARD  slide count outside 5-15.
#     6. SOFT  slide count outside the 6-12 band (warn).
#     7. SOFT  an interior slide block lists 3+ bullet points (crammed; one-idea-per-slide).
#
#   Hard violations exit 1. Soft violations warn and exit 0 (spec is judgement).
#   An empty or clean target is a clean pass (exit 0) — no false failure.
#
# HOW TO RUN (point it at YOUR spec, not the skills repo)
#   ./verify.sh path/to/carousel-spec.md   # check one file
#   ./verify.sh                            # scan ./ for *.{md,mdx,txt}
#   ./verify.sh --path specs               # scan a subdirectory
#   ./verify.sh --strict                   # treat soft warnings as failure (exit 1)
#
# EXIT CODES
#   0  clean, empty target, or warnings-only without --strict
#   1  a hard violation, or --strict with any warning
#   2  bad usage
#
# POSIX sh, no external deps beyond grep/wc/sort. Runs on stock macOS /bin/sh.

set -eu

if [ -t 1 ]; then
  RED=$(printf '\033[31m'); GRN=$(printf '\033[32m'); YEL=$(printf '\033[33m'); NC=$(printf '\033[0m')
else
  RED=''; GRN=''; YEL=''; NC=''
fi

warn_count=0
fail_count=0

ok()   { printf '%s[ ok ]%s %s\n'  "$GRN" "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n'  "$YEL" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n'  "$RED" "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,33p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

TARGET=""
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    --path) shift; TARGET="${1:-}" ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *) TARGET="$1" ;;
  esac
  shift
done
[ -n "$TARGET" ] || TARGET="."

# --- collect files ----------------------------------------------------------
FILES=""
if [ -f "$TARGET" ]; then
  FILES="$TARGET"
elif [ -d "$TARGET" ]; then
  FILES=$(find "$TARGET" -type f \
    \( -name '*.md' -o -name '*.mdx' -o -name '*.txt' \) 2>/dev/null \
    | grep -v '/node_modules/' || true)
else
  printf 'no such file or directory: %s\n' "$TARGET" >&2
  exit 2
fi

if [ -z "$FILES" ]; then
  ok "no spec files found under '$TARGET' — nothing to check"
  exit 0
fi

# explicit-ask verbs that mark a real CTA (case-insensitive)
ASK_VERBS='follow|comment|save|share|repost|visit|subscribe|download|sign up|book|grab'

checked=0
for f in $FILES; do
  [ -f "$f" ] || continue
  [ -s "$f" ] || continue
  checked=$((checked + 1))

  # 1. HARD: a labeled cover slide.
  if grep -Eiq '(^|[^a-z])cover([^a-z]|$)|slide *0*1 *[—:-]' "$f"; then
    :
  else
    fail "$f: no cover slide labeled — the cover wins or loses the swipe to slide 2"
  fi

  # 2. HARD: a CTA closer with an explicit ask verb.
  if grep -Eiq 'cta' "$f" && grep -Eiq "$ASK_VERBS" "$f"; then
    :
  elif grep -Eiq "$ASK_VERBS" "$f"; then
    warn "$f: an ask verb is present but no 'CTA' closer slide is labeled — label the closer"
  else
    fail "$f: no CTA closer with an explicit ask (follow/comment/save/share/visit) — every deck needs one ask"
  fi

  # 3. HARD: a portrait/square canvas.
  if grep -Eiq '1080 *[x×] *1350|1080 *[x×] *1080' "$f"; then
    :
  else
    fail "$f: no portrait/square canvas named (expected 1080x1350 or 1080x1080) — no landscape for the feed"
  fi

  # 4. HARD: a type floor (>=28) and PDF export target.
  if grep -Eiq '(2[89]|[3-9][0-9]|[1-9][0-9][0-9]) *px' "$f"; then
    :
  else
    fail "$f: no type floor >= 28 px stated — body is read on a phone, anything smaller is a stop"
  fi
  if grep -Eiq '(^|[^a-z])pdf([^a-z]|$)' "$f"; then
    :
  else
    fail "$f: no PDF export target named — PDF is the only format that renders consistently"
  fi

  # 5/6. slide count. Count distinct 'slide N' markers (case-insensitive).
  count=$(grep -Eio 'slide *0*[0-9]+' "$f" 2>/dev/null \
    | grep -Eo '[0-9]+' | sort -un | wc -l | tr -d ' ')
  if [ "${count:-0}" -gt 0 ]; then
    if [ "$count" -lt 5 ] || [ "$count" -gt 15 ]; then
      fail "$f: ${count} slides — outside the 5-15 hard range (< 5 underdelivers, > 15 loses people)"
    elif [ "$count" -lt 6 ] || [ "$count" -gt 12 ]; then
      warn "$f: ${count} slides — outside the 6-12 sweet band (~8 is the target)"
    fi
  fi

  # 7. SOFT: a crammed interior slide — 3+ bullet lines within ~12 lines of a slide marker.
  #    Heuristic: if the file has any run of 3+ consecutive bullet lines, warn once.
  bullets=$(grep -Ec '^[[:space:]]*([-*•]|[0-9]+\.) ' "$f" 2>/dev/null || true)
  if [ "${bullets:-0}" -ge 3 ]; then
    max_run=$(awk '
      /^[[:space:]]*([-*•]|[0-9]+\.) /{run++; if(run>max)max=run; next}
      {run=0}
      END{print max+0}' "$f")
    if [ "${max_run:-0}" -ge 3 ]; then
      warn "$f: a slide block lists ${max_run}+ consecutive bullets — keep one idea per slide, split the rest"
    fi
  fi
done

printf '\n'
if [ "$fail_count" -gt 0 ]; then
  fail "$fail_count hard violation(s), $warn_count warning(s) across $checked file(s)"
  exit 1
fi
if [ "$warn_count" -gt 0 ]; then
  warn "$warn_count warning(s) across $checked file(s)"
  [ "$STRICT" -eq 1 ] && { printf '%s--strict: treating warnings as failure%s\n' "$RED" "$NC"; exit 1; }
  exit 0
fi
ok "clean — $checked file(s) checked, no violations"
exit 0
