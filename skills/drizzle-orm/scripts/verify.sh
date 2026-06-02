#!/usr/bin/env bash
set -euo pipefail

# verify.sh — drizzle-orm skill gate. Static lint of Drizzle TS source. NO DB connection.
#
# Usage:
#   scripts/verify.sh [files...]            # lint the given .ts files
#   scripts/verify.sh                       # discover *.ts under cwd (excludes vendor dirs)
#
# What it does (read-only, idempotent, never writes):
#   1. Finds a drizzle.config.ts (given or discovered) and checks it carries dialect/schema/out.
#   2. Reads the configured `dialect` and checks any table helper (pgTable/mysqlTable/sqliteTable)
#      in the scanned files matches it.
#   3. Checks a drizzle() call exists somewhere; and if db.query is used, that drizzle() is passed
#      { schema } or { relations } (else db.query is undefined at runtime).
#   4. Bans Prisma-isms (schema.prisma, PrismaClient, prisma generate) that mean the wrong ORM leaked in.
#
# Exit code: non-zero ONLY on a real failure. An empty/clean target (no Drizzle files found) is a
# clean pass, not a failure. Missing optional context (e.g. no config) is a [skip], not a [fail].
#
# Portability: stock macOS bash 3.2 (no mapfile, no associative arrays). Arrays initialised so
# expansion is safe under `set -u`.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
warn() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# ---- collect target files ----
FILES=()
if [ "$#" -gt 0 ]; then
  for f in "$@"; do
    if [ -f "$f" ]; then FILES+=("$f"); else err "no such file: $f"; fi
  done
else
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(
    find "$ROOT" \
      \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/dist/*' -o -path '*/.next/*' \) -prune -o \
      -type f -name '*.ts' -print0 2>/dev/null
  )
fi

# Filter to files that actually look like Drizzle source (import from drizzle-orm/-kit, or a config).
DRIZ_FILES=()
for f in "${FILES[@]:-}"; do
  [ -z "$f" ] && continue
  if grep -Eq "drizzle-orm|drizzle-kit|drizzle\(|defineConfig" "$f" 2>/dev/null; then
    DRIZ_FILES+=("$f")
  fi
done

if [ "${#DRIZ_FILES[@]}" -eq 0 ]; then
  ok "no Drizzle source found — nothing to verify (clean)"
  exit 0
fi

# ---- locate a config among the targets, else discover one ----
CONFIG=""
for f in "${DRIZ_FILES[@]}"; do
  case "$f" in *drizzle.config.ts) CONFIG="$f"; break;; esac
done
if [ -z "$CONFIG" ] && [ -f "$ROOT/drizzle.config.ts" ]; then
  CONFIG="$ROOT/drizzle.config.ts"
fi

# ---- 1. config keys ----
DIALECT=""
if [ -n "$CONFIG" ]; then
  miss=""
  grep -Eq "\bdialect\b" "$CONFIG" || miss="$miss dialect"
  grep -Eq "\bschema\b"  "$CONFIG" || miss="$miss schema"
  grep -Eq "\bout\b"     "$CONFIG" || miss="$miss out"
  if [ -n "$miss" ]; then
    err "drizzle.config.ts missing key(s):$miss"
  else
    ok "drizzle.config.ts has dialect/schema/out"
  fi
  DIALECT="$(grep -Eo "dialect[[:space:]]*:[[:space:]]*['\"][a-z]+['\"]" "$CONFIG" \
    | grep -Eo "['\"][a-z]+['\"]" | tr -d "\"'" | head -n1 || true)"
else
  warn "no drizzle.config.ts found — skipping config + dialect-match checks"
fi

# ---- 2. table helper matches dialect ----
HELPERS="$(grep -hEo '\b(pgTable|mysqlTable|sqliteTable)\b' "${DRIZ_FILES[@]}" 2>/dev/null | sort -u | tr '\n' ' ' || true)"
if [ -n "$HELPERS" ]; then
  if [ -n "$DIALECT" ]; then
    case "$DIALECT" in
      postgresql) want="pgTable";;
      mysql)      want="mysqlTable";;
      sqlite|turso) want="sqliteTable";;
      *) want="";;
    esac
    if [ -n "$want" ]; then
      bad=""
      for h in $HELPERS; do [ "$h" != "$want" ] && bad="$bad $h"; done
      if [ -n "$bad" ]; then
        err "dialect '$DIALECT' expects $want but found:$bad — table helper does not match config"
      else
        ok "table helper ($HELPERS) matches dialect '$DIALECT'"
      fi
    fi
  else
    note "table helper(s) found ($HELPERS) but no dialect to compare against"
  fi
fi

# ---- 3. drizzle() present; db.query needs { schema } | { relations } ----
HAS_DRIZZLE=0
HAS_SCHEMA_OR_REL=0
HAS_DBQUERY=0
for f in "${DRIZ_FILES[@]}"; do
  grep -Eq "\bdrizzle\(" "$f" && HAS_DRIZZLE=1
  grep -Eq "drizzle\([^)]*\{[^}]*(schema|relations)" "$f" && HAS_SCHEMA_OR_REL=1
  grep -Eq "\bdb\.query\b|\b_query\b" "$f" && HAS_DBQUERY=1
done

# Tolerate multi-line drizzle(...) calls: re-scan whole-file (newline-flattened) for the option.
if [ "$HAS_SCHEMA_OR_REL" -eq 0 ] && [ "$HAS_DRIZZLE" -eq 1 ]; then
  for f in "${DRIZ_FILES[@]}"; do
    if tr '\n' ' ' < "$f" | grep -Eq "drizzle\(.*\{[^}]*(schema|relations)"; then
      HAS_SCHEMA_OR_REL=1; break
    fi
  done
fi

if [ "$HAS_DRIZZLE" -eq 1 ]; then
  ok "drizzle() connection call present"
else
  note "no drizzle() call in scanned files (schema-only file?)"
fi

if [ "$HAS_DBQUERY" -eq 1 ] && [ "$HAS_SCHEMA_OR_REL" -eq 0 ]; then
  err "db.query used but drizzle() is not passed { schema } or { relations } — db.query will be undefined"
elif [ "$HAS_DBQUERY" -eq 1 ]; then
  ok "db.query usage has { schema } | { relations } on drizzle()"
fi

# ---- 4. Prisma-ism banlist ----
for f in "${DRIZ_FILES[@]}"; do
  if grep -Eq "schema\.prisma|PrismaClient|prisma[[:space:]]+generate" "$f"; then
    err "$f: Prisma-ism found (schema.prisma/PrismaClient/prisma generate) — wrong ORM leaked in"
  fi
done
[ "$EXIT" -eq 0 ] && ok "no Prisma-isms"

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
