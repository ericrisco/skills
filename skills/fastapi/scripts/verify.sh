#!/usr/bin/env bash
#
# verify.sh — quality gate for a FastAPI / async Python project.
#
# Usage:
#   ./scripts/verify.sh [TARGET_PATH]
#
# Runs lint, format-check, type-check, tests+coverage, and a dependency audit.
# Auto-detects each tool. If a tool is missing it prints a yellow SKIP and continues
# (it does NOT fail). Prefers `uv run <tool>` when `uv` is present, else the bare tool
# on PATH. Exits non-zero only if a tool actually ran and reported a failure.
# Coverage threshold is read from the project's pyproject.toml (--cov-fail-under);
# this script does not hardcode a second threshold. Idempotent: re-running yields the
# same result (read-only beyond whatever the project's own pytest does).

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

# runner prefix: prefer `uv run` when available
RUNNER=()
if have uv; then RUNNER=(uv run); fi

# run_step <label> <tool> <args...>
run_step() {
  local label="$1"; local tool="$2"; shift 2
  if ! have "$tool" && ! { [ "${#RUNNER[@]}" -gt 0 ] && have uv; }; then
    warn "SKIP: ${label} (${tool} not installed)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  printf '==> %s\n' "$label"
  if "${RUNNER[@]}" "$tool" "$@"; then
    ok "PASS: ${label}"
    PASSED=$((PASSED + 1))
  else
    fail "FAIL: ${label}"
    FAILED=$((FAILED + 1))
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
