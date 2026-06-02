#!/usr/bin/env bash
#
# verify.sh - local quality gate for a Python project (single mirror of CI).
#
# Usage:
#   cd <your-project-root>   # the directory containing pyproject.toml
#   ./verify.sh
#
# Runs: uv sync --frozen, ruff check, ruff format --check, mypy --strict (or ty),
# and pytest. Tools/dirs that are absent are skipped with a yellow warning, never a
# failure. Real problems (lint, format drift, type errors, test failures) exit non-zero.
# Read-only by default: it does not reformat or autofix your source.
#
# Portability: stock macOS bash 3.2 (no mapfile, no associative arrays, guarded under set -u).

set -euo pipefail

if [ -t 1 ]; then
  YELLOW=$'\033[33m'; RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  YELLOW=''; RED=''; GREEN=''; RESET=''
fi

failed=0

have()  { command -v "$1" >/dev/null 2>&1; }
warn()  { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail()  { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; failed=1; }
ok()    { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
info()  { printf -- '----- %s\n' "$*"; }

# Must run from a project root.
if [ ! -f pyproject.toml ]; then
  printf '%serror:%s no pyproject.toml in %s - cd into your project root first.\n' \
    "$RED" "$RESET" "$(pwd)" >&2
  exit 2
fi

# Choose a runner: prefer `uv run <tool>` when uv is present, else the bare tool.
have_uv=0
if have uv; then have_uv=1; fi

run_tool() {
  # run_tool <toolname> [args...] : invoke via uv when available, else directly.
  local tool="$1"; shift
  if [ "$have_uv" -eq 1 ]; then
    uv run "$tool" "$@"
  else
    "$tool" "$@"
  fi
}
tool_present() {
  # tool_present <toolname> : true if reachable directly or via uv.
  if have "$1"; then return 0; fi
  if [ "$have_uv" -eq 1 ] && uv run "$1" --version >/dev/null 2>&1; then return 0; fi
  return 1
}

# 1. uv sync --frozen - reproducible install from the committed lockfile.
info "uv sync"
if [ "$have_uv" -eq 1 ]; then
  if [ -f uv.lock ]; then
    if uv sync --frozen; then ok "uv sync --frozen"; else fail "uv sync --frozen failed"; fi
  else
    warn "no uv.lock; trying uv sync (will create one)"
    if uv sync; then ok "uv sync"; else fail "uv sync failed"; fi
  fi
else
  warn "uv not found (https://docs.astral.sh/uv/); using whatever is on PATH"
fi

# 2. ruff check - lint. Read-only here (no --fix); CI should not mutate source.
info "ruff check"
if tool_present ruff; then
  if run_tool ruff check .; then ok "ruff check clean"; else fail "ruff reported lint issues (run: ruff check --fix .)"; fi
else
  warn "ruff not found (uv add --dev ruff)"
fi

# 3. ruff format --check - formatting must be clean, but do not rewrite files.
info "ruff format --check"
if tool_present ruff; then
  if run_tool ruff format --check .; then ok "ruff format clean"; else fail "formatting drift (run: ruff format .)"; fi
else
  warn "ruff not found - skipping format check"
fi

# 4. type check: mypy --strict, or ty if the project opted into it via [tool.ty].
info "type check"
type_target="."
if [ -d src ]; then type_target="src"; fi
if grep -q '^\[tool\.ty\]' pyproject.toml 2>/dev/null && tool_present ty; then
  if run_tool ty check "$type_target"; then ok "ty clean"; else fail "ty reported type errors"; fi
elif tool_present mypy; then
  if run_tool mypy --strict "$type_target"; then ok "mypy --strict clean ($type_target)"; else fail "mypy --strict reported type errors"; fi
else
  warn "no type checker found (uv add --dev mypy)"
fi

# 5. pytest - only if there are tests to run.
info "pytest"
has_tests=0
if [ -d tests ]; then has_tests=1; fi
# Any test_*.py / *_test.py anywhere also counts.
if [ "$has_tests" -eq 0 ]; then
  if find . -type d -name .venv -prune -o -type f \( -name 'test_*.py' -o -name '*_test.py' \) -print 2>/dev/null | grep -q .; then
    has_tests=1
  fi
fi
if [ "$has_tests" -eq 1 ]; then
  if tool_present pytest; then
    if run_tool pytest -q; then ok "pytest passed"; else fail "pytest failed"; fi
  else
    warn "pytest not found (uv add --dev pytest)"
  fi
else
  warn "no tests found - skipping pytest"
fi

echo
if [ "$failed" -ne 0 ]; then
  printf '%sFAIL:%s one or more checks failed.\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s all checks passed.\n' "$GREEN" "$RESET"
