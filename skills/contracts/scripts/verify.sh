#!/usr/bin/env bash
# verify.sh — plain-language + risk-carve-out discipline check for a contracts draft.
# Read-only. Takes a generated contract/clause file as $1.
# No argument => prints usage and exits 0 (never blocks when not given a draft).
# Exits non-zero only when a real artifact violates a rule.
set -euo pipefail

artifact="${1:-}"

if [ -z "$artifact" ]; then
  echo "usage: verify.sh <contract-draft-file>"
  echo "Checks a drafted contract/clause for archaic legalese, a liability cap"
  echo "missing its carve-outs, and a missing attorney-review line."
  echo "No file given — nothing to check."
  exit 0
fi

if [ ! -f "$artifact" ]; then
  echo "verify.sh: not a file: $artifact" >&2
  exit 2
fi

fail=0

# 1) Archaic legalese banlist (case-insensitive). Plain-language rule.
legalese='heretofore|hereinafter|witnesseth|party of the first part|aforesaid'
if grep -niE "$legalese" "$artifact" >/dev/null; then
  echo "FAIL: archaic legalese — rewrite in plain language:"
  grep -niE "$legalese" "$artifact" | sed 's/^/  /'
  fail=1
fi

# 2) Liability cap present but no carve-out for confidentiality/indemnity/fraud.
if grep -niE 'limit.*liabilit|aggregate liabilit|liability.*cap|capped at' "$artifact" >/dev/null; then
  if ! grep -niE 'except|carve|carve-out|fraud|willful|confidential|indemnif' "$artifact" >/dev/null; then
    echo "FAIL: a liability cap exists but no carve-out (confidentiality/indemnity) or fraud exclusion was found."
    fail=1
  fi
fi

# 3) Full-contract draft with no attorney-review line. Heuristic on length.
lines=$(wc -l < "$artifact" | tr -d ' ')
if [ "$lines" -ge 30 ]; then
  if ! grep -niE 'attorney|legal counsel|qualified lawyer|licensed lawyer' "$artifact" >/dev/null; then
    echo "FAIL: full-contract draft has no attorney-review line (add 'Have a licensed attorney review this before signing')."
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: $artifact passed plain-language and risk-carve-out checks."
fi
exit "$fail"
