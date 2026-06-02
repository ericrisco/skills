#!/usr/bin/env bash
#
# verify.sh — DNS / mail-config deliverability linter. NO network, NO DNS
# lookups. Scans a target dir or file for the authentication anti-patterns this
# skill bans and exits non-zero on a hard finding.
#
# Read-only. Never writes, edits, or sends anything.
#
# Checks (text-only; this does not resolve DNS):
#   1. A DMARC record left at "p=none" — a WARN, not a fail: fine for the report
#      phase, but a reminder it must be tightened to quarantine/reject.
#   2. A DMARC record at "p=reject" with NO rua= reporting address — a FAIL:
#      enforcing with no visibility silently drops legitimate sub-streams.
#   3. A "v=spf1" record ending in "+all" — a FAIL: passes any sender, defeats SPF.
#
# Usage:
#   scripts/verify.sh [PATH ...]    PATH = a zone/config file or dir; default "."
#
# Exit 0 = no hard finding (clean/empty target passes). 1 = a hard finding.
# Exit 2 = usage/environment problem.

set -euo pipefail

# Never let this script flag itself. grep -rn emits "<path>:<line>:..."; strip
# any hit whose path component basenames to this script (relative or absolute).
SELF_BASE="$(basename "${BASH_SOURCE[0]}")"
drop_self() {
  awk -v self="$SELF_BASE" -F: '{
    p = $1
    n = split(p, parts, "/")
    if (parts[n] != self) print
  }'
}

if [ "$#" -eq 0 ]; then
  set -- "."
fi

declare -a TARGETS=()
for t in "$@"; do
  if [ -e "$t" ]; then
    TARGETS+=("$t")
  else
    echo "verify.sh: no such path: $t" >&2
  fi
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "verify.sh: nothing to scan"
  exit 0
fi

INCLUDE=(--include='*.txt' --include='*.zone' --include='*.dns'
  --include='*.conf' --include='*.cf' --include='*.yaml' --include='*.yml'
  --include='*.tf' --include='*.json' --include='*.env')
EXCLUDE=(--exclude-dir=.git --exclude-dir=node_modules --exclude=verify.sh)

fail=0
emit() {
  echo "FAIL  $1"
  while IFS= read -r line; do
    [ -n "$line" ] && echo "        $line"
  done <<< "$2"
  fail=1
}

# --- check 1: DMARC p=none (WARN) -----------------------------------------
none="$( { grep -rnI "${EXCLUDE[@]}" "${INCLUDE[@]}" \
  -E 'v=DMARC1[^"]*p=none' "${TARGETS[@]}" 2>/dev/null || true; } | drop_self)"
if [ -n "${none//[$'\n']/}" ]; then
  echo "WARN  DMARC at p=none (report phase only — tighten to quarantine/reject):"
  while IFS= read -r l; do [ -n "$l" ] && echo "        $l"; done <<< "$none"
fi

# --- check 2: DMARC p=reject with no rua= reporting (FAIL) -----------------
reject_hits=""
while IFS= read -r l; do
  [ -z "$l" ] && continue
  if ! printf '%s' "$l" | grep -q 'rua='; then
    reject_hits+="${l}"$'\n'
  fi
done < <( { grep -rnI "${EXCLUDE[@]}" "${INCLUDE[@]}" \
  -E 'v=DMARC1[^"]*p=reject' "${TARGETS[@]}" 2>/dev/null || true; } | drop_self)
if [ -n "${reject_hits//[$'\n']/}" ]; then
  emit "DMARC p=reject with no rua= report address (enforcing blind drops legit mail)" "$reject_hits"
fi

# --- check 3: SPF +all (FAIL) ---------------------------------------------
spf="$( { grep -rnI "${EXCLUDE[@]}" "${INCLUDE[@]}" \
  -E 'v=spf1[^"]*\+all' "${TARGETS[@]}" 2>/dev/null || true; } | drop_self)"
if [ -n "${spf//[$'\n']/}" ]; then
  emit "SPF ends in +all (passes any sender — use -all or ~all)" "$spf"
fi

if [ "$fail" -eq 0 ]; then
  echo "OK    no hard deliverability anti-pattern found"
fi
exit "$fail"
