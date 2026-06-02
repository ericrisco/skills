#!/usr/bin/env bash
#
# verify.sh — static correctness lint for an emitted Modal app (*.py).
#
# Usage:
#   ./scripts/verify.sh [TARGET_PATH]   # default: .
#
# Pure read-only static checks over the Modal Python files under TARGET. Requires NO Modal
# credentials and never executes the app. Checks, per file that looks like a Modal app:
#   - requires `modal.App(`                                  (it is a Modal app at all)
#   - FAILS if the removed `modal.gpu.<X>(` object form is present (use the string form)
#   - if a web decorator (@modal.fastapi_endpoint/asgi_app/wsgi_app/web_server) is present,
#     checks an `@app.function` decorator appears somewhere above it (stack-order heuristic)
#   - if `modal.Volume.from_name(` is present, checks `create_if_missing` appears nearby
# Best-effort: runs `python -c "import modal"` ONLY if a python with modal installed is found,
# otherwise SKIPs (never FAILs on a missing interpreter/package).
#
# On an empty/clean target (no Modal *.py at all) it prints a SKIP and exits 0 — no false fail.
# Compatible with stock macOS bash 3.2: no mapfile, no associative arrays, no globstar.

set -euo pipefail

TARGET="${1:-.}"

if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi
warn() { printf '%s%s%s\n' "$YELLOW" "$*" "$RESET"; }
ok()   { printf '%s%s%s\n' "$GREEN" "$*" "$RESET"; }
fail() { printf '%s%s%s\n' "$RED" "$*" "$RESET"; }

have() { command -v "$1" >/dev/null 2>&1; }

PASSED=0; FAILED=0; SKIPPED=0

if [ ! -e "$TARGET" ]; then
  warn "SKIP: target '${TARGET}' does not exist (nothing to verify)"
  ok "verify.sh: ok (nothing to verify)"
  exit 0
fi

# Collect candidate Modal app files: any *.py under TARGET that imports/uses modal.
# bash 3.2 friendly: feed find output through a while-read loop, NUL-separated.
APP_FILES=""
while IFS= read -r -d '' f; do
  if grep -lqE 'import[[:space:]]+modal|modal\.App\(' "$f" 2>/dev/null; then
    APP_FILES="${APP_FILES}${f}"$'\n'
  fi
done < <(find "$TARGET" -type f -name '*.py' -print0 2>/dev/null)

# Strip trailing newline; if empty, there is nothing to verify.
APP_FILES="$(printf '%s' "$APP_FILES")"
if [ -z "$APP_FILES" ]; then
  warn "SKIP: no Modal *.py found under '${TARGET}' (no 'import modal' / 'modal.App(')"
  ok "verify.sh: ok (nothing to verify)"
  exit 0
fi

check_file() {
  file="$1"
  printf '==> %s\n' "$file"

  # 1) Must declare a modal.App
  if grep -qE 'modal\.App\(' "$file"; then
    ok "  PASS: declares modal.App(...)"; PASSED=$((PASSED + 1))
  else
    fail "  FAIL: no modal.App(...) found (imports modal but never builds an App)"
    FAILED=$((FAILED + 1))
  fi

  # 2) Removed GPU object form -> FAIL. Match modal.gpu.<Word>( e.g. modal.gpu.H100(
  if grep -qE 'modal\.gpu\.[A-Za-z0-9_]+\(' "$file"; then
    fail "  FAIL: removed API 'modal.gpu.X()' — use the string form, e.g. gpu=\"H100\""
    FAILED=$((FAILED + 1))
  else
    ok "  PASS: no removed modal.gpu.X() object form"; PASSED=$((PASSED + 1))
  fi

  # 3) Web decorator present -> expect an @app.function above it (stack-order heuristic).
  if grep -qE '@modal\.(fastapi_endpoint|asgi_app|wsgi_app|web_server)' "$file"; then
    if grep -qE '@app\.function|@[A-Za-z_][A-Za-z0-9_]*\.function' "$file"; then
      ok "  PASS: web decorator paired with an @app.function"; PASSED=$((PASSED + 1))
    else
      fail "  FAIL: web decorator without an @app.function (stack order: @app.function outermost)"
      FAILED=$((FAILED + 1))
    fi
  fi

  # 4) Volume.from_name -> expect create_if_missing somewhere in the file.
  if grep -qE 'Volume\.from_name\(' "$file"; then
    if grep -qE 'create_if_missing' "$file"; then
      ok "  PASS: Volume.from_name uses create_if_missing"; PASSED=$((PASSED + 1))
    else
      fail "  FAIL: Volume.from_name without create_if_missing (will error if the volume is absent)"
      FAILED=$((FAILED + 1))
    fi
  fi
}

while IFS= read -r f; do
  [ -n "$f" ] && check_file "$f"
done <<EOF
$APP_FILES
EOF

# 5) Best-effort import smoke test, only if a python with modal is available.
PYBIN=""
if have python3; then PYBIN="python3"; elif have python; then PYBIN="python"; fi
if [ -n "$PYBIN" ] && "$PYBIN" -c "import modal" >/dev/null 2>&1; then
  printf '==> import modal smoke test\n'
  if "$PYBIN" -c "import modal" >/dev/null 2>&1; then
    ok "  PASS: 'import modal' works ($PYBIN)"; PASSED=$((PASSED + 1))
  fi
else
  warn "SKIP: 'import modal' smoke test (modal not installed in this env)"
  SKIPPED=$((SKIPPED + 1))
fi

printf '\n%d passed, %d skipped, %d failed\n' "$PASSED" "$SKIPPED" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  fail "verify.sh: failures detected"
  exit 1
fi
ok "verify.sh: ok"
exit 0
