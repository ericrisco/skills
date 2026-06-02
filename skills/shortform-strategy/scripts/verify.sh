#!/usr/bin/env bash
#
# verify.sh — structural linter for a produced shortform strategy doc.
#
# WHAT IT DOES (read-only; never edits, writes, or hits the network)
#   Static checks over ONE strategy/decisions file you point it at
#   (markdown — e.g. 02-DOCS/wiki/shortform/strategy.md):
#     1. Required structure -> FAIL each missing:
#        - a positioning / one-promise statement,
#        - a cadence number (a per-week figure),
#        - a completion / hook KPI mention,
#        - a trend ride-or-skip rule,
#        - at least one DATED decision record (a YYYY-MM-DD heading).
#     2. WARN (heuristic, never fails without --strict):
#        - cadence reads > 10/week (over the dilution ceiling),
#        - the ledger logs only likes/views (no completion / sends / saves),
#        - identical-creative cross-posting mentioned as a plan
#          (Originality Score suppresses it).
#   A clean OR empty/whitespace-only file exits 0 — never a false failure.
#   --strict promotes warnings to a failure (for a CI gate).
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh 02-DOCS/wiki/shortform/strategy.md
#   ./verify.sh strategy.md --strict
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/no-content file
#   1  a hard failure (missing required structure) — or any warning under --strict
#   2  bad usage (no file given, or file does not exist)
#
# Targets stock macOS bash 3.2: no mapfile, no associative arrays, no bc.

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

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --strict) STRICT=1; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

if [ -z "$FILE" ]; then
  printf '%sno strategy file given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  ok "empty file — nothing to check"
  exit 0
fi

printf 'shortform-strategy verify — %s\n\n' "$FILE"

has() { grep -Eiq "$1" "$FILE" 2>/dev/null; }

# --- 1. required structure (hard) ---------------------------------------------

# Positioning / one-promise.
if has 'position|one[- ]promise|niche|lane|for whom|who it is for'; then
  ok "positioning / one-promise statement present"
else
  fail "no positioning / one-promise / lane statement found"
fi

# A cadence number: some "<n>/week" or "<n> per week" or "<n> posts a week".
if has '[0-9]+ *(-|to|–) *[0-9]+ *(reels|posts)?/? *(per +week|/ *week|a +week|wk)'; then
  ok "cadence number present"
elif has '[0-9]+ *(reels|posts)? *(per +week|/ *week|a +week|/wk)'; then
  ok "cadence number present"
else
  fail "no cadence number found (e.g. '4-7 Reels/week', '3-5 posts a week')"
fi

# Completion / hook KPI.
if has 'completion|watch[- ]?time|first 3|3 ?sec|hook'; then
  ok "completion / hook KPI present"
else
  fail "no completion / hook / watch-time KPI found"
fi

# Trend ride-or-skip rule.
if has 'ride[- ]or[- ]skip|ride.*skip|skip.*trend|trend.*skip|whether to (jump|ride)|sound.*niche'; then
  ok "trend ride-or-skip rule present"
else
  fail "no trend ride-or-skip rule found"
fi

# At least one dated decision record: a YYYY-MM-DD heading-ish line.
DEC_N="$(grep -Ec '^#{1,6} *[0-9]{4}-[0-9]{2}-[0-9]{2}' "$FILE" 2>/dev/null || true)"
DEC_N="${DEC_N:-0}"
if [ "$DEC_N" -ge 1 ]; then
  ok "dated decision record present (${DEC_N} found)"
else
  # Fall back: any dated line near a 'decision' word.
  if grep -Eiq '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$FILE" 2>/dev/null && has 'decision'; then
    ok "dated decision record present (loose match)"
  else
    fail "no dated decision record (a '## YYYY-MM-DD — decision' block)"
  fi
fi

# --- 2. heuristic warnings ----------------------------------------------------

# Cadence over the ~10/week ceiling. Pull weekly figures and flag any > 10.
CADENCE_HITS="$(grep -Eio '[0-9]+ *(reels|posts)? *(per +week|/ *week|a +week|/wk)' "$FILE" 2>/dev/null || true)"
OVER=0
if [ -n "$CADENCE_HITS" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    n="$(printf '%s' "$line" | grep -Eo '[0-9]+' | head -1)"
    [ -z "$n" ] && continue
    if [ "$n" -gt 10 ]; then OVER=$((OVER + 1)); fi
  done <<EOF
$CADENCE_HITS
EOF
fi
if [ "$OVER" -gt 0 ]; then
  warn "cadence reads >10/week — past the dilution ceiling (consistency beats volume)"
else
  ok "no cadence over the ~10/week ceiling"
fi

# Ledger logs only vanity metrics.
if has 'like|view'; then
  if has 'completion|sends?|saves?'; then
    ok "ledger logs completion / sends / saves (not only vanity)"
  else
    warn "likes/views mentioned but no completion / sends / saves — log the signals that move reach"
  fi
else
  ok "no vanity-only metric set detected"
fi

# Identical-creative cross-posting as a plan.
if has 'identical (creative|video)|same (creative|clip).*(both|all).*platform|repost.*same|cross[- ]?post.*identical'; then
  warn "identical-creative cross-posting mentioned — Originality Score suppresses recycled content; re-cut natively"
else
  ok "no identical-creative cross-posting plan detected"
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
