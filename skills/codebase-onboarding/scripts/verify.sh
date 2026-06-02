#!/usr/bin/env bash
# verify.sh — structural check for the codebase-onboarding artifact.
#
# Validates that a CODEBASE-MAP.md contains the required sections. This is a
# STRUCTURE check, not a content-correctness check (this is a process skill;
# its real rigor is the capability eval). Read-only: it never writes or edits.
#
# Usage:   verify.sh [path-to-map]      (default: ./CODEBASE-MAP.md)
# Exit 0:  map present with all required sections, OR no map yet (nothing to
#          check — an empty/clean target must not produce a false failure).
# Exit 1:  map present but missing one or more required sections.

set -euo pipefail

MAP="${1:-CODEBASE-MAP.md}"

# No artifact yet => nothing to validate. Clean target, exit 0 (no false fail).
if [[ ! -f "$MAP" ]]; then
  echo "OK: no $MAP yet — nothing to verify (run the recon pass to produce one)."
  exit 0
fi

# Required section headers. Each entry is an extended-regex alternation so that
# reasonable wording variants (e.g. "Request flow" / "Data flow") still pass.
declare -a SECTIONS=(
  "Stack"
  "Entry points?"
  "Request flow|Data flow"
  "Module ownership"
  "Hidden behavior|Hidden behaviour|Side effects?"
  "Hotspots?"
  "How to run|Running locally"
)

missing=()
for pat in "${SECTIONS[@]}"; do
  # Match a markdown heading line (## ...) containing the pattern, case-insensitive.
  if ! grep -Eiq "^#{1,6}[[:space:]].*(${pat})" "$MAP"; then
    # Use the first alternative as the human-readable label.
    missing+=("${pat%%|*}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "FAIL: $MAP is missing required section(s):" >&2
  for m in "${missing[@]}"; do
    echo "  - $m" >&2
  done
  echo "Required: Stack, Entry points, Request flow, Module ownership, Hidden behavior, Hotspots, How to run." >&2
  exit 1
fi

echo "OK: $MAP has all required sections."
exit 0
