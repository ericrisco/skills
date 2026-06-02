#!/usr/bin/env bash
set -euo pipefail

# verify.sh — db-migrations skill gate.
#
# This is a self-consistency + artifact-shape check on the skill's OWN files, not a live DB check.
# It NEVER connects to a database and NEVER writes anything.
#
# What it asserts:
#   1. The skill ships a Squawk / migration-lint reference (CI gate the body tells you to add).
#   2. SKILL.md documents each forbidden DDL pattern as a Bad->Good (lock_timeout, CONCURRENTLY,
#      multi-step NOT NULL, batched backfill).
#   3. Example .sql shipped in references/ is itself safe — none of the danger signatures the body
#      forbids: bare CREATE INDEX (no CONCURRENTLY), an ALTER that is missing lock_timeout, or
#      ADD COLUMN ... NOT NULL without the multi-step path. (DROP INDEX CONCURRENTLY is exempt from
#      the lock_timeout rule; it manages its own locking.)
#
# Exit code: non-zero only if the skill's own artifacts are inconsistent with what the body teaches.
# An empty / missing references dir is a clean skip, not a failure (exit 0).
#
# Portable to stock macOS bash 3.2: no mapfile, no associative arrays; arrays are initialised so they
# expand safely under `set -u`.

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

# Resolve the skill root from this script's location, so the gate works from any CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_MD="$SKILL_DIR/SKILL.md"
REF_DIR="$SKILL_DIR/references"

# ---- 1. SKILL.md documents the safe patterns ----
if [ -f "$SKILL_MD" ]; then
  needles=(
    "lock_timeout"
    "CONCURRENTLY"
    "NOT VALID"
    "VALIDATE CONSTRAINT"
    "Squawk"
  )
  missing=""
  for n in "${needles[@]}"; do
    grep -Fq "$n" "$SKILL_MD" || missing="$missing $n"
  done
  if [ -n "$missing" ]; then
    fail "SKILL.md is missing required safe-migration concepts:$missing"
  else
    ok "SKILL.md documents lock_timeout, CONCURRENTLY, NOT VALID/VALIDATE, Squawk"
  fi
  # The body must show a Bad->Good contrast (it teaches by counter-example).
  if grep -Eq -- '--[[:space:]]*Bad' "$SKILL_MD" && grep -Eq -- '--[[:space:]]*Good' "$SKILL_MD"; then
    ok "SKILL.md shows Bad->Good DDL contrasts"
  else
    fail "SKILL.md should contrast a Bad vs Good DDL fence"
  fi
else
  fail "SKILL.md not found at $SKILL_MD"
fi

# ---- 2. Squawk / lint reference is shipped ----
if [ -d "$REF_DIR" ] && grep -rIlq -- "squawk" "$REF_DIR" 2>/dev/null; then
  ok "references/ ship a Squawk migration-lint reference"
elif [ -d "$REF_DIR" ]; then
  fail "references/ exist but no Squawk lint reference found (the body's CI gate is undocumented)"
else
  skip "no references/ dir — nothing to lint-reference yet"
fi

# ---- 3. Example .sql in references/ is itself safe ----
SQL_FILES=()
if [ -d "$REF_DIR" ]; then
  while IFS= read -r -d '' f; do
    SQL_FILES+=("$f")
  done < <(find "$REF_DIR" -type f -name '*.sql' -print0 2>/dev/null)
fi

# The references ship example DDL inside fenced code blocks, not standalone .sql files. If real .sql
# files exist, scan them; otherwise this is a clean skip (no false failure on an empty target).
if [ "${#SQL_FILES[@]}" -eq 0 ]; then
  skip "no standalone .sql files in references/ to scan (examples live in fenced code blocks)"
else
  for f in "${SQL_FILES[@]}"; do
    # Strip line comments so a "-- Bad: ..." annotation never trips the scanner.
    body="$(sed -e 's/--.*$//' "$f")"

    # bare CREATE INDEX without CONCURRENTLY
    if printf '%s' "$body" | grep -Eiq 'create[[:space:]]+(unique[[:space:]]+)?index' \
       && ! printf '%s' "$body" | grep -Eiq 'create[[:space:]]+(unique[[:space:]]+)?index[[:space:]]+concurrently'; then
      fail "$f: CREATE INDEX without CONCURRENTLY"
    fi

    # ADD COLUMN ... NOT NULL in one shot (the multi-step path uses a separate NOT VALID CHECK)
    if printf '%s' "$body" | grep -Eiq 'add[[:space:]]+column[^;]*not[[:space:]]+null'; then
      fail "$f: ADD COLUMN ... NOT NULL in a single statement"
    fi

    # any ALTER TABLE that is not preceded anywhere in the file by a lock_timeout
    if printf '%s' "$body" | grep -Eiq 'alter[[:space:]]+table' \
       && ! printf '%s' "$body" | grep -Fiq 'lock_timeout'; then
      fail "$f: ALTER TABLE without a lock_timeout in the same file"
    fi
  done
  [ "$EXIT" -eq 0 ] && ok "example .sql in references/ is free of forbidden DDL signatures (${#SQL_FILES[@]} files)"
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else fail "verify.sh found inconsistencies"; fi
exit "$EXIT"
