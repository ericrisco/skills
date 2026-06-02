#!/usr/bin/env bash
# verify.sh — read-only gates for a Phoenix / Elixir target.
#
# When run inside a mix project it runs the standard project gates:
#   - mix format --check-formatted        (style)
#   - mix compile --warnings-as-errors    (warning-free compile)
#   - mix test                            (only if a test/ dir exists)
#
# It never fails a toolchain-free or empty target: it exits 0 with a skip note
# when mix is absent or there is no mix.exs to check. Read-only: no writes, no
# network and no database are required to pass the compile/format gates.
#
# Usage: bash scripts/verify.sh [TARGET_DIR]   (default: current directory)

set -euo pipefail

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "verify: target '$TARGET' is not a directory — nothing to check. SKIP."
  exit 0
fi

# Toolchain gate: no mix on PATH -> skip cleanly (never fail without a toolchain).
if ! command -v mix >/dev/null 2>&1; then
  echo "verify: 'mix' not found on PATH — Elixir/Phoenix toolchain not installed. SKIP."
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

if [ -z "$mix_root" ]; then
  echo "verify: no mix.exs under '$TARGET' — not a mix project, nothing to check. SKIP."
  exit 0
fi

echo "verify: mix project root -> $mix_root"
status=0

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

if [ -d "$mix_root/test" ]; then
  echo "verify: mix test"
  if ! ( cd "$mix_root" && mix test ); then
    echo "verify: FAIL — test suite did not pass"
    status=1
  fi
else
  echo "verify: no test/ directory — skipping mix test."
fi

if [ "$status" -eq 0 ]; then
  echo "verify: OK"
fi
exit "$status"
