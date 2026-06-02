#!/usr/bin/env bash
set -euo pipefail

# verify.sh — mysql skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, never writes, NEVER connects to a database):
#   Discovers *.sql and *.cnf / my.cnf files and heuristically lints them for the MySQL/InnoDB
#   foot-guns this skill warns about:
#     - CHARACTER SET utf8 / CHARSET=utf8 that is not utf8mb4 (silent emoji truncation)   [warn]
#     - ENGINE=MyISAM on CREATE TABLE (no transactions/FKs)                               [warn]
#     - likely random-UUID / CHAR(36) PRIMARY KEY (InnoDB clustered-index bloat)          [warn]
#     - default_authentication_plugin = mysql_native_password in config                   [warn]
#     - an indexed column wrapped in a function in WHERE (DATE(col)/LOWER(col), non-sargable) [warn]
#     - binlog_format = STATEMENT in a committed config                                   [FAIL]
#     - unbalanced parens/single-quotes in a SQL statement                                [FAIL]
#   Optionally runs `sqlfluff --dialect mysql` if sqlfluff is installed.
#
# Exit code: non-zero ONLY on (a) unbalanced delimiters, (b) a committed binlog_format=STATEMENT,
# or (c) a real sqlfluff lint error. Every schema heuristic is advisory [warn], never a failure.
# An empty/clean target exits 0 with no false failure.
#
# Portability: stock macOS bash 3.2 — no mapfile, no associative arrays. Arrays are initialised so
# they are safe to expand under `set -u`. Pure grep/awk; no network, no mysql client.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# --- discover files (exclude vendor dirs) -----------------------------------------------------
SQL_FILES=()
while IFS= read -r -d '' f; do SQL_FILES+=("$f"); done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \) -prune -o \
    -type f -name '*.sql' -print0 2>/dev/null
)

CNF_FILES=()
while IFS= read -r -d '' f; do CNF_FILES+=("$f"); done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \) -prune -o \
    -type f \( -name '*.cnf' -o -name 'my.cnf' \) -print0 2>/dev/null
)

if [ "${#SQL_FILES[@]}" -eq 0 ] && [ "${#CNF_FILES[@]}" -eq 0 ]; then
  ok "no *.sql or *.cnf files found — nothing to lint"
  exit 0
fi

# --- strip comments + string literals for the balance heuristic -------------------------------
# Pure awk so it behaves identically on BSD (macOS) and GNU awk. Removes -- line comments,
# /* */ block comments, and '...' single-quoted literals (handling '' escapes) so the
# paren/quote balance check does not trip on legitimate content.
strip_sql() {
  awk '
    BEGIN { inblock = 0; instr = 0 }
    {
      line = $0; out = ""; i = 1; n = length(line)
      while (i <= n) {
        ch  = substr(line, i, 1)
        ch2 = substr(line, i, 2)
        if (inblock) { p = index(substr(line,i), "*/"); if (p==0){i=n+1;continue} i+=p+1; inblock=0; continue }
        if (instr)   {
          if (ch == "\x27") {
            if (substr(line,i,2) == "\x27\x27") { i+=2; continue }   # escaped quote
            instr = 0; i++; continue
          }
          i++; continue
        }
        if (ch2 == "--") { i = n + 1; continue }
        if (ch2 == "/*") { inblock = 1; i += 2; continue }
        if (ch == "\x27") { instr = 1; i++; continue }
        out = out ch; i++
      }
      print out
    }
  ' "$1"
}

# --- per-SQL-file checks ----------------------------------------------------------------------
for f in ${SQL_FILES[@]+"${SQL_FILES[@]}"}; do
  # legacy utf8 (not utf8mb4)
  if grep -Eiq '(CHARACTER[[:space:]]+SET|CHARSET[[:space:]]*=)[[:space:]]*utf8([^m]|$|mb3)' "$f"; then
    note "$f: legacy 'utf8' (utf8mb3) charset — silently truncates emoji. Use utf8mb4."
  fi
  # MyISAM
  if grep -Eiq 'ENGINE[[:space:]]*=[[:space:]]*MyISAM' "$f"; then
    note "$f: ENGINE=MyISAM — no transactions/FKs, crash-unsafe. Use InnoDB."
  fi
  # likely random-UUID / CHAR(36) PK
  if grep -Eiq 'CHAR\(36\)[^,)]*PRIMARY[[:space:]]+KEY|PRIMARY[[:space:]]+KEY[^,)]*CHAR\(36\)' "$f"; then
    note "$f: CHAR(36) PRIMARY KEY — likely a random UUID PK; bloats InnoDB secondary indexes. Prefer BIGINT AUTO_INCREMENT or UUIDv7 as BINARY(16)."
  fi
  # function-wrapped indexed column in WHERE (non-sargable)
  if grep -Eiq 'WHERE[[:space:]].*(DATE|LOWER|UPPER|YEAR|MONTH|CAST|CONVERT)[[:space:]]*\([[:alnum:]_.`]+\)[[:space:]]*=' "$f"; then
    note "$f: a function-wrapped column in WHERE (e.g. WHERE DATE(col)=...) is non-sargable — the index can't be used. Rewrite to a range, or add a functional/generated-column index."
  fi
  # balance check on comment/literal-stripped SQL
  stripped="$(strip_sql "$f")"
  opens="$(printf '%s' "$stripped" | tr -cd '(' | wc -c | tr -d ' ')"
  closes="$(printf '%s' "$stripped" | tr -cd ')' | wc -c | tr -d ' ')"
  quotes="$(printf '%s' "$stripped" | tr -cd "\047" | wc -c | tr -d ' ')"
  if [ "$opens" != "$closes" ]; then
    err "$f: unbalanced parentheses ($opens '(' vs $closes ')')."
  fi
  if [ $(( quotes % 2 )) -ne 0 ]; then
    err "$f: unbalanced single-quotes after stripping comments/literals."
  fi
done

# --- per-config-file checks -------------------------------------------------------------------
for f in ${CNF_FILES[@]+"${CNF_FILES[@]}"}; do
  if grep -Eiq '^[[:space:]]*binlog_format[[:space:]]*=[[:space:]]*STATEMENT' "$f"; then
    err "$f: binlog_format = STATEMENT — non-deterministic statements drift on replicas. Use ROW."
  fi
  if grep -Eiq '^[[:space:]]*default_authentication_plugin[[:space:]]*=[[:space:]]*mysql_native_password' "$f"; then
    note "$f: default_authentication_plugin = mysql_native_password — disabled by default in 8.4, removed in 9.0. Use caching_sha2_password + TLS."
  fi
done

# --- optional sqlfluff --------------------------------------------------------------------------
if [ "${#SQL_FILES[@]}" -gt 0 ]; then
  if command -v sqlfluff >/dev/null 2>&1; then
    if sqlfluff lint --dialect mysql ${SQL_FILES[@]+"${SQL_FILES[@]}"} >/dev/null 2>&1; then
      ok "sqlfluff (dialect mysql): no lint errors"
    else
      err "sqlfluff (dialect mysql) reported lint errors — run: sqlfluff lint --dialect mysql <file>"
    fi
  else
    skip "sqlfluff not installed — skipping SQL lint (advisory)"
  fi
fi

if [ "$EXIT" -eq 0 ]; then
  ok "verify passed (advisory warnings, if any, are non-blocking)"
fi
exit "$EXIT"
