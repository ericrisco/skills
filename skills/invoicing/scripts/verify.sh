#!/usr/bin/env bash
#
# verify.sh — lint an invoice JSON payload against the legally-valid-invoice
# rule set, and check an invoice-number array for gaps / duplicates.
#
# Read-only. Never writes, edits, or sends anything.
#
# Usage:
#   scripts/verify.sh [PATH ...]
#     PATH = an invoice JSON file, or a directory scanned for *.json.
#     With no PATH, scans ./fixtures next to this script.
#
# Exit 0 = every checked payload is valid AND no target was found to check
#          (an empty/clean target is a pass, never a false failure).
# Exit 1 = at least one payload is missing a required field or has a
#          gap/duplicate in its invoice-number sequence.
# Exit 2 = a usage / environment problem (e.g. jq missing).
#
# Invoice JSON shape (all fields required unless noted):
#   {
#     "number": "2024-001",
#     "issue_date": "2024-03-01",
#     "due_date": "2024-03-31",
#     "supplier": { "name": "...", "vat_id": "ESB12345678" },
#     "customer": { "name": "..." },
#     "line_items": [ { "description": "...", "amount": 120000 } ],
#     "vat_breakdown": [ { "rate": 21, "net": 120000, "vat": 25200 } ],
#     "total": 145200,
#     "sequence": ["2024-001","2024-002","2024-003"]   // optional series check
#   }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "verify.sh: jq is required but not installed" >&2
  exit 2
fi

# Resolve targets -> list of .json files.
declare -a TARGETS=()
if [ "$#" -eq 0 ]; then
  set -- "${SCRIPT_DIR}/fixtures"
fi

declare -a FILES=()
for t in "$@"; do
  if [ -d "$t" ]; then
    while IFS= read -r f; do FILES+=("$f"); done \
      < <(find "$t" -type f -name '*.json' 2>/dev/null | sort)
  elif [ -f "$t" ]; then
    FILES+=("$t")
  else
    echo "verify.sh: no such path: $t" >&2
  fi
done

# Empty / clean target is a pass, not a failure.
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "verify.sh: nothing to check (no invoice JSON found) — OK"
  exit 0
fi

fail=0

check_file() {
  local file="$1"
  local -a problems=()

  if ! jq empty "$file" >/dev/null 2>&1; then
    echo "FAIL  $file"
    echo "        - not valid JSON"
    fail=1
    return
  fi

  # Field-by-field presence check (handles nested + arrays).
  for f in number issue_date due_date total; do
    if [ "$(jq -r --arg k "$f" '(.[$k] // "") | tostring | length' "$file")" = "0" ]; then
      problems+=("missing or empty field: $f")
    fi
  done
  [ "$(jq -r '(.supplier.vat_id // "") | tostring | length' "$file")" = "0" ] \
    && problems+=("missing supplier.vat_id")
  [ "$(jq -r '(.supplier.name // "") | tostring | length' "$file")" = "0" ] \
    && problems+=("missing supplier.name")
  [ "$(jq -r '(.customer.name // "") | tostring | length' "$file")" = "0" ] \
    && problems+=("missing customer.name")
  [ "$(jq -r '(.line_items // []) | length' "$file")" = "0" ] \
    && problems+=("no line_items")
  [ "$(jq -r '(.vat_breakdown // []) | length' "$file")" = "0" ] \
    && problems+=("no vat_breakdown (need net+rate+vat per rate)")

  # Each VAT row must carry rate, net, vat.
  if [ "$(jq -r '
      (.vat_breakdown // [])
      | map(select((.rate==null) or (.net==null) or (.vat==null)))
      | length' "$file")" != "0" ]; then
    problems+=("a vat_breakdown row is missing rate/net/vat")
  fi

  # Optional invoice-number sequence: detect gaps + duplicates.
  if [ "$(jq -r 'has("sequence")' "$file")" = "true" ]; then
    # duplicates
    if [ "$(jq -r '.sequence | (length) - (unique | length)' "$file")" != "0" ]; then
      problems+=("invoice-number sequence has duplicates")
    fi
    # numeric-suffix gap detection (e.g. 2024-001 .. 2024-003)
    gap="$(jq -r '
      [ .sequence[] | (capture("(?<n>[0-9]+)$").n // empty) | tonumber ]
      | if length < 2 then empty
        else . as $a
          | [range(0; length-1) | select(($a[.+1]) - ($a[.]) != 1)]
          | if length > 0 then "gap" else empty end
        end' "$file" 2>/dev/null || true)"
    [ "$gap" = "gap" ] && problems+=("invoice-number sequence has a gap")
  fi

  if [ "${#problems[@]}" -eq 0 ]; then
    echo "OK    $file"
  else
    echo "FAIL  $file"
    for p in "${problems[@]}"; do echo "        - $p"; done
    fail=1
  fi
}

for f in "${FILES[@]}"; do
  check_file "$f"
done

exit "$fail"
