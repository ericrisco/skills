#!/usr/bin/env bash
#
# verify.sh — static lint for Together AI / Fireworks AI inference snippets.
#
# WHAT IT DOES (read-only; never edits, never hits the network, no API key needed)
#   Greps target .py/.ts/.js/.tsx/.jsx files that mention Together or Fireworks and
#   flags the classic mistakes:
#     1. A together/fireworks API key (or its base_url) paired with api.openai.com
#        -> FAIL (the key only authenticates against its own host).
#     2. A bare model name (no namespace) when a Together/Fireworks base_url is
#        present -> FAIL. Together needs "<vendor>/<model>"; Fireworks needs
#        "accounts/fireworks/models/<name>".
#     3. A hardcoded API-key string literal (api_key="sk-..."/literal) where an
#        env var belongs -> FAIL (committed key = leaked key).
#     4. Wrong/legacy base_url for the provider in use -> WARN (verify the exact
#        host: https://api.together.ai/v1 or https://api.fireworks.ai/inference/v1).
#
# EXIT CODES
#   0  clean, or no relevant file to inspect (empty/clean target is NOT a failure)
#   1  at least one [fail] finding
#   2  bad usage
#
# HOW TO RUN (point it at YOUR code, not the skills repo)
#   ./verify.sh app.py                 # lint one file
#   ./verify.sh --path src/            # lint every .py/.ts/.js under a dir
#   ./verify.sh                        # scan ./ ; if nothing matches, skip + exit 0
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

# --- arg parse --------------------------------------------------------------
SCAN_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --path)    SCAN_PATH="${2:?--path needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)        printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
    *)         SCAN_PATH="$1"; shift ;;
  esac
done
[ -z "$SCAN_PATH" ] && SCAN_PATH="."

if [ ! -e "$SCAN_PATH" ]; then
  printf '%sPath not found: %s%s\n' "$RED" "$SCAN_PATH" "$NC"; exit 2
fi

# --- collect candidate source files ----------------------------------------
if [ -f "$SCAN_PATH" ]; then
  FILES="$SCAN_PATH"
else
  FILES="$(find "$SCAN_PATH" -type f \
    \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) \
    2>/dev/null || true)"
fi

# Keep only files that actually reference these providers (so we never false-fail
# on unrelated code).
RELEVANT=""
if [ -n "$FILES" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if grep -iEq 'together\.ai|fireworks\.ai|TOGETHER_API_KEY|FIREWORKS_API_KEY|accounts/fireworks/models' "$f" 2>/dev/null; then
      RELEVANT="$RELEVANT$f
"
    fi
  done <<EOF
$FILES
EOF
fi

# Empty / clean target is NOT a failure.
if [ -z "$RELEVANT" ]; then
  skip "no Together/Fireworks inference code found under '$SCAN_PATH' — nothing to lint"
  exit 0
fi

n_files="$(printf '%s' "$RELEVANT" | grep -c . || true)"
printf 'Linting %s Together/Fireworks file(s) under: %s\n\n' "$n_files" "$SCAN_PATH"

fail_total=0

while IFS= read -r f; do
  [ -z "$f" ] && continue
  printf '%s— %s%s\n' "$YELLOW" "$f" "$NC"

  uses_together=0; uses_fireworks=0
  grep -iEq 'together\.ai|TOGETHER_API_KEY' "$f" 2>/dev/null && uses_together=1
  grep -iEq 'fireworks\.ai|FIREWORKS_API_KEY|accounts/fireworks/models' "$f" 2>/dev/null && uses_fireworks=1

  # 1. provider key/url paired with the OpenAI host -> FAIL
  if grep -iEq 'api\.openai\.com' "$f" 2>/dev/null; then
    hits="$(grep -inE 'api\.openai\.com' "$f" 2>/dev/null || true)"
    fail "  api.openai.com used in a Together/Fireworks file — a provider key only works on its own host:"
    printf '%s\n' "$hits" | head -n 5 | sed 's/^/        /'
    fail_total=$((fail_total + 1))
  else
    ok "  no api.openai.com host mixed in"
  fi

  # 4. base_url present and correct -> WARN if a provider is used but its exact URL is absent
  if [ "$uses_together" -eq 1 ]; then
    if grep -Eq 'https://api\.together\.ai/v1' "$f" 2>/dev/null; then
      ok "  Together base_url present and correct"
    elif grep -iEq 'base_?url|baseURL' "$f" 2>/dev/null; then
      warn "  Together used but exact base_url not found — expect https://api.together.ai/v1"
    fi
  fi
  if [ "$uses_fireworks" -eq 1 ]; then
    if grep -Eq 'https://api\.fireworks\.ai/inference/v1' "$f" 2>/dev/null; then
      ok "  Fireworks base_url present and correct"
    elif grep -iEq 'base_?url|baseURL' "$f" 2>/dev/null; then
      warn "  Fireworks used but exact base_url not found — expect https://api.fireworks.ai/inference/v1"
    fi
  fi

  # 2. bare model name (no namespace slash) -> FAIL
  #    Capture model="..."/model: "..." values; a valid id contains a '/'.
  bare="$(grep -inE 'model[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']+["'\'']' "$f" 2>/dev/null \
            | grep -vE 'model[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']*/' \
            | grep -viE 'os\.environ|process\.env|getenv|LLM_MODEL' || true)"
  if [ -n "$bare" ]; then
    fail "  bare model id (missing namespace '/') — Together needs <vendor>/<model>, Fireworks needs accounts/fireworks/models/<name>:"
    printf '%s\n' "$bare" | head -n 5 | sed 's/^/        /'
    fail_total=$((fail_total + 1))
  else
    ok "  model ids are namespaced (or env-driven)"
  fi

  # 3. hardcoded API key literal -> FAIL
  hard="$(grep -inE 'api_?key[[:space:]]*[:=][[:space:]]*["'\''](sk-|fw_|[A-Za-z0-9]{16,})' "$f" 2>/dev/null \
            | grep -viE 'os\.environ|process\.env|getenv|(^|[[:space:]])//|(^|[[:space:]])#' || true)"
  if [ -n "$hard" ]; then
    fail "  hardcoded API key literal — read it from an env var instead:"
    printf '%s\n' "$hard" | head -n 5 | sed 's/^/        /'
    fail_total=$((fail_total + 1))
  else
    ok "  API key is read from an env var"
  fi

  printf '\n'
done <<EOF
$RELEVANT
EOF

cat <<'NOTE'
Note: [fail] = a routing/security bug that breaks the call or leaks a secret (fix it).
      [warn] = the exact base_url string wasn't found (confirm the host is right).
NOTE

if [ "$fail_total" -gt 0 ]; then exit 1; fi
exit 0
