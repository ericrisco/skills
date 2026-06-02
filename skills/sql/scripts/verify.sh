#!/usr/bin/env bash
set -euo pipefail

# verify.sh — sql skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, NEVER connects to a database):
#   1. Discovers *.sql files (skips vendor dirs).
#   2. Heuristic foot-gun scan — ALL advisory [warn], never fail the build:
#        - NOT IN (SELECT ...)            -> suggest NOT EXISTS (NULL-eating 3VL footgun)
#        - comma-join in FROM + WHERE-side join predicate -> suggest explicit JOIN ... ON
#        - window OVER (... ORDER BY ...) with no ROWS/RANGE/GROUPS -> implicit-frame trap
#        - SELECT * co-occurring with GROUP BY in the same file
#   3. Balanced-delimiter sanity (dollar-quote, literal and comment aware).
#   4. Optional: sqlfluff lint --dialect ansi IF sqlfluff is installed.
#
# Exit code: non-zero ONLY on unbalanced parens/quotes (after stripping literals/comments)
# or a real sqlfluff lint error. Every heuristic above is advisory. An empty or clean
# target exits 0. Stock macOS bash 3.2 (no mapfile, no associative arrays).

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# Discover .sql files. bash 3.2 has no mapfile; read NUL-delimited names into an
# explicitly-initialised array so expansion is safe under `set -u`.
SQL_FILES=()
while IFS= read -r -d '' f; do
  SQL_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \) -prune -o \
    -type f -name '*.sql' -print0 2>/dev/null
)

if [ "${#SQL_FILES[@]}" -eq 0 ]; then
  skip "no .sql files found under $ROOT — nothing to lint"
  ok "verify.sh passed (empty target)"
  exit 0
fi

# Strip line/block comments, single-quoted literals and dollar-quoted bodies, so delimiter
# counting and pattern matching don't trip on text that lives inside strings/comments.
strip_for_counting() {
  awk '
    BEGIN { inblock = 0; dq = "" }
    {
      line = $0; n = length(line); out = ""; i = 1
      while (i <= n) {
        rest = substr(line, i)
        if (inblock) {
          if (substr(line, i, 2) == "*/") { inblock = 0; i += 2; continue }
          i += 1; continue
        }
        if (dq != "") {
          if (substr(rest, 1, length(dq)) == dq) { i += length(dq); dq = ""; continue }
          i += 1; continue
        }
        ch  = substr(line, i, 1)
        ch2 = substr(line, i, 2)
        if (ch2 == "--") { i = n + 1; continue }
        if (ch2 == "/*") { inblock = 1; i += 2; continue }
        if (ch == "$") {
          if (match(rest, /^\$[A-Za-z_]*\$/)) { dq = substr(rest, RSTART, RLENGTH); i += RLENGTH; continue }
        }
        if (ch == "'\''") {
          i += 1
          while (i <= n) {
            c = substr(line, i, 1)
            if (c == "'\''") {
              if (substr(line, i + 1, 1) == "'\''") { i += 2; continue }
              i += 1; break
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

for f in "${SQL_FILES[@]}"; do
  body="$(strip_for_counting "$f")"

  # --- heuristics (advisory) ---

  # NOT IN (SELECT ...) — the NULL three-valued-logic footgun.
  if printf '%s' "$body" | grep -Eiqz 'not[[:space:]]+in[[:space:]]*\([[:space:]]*select'; then
    note "$f: NOT IN (SELECT ...) — a NULL in the subquery returns zero rows; prefer NOT EXISTS"
  fi

  # Comma-join in FROM combined with a WHERE that joins two aliases (t1.x = t2.y).
  if grep -Eiq 'from[[:space:]]+[a-z_][a-z0-9_]*([[:space:]]+(as[[:space:]]+)?[a-z_][a-z0-9_]*)?[[:space:]]*,[[:space:]]*[a-z_]' "$f" \
     && grep -Eiq 'where[^;]*[a-z_][a-z0-9_]*\.[a-z0-9_]+[[:space:]]*=[[:space:]]*[a-z_][a-z0-9_]*\.[a-z0-9_]+' "$f"; then
    note "$f: comma-join in FROM with a join predicate in WHERE — use explicit JOIN ... ON"
  fi

  # Window with ORDER BY inside OVER() but no explicit frame keyword -> implicit-frame trap.
  if grep -Eiq 'over[[:space:]]*\([^)]*order[[:space:]]+by' "$f" \
     && ! grep -Eiq '(rows|range|groups)[[:space:]]+(between|unbounded|current|[0-9])' "$f"; then
    note "$f: window OVER(... ORDER BY ...) with no ROWS/RANGE/GROUPS frame — implicit RANGE groups tied rows; state ROWS for a true running total"
  fi

  # SELECT * alongside a GROUP BY in the same file.
  if grep -Eiq 'select[[:space:]]+\*' "$f" && grep -Eiq 'group[[:space:]]+by' "$f"; then
    note "$f: SELECT * with a GROUP BY — name the grouped columns explicitly"
  fi

  # --- balanced-delimiter sanity (hard fail) ---
  sq=$(printf '%s' "$body" | tr -cd "'" | wc -c | tr -d ' ')
  op=$(printf '%s' "$body" | tr -cd '(' | wc -c | tr -d ' ')
  cp=$(printf '%s' "$body" | tr -cd ')' | wc -c | tr -d ' ')
  if [ $((sq % 2)) -ne 0 ]; then err "$f: unbalanced single quotes (after stripping literals/comments)"; fi
  if [ "$op" -ne "$cp" ]; then err "$f: unbalanced parentheses ($op '(' vs $cp ')')"; fi
done
ok "scanned ${#SQL_FILES[@]} .sql file(s)"

# --- optional sqlfluff (ANSI dialect) ---
if command -v sqlfluff >/dev/null 2>&1; then
  if sqlfluff lint --dialect ansi "${SQL_FILES[@]}"; then
    ok "sqlfluff lint clean (--dialect ansi)"
  else
    err "sqlfluff reported lint errors"
  fi
else
  skip "sqlfluff not installed — skipping standard-SQL lint"
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
