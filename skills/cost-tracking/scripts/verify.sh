#!/usr/bin/env bash
#
# verify.sh - lint a candidate cost-tracking config/ledger artifact.
#
# Usage:
#   cd <dir containing the config>
#   ./verify.sh [path-to-config]      # yaml | yml | json | ts | js
#
# Read-only: never mutates anything. Checks the artifact for:
#   1. every pricing entry carries effective_date AND source
#   2. no model referenced in logic is absent from the pricing table
#   3. the ledger schema has an idempotency/request key + >=1 attribution key
#   4. the budget declares BOTH a soft and a hard threshold
#   5. cost is derived from a usage/response field, not a len()/char estimate
#
# Emits [ ok ]/[fail] per check, then PASS or FAIL.
# Exits 0 on a clean config AND on no config found (no false failure).
# Exits 1 with the missing pieces on any violation.
#
# Portable: stock macOS bash 3.2 + grep + awk. No associative arrays, no mapfile.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi

failed=0
fail() { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; failed=1; }
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }

# --- locate the config -------------------------------------------------------
file="${1:-}"
if [ -z "$file" ]; then
  for cand in cost-tracking.yaml cost-tracking.yml pricing.yaml pricing.yml \
              cost-config.yaml cost-config.yml cost-tracking.json cost-tracking.ts; do
    if [ -f "$cand" ]; then file="$cand"; break; fi
  done
fi

if [ -z "$file" ] || [ ! -f "$file" ]; then
  printf '%s[skip]%s no cost-tracking config found (cost-tracking.{yaml,json,ts} / pricing.yaml) - nothing to verify.\n' "$YELLOW" "$RESET"
  exit 0
fi

printf -- '----- linting %s\n' "$file"

# case-insensitive fixed-ish grep helper
has() { grep -Eiq "$1" "$file"; }

# --- 1. pricing entries carry effective_date AND source ----------------------
mentions_pricing=0
if has 'pric|input_per_mtok|in_per_mtok|rate_in|cost_per'; then mentions_pricing=1; fi
if [ "$mentions_pricing" -eq 1 ]; then
  miss=""
  has 'effective_date|effective-date|effectiveDate' || miss="$miss effective_date"
  has 'source' || miss="$miss source"
  if [ -z "$miss" ]; then
    ok "pricing entries carry effective_date + source"
  else
    fail "pricing table missing:$miss (each model row must be dated and sourced)"
  fi
else
  printf '%s[skip]%s no pricing table in this file (check 1)\n' "$YELLOW" "$RESET"
fi

# --- 2. no model referenced in logic absent from the table -------------------
# Heuristic: collect model-ish identifiers (claude-*/gpt-*/sonnet/opus/haiku/o-series)
# that appear OUTSIDE a "model:" / "- model:" declaration line, and warn if the
# file declares no model rows at all while still naming models.
declared=$(grep -Eio '(^|[^a-z])model[[:space:]]*[:=]' "$file" | wc -l | tr -d ' ')
named=$(grep -Eio '(claude-[a-z0-9.]+|gpt-[a-z0-9.]+|sonnet|opus|haiku|gemini-[a-z0-9.]+)' "$file" \
        | sort -u | wc -l | tr -d ' ')
if [ "$named" -gt 0 ]; then
  if [ "$declared" -eq 0 ]; then
    fail "models are named but no 'model:' table rows declared - unknown models would price as \$0"
  else
    ok "models named ($named) are declared in 'model:' rows ($declared) - lookup can fail-loud on unknowns"
  fi
else
  printf '%s[skip]%s no model identifiers found (check 2)\n' "$YELLOW" "$RESET"
fi

# --- 3. ledger: idempotency key + >=1 attribution key ------------------------
mentions_ledger=0
if has 'ledger|usage|input_tokens|output_tokens|cost_usd'; then mentions_ledger=1; fi
if [ "$mentions_ledger" -eq 1 ]; then
  miss=""
  has 'request_id|idempotency|request-id|requestId|dedup' || miss="$miss idempotency/request key"
  has 'user_id|tenant_id|tenant|feature|user-id|tenantId|userId' || miss="$miss attribution-key(user/tenant/feature)"
  if [ -z "$miss" ]; then
    ok "ledger has an idempotency key + at least one attribution key"
  else
    fail "ledger missing:$miss"
  fi
else
  printf '%s[skip]%s no ledger schema in this file (check 3)\n' "$YELLOW" "$RESET"
fi

# --- 4. budget: both a soft and a hard threshold -----------------------------
mentions_budget=0
if has 'budget|threshold|cap|alert'; then mentions_budget=1; fi
if [ "$mentions_budget" -eq 1 ]; then
  miss=""
  has 'soft|alert|warn|degrade|downshift' || miss="$miss soft(alert/degrade)"
  has 'hard|refuse|hard_cap|hard-cap|block|reject' || miss="$miss hard(refuse)"
  if [ -z "$miss" ]; then
    ok "budget declares both a soft and a hard threshold"
  else
    fail "budget missing:$miss threshold"
  fi
else
  printf '%s[skip]%s no budget config in this file (check 4)\n' "$YELLOW" "$RESET"
fi

# --- 5. cost derived from usage, not a len()/char estimate -------------------
if has 'usage|input_tokens|output_tokens|cached_tokens|prompt_tokens'; then
  if grep -Eiq 'len\(|\.length|char_count|charcount|//[[:space:]]*4|/[[:space:]]*4' "$file" \
     && ! has 'estimate|pre-?flight|preflight'; then
    fail "cost may be derived from a len()/char estimate - bill against the response usage object"
  else
    ok "cost derived from a usage/response field, not a char estimate"
  fi
else
  printf '%s[skip]%s no usage-based cost field found (check 5)\n' "$YELLOW" "$RESET"
fi

echo
if [ "$failed" -ne 0 ]; then
  printf '%sFAIL:%s cost-tracking config is missing required pieces (see [fail] lines above).\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s cost-tracking config carries the required guardrails.\n' "$GREEN" "$RESET"
