#!/usr/bin/env bash
#
# verify.sh — advisory quality scan for a Shopify theme or app directory.
#
# Usage:
#   ./scripts/verify.sh [TARGET_PATH]
#
# Read-only by default. Greps a theme/app dir for high-signal Shopify foot-guns and prints
# WARN / FAIL advisories. WARN = a smell to review; FAIL = a deprecated/removed mechanism that
# will break. Exits non-zero only when a FAIL-level issue is found in a real Shopify dir.
# On an empty or non-Shopify target it SKIPs and exits 0 (no false failure).
#
# Compatible with stock macOS bash 3.2: no mapfile, no associative arrays, find-based globbing.

set -euo pipefail

TARGET="${1:-.}"

if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi
warn() { printf '%sWARN%s %s\n' "$YELLOW" "$RESET" "$*"; }
ok()   { printf '%s%s%s\n' "$GREEN" "$*" "$RESET"; }
fail() { printf '%sFAIL%s %s\n' "$RED" "$RESET" "$*"; }

WARNS=0; FAILS=0

# A Shopify dir has either theme structure (sections/ or templates/*.json or *.liquid) or an
# app/theme config TOML. Neither → nothing to verify, SKIP (exit 0).
shopify_present() {
  if [ -f "$TARGET/shopify.app.toml" ] || [ -f "$TARGET/shopify.theme.toml" ]; then return 0; fi
  if [ -n "$(find "$TARGET" -type f -name '*.liquid' -print -quit 2>/dev/null)" ]; then return 0; fi
  if [ -d "$TARGET/sections" ] || [ -d "$TARGET/extensions" ]; then return 0; fi
  return 1
}

if ! shopify_present; then
  warn "no Shopify theme/app found under '${TARGET}' (no *.liquid, no shopify.*.toml, no sections/ or extensions/)"
  ok "verify.sh: ok (nothing to verify)"
  exit 0
fi

# grep_count <pattern> <find-name-filter...> — count matching lines across files, 0 if none.
# Uses find + grep so it stays bash-3.2 / BSD-grep safe and never errors on no match.
scan() { # scan <label> <level:warn|fail> <regex> <file-glob>
  local label="$1" level="$2" regex="$3" glob="$4"
  local hits
  hits=$(find "$TARGET" -type f -name "$glob" -print0 2>/dev/null \
    | xargs -0 grep -nE "$regex" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    if [ "$level" = "fail" ]; then
      fail "$label"; FAILS=$((FAILS + 1))
    else
      warn "$label"; WARNS=$((WARNS + 1))
    fi
    printf '%s\n' "$hits" | sed 's/^/    /' | head -10
  fi
}

# 1. Deprecated {% include %} in Liquid (prefer {% render %}).
scan "deprecated {% include %} — use {% render %} (scoped, cacheable)" warn \
  '\{%-?[[:space:]]*include[[:space:]]' '*.liquid'

# 2. Raw money output without a | money filter (heuristic: .price echoed without 'money').
scan "price output without | money — renders raw cents/locale wrong" warn \
  '\{\{[^}]*\.price[^}|]*\}\}' '*.liquid'

# 3. checkout.liquid present — deprecated; automatic upgrades roll out starting 2026-01.
if find "$TARGET" -type f -name 'checkout.liquid' -print -quit 2>/dev/null | grep -q . ; then
  fail "checkout.liquid present — deprecated/removed; migrate to checkout extensibility"
  FAILS=$((FAILS + 1))
fi

# 4. ScriptTag / additional-script usage — deprecated checkout/tracking mechanism.
scan "ScriptTag / additional-scripts usage — deprecated; use Web Pixels / UI extensions" warn \
  'ScriptTag|additional_scripts|additional scripts' '*'

# 5. REST Admin API calls in app source — legacy; prefer GraphQL.
scan "REST Admin API call (/admin/api/.../.json) — legacy; use admin.graphql()" warn \
  '/admin/api/[0-9]{4}-[0-9]{2}/[^"'"'"' ]+\.json' '*'

# 6. apiVersion pinned and within the supported window (2025-10 .. 2026-04 at time of writing;
#    2025-07 is sunsetting ~2026-07-16, so flag it). Unpinned or an older literal → warn.
APIV=$(find "$TARGET" -type f \( -name '*.js' -o -name '*.ts' -o -name '*.toml' \) -print0 2>/dev/null \
  | xargs -0 grep -hoE 'apiVersion[^0-9]*(2[0-9]{3}-[0-9]{2})' 2>/dev/null \
  | grep -oE '2[0-9]{3}-[0-9]{2}' | head -1 || true)
if [ -f "$TARGET/shopify.app.toml" ] || find "$TARGET" -type f -name '*.server.*' -print -quit 2>/dev/null | grep -q .; then
  if [ -z "$APIV" ]; then
    warn "no pinned apiVersion found in app config/server — pin a supported version (e.g. 2026-04)"
    WARNS=$((WARNS + 1))
  else
    case "$APIV" in
      2026-04|2026-01|2025-10) : ;;
      2025-07) warn "apiVersion '2025-07' is sunsetting (accessible only until 2026-07-16) — bump to a current version"; WARNS=$((WARNS + 1)) ;;
      *) warn "apiVersion '$APIV' is outside the supported window (2025-10..2026-04) — bump it"; WARNS=$((WARNS + 1)) ;;
    esac
  fi
fi

# 7. Run Theme Check if a config and the CLI are both present (still read-only).
if [ -f "$TARGET/.theme-check.yml" ] || [ -f "$TARGET/.theme-check.yaml" ]; then
  if command -v shopify >/dev/null 2>&1; then
    printf '==> shopify theme check\n'
    if ! shopify theme check "$TARGET"; then
      warn "theme check reported issues"; WARNS=$((WARNS + 1))
    fi
  else
    warn ".theme-check.yml present but shopify CLI not installed — skipping theme check"
  fi
fi

printf '\n%d warn, %d fail\n' "$WARNS" "$FAILS"
if [ "$FAILS" -gt 0 ]; then
  fail "verify.sh: deprecated/removed mechanisms detected"
  exit 1
fi
ok "verify.sh: ok"
exit 0
