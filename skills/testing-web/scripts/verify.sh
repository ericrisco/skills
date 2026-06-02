#!/usr/bin/env bash
set -euo pipefail

# verify.sh — testing-web skill gate. Lints frontend test files for the load-bearing rules.
#
# Usage:  scripts/verify.sh [PATH]      (PATH = a test file or a directory; default: current dir)
#
# Read-only. Never executes the tests, never edits anything. It checks artifact SHAPE, not whether the
# assertions are true.
#
# Discovers test files matching *.test.* / *.spec.* (.ts/.tsx/.js/.jsx), skipping node_modules/.git/dist.
# Per file:
#   HARD fail (exit 1):
#     - zero `expect(`                                  -> a test that asserts nothing
#     - a userEvent/`user.<verb>(` interaction not preceded by `await` on the same line
#   WARN (advisory, never changes exit code):
#     - getByTestId used while no getByRole/getByLabelText/getByText query is present
#     - raw fireEvent( where userEvent would do
#     - act( inside a component (non-hook) test file
#     - setTimeout(-based waiting instead of waitFor/findBy
#
# An empty or clean target exits 0 (no false failure). Stock macOS bash 3.2 compatible.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

TARGET="${1:-.}"
if [ ! -e "$TARGET" ]; then
  err "path not found: $TARGET"
  exit 1
fi

FILES=()
if [ -f "$TARGET" ]; then
  FILES+=("$TARGET")
else
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(
    find "$TARGET" \
      \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/coverage/*' \) -prune -o \
      -type f \( -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.test.js' -o -name '*.test.jsx' \
                 -o -name '*.spec.ts' -o -name '*.spec.tsx' -o -name '*.spec.js' -o -name '*.spec.jsx' \) -print0 2>/dev/null
  )
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  warn "no *.test.* / *.spec.* files found under $TARGET — nothing to lint"
  ok "verify.sh passed (empty target)"
  exit 0
fi

for f in "${FILES[@]}"; do
  problems=0

  # --- HARD: must contain at least one assertion ---
  if ! grep -Eq 'expect[[:space:]]*\(' "$f"; then
    err "$f: no expect(...) — a test must assert something observable"
    problems=$((problems + 1))
  fi

  # --- HARD: every userEvent/user.<verb>( interaction must be awaited on its line ---
  # Match interaction calls (user.click(, userEvent.type(, etc.) whose line lacks `await`.
  unawaited="$(grep -nE '(^|[^a-zA-Z0-9_.])(user|userEvent)\.[a-zA-Z]+[[:space:]]*\(' "$f" 2>/dev/null \
                | grep -vE '\bawait\b' \
                | grep -vE '\.setup[[:space:]]*\(' || true)"
  if [ -n "$unawaited" ]; then
    err "$f: user-event interaction not awaited (await user.click/type/...):"
    printf '%s\n' "$unawaited" | sed 's/^/      /'
    problems=$((problems + 1))
  fi

  # --- WARN: testid as the only query (no role/label/text query present) ---
  if grep -Eq 'getByTestId|findByTestId|queryByTestId' "$f"; then
    if ! grep -Eq 'ByRole|ByLabelText|ByText|ByPlaceholderText|ByDisplayValue' "$f"; then
      warn "$f: uses *ByTestId with no role/label/text query — climb the query ladder first"
    fi
  fi

  # --- WARN: raw fireEvent ---
  if grep -Eq '\bfireEvent\.' "$f"; then
    warn "$f: uses fireEvent — prefer userEvent.setup() + await user.* for realistic events"
  fi

  # --- WARN: act( in a component (non-hook) test file ---
  if grep -Eq '(^|[^a-zA-Z0-9_])act[[:space:]]*\(' "$f"; then
    if ! grep -Eq 'renderHook' "$f"; then
      warn "$f: bare act() in a component test — await findBy/waitFor instead"
    fi
  fi

  # --- WARN: setTimeout-based waiting ---
  if grep -Eq '\bsetTimeout[[:space:]]*\(' "$f" && ! grep -Eq 'waitFor|findBy' "$f"; then
    warn "$f: waits with setTimeout and no waitFor/findBy — use waitFor/findBy to retry until ready"
  fi

  if [ "$problems" -eq 0 ]; then
    ok "$f"
  fi
done

printf '\n'
if [ "$EXIT" -eq 0 ]; then
  ok "verify.sh passed"
else
  err "verify.sh found hard violations"
fi
exit "$EXIT"
