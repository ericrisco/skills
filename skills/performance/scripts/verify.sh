#!/usr/bin/env bash
# verify.sh — budget-validity gate for the performance skill's artifacts.
#
# The skill tells you to commit a performance budget (a Core Web Vitals target
# + a bundle-size budget) so the thresholds can't silently drift. This script
# statically lints any such budget file it finds. It does NOT run a live
# Lighthouse audit — that needs a real URL and a browser and is non-hermetic;
# the behavioral rigor lives in ../evals/. This only checks the committed
# artifact.
#
# Read-only: it never writes, never makes a network request.
# Exits 0 on a clean/empty target (no budget file found is NOT a failure).
# Exits 1 only when a budget file that DOES exist is malformed or carries a
# Core Web Vitals threshold that contradicts the canonical "good" numbers:
#   LCP 2500 ms, INP 200 ms, CLS 0.1.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
checked=0

# Canonical CWV "good" thresholds (field 75th percentile).
LCP_MS=2500
INP_MS=200
CLS=0.1

have() { command -v "$1" >/dev/null 2>&1; }

# Extract a numeric value for a key from a JSON file. Prefer jq; fall back to a
# grep/sed scrape so the check works with zero dependencies.
json_num() {
  local file="$1" key="$2"
  if have jq; then
    jq -r ".. | objects | .\"$key\"? // empty | select(type==\"number\")" "$file" 2>/dev/null | head -n1
  else
    grep -Eo "\"$key\"[[:space:]]*:[[:space:]]*[0-9.]+" "$file" 2>/dev/null \
      | head -n1 | grep -Eo '[0-9.]+$'
  fi
}

# A budget is "LCP-shaped" if it mentions LCP at all; only then do we lint it.
looks_like_budget() {
  grep -Eqi '"?lcp"?|core[ _-]?web[ _-]?vitals|first[ _-]?load[ _-]?js|bundle' "$1" 2>/dev/null
}

check_budget() {
  local file="$1"
  looks_like_budget "$file" || return 0
  checked=$((checked + 1))

  # Must be valid JSON when jq is available.
  if have jq && ! jq empty "$file" >/dev/null 2>&1; then
    echo "FAIL  $file (invalid JSON)"
    fail=1
    return 0
  fi

  local missing=() bad=()
  local lcp inp cls
  lcp="$(json_num "$file" lcp)"
  inp="$(json_num "$file" inp)"
  cls="$(json_num "$file" cls)"

  [ -n "$lcp" ] || missing+=("lcp")
  [ -n "$inp" ] || missing+=("inp")
  [ -n "$cls" ] || missing+=("cls")

  # A budget threshold must not be LOOSER than the canonical "good" number.
  [ -n "$lcp" ] && awk "BEGIN{exit !($lcp > $LCP_MS)}" && bad+=("lcp=$lcp ms looser than $LCP_MS")
  [ -n "$inp" ] && awk "BEGIN{exit !($inp > $INP_MS)}" && bad+=("inp=$inp ms looser than $INP_MS")
  [ -n "$cls" ] && awk "BEGIN{exit !($cls > $CLS)}"   && bad+=("cls=$cls looser than $CLS")

  if [ "${#missing[@]}" -ne 0 ] || [ "${#bad[@]}" -ne 0 ]; then
    echo "FAIL  $file"
    [ "${#missing[@]}" -ne 0 ] && printf '      missing metric: %s\n' "${missing[@]}"
    [ "${#bad[@]}" -ne 0 ]     && printf '      drifted: %s\n' "${bad[@]}"
    fail=1
  else
    echo "OK    $file (LCP/INP/CLS budget within canonical good thresholds)"
  fi
}

# Lint every JSON budget candidate under the skill dir (bash 3.x safe — no mapfile).
while IFS= read -r f; do
  [ -n "$f" ] || continue
  check_budget "$f"
done < <(find "$SKILL_DIR" -type f \( -name 'budget*.json' -o -name '*budget.json' \
            -o -name '.lighthouserc.json' -o -name 'perf-budget.json' \) 2>/dev/null || true)

if [ "$checked" -eq 0 ]; then
  echo "No performance budget file found — nothing to verify (clean)."
fi

exit "$fail"
