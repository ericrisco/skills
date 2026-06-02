#!/usr/bin/env bash
# verify.sh — structural check for a community moderation-config artifact.
# Read-only. Validates required keys, a non-empty north-star, all 3 moderation
# layers, and at least one ritual with a cadence. Exits 0 on a clean/empty target.
#
# Usage: scripts/verify.sh [path/to/moderation-config.yaml|.json]
# If no path is given, scans the working tree for moderation-config.{yaml,yml,json}.
# No target found => nothing to check => exit 0 (no false failure).

set -euo pipefail

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "OK: $1"; }

# --- resolve targets -------------------------------------------------------
targets=()
if [ "$#" -ge 1 ]; then
  for arg in "$@"; do
    [ -f "$arg" ] || fail "no such file: $arg"
    targets+=("$arg")
  done
else
  while IFS= read -r f; do targets+=("$f"); done < <(
    find . -type f \( -name 'moderation-config.yaml' -o -name 'moderation-config.yml' -o -name 'moderation-config.json' \) 2>/dev/null
  )
fi

if [ "${#targets[@]}" -eq 0 ]; then
  echo "OK: no moderation-config artifact found — nothing to verify."
  exit 0
fi

# --- per-file checks -------------------------------------------------------
check_file() {
  local file="$1"
  local body
  body="$(cat "$file")"

  # Parse-only sanity for JSON; YAML is checked line-wise via grep below.
  case "$file" in
    *.json)
      if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$file" \
          || fail "$file is not valid JSON"
      fi
      ;;
  esac

  # required top-level / nested keys (token presence is enough for the structural gate)
  local required=(platform purpose north_star_metric onboarding_path moderation rituals)
  local k
  for k in "${required[@]}"; do
    grep -Eq "(\"$k\"[[:space:]]*:|^[[:space:]]*$k[[:space:]]*:)" <<<"$body" \
      || fail "$file is missing required key: $k"
  done

  # north_star_metric must be non-empty (the no-purpose defect)
  local nsm
  nsm="$(grep -E "(\"north_star_metric\"|north_star_metric)[[:space:]]*:" <<<"$body" \
        | head -n1 | sed -E 's/.*north_star_metric"?[[:space:]]*:[[:space:]]*//' \
        | tr -d '",' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -n "$nsm" ] || fail "$file has an empty north_star_metric"

  # moderation must declare all three layers
  local layer
  for layer in native bot human; do
    grep -Eq "(\"$layer\"[[:space:]]*:|^[[:space:]]*$layer[[:space:]]*:)" <<<"$body" \
      || fail "$file moderation does not declare the '$layer' layer"
  done

  # at least one ritual with a non-empty cadence
  grep -Eq "(\"cadence\"|cadence)[[:space:]]*:[[:space:]]*[\"']?[[:alnum:]]" <<<"$body" \
    || fail "$file has no ritual with a non-empty cadence"

  ok "$file passed all structural checks."
}

for t in "${targets[@]}"; do
  check_file "$t"
done

echo "OK: all ${#targets[@]} artifact(s) verified."
exit 0
