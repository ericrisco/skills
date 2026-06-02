#!/usr/bin/env bash
# verify.sh — Expo / EAS config gate.
#
# Run from the root of an Expo project:
#   bash scripts/verify.sh
#
# Checks the EMITTED CONFIG ARTIFACTS, not your process:
#   1. eas.json parses as JSON and declares a build.production profile.
#   2. If EAS Update / expo-updates is in use, a runtimeVersion policy is declared
#      (a hardcoded literal string is WARNED, not failed).
#   3. No keystore / .p12 / .mobileprovision is tracked, and no obvious plaintext
#      secret sits in app.config / app.json.
#   4. Informational: flag dead newArchEnabled config on SDK >= 55 (Legacy
#      Architecture was removed; the flag no longer exists in app.json).
#
# Read-only. Exits 0 on a clean OR empty/non-Expo target (no false failure).
# Hard violations exit 1; soft issues print warnings only.
# Portable to stock macOS bash 3.2.
set -eu

YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
RESET=$'\033[0m'

errors=0

warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$RESET" "$1"; }
info() { printf '==> %s\n' "$1"; }
fail() { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$1"; errors=$((errors + 1)); }
have() { command -v "$1" >/dev/null 2>&1; }

# JSON validity helper: prefer node, fall back to python3, else skip the parse.
json_valid() {
  if have node; then
    node -e "JSON.parse(require('fs').readFileSync('$1','utf8'))" >/dev/null 2>&1
  elif have python3; then
    python3 -c "import json,sys; json.load(open('$1'))" >/dev/null 2>&1
  else
    return 2  # cannot verify
  fi
}

# Guard: only meaningful inside an Expo project. Empty/unrelated dir -> clean exit.
app_config=""
for f in app.config.ts app.config.js app.config.mjs app.config.cjs app.json app.config.json; do
  [ -f "$f" ] && app_config="$f" && break
done

if [ -z "$app_config" ] && [ ! -f eas.json ]; then
  warn "no app.config/app.json/eas.json in $PWD — not an Expo project; nothing to check"
  exit 0
fi

# 1. eas.json — valid JSON + production profile.
if [ -f eas.json ]; then
  info "eas.json"
  rc=0; json_valid eas.json || rc=$?
  if [ "$rc" -eq 1 ]; then
    fail "eas.json is not valid JSON"
  elif [ "$rc" -eq 2 ]; then
    warn "no node/python3 on PATH — skipping eas.json JSON parse"
  fi
  # production profile (tolerant grep; works even without a JSON parser)
  if ! grep -Eq '"production"[[:space:]]*:' eas.json; then
    fail "eas.json has no build.production profile — add one before releasing"
  fi
else
  warn "no eas.json — run 'eas build:configure' to create build profiles"
fi

# 2. runtimeVersion policy, only if EAS Update / expo-updates is in use.
uses_updates=false
if [ -f package.json ] && grep -q 'expo-updates' package.json; then uses_updates=true; fi
if [ -n "$app_config" ] && grep -q 'expo-updates\|EAS Update\|"updates"' "$app_config"; then uses_updates=true; fi

if [ "$uses_updates" = true ]; then
  info "runtimeVersion policy (EAS Update detected)"
  if [ -n "$app_config" ]; then
    if grep -q 'runtimeVersion' "$app_config"; then
      # A policy object is good; a bare string literal is a footgun -> warn.
      if grep -Eq 'runtimeVersion["'\'' ]*:[^{]*"[0-9A-Za-z._-]+"' "$app_config"; then
        warn "runtimeVersion looks like a hardcoded literal in $app_config — prefer { policy: 'fingerprint' } so it tracks the native runtime"
      fi
    else
      fail "EAS Update is in use but no runtimeVersion is declared in $app_config — add { policy: 'fingerprint' }"
    fi
  else
    warn "EAS Update detected but no app.config to inspect for runtimeVersion"
  fi
fi

# 3. Tracked credentials / secrets.
info "credentials & secrets"
secret_hits=$(find . \
  -path ./node_modules -prune -o \
  -type f \( -name '*.jks' -o -name '*.keystore' -o -name '*.p12' -o -name '*.mobileprovision' \) -print 2>/dev/null)
if [ -n "$secret_hits" ]; then
  fail "signing material is present in the tree (let EAS manage credentials, gitignore these):"
  printf '%s\n' "$secret_hits" | sed 's/^/    /'
fi

# Plaintext secrets in app config (heuristic).
if [ -n "$app_config" ]; then
  if grep -Eiq '(api[_-]?key|secret|password|access[_-]?token|private[_-]?key)["'\'' ]*[:=]["'\'' ]*[A-Za-z0-9_\-]{12,}' "$app_config"; then
    fail "possible plaintext secret in $app_config — app config ships in the public bundle; use EAS env vars or a backend"
  fi
fi

# 4. New Architecture state (informational). Since SDK 55 the Legacy Architecture
#    is gone and the New Architecture is always on; the newArchEnabled flag was
#    removed from app.json. On SDK >= 55 any lingering flag is dead config.
if [ -f package.json ]; then
  sdk_major=$(grep -Eo '"expo"[[:space:]]*:[[:space:]]*"[~^>=<[:space:]]*[0-9]+' package.json 2>/dev/null \
    | grep -Eo '[0-9]+$' | head -n1 || true)
  if [ -n "${sdk_major:-}" ] && [ "$sdk_major" -ge 55 ] 2>/dev/null; then
    if grep -Eq 'newArchEnabled' "${app_config:-/dev/null}" 2>/dev/null; then
      warn "newArchEnabled is set in $app_config but was removed in SDK 55 — the New Architecture is always on now; delete the dead flag"
    else
      info "SDK $sdk_major detected — Legacy Architecture removed; New Architecture is always enabled"
    fi
  elif [ -n "${sdk_major:-}" ] && [ "$sdk_major" -eq 54 ] 2>/dev/null; then
    info "SDK 54 detected — the last Legacy-Architecture release; SDK 55+ removed it, so plan your upgrade onto New Arch"
  fi
fi

# Summary.
if [ "$errors" -gt 0 ]; then
  printf '%s%d hard violation(s).%s\n' "$RED" "$errors" "$RESET"
  exit 1
fi
printf '%sall checks passed.%s\n' "$GREEN" "$RESET"
