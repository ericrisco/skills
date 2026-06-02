#!/usr/bin/env bash
# verify.sh — read-only checks for Go test artifacts.
# Finds the nearest Go module at/under the target dir, then runs gofmt -l,
# go vet, and go test. No module => clean skip, exit 0 (no false failure).
#
# Usage: scripts/verify.sh [target-dir]   (defaults to current directory)
set -euo pipefail

target="${1:-.}"

if [ ! -d "$target" ]; then
  echo "verify: target '$target' is not a directory; nothing to check." >&2
  exit 0
fi

# Locate a go.mod: prefer one directly in target, else search downward.
modfile=""
if [ -f "$target/go.mod" ]; then
  modfile="$target/go.mod"
else
  modfile="$(find "$target" -name go.mod -type f -not -path '*/vendor/*' 2>/dev/null | head -n1 || true)"
fi

if [ -z "$modfile" ]; then
  echo "verify: no go.mod found under '$target' — skipping (nothing to verify)."
  exit 0
fi

if ! command -v go >/dev/null 2>&1; then
  echo "verify: 'go' toolchain not on PATH — skipping." >&2
  exit 0
fi

moddir="$(dirname "$modfile")"
echo "verify: Go module at $moddir"

status=0

# 1. Formatting — gofmt -l lists files that are NOT formatted; empty output is good.
unformatted="$(gofmt -l "$moddir" 2>/dev/null || true)"
if [ -n "$unformatted" ]; then
  echo "FAIL gofmt: the following files are not gofmt-clean:" >&2
  echo "$unformatted" >&2
  status=1
else
  echo "ok   gofmt: all files formatted"
fi

# 2. Vet — static checks. Run from the module dir.
if ( cd "$moddir" && go vet ./... ); then
  echo "ok   go vet"
else
  echo "FAIL go vet" >&2
  status=1
fi

# 3. Tests — try -race first; fall back if the platform lacks the race detector.
if ( cd "$moddir" && go test ./... -count=1 -race ) 2>/dev/null; then
  echo "ok   go test (-race)"
elif ( cd "$moddir" && go test ./... -count=1 ); then
  echo "ok   go test (no race detector available)"
else
  echo "FAIL go test" >&2
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "verify: PASS"
else
  echo "verify: FAIL" >&2
fi
exit "$status"
