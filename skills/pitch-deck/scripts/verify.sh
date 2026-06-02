#!/usr/bin/env bash
#
# verify.sh — structural/numeric lint for an investor pitch-deck OUTLINE.
#
# WHAT IT DOES (read-only; no edits, no network)
#   Parses a deck outline (markdown — one slide per heading line, e.g. `## Problem`
#   or `## Slide 8: Traction`) and checks the CONTENT CONTRACT, not prose taste:
#     1. Required core slides present: problem, solution, why-now, market, product,
#        business-model, traction, team, ask (case-insensitive heading match).
#     2. Slide count: warn if > 15 (the deck-discipline limit).
#     3. Ask block: must name a currency amount (or "raising ...") AND a
#        use-of-funds / runway / milestone token. A numberless ask FAILS.
#     4. Traction block: must carry >=1 metric with a unit (%, MRR, ARR, x, $).
#        Numberless traction WARNS.
#     5. Buzzword banlist WARNING (revolutionary, disruptive, world-class,
#        no competition, best-in-class, hockey stick, conservative estimate).
#
#   Narrative quality is NOT judged here — that is the capability eval's job.
#   This is grep-level structure only.
#
# HOW TO RUN (against your own deck outline, not the skills repo)
#   ./verify.sh path/to/deck.md
#   ./verify.sh --strict path/to/deck.md      # warnings become failures (CI gate)
#   ./verify.sh                               # no path -> nothing to lint, exits 0
#
# EXIT CODES
#   0  clean, or warn-only (and not --strict), or no target given / empty target
#   1  a real failure: a missing CORE slide, or an ask with no number
#      (also: any warning when --strict)
#   2  bad usage (path given but not a readable file)

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  printf 'This script requires bash (>= 3.2). Run: bash %s\n' "$0" >&2
  exit 2
fi

# --- color (suppressed when not a TTY) -------------------------------------
if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '3,35p' "$0" | sed 's/^# \{0,1\}//'; }

# --- arg parse -------------------------------------------------------------
STRICT=0
DECK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --strict)  STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*)        printf '%sUnknown flag: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
    *)         DECK="$1"; shift ;;
  esac
done

# No target -> nothing to check. Clean exit (no false failure on empty input).
if [ -z "$DECK" ]; then
  printf 'No deck outline given. Pass a markdown path, e.g.: %s deck.md\n' "$0"
  printf '(nothing to lint — exiting clean)\n'
  exit 0
fi

if [ ! -f "$DECK" ]; then
  printf '%sNot a readable file: %s%s\n' "$RED" "$DECK" "$NC"
  exit 2
fi

# Empty file -> clean exit, no false failure.
if [ ! -s "$DECK" ]; then
  warn "deck outline is empty: $DECK (nothing to lint)"
  printf '\nok=%d warn=%d fail=%d\n' "$ok_count" "$warn_count" "$fail_count"
  exit 0
fi

printf 'Linting deck outline: %s\n\n' "$DECK"

# Headings only (lines starting with one or more '#').
HEADINGS="$(grep -E '^#{1,6}[[:space:]]' "$DECK" 2>/dev/null || true)"

# --- 1. required core slides ----------------------------------------------
# Each entry: "Label|regex matched against heading text (case-insensitive)".
check_slide() {
  label="$1"; pat="$2"
  if printf '%s\n' "$HEADINGS" | grep -iqE "$pat"; then
    ok "core slide present: $label"
  else
    fail "missing core slide: $label (heading matching /$pat/)"
  fi
}

check_slide "Problem"        'problem|pain'
check_slide "Solution"       'solution|how it works|approach'
check_slide "Why now"        'why[ -]?now|timing'
check_slide "Market"         'market|tam|sam|som|market size'
check_slide "Product"        'product|demo|how it works'
check_slide "Business model" 'business model|model|pricing|revenue model|how we (make|earn)'
check_slide "Traction"       'traction|growth|metrics|momentum'
check_slide "Team"           'team|founders|who we are'
check_slide "Ask"            'ask|raise|raising|fundrais|the ask|use of funds'

