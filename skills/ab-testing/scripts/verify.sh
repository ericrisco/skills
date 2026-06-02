#!/usr/bin/env bash
set -euo pipefail

# verify.sh — ab-testing skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, NEVER runs anything destructive):
#   1. Discovers experiment artifacts produced by this skill:
#        - Python sizing/analysis scripts whose names hint at experiments
#          (*sample*size*.py, *ab*test*.py, *experiment*.py, *power*.py, *cuped*.py, *srm*.py)
#        - experiment-design docs (*experiment*.md, *ab*test*.md, *design*.md)
#   2. For each Python artifact: checks scipy + statsmodels import, then executes it under
#      python3 and asserts it prints at least one integer (a sample size / count).  [warn-only]
#   3. For each design doc: greps for a primary metric, an MDE, and power/alpha.   [warn-only]
#
# Exit code: non-zero ONLY when a discovered Python artifact crashes (non-zero exit) under an
# environment that HAS python3 + scipy + statsmodels. Missing interpreter/libs -> skip, never fail.
# Missing fields in a doc -> advisory warn. An empty or clean target exits 0 (no false failure).
# Stock macOS bash 3.2 compatible (no mapfile, no associative arrays).

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# --- discover python sizing/analysis artifacts ---
PY_FILES=()
while IFS= read -r -d '' f; do
  PY_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/.venv/*' -o -path '*/venv/*' -o -path '*/site-packages/*' \) -prune -o \
    -type f \( -iname '*sample*size*.py' -o -iname '*ab*test*.py' -o -iname '*experiment*.py' \
               -o -iname '*power*.py' -o -iname '*cuped*.py' -o -iname '*srm*.py' \) -print0 2>/dev/null
)

# --- discover experiment-design docs ---
DOC_FILES=()
while IFS= read -r -d '' f; do
  DOC_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/.venv/*' \) -prune -o \
    -type f \( -iname '*experiment*.md' -o -iname '*ab*test*.md' -o -iname '*design*.md' \) -print0 2>/dev/null
)

if [ "${#PY_FILES[@]}" -eq 0 ] && [ "${#DOC_FILES[@]}" -eq 0 ]; then
  skip "no experiment scripts or design docs found under $ROOT — design-only conversation"
  ok "verify.sh passed (empty target)"
  exit 0
fi

# --- python artifacts ---
if [ "${#PY_FILES[@]}" -gt 0 ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 not installed — cannot execute sizing scripts"
  elif ! python3 -c 'import scipy, statsmodels' >/dev/null 2>&1; then
    skip "scipy/statsmodels not importable — install with: pip install scipy statsmodels"
  else
    for f in "${PY_FILES[@]}"; do
      out="$(python3 "$f" 2>&1)" || { err "$f: crashed under python3"; printf '%s\n' "$out" | sed 's/^/    /'; continue; }
      if printf '%s' "$out" | grep -Eq '[0-9]+'; then
        ok "$f: executed and printed a number"
      else
        note "$f: ran but printed no numeric output — a sizing/analysis script should print an n or p-value"
      fi
    done
  fi
fi

# --- design docs ---
for f in "${DOC_FILES[@]}"; do
  miss=""
  grep -Eiq 'primary[[:space:]]+metric|metric[[:space:]]*:'                  "$f" || miss="$miss primary-metric"
  grep -Eiq 'mde|minimum[[:space:]]+detectable[[:space:]]+effect'           "$f" || miss="$miss MDE"
  grep -Eiq 'power|alpha|significance[[:space:]]+level'                      "$f" || miss="$miss power/alpha"
  if [ -n "$miss" ]; then
    note "$f: experiment-design doc missing:$miss"
  else
    ok "$f: names a primary metric, an MDE, and power/alpha"
  fi
done

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
