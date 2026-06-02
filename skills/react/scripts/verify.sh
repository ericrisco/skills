#!/usr/bin/env bash
# verify.sh — React + Vite SPA project gate.
#
# Usage:
#   bash scripts/verify.sh            # run from the Vite project root
#
# What it does (in order): ESLint -> tsc --noEmit -> Vitest -> vite build.
# Each tool is detected; if it is not installed/resolvable (or its config/tests
# are absent) it is SKIPPED with a yellow warning, NEVER a failure. A repo that
# does not have a tool cannot fail a command it does not own. Exits non-zero
# only on a real tool failure; exits 0 on a clean or empty target.
#
# Side effects: the lint / type-check / test steps are read-only. The final
# `vite build` WRITES the `dist/` output directory — it is not a pure read-only
# step. No installs, no network mutations. Safe to re-run.
#
# Portability: targets stock macOS bash 3.2. No `mapfile`; no empty-array
# expansion under `set -u`. `set -e` is intentionally NOT used (each check owns
# its exit code); `set -u` is on.

set -u

# --- colors (only when stdout is a TTY) -----------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

failures=0
skips=""  # space-separated (bash 3.2 safe under set -u)

have() { command -v "$1" >/dev/null 2>&1; }
warn() { printf '%s\n' "${YELLOW}SKIP: $1${RESET}"; skips="${skips}${skips:+ }$2"; return 0; }
fail() { printf '%s\n' "${RED}FAIL: $1${RESET}"; failures=$((failures + 1)); }
ok()   { printf '%s\n' "${GREEN}OK: $1${RESET}"; }

# --- guard: only meaningful inside a Node/Vite project --------------------
if [ ! -f package.json ]; then
  printf '%s\n' "${YELLOW}no package.json here — nothing to verify${RESET}"
  exit 0
fi

# --- resolve a package runner from the lockfile ----------------------------
RUN=""
if [ -f pnpm-lock.yaml ] && have pnpm; then
  RUN="pnpm exec"
elif [ -f yarn.lock ] && have yarn; then
  RUN="yarn"
elif [ -f package-lock.json ] && have npm; then
  RUN="npm exec --"
elif have npx; then
  RUN="npx --no-install"
fi

run_bin() {
  # run_bin <bin-name> <args...> : true if the bin is resolvable and runs
  bin="$1"; shift
  if have "$bin"; then "$bin" "$@"; return $?; fi
  if [ -x "node_modules/.bin/$bin" ]; then "node_modules/.bin/$bin" "$@"; return $?; fi
  if [ -n "$RUN" ]; then $RUN "$bin" "$@"; return $?; fi
  return 127
}

bin_available() {
  bin="$1"
  have "$bin" && return 0
  [ -x "node_modules/.bin/$bin" ] && return 0
  return 1
}

# --- 1. ESLint -------------------------------------------------------------
if bin_available eslint; then
  printf '%s\n' "Running ESLint..."
  if run_bin eslint .; then ok "eslint"; else fail "eslint"; fi
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
# Treat the repo as having Vitest unit tests when a vitest config exists OR
# *.test.* files exist. Playwright e2e uses *.spec.* and must not trigger Vitest.
has_tests=false
if ls vitest.config.* vitest.workspace.* >/dev/null 2>&1; then
  has_tests=true
elif find . \( -name node_modules -o -name dist -o -name .git \) -prune -o \
       -name '*.test.*' -print 2>/dev/null | grep -q .; then
  has_tests=true
fi
if bin_available vitest && [ "$has_tests" = true ]; then
  printf '%s\n' "Running vitest run..."
  if run_bin vitest run; then ok "vitest"; else fail "vitest"; fi
else
  warn "vitest or unit tests (vitest.config.* / *.test.*) not present — skipping unit tests" "vitest"
fi

# --- 4. vite build (slow; WRITES dist/; run last) --------------------------
if bin_available vite; then
  printf '%s\n' "Running vite build... (writes dist/)"
  if run_bin vite build; then ok "vite build"; else fail "vite build"; fi
else
  warn "vite not resolvable — skipping build" "vite build"
fi

# --- summary ---------------------------------------------------------------
printf '\n'
if [ -n "$skips" ]; then
  printf '%s\n' "${YELLOW}skipped: ${skips}${RESET}"
fi
if [ "$failures" -gt 0 ]; then
  printf '%s\n' "${RED}verify.sh: $failures check(s) failed${RESET}"
  exit 1
fi
printf '%s\n' "${GREEN}verify.sh: all runnable checks passed${RESET}"
exit 0
