#!/usr/bin/env bash
# verify.sh — read-only check of an API-design artifact (OpenAPI 3.1 spec).
#
# The api-design skill emits its contract as an OpenAPI document. This script
# finds candidate spec files under a target dir, validates they parse and carry
# the required OpenAPI keys, and emits non-fatal warnings for the design
# anti-patterns it can detect statically. It never writes anything.
#
# Usage:   verify.sh [TARGET_DIR]   (default: current directory)
# Exit:    0  no spec found (soft-pass) OR all found specs valid
#          1  a spec file is present but invalid/unparseable
#
# Soft-pass on a clean/empty target: a design may live only in a doc.

set -uo pipefail

TARGET="${1:-.}"
fail=0

note()  { printf '  - %s\n' "$1"; }
warn()  { printf '  ! %s\n' "$1"; }

if [ ! -d "$TARGET" ]; then
  echo "verify(api-design): target '$TARGET' is not a directory — nothing to check."
  exit 0
fi

# Collect candidate OpenAPI files (read-only). Tolerate no matches.
# Portable to bash 3.2 (macOS default): no mapfile; newline-delimited list.
specs=()
while IFS= read -r f; do
  [ -n "$f" ] && specs+=("$f")
done < <(
  find "$TARGET" \
    \( -name 'openapi.yaml' -o -name 'openapi.yml' -o -name 'openapi.json' \
       -o -name '*.openapi.yaml' -o -name '*.openapi.yml' -o -name '*.openapi.json' \) \
    -type f 2>/dev/null
)

if [ "${#specs[@]}" -eq 0 ]; then
  echo "verify(api-design): no OpenAPI spec found under '$TARGET' — soft-pass (design may be in-doc only)."
  exit 0
fi

# Choose a linter if available; else fall back to a structural check.
LINTER=""
if command -v redocly >/dev/null 2>&1; then
  LINTER="redocly"
elif command -v spectral >/dev/null 2>&1; then
  LINTER="spectral"
fi

# Structural fallback: parse + required keys, using whatever is on PATH.
parse_check() {
  local f="$1"
  case "$f" in
    *.json)
      if command -v jq >/dev/null 2>&1; then
        jq -e 'has("openapi") and has("info") and has("paths")' "$f" >/dev/null 2>&1
        return $?
      fi
      ;;
    *.yaml|*.yml)
      if command -v python3 >/dev/null 2>&1; then
        python3 - "$f" <<'PY' >/dev/null 2>&1
import sys
try:
    import yaml
except Exception:
    sys.exit(2)  # no yaml lib -> can't check, treat as inconclusive
with open(sys.argv[1]) as fh:
    d = yaml.safe_load(fh)
sys.exit(0 if isinstance(d, dict) and all(k in d for k in ("openapi", "info", "paths")) else 1)
PY
        local rc=$?
        [ "$rc" -eq 2 ] && return 3   # inconclusive
        return $rc
      fi
      ;;
  esac
  return 3  # inconclusive: no suitable parser on PATH
}

# Static anti-pattern warnings (grep-based, never fatal).
antipattern_scan() {
  local f="$1"
  if grep -Eiq '"?/[A-Za-z0-9_]*(get|create|update|delete|fetch|list)[A-Za-z0-9_]*"?[[:space:]]*:' "$f"; then
    warn "verb-like path segment(s) detected — paths should be nouns; HTTP methods are the verbs."
  fi
  if grep -Eq '(/[A-Za-z0-9_/{}]*)+[[:space:]]*:' "$f" && ! grep -Eiq 'cursor|limit|offset|first|after|page' "$f"; then
    warn "no pagination params (cursor/limit/offset) found — list endpoints should paginate."
  fi
  if ! grep -Eiq 'problem\+json|"4[0-9][0-9]"|default[[:space:]]*:' "$f"; then
    warn "no 4xx / default error responses found — every operation should define an error response (RFC 9457)."
  fi
}

echo "verify(api-design): checking ${#specs[@]} spec file(s) under '$TARGET'"
[ -n "$LINTER" ] && echo "  using linter: $LINTER"

for f in "${specs[@]}"; do
  echo "* $f"
  ok=1
  if [ -n "$LINTER" ]; then
    if [ "$LINTER" = "redocly" ]; then
      redocly lint "$f" >/dev/null 2>&1 || ok=0
    else
      spectral lint "$f" >/dev/null 2>&1 || ok=0
    fi
    if [ "$ok" -eq 0 ]; then
      # Linter unhappy: confirm with structural parse before failing hard.
      parse_check "$f"; pc=$?
      if [ "$pc" -eq 0 ]; then
        warn "$LINTER reported issues but the spec parses and has required keys — review lint output."
      else
        note "spec is invalid per $LINTER."
        fail=1
        continue
      fi
    fi
  else
    parse_check "$f"; pc=$?
    case "$pc" in
      0) : ;;  # valid
      3) warn "no parser on PATH (jq/python3+pyyaml) — skipped structural validation." ;;
      *) note "spec does not parse or is missing required keys (openapi/info/paths)."; fail=1; continue ;;
    esac
  fi
  antipattern_scan "$f"
done

if [ "$fail" -ne 0 ]; then
  echo "verify(api-design): FAIL — one or more specs are invalid."
  exit 1
fi

echo "verify(api-design): OK (warnings, if any, are advisory)."
exit 0
