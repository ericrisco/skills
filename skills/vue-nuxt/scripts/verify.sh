#!/usr/bin/env bash
# verify.sh — Vue 3 + Nuxt 4 project gate.
#
# Usage:
#   bash scripts/verify.sh            # run from the Vue/Nuxt project root
#
# What it does (in order): typecheck -> package `lint` script -> Vitest -> build.
#   - Nuxt repo  (nuxt.config.{ts,js,mjs} present): nuxi typecheck (fallback vue-tsc
#     --noEmit), lint, vitest run, nuxi build.
#   - Plain Vue repo (no Nuxt config):              vue-tsc --noEmit, lint, vitest run,
#     vite build.
# Each tool is detected; if it is not installed/resolvable, it is SKIPped with a yellow
# warning (NOT a failure). Exits non-zero only on a real tool failure.
#
# Side effects: typecheck / lint / test are read-only. The final build WRITES output
# (`.nuxt/` + `.output/` for Nuxt, `dist/` for plain Vue). It performs no installs and no
# network mutations. Safe to re-run. Exits 0 on a clean/empty target (everything skipped).
#
# Portability: targets stock macOS bash 3.2. No `mapfile`, no empty-array expansion under
# `set -u`, graceful degradation when a tool is missing. `set -e` is intentionally NOT used.

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

# --- detect Nuxt vs plain Vue ----------------------------------------------
IS_NUXT=false
if [ -f nuxt.config.ts ] || [ -f nuxt.config.js ] || [ -f nuxt.config.mjs ]; then
  IS_NUXT=true
fi

# Does package.json declare a "lint" script? (bash-3.2 safe, no jq/node)
has_lint_script() {
  [ -f package.json ] || return 1
  grep -q '"lint"[[:space:]]*:' package.json 2>/dev/null
}

# --- 1. typecheck ----------------------------------------------------------
if [ "$IS_NUXT" = true ] && bin_available nuxi; then
  printf '%s\n' "Running nuxi typecheck..."
  if run_bin nuxi typecheck; then ok "nuxi typecheck"; else fail "nuxi typecheck"; fi
elif bin_available vue-tsc && [ -f tsconfig.json ]; then
  printf '%s\n' "Running vue-tsc --noEmit..."
  if run_bin vue-tsc --noEmit; then ok "vue-tsc --noEmit"; else fail "vue-tsc --noEmit"; fi
else
  warn "nuxi/vue-tsc (or tsconfig.json) not resolvable — skipping type check" "typecheck"
fi

# --- 2. lint (package script: ESLint / oxlint) -----------------------------
if has_lint_script && [ -n "$RUN" ]; then
  printf '%s\n' "Running package lint script..."
  case "$RUN" in
    "pnpm exec") LINT_CMD="pnpm run lint" ;;
    "yarn")      LINT_CMD="yarn lint" ;;
    "npm exec --") LINT_CMD="npm run lint" ;;
    *)           LINT_CMD="npm run lint" ;;
  esac
  if $LINT_CMD; then ok "lint"; else fail "lint"; fi
else
  warn "no package lint script (or no package runner) — skipping lint" "lint"
fi

# --- 3. Vitest -------------------------------------------------------------
# Treat as having unit tests when a vitest config exists OR *.test.* / *.spec.*
# files exist (Vue/Nuxt commonly use either for unit tests).
has_tests=false
if ls vitest.config.* vitest.workspace.* >/dev/null 2>&1; then
  has_tests=true
elif find . \( -name node_modules -o -name .nuxt -o -name .output -o -name dist \) -prune -o \
       \( -name '*.test.*' -o -name '*.spec.*' \) -print 2>/dev/null | grep -q .; then
  has_tests=true
fi
if bin_available vitest && [ "$has_tests" = true ]; then
  printf '%s\n' "Running vitest run..."
  if run_bin vitest run; then ok "vitest"; else fail "vitest"; fi
else
  warn "vitest or tests (vitest.config.* / *.test.* / *.spec.*) not present — skipping unit tests" "vitest"
fi

# --- 4. build (slow; WRITES output; run last) ------------------------------
if [ "$IS_NUXT" = true ]; then
  if bin_available nuxi; then
    printf '%s\n' "Running nuxi build... (writes .nuxt/ and .output/)"
    if run_bin nuxi build; then ok "nuxi build"; else fail "nuxi build"; fi
  else
    warn "nuxi not resolvable — skipping build" "build"
  fi
else
  if bin_available vite; then
    printf '%s\n' "Running vite build... (writes dist/)"
    if run_bin vite build; then ok "vite build"; else fail "vite build"; fi
  else
    warn "vite not resolvable — skipping build" "build"
  fi
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
