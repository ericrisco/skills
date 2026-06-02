#!/usr/bin/env bash
set -euo pipefail

# verify.sh — sqlite-turso skill gate. Read-only, no network, deterministic.
#
# Statically checks @libsql/client integration file(s) for the foot-guns this skill exists to
# prevent. Pass a file or a directory; with no arg it scans the current directory.
#
#   bash verify.sh                 # scan ./ for *.ts / *.js / *.mjs / *.mts
#   bash verify.sh src/db.ts       # check one file
#   bash verify.sh src/            # scan a directory
#
# What it checks PER FILE that imports @libsql/client:
#   1. uses createClient (else: not really wiring the client) ......... FAIL
#   2. if `syncUrl` appears, a local `file:` url must also appear ...... FAIL
#      (an embedded replica must be backed by a local file)
#   3. no hardcoded auth token literal (require process.env/Deno.env) .. FAIL
#   4. file-backed client (`file:`) should set PRAGMA ... WAL .......... advisory [warn]
#
# Exit code: non-zero ONLY when a FAIL is recorded. Files with no @libsql/client import are
# skipped. An empty/clean target prints nothing actionable and exits 0 (no false failure).

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

TARGET="${1:-.}"

# Collect candidate files (bash 3.2: no mapfile; NUL-delimited into an initialised array).
FILES=()
if [ -f "$TARGET" ]; then
  FILES+=("$TARGET")
elif [ -d "$TARGET" ]; then
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(
    find "$TARGET" \
      \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/dist/*' -o -path '*/build/*' \) -prune -o \
      -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.mjs' -o -name '*.mts' \) -print0 2>/dev/null
  )
else
  warn "target not found: $TARGET (nothing to check)"
  exit 0
fi

CHECKED=0
for f in "${FILES[@]+"${FILES[@]}"}"; do
  # Only inspect files that actually pull in the libSQL client.
  grep -Eq "@libsql/client" "$f" 2>/dev/null || continue
  CHECKED=$((CHECKED + 1))

  # 1. must call createClient
  if grep -Eq "createClient[[:space:]]*\(" "$f"; then
    ok "$f: imports @libsql/client and calls createClient"
  else
    err "$f: imports @libsql/client but never calls createClient"
  fi

  # 2. embedded replica must be file-backed
  if grep -Eq "syncUrl" "$f"; then
    if grep -Eq "[\"'\`]file:" "$f"; then
      ok "$f: syncUrl is backed by a local file: url (embedded replica)"
    else
      err "$f: syncUrl present but no local 'file:' url — that is a confused remote client, not a replica"
    fi
  fi

  # 3. no hardcoded auth token literal. authToken must come from an env source.
  if grep -Eq "authToken" "$f"; then
    if grep -Eq "authToken[[:space:]]*:[[:space:]]*[\"'\`]" "$f"; then
      err "$f: authToken assigned a string literal — read it from process.env / Deno.env instead"
    elif grep -Eq "authToken[[:space:]]*:[[:space:]]*(process\.env|Deno\.env|import\.meta\.env|Bun\.env)" "$f"; then
      ok "$f: authToken read from an environment source"
    else
      warn "$f: authToken present — confirm it comes from the environment, not a literal"
    fi
  fi

  # 4. advisory: a file-backed client should set WAL
  if grep -Eq "[\"'\`]file:" "$f"; then
    if grep -Eiq "journal_mode[[:space:]]*=[[:space:]]*WAL" "$f"; then
      ok "$f: file-backed client sets journal_mode=WAL"
    else
      warn "$f: file-backed client — consider PRAGMA journal_mode=WAL (advisory)"
    fi
  fi
done

if [ "$CHECKED" -eq 0 ]; then
  ok "no @libsql/client integration files found — nothing to verify"
fi

exit "$EXIT"
