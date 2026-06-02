#!/usr/bin/env bash
# verify.sh — Svelte 5 / SvelteKit project gate.
#
# Usage:
#   bash scripts/verify.sh            # run from the SvelteKit project root
#
# What it does (in order): svelte-check -> tsc --noEmit -> Vitest -> vite build.
# Each tool is detected; if it is not installed/resolvable it is SKIPPED with a
# yellow warning (NOT a failure). Exits non-zero only on a real tool failure, so
# an empty or tooling-free directory exits 0.
#
# Side effects: svelte-check, tsc and the test run are read-only. The final
# `vite build` WRITES the build output dir (`.svelte-kit/output`, `build/`) and
# may write `.svelte-kit/` type stubs — it is NOT a pure read-only step. It does
# no installs and no network mutations. Safe to re-run.
#
# Portability: targets stock macOS bash 3.2. No `mapfile`, no empty-array
# expansion under `set -u`, graceful skip when a tool is missing. `set -e` is
# intentionally NOT used (each check owns its exit code); `set -u` is on.

set -u

# --- colors (only when stdout is a TTY) -----------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

failures=0
# Space-separated list (portable to bash 3.2; avoids empty-array expansion under set -u).
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

# --- 0. bail early on a non-SvelteKit / empty directory --------------------
# No package.json at all → nothing to verify; succeed (don't false-fail an
# empty or clean target).
if [ ! -f package.json ]; then
  printf '%s\n' "${YELLOW}no package.json here — nothing to verify${RESET}"
  printf '%s\n' "${GREEN}verify.sh: all runnable checks passed${RESET}"
  exit 0
fi

# --- 1. svelte-check (type + template diagnostics) -------------------------
if bin_available svelte-check; then
  printf '%s\n' "Running svelte-check..."
  if run_bin svelte-check --threshold error; then ok "svelte-check"; else fail "svelte-check"; fi
else
  warn "svelte-check not resolvable — skipping template/type diagnostics" "svelte-check"
fi

# --- 2. TypeScript ---------------------------------------------------------
if bin_available tsc && [ -f tsconfig.json ]; then
  printf '%s\n' "Running tsc --noEmit..."
  if run_bin tsc --noEmit; then ok "tsc --noEmit"; else fail "tsc --noEmit"; fi
else
  warn "tsc or tsconfig.json missing — skipping type check" "tsc"
fi

# --- 3. Vitest -------------------------------------------------------------
# Treat the repo as having unit tests when a vitest config exists OR `*.test.*`
# files exist. (SvelteKit scaffolds use Vitest for unit tests.)
has_tests=false
if ls vitest.config.* vitest.workspace.* >/dev/null 2>&1; then
  has_tests=true
elif find . \( -name node_modules -o -name .svelte-kit -o -name build -o -name dist \) -prune -o \
       -name '*.test.*' -print 2>/dev/null | grep -q .; then
  has_tests=true
fi
if bin_available vitest && [ "$has_tests" = true ]; then
  printf '%s\n' "Running vitest run..."
  if run_bin vitest run; then ok "vitest"; else fail "vitest"; fi
else
  warn "vitest or unit tests (vitest.config.* / *.test.*) not present — skipping unit tests" "vitest"
fi

# --- 4. vite build (slow; WRITES build output; run last) -------------------
# SvelteKit builds through Vite. Skip (not fail) if vite is unresolvable.
if bin_available vite; then
  printf '%s\n' "Running vite build... (writes .svelte-kit/output and the adapter output dir)"
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