# --- 2. slide count --------------------------------------------------------
SLIDE_COUNT="$(printf '%s\n' "$HEADINGS" | grep -cE '^#{1,6}[[:space:]]' || true)"
SLIDE_COUNT="${SLIDE_COUNT:-0}"
if [ "$SLIDE_COUNT" -gt 15 ]; then
  warn "deck has $SLIDE_COUNT headings — over the ~15-slide discipline; move detail to the conversation/data room"
elif [ "$SLIDE_COUNT" -eq 0 ]; then
  warn "no '#' headings found — is this a slide-per-heading outline?"
else
  ok "slide count $SLIDE_COUNT (<= 15 discipline limit)"
fi

# --- block extraction ------------------------------------------------------
# Print the lines from the heading matching $1 up to (not incl.) the next heading.
block_for() {
  # Lowercase the heading for matching so it works on BSD awk (no IGNORECASE).
  awk -v pat="$1" '
    BEGIN { inblk = 0 }
    /^#{1,6}[[:space:]]/ {
      if (inblk) { exit }
      if (tolower($0) ~ pat) { inblk = 1; print; next }
    }
    { if (inblk) print }
  ' "$DECK"
}

# --- 3. ask block: amount AND a use-of-funds/runway/milestone token --------
ASK_BLOCK="$(block_for 'ask|raise|raising|fundrais|use of funds')"
if [ -z "$ASK_BLOCK" ]; then
  warn "could not isolate an ask block to inspect (heading not found earlier?)"
else
  has_amount=0; has_use=0
  # currency amount: $/€/£ + number, or a number + k/m/mm, or the word raising/raise
  # An actual figure: currency+digit, a number with a k/m unit, or "raising <number>".
  # Bare "raise/raising" with no number does NOT count as an amount.
  if printf '%s\n' "$ASK_BLOCK" | grep -iqE '[$€£][0-9]|[0-9]+(\.[0-9]+)?[[:space:]]*(k|m|mm|million|thousand)|rais(e|ing)[[:space:]]+[$€£]?[0-9]'; then
    has_amount=1
  fi
  if printf '%s\n' "$ASK_BLOCK" | grep -iqE 'use of funds|runway|milestone|months?|to[[:space:]]+[$€£]?[0-9]|series[ -]?[ab]|allocat|breakdown'; then
    has_use=1
  fi
  if [ "$has_amount" -eq 1 ] && [ "$has_use" -eq 1 ]; then
    ok "ask names an amount AND a use-of-funds/runway/milestone"
  elif [ "$has_amount" -eq 0 ]; then
    fail "ask slide names no raise amount (need e.g. '\$1.5M' or 'raising ...')"
  else
    warn "ask names an amount but no use-of-funds/runway/milestone — add 'what it buys'"
  fi
fi

# --- 4. traction block: at least one metric with a unit --------------------
TRACTION_BLOCK="$(block_for 'traction|growth|metrics|momentum')"
if [ -z "$TRACTION_BLOCK" ]; then
  warn "could not isolate a traction block to inspect"
else
  if printf '%s\n' "$TRACTION_BLOCK" | grep -iqE '[0-9]+([.,][0-9]+)?[[:space:]]*(%|x|mrr|arr|nrr)|[$€£][0-9]|[0-9]+[[:space:]]*(mom|mo|month)'; then
    ok "traction carries >=1 metric with a unit (%, x, MRR/ARR, \$, MoM)"
  else
    warn "traction slide has no number+unit — show the growth SHAPE (e.g. '\$50K MRR, +22% MoM')"
  fi
fi

# --- 5. buzzword banlist (warn-only) ---------------------------------------
BUZZ='revolutionary|disruptive|world-?class|no competition|best-?in-?class|hockey ?stick|conservative estimate|game-?changer'
hits="$(grep -inE "$BUZZ" "$DECK" 2>/dev/null || true)"
if [ -n "$hits" ]; then
  warn "buzzwords found (replace with a number / mechanism / receipt):"
  printf '%s\n' "$hits" | head -n 6
else
  ok "no banlist buzzwords"
fi

# --- summary ---------------------------------------------------------------
printf '\nok=%d warn=%d fail=%d\n' "$ok_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
