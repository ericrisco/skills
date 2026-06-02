#!/usr/bin/env bash
# verify.sh — lint a fly.toml. Read-only. Exits 0 on a clean/empty target.
#
# Usage: scripts/verify.sh [path/to/fly.toml]   (defaults to ./fly.toml)
#
# Prefers `fly config validate` when flyctl is on PATH; otherwise runs
# structural grep checks. Prints PASS:/FAIL: lines; nonzero exit on any FAIL.

set -u

TARGET="${1:-fly.toml}"
fails=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }
info() { printf 'INFO: %s\n' "$1"; }

# Empty/clean target: nothing to lint, do not invent a failure.
if [ ! -e "$TARGET" ]; then
  info "no fly.toml at '$TARGET' — nothing to verify"
  exit 0
fi
if [ ! -s "$TARGET" ]; then
  info "'$TARGET' is empty — nothing to verify"
  exit 0
fi

pass "found $TARGET"

# Prefer the real validator when available.
FLY_BIN=""
if command -v fly >/dev/null 2>&1; then
  FLY_BIN="fly"
elif command -v flyctl >/dev/null 2>&1; then
  FLY_BIN="flyctl"
fi

if [ -n "$FLY_BIN" ]; then
  info "$FLY_BIN on PATH — running '$FLY_BIN config validate'"
  if "$FLY_BIN" config validate --config "$TARGET" >/dev/null 2>&1; then
    pass "$FLY_BIN config validate"
  else
    fail "$FLY_BIN config validate reported errors (run '$FLY_BIN config validate --config $TARGET')"
  fi
  [ "$fails" -eq 0 ] && exit 0 || exit 1
fi

info "flyctl not found — falling back to structural checks"

# app = "..."
if grep -Eq '^[[:space:]]*app[[:space:]]*=' "$TARGET"; then
  pass "app is set"
else
  fail "missing top-level 'app ='"
fi

# primary_region = "..."
if grep -Eq '^[[:space:]]*primary_region[[:space:]]*=' "$TARGET"; then
  pass "primary_region is set"
else
  fail "missing 'primary_region ='"
fi

# an internal_port under [http_service] or [[services]]
if grep -Eq '^[[:space:]]*internal_port[[:space:]]*=' "$TARGET"; then
  pass "internal_port is defined"
else
  fail "no 'internal_port' found (expected under [http_service] or [[services]])"
fi

# autostop pair lint: if either key present, both must be present
has_stop=0; has_start=0
grep -Eq '^[[:space:]]*auto_stop_machines[[:space:]]*='  "$TARGET" && has_stop=1
grep -Eq '^[[:space:]]*auto_start_machines[[:space:]]*=' "$TARGET" && has_start=1
if [ "$has_stop" -eq 1 ] || [ "$has_start" -eq 1 ]; then
  if [ "$has_stop" -eq 1 ] && [ "$has_start" -eq 1 ]; then
    pass "auto_stop_machines and auto_start_machines set together"
  else
    fail "set auto_stop_machines and auto_start_machines together (only one is present)"
  fi
else
  info "no autostop keys — skipping pair lint"
fi

if [ "$fails" -eq 0 ]; then
  printf '\nOK: %s passed structural checks\n' "$TARGET"
  exit 0
fi
printf '\n%d check(s) failed\n' "$fails"
exit 1
