#!/usr/bin/env bash
#
# verify.sh — FTC copy-banlist linter for review-request & reply copy.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free scan over ONE copy file you point it at (a review-request
#   template, a reply, or a config snippet) — or stdin. It catches the three ways
#   review copy crosses the FTC Consumer Review Rule line, plus the dead Q&A API:
#
#     1. GATING / sentiment-screen phrasing (HARD FAIL) — e.g. "if you loved",
#        "only if you're happy", "had a bad experience? contact us instead",
#        "give us 5 stars", "rate us 5". FTC review-suppression risk.
#     2. INCENTIVE-BY-SENTIMENT phrasing (HARD FAIL) — e.g. "leave a positive
#        review", "in exchange for a good review", "discount for a 5-star".
#        You may incentivize a review; you may NOT condition it on sentiment.
#     3. DEAD-API usage (HARD FAIL) — a "...googleapis.com/v4/.../questions"
#        endpoint or the literal "Q&A API" in config. Shut down Nov 2025.
#
#   A clean OR empty/missing-content file (or empty stdin) exits 0 — no false fail.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh review-copy.md          # scan a file
#   cat reply.txt | ./verify.sh -        # scan stdin
#   ./verify.sh -h                       # this help
#
# EXIT CODES
#   0  clean, or empty/missing-content input
#   1  one or more banlist hits (each printed with its line number)
#   2  bad usage (no input given, or file does not exist)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays, no bc.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
hit()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }
note() { printf '%s%s%s\n'        "$YELLOW" "$*" "$NC"; }

usage() { sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; }

INPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --) shift; INPUT="${1:-}"; shift || true ;;
    -) INPUT="-"; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$INPUT" ]; then INPUT="$1"; fi; shift ;;
  esac
done

if [ -z "$INPUT" ]; then
  printf '%sno input given (pass a file or "-" for stdin)%s\n' "$RED" "$NC" >&2
  usage; exit 2
fi

# Resolve input to a temp file so we can grep with line numbers uniformly.
TMP=""
cleanup() { [ -n "$TMP" ] && rm -f "$TMP"; return 0; }
trap cleanup EXIT

if [ "$INPUT" = "-" ]; then
  TMP="$(mktemp 2>/dev/null || mktemp -t revmgmt)"
  cat > "$TMP"
  SRC="$TMP"
  LABEL="stdin"
else
  if [ ! -f "$INPUT" ]; then
    printf '%sfile not found: %s%s\n' "$RED" "$INPUT" "$NC" >&2
    exit 2
  fi
  SRC="$INPUT"
  LABEL="$INPUT"
fi

# Empty / whitespace-only: nothing to check, never a false failure.
if [ ! -s "$SRC" ] || ! grep -q '[^[:space:]]' "$SRC" 2>/dev/null; then
  ok "empty input — nothing to check"
  exit 0
fi

note "review-management verify — $LABEL"
printf '\n'

fail_count=0

# Each entry: a label, then an extended-regex of banned phrasings (case-insensitive).
# Printed with grep -nEi so every hit carries its line number.
scan() {
  # $1 = human label, $2 = regex
  local label="$1" rx="$2" out
  out="$(grep -nEi "$rx" "$SRC" 2>/dev/null || true)"
  if [ -n "$out" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && hit "$label — line $line"
      fail_count=$((fail_count + 1))
    done <<EOF
$out
EOF
  fi
}

# 1. Gating / sentiment-screen.
scan "GATING (FTC review-suppression)" \
  "if you('| a)?re? (loved|happy|satisfied)|if you loved|only if you('| a)?re? (happy|satisfied)|loved us\??|had a (bad|poor|negative) experience.*(contact|email|reach|instead)|tell us (privately|directly) (first|instead)|give (us|me) (a |an )?5|rate (us|me) (a |an )?5|leave (us )?(a |an )?5[ -]?star|5[ -]?stars? (please|if)|please (give|leave|rate).*5"

# 2. Incentive conditioned on sentiment.
scan "INCENTIVE-BY-SENTIMENT (FTC banned)" \
  "leave (a |an )?positive review|positive review (in|for) (exchange|return)|in exchange for (a |an )?(good|positive|5)|discount for (a |an )?(5|positive|good)|(\\\$|€|gift).* for (a |an )?(5|positive|good) (star|review)|reward.* (positive|5[ -]?star) review"

# 3. Dead Google Q&A API.
scan "DEAD Q&A API (shut down Nov 2025)" \
  "googleapis\.com/v4/[^[:space:]]*questions|/questions[^a-z]|\bq&a api\b|questions-?and-?answers api"

printf '\n'
if [ "$fail_count" -gt 0 ]; then
  printf '%s%d banlist hit(s) — fix before shipping (FTC Consumer Review Rule)%s\n' \
    "$RED" "$fail_count" "$NC"
  exit 1
fi
ok "clean — no gating, sentiment-incentive, or dead-API phrasing"
exit 0
