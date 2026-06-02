#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NAME
#   verify.sh — stripe integration static linter
#
# USAGE
#   ./verify.sh [TARGET]
#   TARGET is a file or directory (default: current directory). Run it against
#   the source that wires your app to Stripe. READ-ONLY: it never edits files.
#
# WHAT IT CHECKS (FAIL on any violation)
#   1. Hard-coded sk_live_ / sk_test_ / whsec_ literals in source.
#   2. A webhook handler (uses constructEvent / handles stripe-signature) that
#      also applies JSON body parsing on that route — the raw-body violation
#      that yields "No signatures found matching the expected signature".
#   3. A webhook route present with NO signature verification at all.
#   4. A Stripe client constructed with no explicit apiVersion pin.
#
# GUARANTEES
#   - Read-only and idempotent; writes nothing to the target.
#   - Exit 0 on a clean OR empty/no-Stripe target (never a false failure).
#   - No network. Portable to stock macOS bash 3.2.
#
# EXIT CODES
#   0  No violations (clean, or nothing Stripe-related found).
#   1  At least one violation.
# ============================================================================

TARGET="${1:-.}"

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
if [ -n "${NO_COLOR:-}" ]; then RED=""; YEL=""; GRN=""; RST=""; fi

FAILED=0
bad()  { printf '%s[FAIL]%s %s\n' "$RED" "$RST" "$*" >&2; FAILED=1; }
ok()   { printf '%s[ok]%s %s\n'   "$GRN" "$RST" "$*"; }
info() { printf '%s[info]%s %s\n' "$YEL" "$RST" "$*"; }

if [ ! -e "$TARGET" ]; then
  info "target '$TARGET' does not exist; nothing to check"
  exit 0
fi

# Collect candidate source files (JS/TS family). Skip vendored/build dirs.
FILES=""
if [ -f "$TARGET" ]; then
  FILES="$TARGET"
else
  FILES=$(find "$TARGET" \
    \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .next \) -prune -o \
    -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' \) -print 2>/dev/null || true)
fi

if [ -z "$FILES" ]; then
  info "no JS/TS source files under '$TARGET'; nothing to check"
  exit 0
fi

# --- 1. Hard-coded keys -----------------------------------------------------
# Match real Stripe key prefixes followed by a body char. Documentation/example
# placeholders like sk_test_... or sk_test_xxx are ignored.
KEY_HITS=$(grep -REn "(sk_live|sk_test|whsec)_[A-Za-z0-9]{6,}" $FILES 2>/dev/null | grep -Ev "x{6,}|\.\.\.|YOUR_|<|placeholder" || true)
if [ -n "$KEY_HITS" ]; then
  bad "hard-coded Stripe key literal(s) — read from env instead:"
  printf '%s\n' "$KEY_HITS" >&2
else
  ok "no hard-coded Stripe key literals"
fi

# --- Identify webhook-handling files ----------------------------------------
# A file is "webhook-related" if it references the stripe-signature header or
# the constructEvent API.
WEBHOOK_FILES=""
for f in $FILES; do
  if grep -Eqi "stripe-signature|constructEvent" "$f" 2>/dev/null; then
    WEBHOOK_FILES="$WEBHOOK_FILES $f"
  fi
done

if [ -z "$WEBHOOK_FILES" ]; then
  info "no Stripe webhook handler found; skipped webhook checks"
else
  for f in $WEBHOOK_FILES; do
    # 2. raw-body violation: JSON parsing on a route that also verifies.
    if grep -Eqi "express\.json|bodyParser\.json|req\.json\(\)|await\s+req\.json|res\.json" "$f" 2>/dev/null \
       && grep -Eqi "express\.json\(\)|bodyParser\.json|req\.json\(\)|await\s+req\.json" "$f" 2>/dev/null; then
      bad "$f: webhook handler parses JSON body (express.json/req.json) — breaks signature verification; use raw body (express.raw / await req.text())"
    fi

    # 3. signature verification present?
    if grep -Eqi "constructEvent" "$f" 2>/dev/null; then
      ok "$f: verifies webhook signature (constructEvent)"
    else
      bad "$f: handles stripe-signature but never calls constructEvent — unverified webhook"
    fi
  done
fi

# --- 4. apiVersion pin on the Stripe client ---------------------------------
# For each file that constructs `new Stripe(`, require an apiVersion within the
# same file.
CLIENT_FILES=""
for f in $FILES; do
  if grep -Eq "new\s+Stripe\s*\(" "$f" 2>/dev/null; then
    CLIENT_FILES="$CLIENT_FILES $f"
  fi
done

if [ -z "$CLIENT_FILES" ]; then
  info "no 'new Stripe(' client construction found; skipped apiVersion check"
else
  for f in $CLIENT_FILES; do
    if grep -Eq "apiVersion" "$f" 2>/dev/null; then
      ok "$f: Stripe client pins apiVersion"
    else
      bad "$f: 'new Stripe(' without an explicit apiVersion pin"
    fi
  done
fi

# --- Summary ----------------------------------------------------------------
printf '\n'
if [ "$FAILED" -eq 0 ]; then
  ok "PASS — no Stripe integration violations"
else
  printf '%sFAIL — Stripe integration violations above%s\n' "$RED" "$RST" >&2
fi
exit "$FAILED"
