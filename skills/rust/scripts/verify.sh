#!/usr/bin/env bash
#
# verify.sh - local quality gate for a Rust crate/workspace (superset of CI).
#
# Usage:
#   cd <your-crate-root>      # the directory containing Cargo.toml
#   ./verify.sh
#
# Runs: cargo fmt --check, cargo clippy -D warnings, cargo test, and cargo audit (if installed).
# Read-only: it never mutates your source.
# Degrades gracefully: if there is no Cargo.toml or no `cargo` on PATH, it prints a skip
# note and exits 0 (a clean/empty target is not a failure). Tools that are not installed
# are skipped with a warning, not a failure. Real problems exit non-zero.
#
# Portability: stock macOS bash 3.2 (no mapfile, no associative arrays).

set -euo pipefail

# Colors only when stdout is a TTY (keeps logs/CI output clean).
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

# No manifest? Nothing to verify - skip cleanly (do not fail an empty target).
if [ ! -f Cargo.toml ]; then
  warn "no Cargo.toml in $(pwd) - nothing to verify (cd into your crate root to run the gate)."
  exit 0
fi

# No toolchain? Skip cleanly.
if ! have cargo; then
  warn "cargo not found - install the Rust toolchain (https://rustup.rs) to run the gate."
  exit 0
fi

# 1. cargo fmt --check - formatting is non-negotiable; --check never rewrites files.
info "cargo fmt --check"
if cargo fmt --all -- --check; then
  ok "formatting clean"
else
  fail "unformatted code (run: cargo fmt --all)"
fi

# 2. cargo clippy -D warnings - lints are correctness gates here, not style suggestions.
info "cargo clippy -- -D warnings"
if have cargo-clippy || cargo clippy --version >/dev/null 2>&1; then
  if cargo clippy --all-targets --all-features -- -D warnings; then
    ok "clippy clean"
  else
    fail "clippy reported warnings/errors"
  fi
else
  warn "clippy not found (rustup component add clippy)"
fi

# 3. cargo test - unit + integration; add --doc separately for doctests if desired.
info "cargo test"
if cargo test --all-targets; then
  ok "tests pass"
else
  fail "tests failed"
fi

# 4. cargo audit - optional; RustSec advisory findings are a real failure.
info "cargo audit"
if have cargo-audit || cargo audit --version >/dev/null 2>&1; then
  if cargo audit; then
    ok "no known vulnerabilities"
  else
    fail "cargo audit found advisories"
  fi
else
  warn "cargo audit not found (cargo install cargo-audit)"
fi

echo
if [ "$failed" -ne 0 ]; then
  printf '%sFAIL:%s one or more checks failed.\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s all checks passed.\n' "$GREEN" "$RESET"
