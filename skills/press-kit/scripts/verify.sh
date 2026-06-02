#!/usr/bin/env bash
#
# verify.sh — structural guardrail for a drafted press release.
#
# WHAT IT DOES (read-only; never edits, moves, or writes a file)
#   Static, network-free checks over ONE release file you point it at
#   (a .md or .txt press release):
#     1. Header line: a "FOR IMMEDIATE RELEASE" or "EMBARGOED UNTIL" line is
#        present -> else FAIL. Reporters scan for it; missing = amateur.
#     2. Dateline: a line shaped "CITY, ST, Month DD, YYYY —" (em dash, en dash,
#        or "--") is present -> else FAIL. Anchors the story in time/place.
#     3. Boilerplate: a line starting "About " is present -> else FAIL. The
#        evergreen "About [Company]" paragraph every release closes with.
#     4. End marker: a line that is exactly "###" or "-30-" -> else FAIL.
#        Signals where the release ends.
#     5. Contact: at least one email address (a press-contact block) -> else FAIL.
#     6. Banlist (WARN): "thrilled to announce", "excited to announce",
#        "world-class", "game-changer", "game changer", "revolutionary",
#        "cutting-edge", "best-in-class" -> filler that weakens pickup.
#     7. Embargo timezone (WARN): an EMBARGOED line with no recognizable timezone
#        token (ET/PT/CT/MT/UTC/GMT/CET/CEST/EST/PST...) -> ambiguous embargo.
#     8. Length (WARN): body word count over the ceiling (default 600 ~ two pages).
#
#   Checks 1–5 are hard failures. Banlist / embargo-TZ / length are warnings and
#   do NOT fail the run unless --strict. A clean OR empty/missing-content file
#   exits 0 — never a false failure on nothing.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh release.md                 # hard checks + warnings
#   ./verify.sh release.md --ceiling 500   # tighten the body word ceiling
#   ./verify.sh release.md --strict        # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/missing-content file
#   1  a hard failure (missing required marker) — or any warning under --strict
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

usage() { sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
CEILING=600
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --ceiling) CEILING="${2:-600}"; shift 2 ;;
    --strict)  STRICT=1; shift ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *)  if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

if [ -z "$FILE" ]; then
  printf 'usage: %s <release.md> [--ceiling N] [--strict]\n' "$(basename "$0")" >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  printf 'no such file: %s\n' "$FILE" >&2
  exit 2
fi

# Empty / whitespace-only file: nothing to check, never a false failure.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE"; then
  ok "empty or content-free file: nothing to verify"
  exit 0
fi

# --- 1. Header line ---------------------------------------------------------
if grep -qiE 'FOR IMMEDIATE RELEASE|EMBARGOED UNTIL' "$FILE"; then
  ok "header line present (FOR IMMEDIATE RELEASE / EMBARGOED UNTIL)"
else
  fail "no header line — add 'FOR IMMEDIATE RELEASE' or 'EMBARGOED UNTIL [date time TZ]'"
fi

# --- 2. Dateline ------------------------------------------------------------
# CITY[, ST], Month DD, YYYY followed by an em/en dash or --
MONTHS='January|February|March|April|May|June|July|August|September|October|November|December'
if grep -qE "[A-Z][A-Za-z.]+(,[ ]?[A-Z]{2})?,[ ]?(${MONTHS})[ ]+[0-9]{1,2},[ ]?[0-9]{4}[ ]*(—|–|--)" "$FILE"; then
  ok "dateline present (CITY, ST, Month DD, YYYY —)"
else
  fail "no dateline — add 'CITY, ST, Month DD, YYYY —' before the lede"
fi

# --- 3. Boilerplate ---------------------------------------------------------
if grep -qE '^[[:space:]]*(#+[[:space:]]*)?About ' "$FILE"; then
  ok "boilerplate present (About [Company])"
else
  fail "no boilerplate — add an 'About [Company]' paragraph (<=100 words)"
fi

# --- 4. End marker ----------------------------------------------------------
if grep -qE '^[[:space:]]*(###|-30-)[[:space:]]*$' "$FILE"; then
  ok "end marker present (### / -30-)"
else
  fail "no end marker — close the body with '###' (or '-30-') on its own line"
fi

# --- 5. Contact (email) -----------------------------------------------------
if grep -qE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$FILE"; then
  ok "press-contact email present"
else
  fail "no contact email — add a Media Contact block with a real email address"
fi

# --- 6. Banlist (warn) ------------------------------------------------------
BANLIST="thrilled to announce|excited to announce|world-class|game-changer|game changer|revolutionary|cutting-edge|best-in-class"
hits=$(grep -inE "$BANLIST" "$FILE" || true)
if [ -n "$hits" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && warn "filler phrase: ${line}"
  done <<EOF
$hits
EOF
else
  ok "no banned filler phrases"
fi

# --- 7. Embargo timezone (warn) --------------------------------------------
if grep -qiE 'EMBARGOED UNTIL' "$FILE"; then
  if grep -iE 'EMBARGOED UNTIL' "$FILE" | grep -qiE '\b(ET|PT|CT|MT|EST|EDT|PST|PDT|CST|CDT|MST|MDT|UTC|GMT|CET|CEST|BST)\b'; then
    ok "embargo line includes a timezone"
  else
    warn "embargo line has no timezone — an embargo without a TZ is ambiguous"
  fi
fi

# --- 8. Body length (warn) --------------------------------------------------
words=$(wc -w < "$FILE" | tr -d ' ')
if [ "$words" -gt "$CEILING" ]; then
  warn "release is ${words} words (> ${CEILING}); over two pages reads as too long"
else
  ok "length ${words} words (ceiling ${CEILING})"
fi

# --- Summary ---------------------------------------------------------------
printf '\n'
if [ "$fail_count" -gt 0 ]; then
  printf '%s%d failure(s), %d warning(s)%s\n' "$RED" "$fail_count" "$warn_count" "$NC"
  exit 1
fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then
  printf '%s0 failures but %d warning(s) under --strict%s\n' "$YELLOW" "$warn_count" "$NC"
  exit 1
fi
printf '%spassed: 0 failures, %d warning(s)%s\n' "$GREEN" "$warn_count" "$NC"
exit 0
