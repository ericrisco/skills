#!/usr/bin/env bash
# verify.sh — read-only checks for an Elixir/OTP target.
#
# Checks (only when the toolchain and artifacts are present):
#   - `mix format --check-formatted` (style)
#   - `mix compile --warnings-as-errors` (warning-free compile) at a mix project root
#
# Never blocks a toolchain-free or empty target: exits 0 with a skip note when
# Elixir/mix is absent or there is nothing to check. No network, no writes.
#
# Usage: bash scripts/verify.sh [TARGET_DIR]   (default: current directory)

set -euo pipefail

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "verify: target '$TARGET' is not a directory — nothing to check. SKIP."
  exit 0
fi

# Toolchain gate: no mix on PATH -> skip cleanly (do not fail CI without a toolchain).
if ! command -v mix >/dev/null 2>&1; then
  echo "verify: 'mix' not found on PATH — Elixir toolchain not installed. SKIP."
  exit 0
fi

# Find a mix project root (a directory containing mix.exs), shallowest first.
mix_root=""
if [ -f "$TARGET/mix.exs" ]; then
  mix_root="$TARGET"
else
  mix_root="$(find "$TARGET" -maxdepth 4 -name mix.exs -not -path '*/deps/*' -not -path '*/_build/*' 2>/dev/null \
    | awk '{ print gsub(/\//,"/"), $0 }' | sort -n | head -n1 | cut -d' ' -f2- || true)"
  [ -n "$mix_root" ] && mix_root="$(dirname "$mix_root")"
fi

# Count loose Elixir sources in the target (excludes deps/_build).
ex_count="$(find "$TARGET" \( -name '*.ex' -o -name '*.exs' \) \
  -not -path '*/deps/*' -not -path '*/_build/*' 2>/dev/null | wc -l | tr -d ' ')"

if [ -z "$mix_root" ] && [ "$ex_count" = "0" ]; then
  echo "verify: no mix.exs and no .ex/.exs files under '$TARGET' — nothing to check. SKIP."
  exit 0
fi

status=0

if [ -n "$mix_root" ]; then
  echo "verify: mix project root -> $mix_root"

  echo "verify: mix format --check-formatted"
  if ! ( cd "$mix_root" && mix format --check-formatted ); then
    echo "verify: FAIL — files are not formatted (run: mix format)"
    status=1
  fi

  echo "verify: mix compile --warnings-as-errors"
  if ! ( cd "$mix_root" && mix compile --warnings-as-errors ); then
    echo "verify: FAIL — compile produced warnings or errors"
    status=1
  fi
else
  # Loose .ex/.exs without a mix project: format check only (compile needs a project).
  echo "verify: no mix.exs found; checking formatting of $ex_count loose Elixir file(s)"
  echo "verify: mix format --check-formatted"
  if ! ( cd "$TARGET" && mix format --check-formatted ); then
    echo "verify: FAIL — files are not formatted (run: mix format)"
    status=1
  fi
fi

if [ "$status" -eq 0 ]; then
  echo "verify: OK"
fi
exit "$status"
