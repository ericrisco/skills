#!/usr/bin/env bash
# verify.sh — Next.js App Router project gate.
#
# Usage:
#   bash scripts/verify.sh            # run from the Next.js project root
#
# What it does (in order): ESLint -> tsc --noEmit -> Vitest -> next build.
# Each tool is detected; if it is not installed/resolvable, it is skipped with a
# yellow warning (NOT a failure). Exits non-zero only on a real tool failure.
#
# Side effects: the lint / type-check / test steps are read-only. The final
# `next build` WRITES the `.next/` output directory (and may write `tsconfig.json`
# / `next-env.d.ts` defaults) — it is not a pure read-only step. It performs no
# installs and no network mutations. Safe to re-run.
#
# Portability: targets stock macOS bash 3.2. We avoid `mapfile`, never expand a
# possibly-empty array under `set -u`, and degrade gracefully when a tool is
# missing. `set -e` is intentionally NOT used (each check handles its own exit
# code); `set -u` is on, with arrays initialised before use.

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

# Detect the installed Next.js MAJOR version from package.json (best-effort,
# bash-3.2 safe: no jq, no node required). Echoes a bare integer, or nothing.
next_major() {
  [ -f node_modules/next/package.json ] || return 0
  # grep the "version": "x.y.z" line, then strip to the leading major integer.
  ver="$(grep -m1 '"version"' node_modules/next/package.json 2>/dev/null \
         | sed -e 's/.*"version"[^0-9]*//' -e 's/[^0-9].*//')"
  [ -n "$ver" ] && printf '%s' "$ver"
}

# --- 1. ESLint -------------------------------------------------------------
# `next lint` was REMOVED in Next.js 16 (and `next build` no longer lints).
# So the fallback to `next lint` is only valid on v15 and earlier — on v16+ a
# missing eslint must be a SKIP, never a FAIL (a v16 repo cannot pass a command
# that no longer exists).
if bin_available eslint; then
  printf '%s\n' "Running ESLint..."
  if run_bin eslint .; then ok "eslint"; else fail "eslint"; fi
else
  nxmajor="$(next_major)"
  if bin_available next && [ -n "$nxmajor" ] && [ "$nxmajor" -lt 16 ] 2>/dev/null; then
    printf '%s\n' "Running next lint... (eslint not resolvable; Next.js < 16 fallback)"
    if run_bin next lint; then ok "next lint"; else fail "next lint"; fi
  elif bin_available next && [ -n "$nxmajor" ]; then
    warn "eslint not resolvable; next lint removed in Next.js ${nxmajor} — skipping lint" "eslint"
  else
    warn "eslint not resolvable — skipping lint" "eslint"
  fi
fi

# --- 2. TypeScript ---------------------------------------------------------
if bin_available tsc && [ -f tsconfig.json ]; then
  printf '%s\n' "Running tsc --noEmit..."
  if run_bin tsc --noEmit; then ok "tsc --noEmit"; else fail "tsc --noEmit"; fi
else
  warn "tsc or tsconfig.json missing — skipping type check" "tsc"
fi

# --- 3. Vitest -------------------------------------------------------------
# Only treat the repo as having Vitest unit tests when a vitest config exists OR
# `*.test.*` files exist. Playwright e2e uses `*.spec.*` (typically under e2e/),
# which Vitest must NOT pick up — so `.spec.*` files alone do not trigger Vitest.
has_tests=false
if ls vitest.config.* vitest.workspace.* >/dev/null 2>&1; then
  has_tests=true
elif find . \( -name node_modules -o -name .next -o -name dist \) -prune -o \
       -name '*.test.*' -print 2>/dev/null | grep -q .; then
  has_tests=true
fi
if bin_available vitest && [ "$has_tests" = true ]; then
  printf '%s\n' "Running vitest run..."
  if run_bin vitest run; then ok "vitest"; else fail "vitest"; fi
else
  warn "vitest or unit tests (vitest.config.* / *.test.*) not present — skipping unit tests" "vitest"
fi

# --- 4. next build (slow; WRITES .next/; run last) -------------------------
if bin_available next; then
  printf '%s\n' "Running next build... (writes .next/; Turbopack is the default builder on Next.js 16)"
  if run_bin next build; then ok "next build"; else fail "next build"; fi
else
  warn "next not resolvable — skipping build" "next build"
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
