#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/verify.sh
# Lints example agent code and dry-runs the eval smoke test in THIS project.
# Detects each tool; missing tools print a yellow WARN and are skipped (not failures).
# Exit 0 = all present checks passed (or only skips). Non-zero = a real failure.
# Read-only: never writes files, never installs anything (npx uses --no-install).
#
# Portable to stock macOS bash 3.2: no `mapfile`, no `pipefail` reliance, and every
# array expansion is guarded so it is safe under `set -u` even when empty.

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; RESET="$(tput sgr0)"
else
  YELLOW=""; RED=""; GREEN=""; RESET=""
fi

rc=0
warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$1" >&2; }
info() { printf '[INFO] %s\n' "$1"; }
fail() { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$1" >&2; rc=1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Directories likely to hold example code; fall back to "." with vendored dirs pruned.
# Result is returned newline-delimited so callers read it without arrays (bash 3.2 safe).
PRUNE='-path ./node_modules -o -path ./.venv -o -path ./venv -o -path ./dist -o -path ./build -o -path ./.git'
pick_dirs() {
  found=""
  for d in examples agents src; do
    [ -d "$d" ] && found="${found}${d}
"
  done
  if [ -n "$found" ]; then printf '%s' "$found"; else printf '%s\n' "."; fi
}

# Populate the PYDIRS array portably (no `mapfile`; works on bash 3.2).
PYDIRS=()
while IFS= read -r _d; do
  [ -n "$_d" ] && PYDIRS+=("$_d")
done <<EOF
$(pick_dirs)
EOF
[ "${#PYDIRS[@]}" -gt 0 ] || PYDIRS=(".")   # never expand an empty array under set -u

# 1. Python lint (ruff)
if have ruff; then
  if find "${PYDIRS[@]}" \( $PRUNE \) -prune -o -name '*.py' -print 2>/dev/null | grep -q .; then
    info "ruff: linting ${PYDIRS[*]}"
    if ! ruff check "${PYDIRS[@]}"; then fail "ruff reported lint errors"; fi
  else
    info "ruff present but no .py files found; skipping"
  fi
else
  warn "ruff not found; skipping Python lint"
fi

# 2. Python typecheck (mypy) — soft: only if config present
if have mypy && { [ -f mypy.ini ] || [ -f setup.cfg ] || grep -qs '\[tool.mypy\]' pyproject.toml 2>/dev/null; }; then
  info "mypy: typechecking ${PYDIRS[*]}"
  if ! mypy "${PYDIRS[@]}"; then fail "mypy reported type errors"; fi
elif have mypy; then
  warn "mypy present but no config (mypy.ini/setup.cfg/[tool.mypy]); skipping typecheck"
else
  warn "mypy not found; skipping Python typecheck"
fi

# 3. TS/JS check
if [ -f tsconfig.json ] && have npx; then
  info "tsc: typechecking (no emit)"
  if ! npx --no-install tsc --noEmit; then fail "tsc reported type errors"; fi
elif have node && find . \( $PRUNE \) -prune -o \( -name '*.mjs' -o -name '*.js' \) -print 2>/dev/null | grep -q .; then
  info "node --check: syntax-checking JS/MJS examples"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    node --check "$f" || fail "node --check failed: $f"
  done < <(find . \( $PRUNE \) -prune -o \( -name '*.mjs' -o -name '*.js' \) -print)
else
  warn "no tsconfig.json + npx and no node/JS examples; skipping TS/JS check"
fi

# 4. Go vet (only if module present)
if [ -f go.mod ]; then
  if have go; then
    info "go vet ./..."
    if ! go vet ./...; then fail "go vet reported issues"; fi
  else
    warn "go.mod present but go not found; skipping go vet"
  fi
fi

# 5. Eval smoke dry-run (must not hit live APIs)
EVAL_ENTRY=""
for cand in evals/run.py evals/smoke.py scripts/eval_smoke.py; do
  [ -f "$cand" ] && { EVAL_ENTRY="$cand"; break; }
done
if [ -n "$EVAL_ENTRY" ] && have python; then
  info "eval smoke (dry-run): $EVAL_ENTRY"
  if ! EVAL_DRY_RUN=1 python "$EVAL_ENTRY" --dry-run; then fail "eval smoke dry-run failed"; fi
elif [ -f package.json ] && have npm && grep -qs '"eval"' package.json; then
  info "eval smoke (dry-run): npm run eval -- --dry-run"
  if ! EVAL_DRY_RUN=1 npm run eval -- --dry-run; then fail "eval smoke dry-run failed"; fi
else
  warn "no eval smoke entrypoint (evals/run.py|smoke.py|scripts/eval_smoke.py|package.json eval); skipping"
fi

# 6. Markdown lint (soft — advisory, never fails the gate)
if have markdownlint-cli2; then
  markdownlint-cli2 '**/*.md' >/dev/null 2>&1 || warn "markdownlint-cli2 reported style issues (advisory)"
elif have markdownlint; then
  markdownlint '**/*.md' >/dev/null 2>&1 || warn "markdownlint reported style issues (advisory)"
else
  warn "markdownlint not found; skipping markdown lint (advisory)"
fi

if [ "$rc" -ne 0 ]; then
  printf '%sverify.sh: FAILED%s\n' "$RED" "$RESET" >&2
  exit "$rc"
fi
printf '%sverify.sh: OK%s\n' "$GREEN" "$RESET"
exit 0
