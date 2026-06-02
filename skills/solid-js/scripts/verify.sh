#!/usr/bin/env bash
# verify.sh — SolidJS project gate.
#
# Usage:
#   bash scripts/verify.sh            # run from the Solid project root
#
# What it does (in order): tsc --noEmit -> ESLint -> Vitest -> vite build.
# Each tool is detected; if it is not installed/resolvable, it is skipped with a
# yellow warning (NOT a failure). Exits non-zero only on a real tool failure.
# On an empty or non-Solid directory every step SKIPs and it exits 0.
#
# Side effects: type-check / lint / test are read-only. The final `vite build`
# WRITES the `dist/` output directory — it is not a pure read-only step. It
# performs no installs and no network mutations. Safe to re-run.
#
# Portability: targets stock macOS bash 3.2. We avoid `mapfile`, never expand a
# possibly-empty array under `set -u`, and degrade gracefully when a tool is
# missing. `set -e` is intentionally NOT used (each check handles its own exit
# code); `set -u` is on.

set -u

# --- colors (only when stdout is a TTY) -----------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

failures=0
skips=""

have() { command -v "$1" >/dev/null 2>&1; }
warn() { printf '%s\n' "${YELLOW}SKIP: $1${RESET}"; skips="${skips}${skips:+ }$2"; return 0; }
fail() { printf '%s\n' "${RED}FAIL: $1${RESET}"; failures=$((failures + 1)); }
ok()   { printf '%s\n' "${GREEN}OK: $1${RESET}"; }

# --- resolve a package runner from the lockfile ----------------------------
RUN=""
if [ -f pnpm-lock.yaml ] && have pnpm; then
  RUN="pnpm exec"
elif [ -f yarn.lock ] && have yarn; then
  RUN="yarn"
elif [ -f bun.lockb ] && have bun; then
  RUN="bunx"
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

# --- 1. TypeScript ---------------------------------------------------------
if bin_available tsc && [ -f tsconfig.json ]; then
  printf '%s\n' "Running tsc --noEmit..."
  if run_bin tsc --noEmit; then ok "tsc --noEmit"; else fail "tsc --noEmit"; fi
else
  warn "tsc or tsconfig.json missing — skipping type check" "tsc"
fi

# --- 2. ESLint -------------------------------------------------------------
# Solid projects typically use eslint-plugin-solid. We run eslint only if it is
# resolvable AND an eslint config exists; otherwise SKIP (never FAIL).
has_eslint_config=false
if ls .eslintrc .eslintrc.* eslint.config.* >/dev/null 2>&1; then
  has_eslint_config=true
fi
if bin_available eslint && [ "$has_eslint_config" = true ]; then
  printf '%s\n' "Running ESLint..."
  if run_bin eslint .; then ok "eslint"; else fail "eslint"; fi
else
  warn "eslint or its config not resolvable — skipping lint" "eslint"
fi

# --- 3. Vitest -------------------------------------------------------------
# Treat the repo as having Vitest unit tests when a vitest config exists OR
# *.test.* files exist.
has_tests=false
if ls vitest.config.* vitest.workspace.* >/dev/null 2>&1; then
  has_tests=true
elif find . \( -name node_modules -o -name dist -o -name .solid \) -prune -o \
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
# Only attempt a build when this looks like a Vite project (vite config present).
has_vite_config=false
if ls vite.config.* >/dev/null 2>&1; then
  has_vite_config=true
fi
if bin_available vite && [ "$has_vite_config" = true ]; then
  printf '%s\n' "Running vite build... (writes dist/)"
  if run_bin vite build; then ok "vite build"; else fail "vite build"; fi
else
  warn "vite or vite.config.* not present — skipping build" "vite build"
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
