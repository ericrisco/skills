#!/usr/bin/env bash
#
# verify.sh — quality gate for a FastAPI / async Python project.
#
# Usage:
#   ./scripts/verify.sh [TARGET_PATH]
#
# Runs lint, format-check, type-check, tests+coverage, and a dependency audit.
# Auto-detects each tool. If a tool is missing it prints a yellow SKIP and continues
# (it never FAILs on a missing tool). Prefers `uv run <tool>` when `uv` is present,
# else the bare tool on PATH. Exits non-zero only if a tool actually ran and reported
# a failure. The coverage threshold is read from the project's pyproject.toml
# (--cov-fail-under); this script does not hardcode a second threshold. Idempotent:
# re-running yields the same result (read-only beyond whatever the project's pytest does).
#
# Compatible with stock macOS bash 3.2: no `mapfile`, no associative arrays, and every
# array access is guarded so `set -u` never trips on an "unbound" empty array.

set -euo pipefail

TARGET="${1:-.}"

# --- color helpers (guarded for non-TTY) ---
if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi
warn() { printf '%s%s%s\n' "$YELLOW" "$*" "$RESET"; }
ok()   { printf '%s%s%s\n' "$GREEN" "$*" "$RESET"; }
fail() { printf '%s%s%s\n' "$RED" "$*" "$RESET"; }

PASSED=0; SKIPPED=0; FAILED=0

have() { command -v "$1" >/dev/null 2>&1; }

# Do we have uv? When yes, tools run through `uv run`, which can resolve a tool from the
# project venv even if it is not on PATH.
USE_UV=0
if have uv; then USE_UV=1; fi

# tool_available <tool>
# True when the tool can actually be invoked: either it is on PATH, or (under uv) it can
# be resolved and reports a version. Probing under uv is what lets us SKIP (not FAIL) a
# tool that is genuinely absent from the project's environment.
tool_available() {
  local tool="$1"
  if have "$tool"; then
    return 0
  fi
  if [ "$USE_UV" -eq 1 ]; then
    if uv run --quiet "$tool" --version >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

# run_step <label> <tool> <args...>
run_step() {
  local label="$1"; local tool="$2"; shift 2
  if ! tool_available "$tool"; then
    warn "SKIP: ${label} (${tool} not installed)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  printf '==> %s\n' "$label"
  if [ "$USE_UV" -eq 1 ]; then
    if uv run "$tool" "$@"; then
      ok "PASS: ${label}"; PASSED=$((PASSED + 1))
    else
      fail "FAIL: ${label}"; FAILED=$((FAILED + 1))
    fi
  else
    if "$tool" "$@"; then
      ok "PASS: ${label}"; PASSED=$((PASSED + 1))
    else
      fail "FAIL: ${label}"; FAILED=$((FAILED + 1))
    fi
  fi
}

run_step "ruff check"        ruff check "$TARGET"
run_step "ruff format check" ruff format --check "$TARGET"
run_step "mypy"              mypy "$TARGET"
run_step "pytest + coverage" pytest --cov --cov-report=term-missing
run_step "pip-audit"         pip-audit

printf '\n%d passed, %d skipped, %d failed\n' "$PASSED" "$SKIPPED" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  fail "verify.sh: failures detected"
  exit 1
fi
ok "verify.sh: ok"
exit 0
