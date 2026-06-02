#!/usr/bin/env bash
#
# verify.sh — structural guardrail for a LinkedIn-outreach touch ledger.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free checks over ONE ledger CSV:
#     1. Header row must equal the required columns EXACTLY:
#        date,name,profile_url,channel,trigger,action,stage,outcome,next_touch
#        -> FAIL if it differs.
#     2. Every data row's `outcome` (column 8) must be in the allowed enum
#        {requested, accepted, replied, conversation, call_booked, dead}
#        -> FAIL on any blank or out-of-enum value.
#     3. No cell may carry a placeholder / merge token:
#        a "{...}" merge field, a "[...]" slot, "XXXX", or "TODO" -> FAIL.
#
#   A missing ledger OR an empty / header-only file exits 0 with a notice
#   (the skill can be used advisorily before any ledger exists) — never a
#   false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                                  # default 02-DOCS/linkedin-outreach/touches.csv
#   ./verify.sh path/to/touches.csv              # explicit path
#
# EXIT CODES
#   0  clean, or no ledger / empty ledger to check
#   1  a structural failure (bad header, bad outcome, or placeholder token)
#   2  bad usage (path given but is a directory)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

FILE="${1:-02-DOCS/linkedin-outreach/touches.csv}"
HEADER='date,name,profile_url,channel,trigger,action,stage,outcome,next_touch'

if [ -d "$FILE" ]; then
  printf '%susage: %s [path/to/touches.csv]%s\n' "$RED" "$0" "$NC"
  exit 2
fi

if [ ! -f "$FILE" ]; then
  warn "no ledger at '$FILE' — nothing to verify (advisory use is fine)"
  exit 0
fi

# Strip a possible trailing CR (CRLF files) when reading rows.
ROW_COUNT="$(awk 'NF{c++} END{print c+0}' "$FILE")"
if [ "$ROW_COUNT" -eq 0 ]; then
  warn "ledger '$FILE' is empty — nothing to verify"
  exit 0
fi

# --- 1. header row exact match ------------------------------------------------
ACTUAL_HEADER="$(awk 'NR==1{sub(/\r$/,""); print; exit}' "$FILE")"
if [ "$ACTUAL_HEADER" = "$HEADER" ]; then
  ok "header row matches the required schema"
else
  fail "header row mismatch"
  printf '       expected: %s\n' "$HEADER"
  printf '       found:    %s\n' "$ACTUAL_HEADER"
fi

DATA_ROWS="$(awk 'NR>1 && NF{c++} END{print c+0}' "$FILE")"
if [ "$DATA_ROWS" -eq 0 ]; then
  warn "header-only ledger — no data rows to check yet"
  printf '\n'
  if [ "$fail_count" -gt 0 ]; then
    printf '%s%d failure(s)%s\n' "$RED" "$fail_count" "$NC"; exit 1
  fi
  printf '%sall checks passed%s\n' "$GREEN" "$NC"; exit 0
fi

# --- 2. outcome enum (column 8) -----------------------------------------------
BAD_OUTCOME="$(awk -F',' '
  NR>1 && NF>0 {
    o=$8; gsub(/\r/,"",o); gsub(/^[ \t]+|[ \t]+$/,"",o);
    allowed="requested accepted replied conversation call_booked dead";
    if (index(" " allowed " ", " " o " ") == 0) print NR": \""o"\"";
  }' "$FILE")"
if [ -n "$BAD_OUTCOME" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && fail "row $line — outcome not in {requested,accepted,replied,conversation,call_booked,dead}"
  done <<EOF
$BAD_OUTCOME
EOF
else
  ok "every data row has a valid outcome"
fi

# --- 3. placeholder / merge-token banlist -------------------------------------
PLACEHOLDERS="$(grep -nE '\{[^}]*\}|\[[^]]*\]|XXXX|TODO' "$FILE" 2>/dev/null || true)"
if [ -n "$PLACEHOLDERS" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && fail "placeholder/merge token present at line ${line%%:*} — fill before logging"
  done <<EOF
$PLACEHOLDERS
EOF
else
  ok "no placeholder / merge tokens in any cell"
fi

# --- summary ------------------------------------------------------------------
printf '\n'
if [ "$fail_count" -gt 0 ]; then
  printf '%s%d failure(s)%s\n' "$RED" "$fail_count" "$NC"
  exit 1
fi
printf '%sall checks passed%s\n' "$GREEN" "$NC"
exit 0
