#!/usr/bin/env bash
# verify.sh — Flutter/Dart project quality gate.
#
# Run from the root of a Flutter (or pure-Dart) project:
#   bash scripts/verify.sh
#
# Runs, in order: dart format check, build_runner codegen (only if build_runner
# is a dependency), dart analyze, then the test suite with coverage.
#
# Codegen runs BEFORE analyze on purpose: on a fresh checkout the ungenerated
# .g.dart / .freezed.dart 'part' files would otherwise make analyze fail for the
# wrong reason. Generating first means analyze sees a complete tree.
#
# Missing tools are SKIPPED with a yellow warning (never fail the run). A gate
# that runs and finds real problems causes a non-zero exit. All gates run even
# if an earlier one fails, so you see every problem at once.
#
# Portable to stock macOS bash 3.2 (no mapfile, no arrays, no associative maps).
set -eu

YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
RESET=$'\033[0m'

errors=0

warn() { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$1"; }
info() { printf '==> %s\n' "$1"; }
fail() { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$1"; errors=$((errors + 1)); }
have() { command -v "$1" >/dev/null 2>&1; }

# Guard: only meaningful inside a Dart/Flutter project.
if [ ! -f pubspec.yaml ]; then
  warn "no pubspec.yaml in $PWD — not a Flutter/Dart project; skipping"
  exit 0
fi

has_dart=false
has_flutter=false
have dart && has_dart=true
have flutter && has_flutter=true

if [ "$has_dart" = false ] && [ "$has_flutter" = false ]; then
  warn "neither 'dart' nor 'flutter' on PATH — install the Flutter SDK; skipping all checks"
  exit 0
fi

# 1. Formatting gate.
if [ "$has_dart" = true ]; then
  info "dart format (check only)"
  if ! dart format --output=none --set-exit-if-changed .; then
    fail "code is not formatted — run: dart format ."
  fi
else
  warn "dart not found — skipping format check"
fi

# 2. Code generation (only if build_runner is a dependency). Runs BEFORE analyze
#    so generated 'part' files exist when the analyzer reads the tree.
if grep -Eq '^[[:space:]]*build_runner[[:space:]]*:' pubspec.yaml; then
  if [ "$has_dart" = true ]; then
    info "build_runner codegen"
    if ! dart run build_runner build --delete-conflicting-outputs; then
      fail "build_runner failed — generated files may be stale"
    fi
  else
    warn "dart not found — skipping build_runner"
  fi
else
  info "build_runner not a dependency — skipping codegen"
fi

# 3. Static analysis gate.
if [ "$has_dart" = true ]; then
  info "dart analyze --fatal-infos"
  if ! dart analyze --fatal-infos; then
    fail "static analysis reported issues"
  fi
else
  warn "dart not found — skipping analyze"
fi

# 4. Tests with coverage.
if [ "$has_flutter" = true ]; then
  info "flutter test --coverage"
  if ! flutter test --coverage; then
    fail "tests failed"
  fi
elif [ "$has_dart" = true ]; then
  info "dart test (pure-Dart package — no flutter on PATH)"
  if ! dart test; then
    fail "tests failed"
  fi
else
  warn "no test runner available — skipping tests"
fi

# Summary.
if [ "$errors" -gt 0 ]; then
  printf '%s%d gate(s) failed.%s\n' "$RED" "$errors" "$RESET"
  exit 1
fi
printf '%sall checks passed.%s\n' "$GREEN" "$RESET"
