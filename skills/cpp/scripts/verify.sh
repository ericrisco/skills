#!/usr/bin/env bash
#
# verify.sh - local quality gate for a CMake C++ project (superset of CI).
#
# Usage:
#   cd <your-project-root>   # the directory containing CMakeLists.txt
#   ./verify.sh
#
# Runs: clang-format (dry-run), a CMake configure+build with warnings-as-errors and
# ASan+UBSan, the test target via ctest, and optional clang-tidy + cppcheck.
# Tools that are not installed are skipped with a yellow warning (not a failure).
# Real problems (format drift, build failure, sanitizer abort, test failure) exit non-zero.
# Read-only: never mutates your source. Only writes under build/verify/.
#
# Portability: runs on stock macOS bash 3.2 (no mapfile, no associative arrays,
# no unguarded array expansions under `set -u`).

set -euo pipefail

# Colors only when stdout is a TTY (keeps logs/CI output clean).
if [ -t 1 ]; then
  YELLOW=$'\033[33m'; RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  YELLOW=''; RED=''; GREEN=''; RESET=''
fi

failed=0
BUILD_DIR="build/verify"

have()  { command -v "$1" >/dev/null 2>&1; }
warn()  { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail()  { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; failed=1; }
ok()    { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
info()  { printf -- '----- %s\n' "$*"; }

# Must run from a CMake project root.
if [ ! -f CMakeLists.txt ]; then
  printf '%serror:%s no CMakeLists.txt in %s - cd into your project root first.\n' \
    "$RED" "$RESET" "$(pwd)" >&2
  exit 2
fi

# Collect tracked C/C++ sources (git if available, else find). Read-only.
collect_sources() {
  if have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files '*.cpp' '*.cc' '*.cxx' '*.hpp' '*.hh' '*.hxx' '*.h' '*.ixx' 2>/dev/null
  else
    find . -path ./"$BUILD_DIR" -prune -o -type f \
      \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' \
         -o -name '*.hpp' -o -name '*.hh' -o -name '*.hxx' \
         -o -name '*.h' -o -name '*.ixx' \) -print 2>/dev/null
  fi
}

# 1. clang-format - dry-run, never rewrites. Empty source set is a clean pass.
info "clang-format"
if have clang-format; then
  srcs="$(collect_sources)"
  if [ -z "$srcs" ]; then
    ok "no C/C++ sources to format"
  else
    fmt_failed=0
    # -Werror + --dry-run makes clang-format exit non-zero on any drift, printing nothing else.
    printf '%s\n' "$srcs" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      clang-format --dry-run -Werror "$f" >/dev/null 2>&1 || printf '%s\n' "$f"
    done > "${TMPDIR:-/tmp}/cpp_verify_fmt.$$" || true
    if [ -s "${TMPDIR:-/tmp}/cpp_verify_fmt.$$" ]; then
      fmt_failed=1
      fail "files need formatting (run: clang-format -i <file>):"
      cat "${TMPDIR:-/tmp}/cpp_verify_fmt.$$"
    fi
    rm -f "${TMPDIR:-/tmp}/cpp_verify_fmt.$$"
    [ "$fmt_failed" -eq 0 ] && ok "clang-format clean"
  fi
else
  warn "clang-format not found (https://clang.llvm.org/docs/ClangFormat.html)"
fi

# 2-4. CMake configure + build under warnings-as-errors + ASan+UBSan, then ctest.
info "cmake configure (ASan+UBSan, warnings-as-errors)"
if have cmake; then
  SAN_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g -Werror"
  if cmake -S . -B "$BUILD_DIR" \
       -DCMAKE_BUILD_TYPE=Debug \
       -DCMAKE_CXX_FLAGS="$SAN_FLAGS" \
       -DCMAKE_EXPORT_COMPILE_COMMANDS=ON >/dev/null 2>&1; then
    ok "configured ($BUILD_DIR)"

    info "cmake build"
    if cmake --build "$BUILD_DIR" >/dev/null 2>&1; then
      ok "build clean (warnings-as-errors)"

      info "ctest"
      if have ctest; then
        # ctest exits non-zero with "No tests were found" when there are none; treat that as a skip.
        ctest_out="$(ctest --test-dir "$BUILD_DIR" --output-on-failure 2>&1 || true)"
        if printf '%s' "$ctest_out" | grep -qi 'no tests were found'; then
          warn "no tests registered with ctest"
        elif printf '%s' "$ctest_out" | grep -qiE 'tests failed|failed out of|errors? while'; then
          fail "ctest reported failures"
          printf '%s\n' "$ctest_out"
        else
          ok "tests pass (ASan+UBSan)"
        fi
      else
        warn "ctest not found (ships with CMake)"
      fi
    else
      fail "build failed (warnings-as-errors / sanitizer compile error)"
    fi
  else
    fail "cmake configure failed"
  fi
else
  warn "cmake not found - cannot build/test (https://cmake.org/download/)"
fi

# 5. clang-tidy - optional; reads compile_commands.json from the build dir.
info "clang-tidy"
if have clang-tidy && [ -f "$BUILD_DIR/compile_commands.json" ]; then
  srcs="$(collect_sources | grep -E '\.(cpp|cc|cxx)$' || true)"
  if [ -z "$srcs" ]; then
    warn "no translation units for clang-tidy"
  else
    tidy_failed=0
    printf '%s\n' "$srcs" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      clang-tidy -p "$BUILD_DIR" "$f" >/dev/null 2>&1 || printf '%s\n' "$f"
    done > "${TMPDIR:-/tmp}/cpp_verify_tidy.$$" || true
    if [ -s "${TMPDIR:-/tmp}/cpp_verify_tidy.$$" ]; then
      tidy_failed=1
      fail "clang-tidy reported issues in:"
      cat "${TMPDIR:-/tmp}/cpp_verify_tidy.$$"
    fi
    rm -f "${TMPDIR:-/tmp}/cpp_verify_tidy.$$"
    [ "$tidy_failed" -eq 0 ] && ok "clang-tidy clean"
  fi
else
  warn "clang-tidy not found or no compile_commands.json (optional)"
fi

# 6. cppcheck - optional static analysis.
info "cppcheck"
if have cppcheck; then
  if [ -f "$BUILD_DIR/compile_commands.json" ]; then
    if cppcheck --enable=warning,performance --error-exitcode=1 \
         --project="$BUILD_DIR/compile_commands.json" >/dev/null 2>&1; then
      ok "cppcheck clean"
    else
      fail "cppcheck reported issues"
    fi
  else
    warn "cppcheck: no compile_commands.json to analyze"
  fi
else
  warn "cppcheck not found (optional)"
fi

echo
if [ "$failed" -ne 0 ]; then
  printf '%sFAIL:%s one or more checks failed.\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s all checks passed.\n' "$GREEN" "$RESET"
