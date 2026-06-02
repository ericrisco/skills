#!/usr/bin/env bash
# verify.sh — Supabase repo footgun gate.
#
# Usage:
#   bash scripts/verify.sh [TARGET_DIR]    # defaults to the current directory
#
# Read-only: it only greps the working tree, writes nothing, makes no network
# calls, runs no installs. Safe to re-run and safe in CI / pre-commit.
#
# Exit codes:
#   0  clean, OR only warnings found, OR target has no relevant files (no false failure)
#   1  HARD violation: a service_role / sb_secret_ key string in a client-reachable file
#
# Checks:
#   HARD  service_role / sb_secret_ in a file that is client-reachable
#         (contains "use client", or lives under app/ pages/ components/ src/components/)
#   WARN  getSession() used in server/middleware code for gating
#   WARN  create policy referencing bare auth.uid()/auth.jwt() without (select ...)
#   WARN  create table in a migration with no nearby `enable row level security`
#
# Targets stock macOS bash 3.2: no mapfile, no associative arrays, arrays
# initialised before use, set -e intentionally off (each check owns its status).

set -u

TARGET="${1:-.}"

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

hard=0
warns=0

hardfail() { printf '%s\n' "${RED}LEAK: $1${RESET}"; hard=$((hard + 1)); }
warn()     { printf '%s\n' "${YELLOW}WARN: $1${RESET}"; warns=$((warns + 1)); }
ok()       { printf '%s\n' "${GREEN}OK: $1${RESET}"; }

if [ ! -d "$TARGET" ]; then
  printf '%s\n' "${YELLOW}SKIP: target '$TARGET' is not a directory; nothing to check.${RESET}"
  exit 0
fi

# Collect candidate source files (exclude vendor/build/VCS dirs). Newline-delimited.
# `|| true` so an empty match never trips set -e-like behaviour.
files="$(find "$TARGET" \
  \( -name node_modules -o -name .git -o -name .next -o -name dist -o -name build -o -name .vercel \) -prune -o \
  -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.sql' -o -name '*.env*' \) -print \
  2>/dev/null || true)"

if [ -z "$files" ]; then
  ok "no JS/TS/SQL/env files under '$TARGET' — nothing to verify."
  exit 0
fi

# --- HARD: service_role / sb_secret_ in client-reachable files ----------------
# A file is client-reachable if it declares "use client" OR sits in a client path.
printf '%s\n' "$files" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -Eqi 'service_?role|sb_secret_' "$f" 2>/dev/null || continue
  client=0
  grep -q '"use client"' "$f" 2>/dev/null && client=1
  case "$f" in
    */components/*|*/src/components/*|*/pages/*) client=1 ;;
  esac
  # app/ is client-reachable except server-only files (route handlers / actions are
  # ambiguous; flag and let the human confirm) — be conservative: only flag app/ when
  # the file also imports the browser client or declares use client.
  case "$f" in
    */app/*) grep -Eq '"use client"|createBrowserClient' "$f" 2>/dev/null && client=1 ;;
  esac
  if [ "$client" -eq 1 ]; then
    printf 'HARDHIT\t%s\n' "$f"
  fi
done > /tmp/supabase_verify_hard.$$ 2>/dev/null || true

while IFS= read -r line; do
  [ -n "$line" ] || continue
  f="${line#HARDHIT	}"
  hardfail "service_role/sb_secret_ in client-reachable file: $f"
done < /tmp/supabase_verify_hard.$$
rm -f /tmp/supabase_verify_hard.$$ 2>/dev/null || true

# --- WARN: getSession() in server/middleware code -----------------------------
printf '%s\n' "$files" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    *middleware.*|*/server.ts|*/server.tsx|*/app/*|*/lib/*) ;;
    *) continue ;;
  esac
  grep -q 'getSession(' "$f" 2>/dev/null && printf 'WARNHIT\t%s\n' "$f"
done > /tmp/supabase_verify_w1.$$ 2>/dev/null || true
while IFS= read -r line; do
  [ -n "$line" ] || continue
  f="${line#WARNHIT	}"
  warn "getSession() in server/middleware file (use getClaims() for authorization; getUser() only for live ban/delete detection): $f"
done < /tmp/supabase_verify_w1.$$
rm -f /tmp/supabase_verify_w1.$$ 2>/dev/null || true

# --- WARN: create policy with bare auth.uid()/auth.jwt() ----------------------
# Heuristic: a .sql file that has create policy AND a bare auth.uid()/auth.jwt()
# not preceded by `select `. Per-file granularity (line context is unreliable in bash 3.2).
printf '%s\n' "$files" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in *.sql) ;; *) continue ;; esac
  grep -qi 'create policy' "$f" 2>/dev/null || continue
  # bare call = auth.uid()/auth.jwt() that is NOT immediately preceded by "select "
  if grep -Eiq '(^|[^t][^ ]?)(auth\.(uid|jwt)\(\))' "$f" 2>/dev/null \
     && grep -Eiq '[^(] *auth\.(uid|jwt)\(\)' "$f" 2>/dev/null \
     && ! grep -Eiq 'select +auth\.(uid|jwt)\(\)' "$f" 2>/dev/null; then
    printf 'WARNHIT\t%s\n' "$f"
  fi
done > /tmp/supabase_verify_w2.$$ 2>/dev/null || true
while IFS= read -r line; do
  [ -n "$line" ] || continue
  f="${line#WARNHIT	}"
  warn "policy uses bare auth.uid()/auth.jwt() — wrap as (select auth.uid()) for per-statement caching: $f"
done < /tmp/supabase_verify_w2.$$
rm -f /tmp/supabase_verify_w2.$$ 2>/dev/null || true

# --- WARN: create table with no enable row level security in same file --------
printf '%s\n' "$files" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in *.sql) ;; *) continue ;; esac
  grep -qi 'create table' "$f" 2>/dev/null || continue
  grep -qi 'enable row level security' "$f" 2>/dev/null && continue
  printf 'WARNHIT\t%s\n' "$f"
done > /tmp/supabase_verify_w3.$$ 2>/dev/null || true
while IFS= read -r line; do
  [ -n "$line" ] || continue
  f="${line#WARNHIT	}"
  warn "migration creates a table but has no 'enable row level security' — exposed tables default to no protection: $f"
done < /tmp/supabase_verify_w3.$$
rm -f /tmp/supabase_verify_w3.$$ 2>/dev/null || true

# --- summary ------------------------------------------------------------------
printf '\n'
if [ "$hard" -gt 0 ]; then
  printf '%s\n' "${RED}FAIL: $hard hard violation(s), $warns warning(s).${RESET}"
  exit 1
fi
if [ "$warns" -gt 0 ]; then
  printf '%s\n' "${YELLOW}PASS with $warns warning(s) to review.${RESET}"
  exit 0
fi
ok "no Supabase footguns detected."
exit 0
