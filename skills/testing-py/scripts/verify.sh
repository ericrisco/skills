#!/usr/bin/env bash
set -euo pipefail

# verify.sh — testing-py static gate.
#
# Read-only lint over a Python test tree. It NEVER runs the tests, NEVER imports
# anything, and NEVER writes a file. It greps for the false-green patterns this
# skill bans and prints file:line for each hit.
#
# What it flags:
#   1. .patch( / mock.patch( / mocker.patch( WITHOUT autospec= / spec= / spec_set=
#      on the same logical call  -> mocks that pass on typos and signature drift.
#   2. A --cov invocation that lacks --cov-branch, AND no `branch = true` /
#      `--cov-branch` anywhere in pyproject.toml / .coveragerc / setup.cfg
#      -> 100% lines, untested branches.
#   3. time.sleep( inside test files  -> flaky-by-design.
#   4. assert True  /  pytest.skip( with no reason  /  empty test bodies (def test_*(): pass)
#      -> tests that can never fail or never run.
#
# Exit: non-zero if any hit; 0 when clean OR when the target has no test files
# (an empty / missing tree is a clean skip, never a false failure).
#
# Portable to stock macOS bash 3.2: no mapfile, no associative arrays; arrays are
# initialised so they expand safely under `set -u`.

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

TARGET="${1:-tests}"

if [ ! -e "$TARGET" ]; then
  skip "target '$TARGET' does not exist — nothing to lint"
  exit 0
fi

# Collect Python test files. A bare file arg is scanned directly even if unnamed.
FILES=()
if [ -d "$TARGET" ]; then
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(find "$TARGET" -type f \( -name 'test_*.py' -o -name '*_test.py' -o -name 'conftest.py' \) -print0 2>/dev/null)
elif [ -f "$TARGET" ]; then
  FILES+=("$TARGET")
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  skip "no test files under '$TARGET' (test_*.py / *_test.py / conftest.py) — clean"
  exit 0
fi

# ---- 1. patch/mock without autospec/spec/spec_set ----
# A patch call is suspect when the same physical line has a patch( and none of
# autospec= / spec= / spec_set=. Multi-line patch calls are a known false-negative;
# this gate targets the common single-line form.
for f in "${FILES[@]}"; do
  while IFS=: read -r ln _; do
    [ -n "${ln:-}" ] && fail "$f:$ln: patch() without autospec=/spec=/spec_set= (false-green risk)"
  done < <(grep -nE '(mock\.|mocker\.|[^A-Za-z_])patch\(' "$f" 2>/dev/null \
             | grep -Ev 'autospec=|spec=|spec_set=' \
             | grep -Ev '^[[:space:]]*#' \
             | cut -d: -f1 | sed 's/$/:/' )
done

# ---- 2. time.sleep( in test files ----
for f in "${FILES[@]}"; do
  while IFS=: read -r ln _; do
    [ -n "${ln:-}" ] && fail "$f:$ln: time.sleep() in a test (flaky-by-design; fake the clock)"
  done < <(grep -nE 'time\.sleep\(|[^A-Za-z_]sleep\(' "$f" 2>/dev/null | cut -d: -f1 | sed 's/$/:/')
done

# ---- 3. no-op tests ----
for f in "${FILES[@]}"; do
  while IFS=: read -r ln _; do
    [ -n "${ln:-}" ] && fail "$f:$ln: assert True / no-op assertion (a test that can never fail)"
  done < <(grep -nE 'assert[[:space:]]+True[[:space:]]*$|assert[[:space:]]+True[[:space:]]*#' "$f" 2>/dev/null | cut -d: -f1 | sed 's/$/:/')
  # pytest.skip( with no reason string
  while IFS=: read -r ln _; do
    [ -n "${ln:-}" ] && fail "$f:$ln: pytest.skip() with no reason"
  done < <(grep -nE 'pytest\.skip\([[:space:]]*\)' "$f" 2>/dev/null | cut -d: -f1 | sed 's/$/:/')
  # def test_*(...): pass  on one line
  while IFS=: read -r ln _; do
    [ -n "${ln:-}" ] && fail "$f:$ln: empty test body (def test_*(): pass)"
  done < <(grep -nE 'def[[:space:]]+test_[A-Za-z0-9_]*\([^)]*\)[[:space:]]*:[[:space:]]*pass[[:space:]]*$' "$f" 2>/dev/null | cut -d: -f1 | sed 's/$/:/')
done

# ---- 4. --cov without --cov-branch (config-aware) ----
# Only meaningful if a --cov invocation is present somewhere in the target's scope
# or its config. We look at the test files plus the usual config files near them.
CONFIG_HAS_BRANCH=0
SEARCH_ROOTS=()
if [ -d "$TARGET" ]; then SEARCH_ROOTS+=("$TARGET" "$TARGET/.."); else SEARCH_ROOTS+=("$(dirname "$TARGET")"); fi
for root in "${SEARCH_ROOTS[@]}"; do
  for cfg in "$root/pyproject.toml" "$root/.coveragerc" "$root/setup.cfg" "$root/tox.ini"; do
    if [ -f "$cfg" ] && grep -Eq 'branch[[:space:]]*=[[:space:]]*[Tt]rue|--cov-branch' "$cfg" 2>/dev/null; then
      CONFIG_HAS_BRANCH=1
    fi
  done
done

if [ "$CONFIG_HAS_BRANCH" -eq 0 ]; then
  for f in "${FILES[@]}"; do
    while IFS=: read -r ln _; do
      [ -n "${ln:-}" ] && fail "$f:$ln: --cov without --cov-branch and no branch=true in config (line coverage lies)"
    done < <(grep -nE -- '--cov[=[:space:]]' "$f" 2>/dev/null | grep -Ev -- '--cov-branch' | cut -d: -f1 | sed 's/$/:/')
  done
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then
  ok "verify.sh passed — no banned test patterns in '$TARGET' (${#FILES[@]} files)"
else
  fail "verify.sh found banned test patterns"
fi
exit "$EXIT"
