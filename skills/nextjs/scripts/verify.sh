#!/usr/bin/env bash
set -euo pipefail

# verify.sh — Next.js App Router project gate.
#
# Usage:
#   bash scripts/verify.sh            # run from the Next.js project root
#
# What it does (in order): ESLint -> tsc --noEmit -> Vitest -> next build.
# Each tool is detected; if it is not installed/resolvable, it is skipped with a
# yellow warning (NOT a failure). Exits non-zero only on a real tool failure.
# Safe to re-run: read-only, no writes, no installs, no network.

# --- colors (only when stdout is a TTY) -----------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

failures=0
skips=()

have() { command -v "$1" >/dev/null 2>&1; }
warn() { printf '%s\n' "${YELLOW}SKIP: $1${RESET}"; skips+=("$2"); return 0; }
fail() { printf '%s\n' "${RED}FAIL: $1${RESET}"; failures=$((failures + 1)); }
ok()   { printf '%s\n' "${GREEN}OK: $1${RESET}"; }

# --- resolve a package runner from the lockfile ----------------------------
if [ -f pnpm-lock.yaml ] && have pnpm; then
  RUN="pnpm exec"
elif [ -f yarn.lock ] && have yarn; then
  RUN="yarn"
elif [ -f package-lock.json ] && have npm; then
  RUN="npm exec --"
elif have npx; then
  RUN="npx --no-install"
else
  RUN=""
fi

run_bin() {
  # run_bin <bin-name> <args...> : true if the bin is resolvable and runs
  local bin="$1"; shift
  if have "$bin"; then "$bin" "$@"; return $?; fi
  if [ -x "node_modules/.bin/$bin" ]; then "node_modules/.bin/$bin" "$@"; return $?; fi
  if [ -n "$RUN" ]; then $RUN "$bin" "$@"; return $?; fi
  return 127
}

bin_available() {
  local bin="$1"
  have "$bin" && return 0
  [ -x "node_modules/.bin/$bin" ] && return 0
  return 1
}

# --- 1. ESLint -------------------------------------------------------------
if bin_available eslint; then
  printf '%s\n' "Running ESLint..."
  if run_bin eslint .; then ok "eslint"; else fail "eslint"; fi
elif bin_available next; then
  printf '%s\n' "Running next lint..."
  if run_bin next lint; then ok "next lint"; else fail "next lint"; fi
else
  warn "eslint not resolvable — skipping lint" "eslint"
fi

# --- 2. TypeScript ---------------------------------------------------------
if bin_available tsc && [ -f tsconfig.json ]; then
  printf '%s\n' "Running tsc --noEmit..."
  if run_bin tsc --noEmit; then ok "tsc --noEmit"; else fail "tsc --noEmit"; fi
else
  warn "tsc or tsconfig.json missing — skipping type check" "tsc"
fi

# --- 3. Vitest -------------------------------------------------------------
has_tests=false
if ls vitest.config.* >/dev/null 2>&1; then has_tests=true; fi
if find . -path ./node_modules -prune -o \
     \( -name '*.test.*' -o -name '*.spec.*' \) -print 2>/dev/null | grep -q .; then
  has_tests=true
fi
if bin_available vitest && [ "$has_tests" = true ]; then
  printf '%s\n' "Running vitest run..."
  if run_bin vitest run; then ok "vitest"; else fail "vitest"; fi
else
  warn "vitest or tests not present — skipping unit tests" "vitest"
fi

# --- 4. next build (slow/expensive — last) ---------------------------------
if bin_available next; then
  printf '%s\n' "Running next build... (Turbopack is the default builder on Next.js 16)"
  if run_bin next build; then ok "next build"; else fail "next build"; fi
else
  warn "next not resolvable — skipping build" "next build"
fi

# --- summary ---------------------------------------------------------------
printf '\n'
if [ "${#skips[@]}" -gt 0 ]; then
  printf '%s\n' "${YELLOW}skipped: ${skips[*]}${RESET}"
fi
if [ "$failures" -gt 0 ]; then
  printf '%s\n' "${RED}verify.sh: $failures check(s) failed${RESET}"
  exit 1
fi
printf '%s\n' "${GREEN}verify.sh: all runnable checks passed${RESET}"
exit 0
