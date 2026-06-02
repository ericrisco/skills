#!/usr/bin/env bash
# verify.sh — offline structural lint for DigitalOcean App Platform app specs.
#
# Read-only. Finds candidate app specs and checks they are parseable YAML with the
# required App Platform top-level keys. Inline-secret literals are WARNINGS, not failures.
# Exits 0 on a clean/empty target (no spec found is fine — nothing to lint).
# Exits non-zero only when a found spec is unparseable YAML or missing required keys.
#
# Usage:
#   scripts/verify.sh [path-to-spec-or-dir]   # default: current directory
set -euo pipefail

target="${1:-.}"
fail=0
checked=0

# --- find candidate specs ----------------------------------------------------
candidates=()
if [ -f "$target" ]; then
  candidates+=("$target")
elif [ -d "$target" ]; then
  while IFS= read -r f; do candidates+=("$f"); done < <(
    {
      [ -f "$target/.do/app.yaml" ] && printf '%s\n' "$target/.do/app.yaml"
      find "$target" -type f \
        \( -iname '*app*spec*.yml' -o -iname '*app*spec*.yaml' -o -path '*/.do/app.yaml' -o -path '*/.do/app.yml' \) \
        2>/dev/null
    } | sort -u
  )
else
  echo "verify: target not found: $target" >&2
  exit 0   # nothing to lint -> clean
fi

if [ "${#candidates[@]}" -eq 0 ]; then
  echo "verify: no App Platform app spec found under '$target' — nothing to lint."
  exit 0
fi

# --- pick a YAML parser -------------------------------------------------------
yaml_ok() {  # $1=file -> 0 if parseable
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$1" <<'PY' 2>/dev/null
import sys, yaml
yaml.safe_load(open(sys.argv[1]))
PY
    return $?
  elif command -v yq >/dev/null 2>&1; then
    yq eval '.' "$1" >/dev/null 2>&1
    return $?
  fi
  return 2  # no parser
}

have_key() {  # $1=file $2=key -> 0 if top-level key present (best-effort grep)
  grep -Eq "^[[:space:]]*${2}:" "$1"
}

parser_warned=0

for spec in "${candidates[@]}"; do
  checked=$((checked + 1))
  echo "verify: checking $spec"

  yaml_ok "$spec"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    if [ "$parser_warned" -eq 0 ]; then
      echo "  WARN: no python3/yq found — skipping YAML parse, doing key + secret grep only"
      parser_warned=1
    fi
  elif [ "$rc" -ne 0 ]; then
    echo "  FAIL: not parseable YAML"
    fail=1
    continue
  fi

  # required: name
  if ! have_key "$spec" name; then
    echo "  FAIL: missing required top-level key 'name'"
    fail=1
  fi

  # required: at least one component type
  if ! grep -Eq "^[[:space:]]*(services|static_sites|workers|jobs|functions):" "$spec"; then
    echo "  FAIL: needs at least one of services|static_sites|workers|jobs|functions"
    fail=1
  fi

  # warn: inline secret literals not behind a SECRET-typed env
  if grep -Eqi 'dop_v1_[a-f0-9]|(password|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9/_+-]{12,}' "$spec"; then
    echo "  WARN: a token/secret-looking literal appears inline — use 'type: SECRET' or \${...} injection"
  fi
done

# --- optional doctl hint ------------------------------------------------------
if command -v doctl >/dev/null 2>&1; then
  echo "verify: doctl detected — for an authoritative check run: doctl apps spec validate <spec>"
fi

echo "verify: checked $checked spec(s)."
exit "$fail"
