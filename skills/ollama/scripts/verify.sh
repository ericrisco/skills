#!/usr/bin/env bash
#
# verify.sh — static checks for a local Ollama setup.
#
# Usage:
#   ./scripts/verify.sh [TARGET]      # TARGET defaults to the current directory
#
# What it does (all read-only, no daemon needed):
#   1. Modelfile lint  — if a Modelfile exists under TARGET: FAIL if it has no FROM line;
#                        WARN on unknown instructions; WARN if PARAMETER num_ctx is absurdly
#                        high (> 32768) — a likely OOM on consumer GPUs.
#   2. App-code scan   — note whether code points at the local localhost:11434 / /v1 endpoint;
#                        WARN if it only references remote LLM hosts when this is meant to be local.
#   3. Ollama presence — only if `ollama` is on PATH: best-effort `ollama list` to confirm a model
#                        is pulled (WARN, never FAIL, if none / daemon down).
#
# Emits PASS / WARN / FAIL lines. Exits non-zero ONLY on a real FAIL. An empty or clean
# target passes cleanly (exit 0). Works on stock macOS bash 3.2 — no mapfile, no assoc arrays.

set -euo pipefail

TARGET="${1:-.}"

if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi
pass() { printf '%sPASS%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%sWARN%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%sFAIL%s %s\n' "$RED" "$RESET" "$*"; FAILED=$((FAILED + 1)); }

FAILED=0

if [ ! -e "$TARGET" ]; then
  warn "target '$TARGET' does not exist — nothing to verify"
  pass "verify.sh: ok (nothing to verify)"
  exit 0
fi

# --- 1. Modelfile lint -------------------------------------------------------
# Match Modelfile and Modelfile.* (case-insensitive), excluding VCS/deps dirs.
MODELFILES=$(find "$TARGET" \
  \( -name node_modules -o -name .git -o -name .venv -o -name venv \) -prune -o \
  -type f \( -iname 'Modelfile' -o -iname 'Modelfile.*' \) -print 2>/dev/null || true)

if [ -z "$MODELFILES" ]; then
  warn "no Modelfile found under '$TARGET' — skipping Modelfile lint"
else
  # Known Modelfile instructions (uppercased first token of a line).
  KNOWN=" FROM PARAMETER SYSTEM TEMPLATE LICENSE ADAPTER MESSAGE STOP "
  # Iterate without a pipe so FAILs increment FAILED in THIS shell (bash 3.2: a piped
  # while runs in a subshell and would lose the counter).
  OLD_IFS=$IFS; IFS=$'\n'
  for mf in $MODELFILES; do
    IFS=$OLD_IFS
    [ -z "$mf" ] && continue
    if grep -qiE '^[[:space:]]*FROM[[:space:]]+' "$mf"; then
      pass "Modelfile '$mf' has a FROM line"
    else
      fail "Modelfile '$mf' has no FROM line (required)"
    fi

    # Unknown instructions: first uppercased token on non-blank, non-comment lines.
    while IFS= read -r line; do
      case "$line" in ''|'#'*) continue ;; esac
      first=$(printf '%s' "$line" | awk '{print toupper($1)}')
      [ -z "$first" ] && continue
      case "$KNOWN" in
        *" $first "*) : ;;
        *) warn "Modelfile '$mf': unknown instruction '$first'" ;;
      esac
    done < "$mf"

    # Absurd num_ctx.
    ctx=$(grep -iE '^[[:space:]]*PARAMETER[[:space:]]+num_ctx[[:space:]]+[0-9]+' "$mf" \
      | awk '{print $3}' | tail -n1 || true)
    if [ -n "${ctx:-}" ] && [ "$ctx" -gt 32768 ] 2>/dev/null; then
      warn "Modelfile '$mf': PARAMETER num_ctx $ctx is very high — likely OOM on consumer GPUs"
    fi
    IFS=$'\n'
  done
  IFS=$OLD_IFS
fi

# --- 2. App-code scan --------------------------------------------------------
SCAN_GLOB='--include=*.py --include=*.js --include=*.ts --include=*.go --include=*.rb --include=*.sh --include=*.env --include=*.yaml --include=*.yml --include=*.toml'
LOCAL_HITS=$(grep -rIl $SCAN_GLOB -e 'localhost:11434' -e '127.0.0.1:11434' -e ':11434/v1' "$TARGET" 2>/dev/null || true)
REMOTE_HITS=$(grep -rIl $SCAN_GLOB -e 'api.openai.com' -e 'api.anthropic.com' -e 'api.together.xyz' -e 'api.replicate.com' "$TARGET" 2>/dev/null || true)

if [ -n "$LOCAL_HITS" ]; then
  pass "found local Ollama endpoint (localhost:11434) in app code"
elif [ -n "$REMOTE_HITS" ]; then
  warn "app code references only remote LLM hosts; for a local Ollama target use http://localhost:11434/v1"
else
  warn "no LLM endpoint references found in app code under '$TARGET' — nothing to check"
fi

# --- 3. Ollama presence (best-effort) ---------------------------------------
if command -v ollama >/dev/null 2>&1; then
  if models=$(ollama list 2>/dev/null) && [ "$(printf '%s\n' "$models" | sed -n '2,$p' | grep -c .)" -gt 0 ]; then
    pass "ollama is on PATH and at least one model is pulled"
  else
    warn "ollama is on PATH but no model is pulled (or daemon is down) — try: ollama pull qwen3:8b"
  fi
else
  warn "ollama not on PATH — skipping runtime check (static checks still ran)"
fi

# --- summary -----------------------------------------------------------------
if [ "$FAILED" -gt 0 ]; then
  fail "verify.sh: $FAILED failure(s)"
  exit 1
fi
pass "verify.sh: ok"
exit 0
