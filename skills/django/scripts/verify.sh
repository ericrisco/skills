#!/usr/bin/env bash
#
# verify.sh — read-only foot-gun lint for a Django project.
#
# Usage:
#   ./scripts/verify.sh [TARGET_PATH]      # default: current directory
#
# Greps tracked Django source for high-signal mistakes. It NEVER edits anything and
# NEVER runs the project; it only reads files. This is a lint, not a replacement for
# `python manage.py check --deploy` or the test suite.
#
# Exit codes:
#   0  clean, empty target, or warnings only
#   2  at least one FAIL-level finding
#
# FAIL  literal SECRET_KEY in source; ALLOWED_HOSTS = ['*']; f-string/%-built SQL
#       passed to .raw()/.extra()/cursor.execute
# WARN  DEBUG = True outside a *dev*/*local* settings file; ModelViewSet/APIView with
#       no permission_classes nearby
#
# Compatible with stock macOS bash 3.2: no mapfile, no associative arrays, find-based
# file discovery, every array access guarded so `set -u` never trips.

set -euo pipefail

TARGET="${1:-.}"

if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi
warn() { printf '%sWARN%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%sFAIL%s %s\n' "$RED" "$RESET" "$*"; }
ok()   { printf '%s%s%s\n' "$GREEN" "$*" "$RESET"; }

FAILS=0
WARNS=0

# A Django project is present if there is a manage.py, a settings file, or any *.py.
# With none of those there is nothing to lint, so exit 0 (no false failure on empty).
django_present() {
  if [ -f "$TARGET/manage.py" ]; then return 0; fi
  if [ -n "$(find "$TARGET" -type f -name 'settings*.py' -print -quit 2>/dev/null)" ]; then return 0; fi
  if [ -n "$(find "$TARGET" -type f -name '*.py' -print -quit 2>/dev/null)" ]; then return 0; fi
  return 1
}

if ! django_present; then
  ok "verify.sh: ok (no Django/Python source under '${TARGET}', nothing to lint)"
  exit 0
fi

# grep helpers: -E extended regex, -r recursive, -n line numbers, -I skip binary.
# Restrict to .py for code checks. Suppress grep's exit status (it is informational).
gpy() { grep -REnI --include='*.py' "$1" "$TARGET" 2>/dev/null || true; }

# --- FAIL: literal SECRET_KEY assignment to a string literal ---
HITS="$(gpy '^[[:space:]]*SECRET_KEY[[:space:]]*=[[:space:]]*["'\'']' | grep -v 'os\.environ\|getenv\|config(\|env(' || true)"
if [ -n "$HITS" ]; then
  fail "SECRET_KEY assigned a literal string (read it from os.environ instead):"
  printf '%s\n' "$HITS"
  FAILS=$((FAILS + 1))
fi

# --- FAIL: ALLOWED_HOSTS = ['*'] (any quote/spacing) ---
HITS="$(gpy 'ALLOWED_HOSTS[[:space:]]*=[[:space:]]*\[[[:space:]]*["'\'']\*["'\'']' || true)"
if [ -n "$HITS" ]; then
  fail "ALLOWED_HOSTS allows every host ('*') — list explicit domains:"
  printf '%s\n' "$HITS"
  FAILS=$((FAILS + 1))
fi

# --- FAIL: f-string / %-built SQL into .raw()/.extra()/cursor.execute ---
HITS="$(gpy '(\.raw|\.extra|cursor\.execute)\([[:space:]]*(f["'\'']|["'\''].*%[^s])' || true)"
if [ -n "$HITS" ]; then
  fail "SQL string interpolation into .raw()/.extra()/cursor.execute (use params, not f-strings/%):"
  printf '%s\n' "$HITS"
  FAILS=$((FAILS + 1))
fi

# --- WARN: DEBUG = True outside a dev/local settings file ---
DEBUG_HITS="$(gpy '^[[:space:]]*DEBUG[[:space:]]*=[[:space:]]*True' || true)"
if [ -n "$DEBUG_HITS" ]; then
  # Drop lines whose file path looks like a dev/local/test settings module.
  NONDEV="$(printf '%s\n' "$DEBUG_HITS" | grep -vEi '(dev|local|test)' || true)"
  if [ -n "$NONDEV" ]; then
    warn "DEBUG = True outside a dev/local settings file (must be False in prod):"
    printf '%s\n' "$NONDEV"
    WARNS=$((WARNS + 1))
  fi
fi

# --- WARN: ModelViewSet / APIView subclasses with no permission_classes nearby ---
# Heuristic: a file that defines such a class but never mentions permission_classes.
VS_FILES="$(grep -rlEI --include='*.py' '(ModelViewSet|ReadOnlyModelViewSet|viewsets\.GenericViewSet|APIView)' "$TARGET" 2>/dev/null || true)"
if [ -n "$VS_FILES" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! grep -qE 'permission_classes' "$f" 2>/dev/null; then
      warn "no permission_classes in a viewset/APIView file (endpoint may be open): $f"
      WARNS=$((WARNS + 1))
    fi
  done <<EOF
$VS_FILES
EOF
fi

printf '\n%d fail, %d warn\n' "$FAILS" "$WARNS"
if [ "$FAILS" -gt 0 ]; then
  fail "verify.sh: foot-guns detected"
  exit 2
fi
ok "verify.sh: ok"
exit 0
