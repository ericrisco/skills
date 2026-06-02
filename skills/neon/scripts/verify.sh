#!/usr/bin/env bash
# verify.sh — static Neon foot-gun scan. Read-only, no network, no DB.
# Usage: verify.sh [TARGET_DIR]   (defaults to current directory)
# Exit 0 when clean or no Neon usage found; non-zero only on a hard FAIL.
set -uo pipefail

TARGET="${1:-.}"
fails=0

say()  { printf '%s\n' "$*"; }
pass() { say "PASS: $*"; }
warn() { say "WARN: $*"; }
fail() { say "FAIL: $*"; fails=$((fails+1)); }

# Files that actually reference Neon — keeps the scan scoped and avoids false hits.
# Portable across bash 3.2 (macOS) and 4+: newline-separated, then filter by grep.
neon_files=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if grep -qE '@neondatabase/serverless|neon\.tech' "$f" 2>/dev/null; then
    neon_files+=("$f")
  fi
done < <(
  find "$TARGET" \
    -type d \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .next \) -prune -o \
    -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.env' -o -name '.env*' \) -print 2>/dev/null
)

if [ "${#neon_files[@]}" -eq 0 ]; then
  say "no Neon usage found — nothing to check"
  exit 0
fi

# (a) WebSocket Pool/Client created at module/top scope (heuristic: `new Pool(`/`new Client(`
#     on a line with no leading indentation, i.e. not inside a function/handler block).
for f in "${neon_files[@]}"; do
  if grep -nE '^(export +)?(const|let|var) +[A-Za-z0-9_]+ *= *new +(Pool|Client) *\(' "$f" >/dev/null 2>&1; then
    while IFS= read -r line; do
      fail "module-scope WebSocket Pool/Client in $f -> $line (move inside the request handler; it leaks connections)"
    done < <(grep -nE '^(export +)?(const|let|var) +[A-Za-z0-9_]+ *= *new +(Pool|Client) *\(' "$f")
  fi
done

# (b) pooled string in a migration config, or a non-pooler Neon host used as the app DATABASE_URL.
for f in "${neon_files[@]}"; do
  base="$(basename "$f")"
  case "$base" in
    *migrat*|drizzle.config.*|knexfile.*|*.env.migrat*)
      if grep -nE '-pooler\.[^ "'\'']*neon\.tech' "$f" >/dev/null 2>&1; then
        warn "pooled (-pooler) host in migration config $f (migrations/DDL need the DIRECT string)"
      fi
      ;;
  esac
  # App DATABASE_URL pointing at a non-pooler Neon host.
  if grep -nE 'DATABASE_URL *= *.*[^-]neon\.tech' "$f" 2>/dev/null | grep -vqE '\-pooler\.' ; then
    if grep -nE 'DATABASE_URL *= *.*[a-z0-9-]+\.[a-z0-9-]*\.?neon\.tech' "$f" 2>/dev/null | grep -vqE '\-pooler' ; then
      warn "DATABASE_URL uses a non -pooler Neon host in $f (app runtime should use the POOLED string)"
    fi
  fi
done

# (c) `ws` imported but neonConfig.webSocketConstructor never assigned (Node <=21 will fail silently).
for f in "${neon_files[@]}"; do
  if grep -qE "(import +ws +from +['\"]ws['\"]|require\(['\"]ws['\"]\))" "$f" 2>/dev/null; then
    if ! grep -qE 'neonConfig\.webSocketConstructor *=' "$f" 2>/dev/null; then
      warn "ws imported without neonConfig.webSocketConstructor in $f (required on Node <=21)"
    fi
  fi
done

if [ "$fails" -gt 0 ]; then
  say "---"
  say "$fails hard failure(s)."
  exit 1
fi
say "---"
say "no hard failures."
exit 0
