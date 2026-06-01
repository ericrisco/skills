#!/usr/bin/env bash
set -euo pipefail

# verify.sh — postgresdb skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, never writes):
#   1. Lints discovered SQL with sqlfluff IF sqlfluff + a .sqlfluff config exist.
#   2. Syntax-sanity-checks migration *.sql files: balanced quotes/parens, ';' terminators,
#      and flags foot-guns (CREATE INDEX without CONCURRENTLY in a migration, ADD COLUMN ...
#      NOT NULL without DEFAULT, VACUUM FULL).
#   3. IF DATABASE_URL is set AND psql is present: checks pg_stat_statements is enabled.
#      It NEVER connects unless DATABASE_URL is set, and a down/unreachable DB is a skip, not a fail.
#
# Exit code: non-zero ONLY on (a) sqlfluff lint errors, or (b) unbalanced quotes/parens.
# Everything else is advisory (yellow [skip] / [warn]). Missing tools never fail the gate.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
warn() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# Discover SQL/migration files (exclude vendor dirs).
mapfile -t SQL_FILES < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \) -prune -o \
    -type f -name '*.sql' -print 2>/dev/null
)

# ---- 1. sqlfluff ----
if command -v sqlfluff >/dev/null 2>&1; then
  if [ -f "$ROOT/.sqlfluff" ]; then
    if [ "${#SQL_FILES[@]}" -gt 0 ]; then
      if sqlfluff lint --dialect postgres "${SQL_FILES[@]}"; then
        ok "sqlfluff lint clean"
      else
        err "sqlfluff lint reported errors"
      fi
    else
      warn "sqlfluff: no .sql files found"
    fi
  else
    warn "sqlfluff present but no .sqlfluff config — skipping lint"
  fi
else
  warn "sqlfluff not installed — skipping SQL lint"
fi

# ---- 2. SQL syntax sanity + foot-gun scan ----
if [ "${#SQL_FILES[@]}" -eq 0 ]; then
  warn "no .sql files to syntax-check"
else
  for f in "${SQL_FILES[@]}"; do
    # Strip line comments before counting, to avoid false positives.
    body="$(sed -E 's/--.*$//' "$f")"
    sq=$(printf '%s' "$body" | tr -cd "'" | wc -c | tr -d ' ')
    op=$(printf '%s' "$body" | tr -cd '(' | wc -c | tr -d ' ')
    cp=$(printf '%s' "$body" | tr -cd ')' | wc -c | tr -d ' ')
    if [ $((sq % 2)) -ne 0 ]; then err "$f: unbalanced single quotes"; fi
    if [ "$op" -ne "$cp" ]; then err "$f: unbalanced parentheses ($op '(' vs $cp ')')"; fi

    # Foot-guns (advisory only) — only flag for files that look like migrations.
    case "$f" in
      *migration*|*migrations*|*alembic/versions*|*prisma/migrations*)
        if grep -Eiq 'create[[:space:]]+(unique[[:space:]]+)?index' "$f" \
           && ! grep -Eiq 'create[[:space:]]+(unique[[:space:]]+)?index[[:space:]]+concurrently' "$f"; then
          note "$f: CREATE INDEX without CONCURRENTLY in a migration"
        fi
        if grep -Eiq 'add[[:space:]]+column[^;]*not[[:space:]]+null' "$f" \
           && ! grep -Eiq 'add[[:space:]]+column[^;]*default' "$f"; then
          note "$f: ADD COLUMN ... NOT NULL without DEFAULT (table rewrite / lock risk)"
        fi
        if grep -Eiq 'vacuum[[:space:]]+full' "$f"; then
          note "$f: VACUUM FULL takes ACCESS EXCLUSIVE — avoid on live tables"
        fi
        ;;
    esac
  done
  [ "$EXIT" -eq 0 ] && ok "SQL syntax sanity passed (${#SQL_FILES[@]} files)"
fi

# ---- 3. pg_stat_statements guidance ----
GUIDE='Enable pg_stat_statements: add "pg_stat_statements" to shared_preload_libraries, restart, then run CREATE EXTENSION pg_stat_statements;'
if [ -n "${DATABASE_URL:-}" ] && command -v psql >/dev/null 2>&1; then
  if res="$(psql "$DATABASE_URL" -At -c \
        "SELECT 1 FROM pg_extension WHERE extname='pg_stat_statements'" 2>/dev/null)"; then
    if [ "$res" = "1" ]; then
      ok "pg_stat_statements is enabled"
    else
      note "pg_stat_statements not enabled. $GUIDE"
    fi
  else
    warn "could not connect to DATABASE_URL (DB down or unreachable) — skipping pg_stat_statements check"
  fi
else
  warn "DATABASE_URL unset or psql missing — skipping DB checks. $GUIDE"
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
