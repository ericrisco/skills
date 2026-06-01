#!/usr/bin/env bash
# verify.sh — Flutter/Dart project quality gate.
#
# Run from the root of a Flutter (or pure-Dart) project:
#   bash scripts/verify.sh
#
# Runs, in order: dart format check, dart analyze, build_runner codegen
# (only if build_runner is a dependency), and the test suite with coverage.
#
# Missing tools are SKIPPED with a yellow warning (never fail the run).
# A gate that runs and reports problems causes a non-zero exit. All gates
# run even if an earlier one fails, so you see every problem at once.
set -euo pipefail

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
if [[ ! -f pubspec.yaml ]]; then
  warn "no pubspec.yaml in $PWD — not a Flutter/Dart project; skipping"
  exit 0
fi

has_dart=false
has_flutter=false
have dart && has_dart=true
have flutter && has_flutter=true

if ! $has_dart && ! $has_flutter; then
  warn "neither 'dart' nor 'flutter' on PATH — install the Flutter SDK; skipping all checks"
  exit 0
fi

# 1. Formatting gate.
if $has_dart; then
  info "dart format (check only)"
  if ! dart format --output=none --set-exit-if-changed .; then
    fail "code is not formatted — run: dart format ."
  fi
else
  warn "dart not found — skipping format check"
fi

# 2. Static analysis gate.
if $has_dart; then
  info "dart analyze --fatal-infos"
  if ! dart analyze --fatal-infos; then
    fail "static analysis reported issues"
  fi
else
  warn "dart not found — skipping analyze"
fi

# 3. Code generation (only if build_runner is a dependency).
if grep -Eq '^\s*build_runner\s*:' pubspec.yaml; then
  if $has_dart; then
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

# 4. Tests with coverage.
if $has_flutter; then
  info "flutter test --coverage"
  if ! flutter test --coverage; then
    fail "tests failed"
  fi
elif $has_dart; then
  info "dart test (pure-Dart package — no flutter on PATH)"
  if ! dart test; then
    fail "tests failed"
  fi
else
  warn "no test runner available — skipping tests"
fi

# Summary.
if [[ "$errors" -gt 0 ]]; then
  printf '%s%d gate(s) failed.%s\n' "$RED" "$errors" "$RESET"
  exit 1
fi
printf '%sall checks passed.%s\n' "$GREEN" "$RESET"
