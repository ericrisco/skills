#!/usr/bin/env bash
# verify.sh — config-validity gate for the scaling skill's k6 artifacts.
#
# Read-only by default: it statically asserts that every k6 test script in the
# skill declares the structure a real load test needs — an `export const options`
# block, a `thresholds` SLO gate, and a load profile (`stages` or `scenarios`).
# If `k6` is on PATH it additionally runs `k6 inspect` to confirm the script
# parses. It never makes a network request and never runs a load test.
#
# Exits 0 on a clean/empty target (no k6 scripts found is not a failure).
# Exits 1 only when a k6 script that DOES exist is missing required structure.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
checked=0

# Collect candidate k6 scripts: every .js under scripts/. We hard-check real .js
# files; the reference doc is checked best-effort below. Portable to bash 3.x
# (no mapfile), so loop over find output via a temp list.

check_script() {
  local file="$1"
  local body
  body="$(cat "$file")"
  local missing=()
  grep -q 'export const options' <<<"$body" || missing+=("export const options")
  grep -q 'thresholds' <<<"$body"            || missing+=("thresholds block")
  grep -Eq 'stages|scenarios' <<<"$body"     || missing+=("stages/scenarios load profile")

  if [ "${#missing[@]}" -ne 0 ]; then
    echo "FAIL  $file"
    printf '      missing: %s\n' "${missing[@]}"
    fail=1
  else
    echo "OK    $file"
    # Optional deeper validation only when k6 is installed; still no network.
    if command -v k6 >/dev/null 2>&1; then
      if k6 inspect "$file" >/dev/null 2>&1; then
        echo "      k6 inspect: parses cleanly"
      else
        echo "      k6 inspect: parse error"
        fail=1
      fi
    fi
  fi
  checked=$((checked + 1))
}

while IFS= read -r f; do
  [ -n "$f" ] || continue
  check_script "$f"
done < <(find "$SKILL_DIR/scripts" -type f -name '*.js' 2>/dev/null || true)

# Best-effort: confirm the reference doc still carries a thresholds example so the
# prose and the shipped artifact don't drift. Absence is a warning, not a failure.
ref="$SKILL_DIR/references/load-testing-k6.md"
if [ -f "$ref" ]; then
  if grep -q 'thresholds' "$ref"; then
    echo "OK    $ref (documents thresholds)"
  else
    echo "WARN  $ref no longer shows a thresholds example"
  fi
fi

if [ "$checked" -eq 0 ]; then
  echo "No k6 scripts found — nothing to verify (clean)."
fi

exit "$fail"
