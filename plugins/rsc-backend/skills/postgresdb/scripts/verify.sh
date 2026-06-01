#!/usr/bin/env bash
set -euo pipefail

# verify.sh — postgresdb skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, never writes):
#   1. Lints discovered SQL with sqlfluff IF sqlfluff + a .sqlfluff config exist.
#   2. Syntax-sanity-checks migration *.sql files: balanced quotes/parens (advisory — it is
#      dollar-quote and block-comment aware, but still heuristic), and flags foot-guns
#      (CREATE INDEX without CONCURRENTLY in a migration, ADD COLUMN ... NOT NULL without
#      DEFAULT, VACUUM FULL).
#   3. IF DATABASE_URL is set AND psql is present: checks pg_stat_statements is enabled.
#      It NEVER connects unless DATABASE_URL is set, and a down/unreachable DB is a skip, not a fail.
#
# Exit code: non-zero ONLY on sqlfluff lint errors. Everything else is advisory
# (yellow [skip] / [warn]) — unbalanced quotes/parens are a heuristic warning, not a hard fail,
# because dollar-quoted PL/pgSQL and string literals can legitimately look "unbalanced".
# Missing tools never fail the gate.
#
# Portability: runs on stock macOS bash 3.2 (no mapfile, no associative arrays). All arrays are
# initialised so they are safe to expand under `set -u`.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
warn() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# Discover SQL/migration files (exclude vendor dirs). bash 3.2 has no mapfile; read NUL-delimited
# names into an explicitly-initialised array so expansion is safe under `set -u`.
SQL_FILES=()
while IFS= read -r -d '' f; do
  SQL_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \) -prune -o \
    -type f -name '*.sql' -print0 2>/dev/null
)

# strip_for_counting <file> — emit the SQL with line comments (--…), block comments (/* … */),
# single-quoted string literals, and dollar-quoted blocks ($$…$$ / $tag$…$tag$) removed, so the
# quote/paren balance heuristic does not trip on PL/pgSQL function bodies or literals. Pure awk,
# so it works identically on macOS (BSD) and Linux (GNU) awk.
strip_for_counting() {
  awk '
    BEGIN { inblock = 0; dq = "" }
    {
      line = $0
      out = ""
      i = 1
      n = length(line)
      while (i <= n) {
        rest = substr(line, i)

        # Inside a /* */ block comment: consume until the closing */.
        if (inblock) {
          p = index(rest, "*/")
          if (p == 0) { i = n + 1; continue }
          i += p + 1
          inblock = 0
          continue
        }

        # Inside a dollar-quoted block: consume until the matching close tag.
        if (dq != "") {
          p = index(rest, dq)
          if (p == 0) { i = n + 1; continue }
          i += p + length(dq) - 1
          dq = ""
          continue
        }

        ch  = substr(line, i, 1)
        ch2 = substr(line, i, 2)

        # Start of a line comment: drop the remainder of the line.
        if (ch2 == "--") { i = n + 1; continue }

        # Start of a block comment.
        if (ch2 == "/*") { inblock = 1; i += 2; continue }

        # Start of a dollar-quote tag: $$ or $tag$.
        if (ch == "$") {
          if (match(rest, /^\$[A-Za-z_]*\$/)) {
            dq = substr(rest, RSTART, RLENGTH)
            i += RLENGTH
            continue
          }
        }

        # Start of a single-quoted string literal: consume to the closing quote,
        # honouring the '' escape (a doubled quote stays inside the literal).
        if (ch == "'\''") {
          i += 1
          while (i <= n) {
            c = substr(line, i, 1)
            if (c == "'\''") {
              if (substr(line, i + 1, 1) == "'\''") { i += 2; continue }
              i += 1
              break
            }
            i += 1
          }
          continue
        }

        out = out ch
        i += 1
      }
      print out
    }
  ' "$1"
}

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
    # Strip comments, string literals and dollar-quoted bodies before counting.
    body="$(strip_for_counting "$f")"
    sq=$(printf '%s' "$body" | tr -cd "'" | wc -c | tr -d ' ')
    op=$(printf '%s' "$body" | tr -cd '(' | wc -c | tr -d ' ')
    cp=$(printf '%s' "$body" | tr -cd ')' | wc -c | tr -d ' ')
    # Advisory only: dollar-quoting/literals are heuristically stripped, but an odd count here is a
    # hint to eyeball the file, not a build-breaker.
    if [ $((sq % 2)) -ne 0 ]; then note "$f: odd number of single quotes (after stripping literals/comments) — eyeball it"; fi
    if [ "$op" -ne "$cp" ]; then note "$f: unbalanced parentheses ($op '(' vs $cp ')') — eyeball it"; fi

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
  ok "SQL syntax sanity scanned (${#SQL_FILES[@]} files)"
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
