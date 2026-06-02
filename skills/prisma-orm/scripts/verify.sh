#!/usr/bin/env bash
set -euo pipefail

# verify.sh — prisma-orm skill gate. Static lint of Prisma artifacts. NO database connection.
#
# Usage:
#   scripts/verify.sh [paths...]   # lint the given files/dirs
#   scripts/verify.sh              # discover schema.prisma + *.ts under cwd (skips vendor dirs)
#
# Read-only and idempotent — it never writes, migrates, or connects. What it checks:
#   1. generator block uses provider = "prisma-client" (legacy "prisma-client-js" is a fail)
#      and carries a required output =.
#   2. every `new PrismaClient(` passes an `adapter`/`accelerateUrl` (bare construction is a fail).
#   3. hard banlist: $queryRawUnsafe(/$executeRawUnsafe( with a ${ interpolation (SQL injection),
#      binaryTargets (Rust-era v6), prisma-client-js generator.
#   4. warn-only: findMany( with no take/cursor nearby (likely unbounded read).
#   5. contamination: drizzle-kit / pgTable( / drizzle.config (wrong ORM leaked in).
#
# Exit code: non-zero ONLY on a hard violation. An empty/clean target is a clean pass.
# Warnings are printed but never fail the run. Targets bash 3.2 (no mapfile/assoc arrays).

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# ---- collect candidate files (schema.prisma + *.ts), skipping vendor/build dirs ----
FILES=()
add_under() {
  local base="$1"
  while IFS= read -r -d '' f; do FILES+=("$f"); done < <(
    find "$base" \
      \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/dist/*' \
         -o -path '*/.next/*' -o -path '*/build/*' -o -path '*/generated/*' \) -prune -o \
      -type f \( -name 'schema.prisma' -o -name '*.prisma' -o -name '*.ts' -o -name '*.mts' \) -print0 \
      2>/dev/null
  )
}

if [ "$#" -gt 0 ]; then
  for p in "$@"; do
    if [ -f "$p" ]; then FILES+=("$p")
    elif [ -d "$p" ]; then add_under "$p"
    else err "no such path: $p"; fi
  done
else
  add_under "$ROOT"
fi

# Keep only files that look Prisma-related (a .prisma file, or TS that touches Prisma).
PRISMA_FILES=()
for f in "${FILES[@]:-}"; do
  [ -z "$f" ] && continue
  case "$f" in
    *.prisma) PRISMA_FILES+=("$f"); continue;;
  esac
  if grep -Eq 'PrismaClient|@prisma/|prisma\.\$|prisma/config|relationLoadStrategy' "$f" 2>/dev/null; then
    PRISMA_FILES+=("$f")
  fi
done

if [ "${#PRISMA_FILES[@]}" -eq 0 ]; then
  ok "no Prisma artifacts found — nothing to verify (clean)"
  exit 0
fi

# ---- 1. generator block in .prisma files ----
SCHEMA_SEEN=0
for f in "${PRISMA_FILES[@]}"; do
  case "$f" in *.prisma) ;; *) continue;; esac
  grep -Eq 'generator\s' "$f" 2>/dev/null || continue
  SCHEMA_SEEN=1
  if grep -Eq 'provider\s*=\s*"prisma-client-js"' "$f" 2>/dev/null; then
    err "$f: legacy generator provider \"prisma-client-js\" — v7 uses \"prisma-client\""
  elif grep -Eq 'provider\s*=\s*"prisma-client"' "$f" 2>/dev/null; then
    if grep -Eq '^\s*output\s*=' "$f" 2>/dev/null; then
      ok "$f: prisma-client generator with output"
    else
      err "$f: prisma-client generator is missing the required output ="
    fi
  fi
done
[ "$SCHEMA_SEEN" -eq 0 ] && skip "no generator block found in a .prisma file"

# ---- 2. PrismaClient construction must carry an adapter / accelerateUrl ----
CLIENT_SEEN=0
for f in "${PRISMA_FILES[@]}"; do
  case "$f" in *.prisma) continue;; esac
  grep -Eq 'new[[:space:]]+PrismaClient[[:space:]]*\(' "$f" 2>/dev/null || continue
  CLIENT_SEEN=1
  # bare new PrismaClient() with empty/no args
  if grep -Eq 'new[[:space:]]+PrismaClient[[:space:]]*\([[:space:]]*\)' "$f" 2>/dev/null; then
    err "$f: bare new PrismaClient() — v7 needs an adapter (throws 'requires either adapter or accelerateUrl')"
  elif grep -Eq 'adapter|accelerateUrl' "$f" 2>/dev/null; then
    ok "$f: PrismaClient construction passes an adapter/accelerateUrl"
  else
    err "$f: new PrismaClient(...) without an adapter or accelerateUrl in the file"
  fi
done
[ "$CLIENT_SEEN" -eq 0 ] && skip "no PrismaClient construction found"

# ---- 3. hard banlist ----
for f in "${PRISMA_FILES[@]}"; do
  # $queryRawUnsafe / $executeRawUnsafe carrying an interpolation = injection
  if grep -Eq '\$(query|execute)RawUnsafe[[:space:]]*\([^)]*\$\{' "$f" 2>/dev/null; then
    err "$f: \$queryRawUnsafe/\$executeRawUnsafe with \${} interpolation — SQL injection; use a tagged \$queryRaw\`\`"
  fi
  if grep -Eq 'binaryTargets' "$f" 2>/dev/null; then
    err "$f: binaryTargets is Rust-era (v6); v7 is Rust-free — remove it"
  fi
done

# ---- 4. warn-only: unbounded findMany ----
for f in "${PRISMA_FILES[@]}"; do
  case "$f" in *.prisma) continue;; esac
  grep -Eq 'findMany[[:space:]]*\(' "$f" 2>/dev/null || continue
  # crude heuristic: file uses findMany but never mentions take or cursor
  if ! grep -Eq '\btake\b|\bcursor\b' "$f" 2>/dev/null; then
    warn "$f: findMany() with no take/cursor in the file — likely an unbounded read"
  fi
done

# ---- 5. wrong-ORM contamination ----
for f in "${PRISMA_FILES[@]}"; do
  if grep -Eq 'drizzle-kit|pgTable[[:space:]]*\(|drizzle\.config' "$f" 2>/dev/null; then
    err "$f: Drizzle signal (drizzle-kit/pgTable/drizzle.config) in a Prisma artifact — wrong ORM leaked in"
  fi
done

if [ "$EXIT" -eq 0 ]; then
  ok "prisma-orm checks passed"
fi
exit "$EXIT"
