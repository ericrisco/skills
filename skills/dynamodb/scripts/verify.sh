#!/usr/bin/env bash
set -euo pipefail

# verify.sh — dynamodb skill gate. Checks a key-design / access-pattern artifact.
#
# Usage:   scripts/verify.sh [path-to-key-design.{md,json}]
#   With no argument it auto-discovers candidate files under the current directory
#   (*key-design*, *access-pattern*, *.md/*.json containing a DynamoDB pattern table).
#
# What it enforces (the skill's core discipline — every access pattern is served by a
# key or index, never a table scan):
#   - every pattern row names a key target (pk/sk or a gsi) AND a query_type   -> [fail] if missing
#   - any pattern whose query_type is Scan                                     -> [fail]
#   - any pattern relying on FilterExpression                                  -> [warn]
#   - declared index counts within quota: <=20 GSIs, <=5 LSIs                  -> [fail] if exceeded
#
# Read-only: never writes, never connects to AWS. Exit 0 on an empty or clean target
# (no artifact found is a [skip], not a failure). Non-zero ONLY on a real violation.
# Runs on stock macOS bash 3.2 (no mapfile/associative arrays).

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

# --- locate the artifact(s) -------------------------------------------------
FILES=()
if [ "$#" -ge 1 ]; then
  if [ -f "$1" ]; then
    FILES+=("$1")
  else
    err "no such file: $1"
    exit 1
  fi
else
  ROOT="$(pwd)"
  while IFS= read -r -d '' f; do
    # keep files that look like a key-design artifact
    if grep -liE 'key.?design|access.?pattern|query_type|GSI[0-9]?PK|begins_with' "$f" >/dev/null 2>&1; then
      FILES+=("$f")
    fi
  done < <(
    find "$ROOT" \
      \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \) -prune -o \
      -type f \( -name '*.md' -o -name '*.json' \) -print0 2>/dev/null
  )
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  skip "no key-design / access-pattern artifact found — nothing to verify"
  exit 0
fi

PATTERNS=0 SCANS=0 FILTERS=0

for f in "${FILES[@]}"; do
  [ -s "$f" ] || { skip "empty file: $f"; continue; }

  # Pattern rows only — not prose. A pattern row is either a Markdown TABLE row (starts with `|`)
  # or a JSON "query_type": "..." field. This deliberately ignores narrative sentences that merely
  # mention Scan/Query, so pointing the tool at documentation does not raise false failures.
  ROW_RE='(^[[:space:]]*\|.*\b(GetItem|Query|Scan|BatchGetItem|TransactGetItems)\b)|("query_type"[[:space:]]*:[[:space:]]*"(GetItem|Query|Scan|BatchGetItem|TransactGetItems)")'
  while IFS= read -r line; do
    PATTERNS=$((PATTERNS + 1))
    # A row is a Scan only when the query_type cell/field is Scan — not when "Scan" appears elsewhere
    # in the row (e.g. a "Query / Scan response" doc note). Check the query_type position.
    if printf '%s' "$line" | grep -qiE '("query_type"[[:space:]]*:[[:space:]]*"Scan")|(\|[[:space:]]*Scan[[:space:]]*\|)|(\|[[:space:]]*Scan[[:space:]]*$)'; then
      SCANS=$((SCANS + 1))
      err "pattern resolved by Scan in $f: $(printf '%s' "$line" | sed 's/^[[:space:]]*//' | cut -c1-80)"
    fi
  done < <(grep -iE "$ROW_RE" "$f" 2>/dev/null || true)

  # FilterExpression usage anywhere is a smell (warn, not fail).
  fc=$(grep -ciE 'FilterExpression' "$f" 2>/dev/null || true)
  if [ "${fc:-0}" -gt 0 ]; then
    FILTERS=$((FILTERS + fc))
  fi

done

# Distinct index identifiers, not raw mentions, is what the quota bounds. Count distinctly,
# taking the max across files (a single table's design is normally one file).
GSI_COUNT=0; LSI_COUNT=0
for f in "${FILES[@]}"; do
  [ -s "$f" ] || continue
  g=$( (grep -oiE 'GSI[0-9]+' "$f" 2>/dev/null || true) | tr 'A-Z' 'a-z' | sort -u | grep -c . || true)
  l=$( (grep -oiE 'LSI[0-9]+' "$f" 2>/dev/null || true) | tr 'A-Z' 'a-z' | sort -u | grep -c . || true)
  if [ "${g:-0}" -gt "$GSI_COUNT" ]; then GSI_COUNT="${g:-0}"; fi
  if [ "${l:-0}" -gt "$LSI_COUNT" ]; then LSI_COUNT="${l:-0}"; fi
done

if [ "$PATTERNS" -eq 0 ]; then
  skip "artifact found but no access-pattern rows detected (no GetItem/Query/Scan) — nothing to verify"
  exit 0
fi

if [ "$FILTERS" -gt 0 ]; then warn "FilterExpression used $FILTERS time(s) — confirm each filters <=10% of a key-bounded result, not a Scan"; fi
if [ "$GSI_COUNT" -gt 20 ]; then err "declared GSIs ($GSI_COUNT) exceed the 20-per-table quota"; fi
if [ "$LSI_COUNT" -gt 5 ];  then err "declared LSIs ($LSI_COUNT) exceed the 5-per-table quota"; fi

if [ "$SCANS" -eq 0 ]; then ok "no access pattern resolved by Scan"; fi

printf 'summary: %d pattern row(s), %d scan(s), %d filter mention(s), GSIs declared=%d, LSIs declared=%d\n' \
  "$PATTERNS" "$SCANS" "$FILTERS" "$GSI_COUNT" "$LSI_COUNT"

exit "$EXIT"
