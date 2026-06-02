#!/usr/bin/env bash
set -euo pipefail

# verify.sh — redis skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, NEVER connects to a Redis server, never writes):
#   Scans discovered Redis-touching source/config for high-confidence foot-guns. It exits
#   non-zero ONLY on a near-certain production bug (`KEYS` / `KEYS *` in non-test source).
#   Everything else is advisory [warn], and an absence of Redis usage is [skip] (exit 0).
#
# Heuristics are deliberately conservative: client SDKs and config look wildly different across
# node-redis, ioredis, redis-py, go-redis and Lettuce, so all the soft checks are warnings you
# eyeball, not build-breakers. The hard fail is reserved for `KEYS` because it is essentially
# always wrong on a hot path and trivially confirmable.
#
# Portability: stock macOS bash 3.2 (no mapfile, no associative arrays). Arrays are initialised so
# they expand safely under `set -u`.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# is_test_path <path> — true for files that look like tests/specs/fixtures, where foot-guns are fine.
is_test_path() {
  case "$1" in
    *test*|*Test*|*spec*|*Spec*|*__tests__*|*fixtures*|*/mocks/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Discover candidate source files (common Redis-client languages) and redis.conf, excluding vendor dirs.
SRC_FILES=()
while IFS= read -r -d '' f; do
  SRC_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \
       -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/.next/*' \) -prune -o \
    -type f \( -name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx' -o -name '*.mjs' \
               -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.java' -o -name '*.kt' \
               -o -name '*.lua' -o -name '*.php' -o -name '*.rs' \) -print0 2>/dev/null
)

CONF_FILES=()
while IFS= read -r -d '' f; do
  CONF_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' \) -prune -o \
    -type f \( -name 'redis.conf' -o -name 'valkey.conf' -o -name '*redis*.conf' \) -print0 2>/dev/null
)

# Decide whether this project touches Redis at all. If not, skip cleanly.
# Use -l (newline-separated) not -Z: BSD/macOS grep ignores -Z when listing filenames, so a
# NUL-delimited read loop would mis-parse. Filenames with newlines are not supported here (rare),
# which is an acceptable trade for portability across BSD and GNU grep.
REDIS_HINT=0
HINT_FILES=()
if [ "${#SRC_FILES[@]}" -gt 0 ]; then
  while IFS= read -r f; do
    [ -n "$f" ] && HINT_FILES+=("$f")
  done < <(
    grep -ril -E 'redis|valkey|ioredis|bullmq|sidekiq|XREADGROUP|maxmemory' "${SRC_FILES[@]}" 2>/dev/null || true
  )
fi
if [ "${#HINT_FILES[@]}" -gt 0 ] || [ "${#CONF_FILES[@]}" -gt 0 ]; then
  REDIS_HINT=1
fi

if [ "$REDIS_HINT" -eq 0 ]; then
  skip "no Redis/Valkey usage detected in this project — nothing to check"
  ok "verify.sh passed"
  exit 0
fi

# Only scan the files that actually mentioned Redis (plus conf files), to cut false positives.
SCAN_FILES=()
for f in ${HINT_FILES[@]+"${HINT_FILES[@]}"}; do SCAN_FILES+=("$f"); done
for f in ${CONF_FILES[@]+"${CONF_FILES[@]}"}; do SCAN_FILES+=("$f"); done

# ---- 1. KEYS / KEYS * in non-test source -> HARD FAIL ----
# Match a KEYS command (quoted, or as a client method call), not the identifier "keys" in general.
KEYS_HIT=0
for f in "${SCAN_FILES[@]}"; do
  is_test_path "$f" && continue
  if grep -Eniq "([\"'\` ]KEYS[[:space:]]+[^)]|\.keys\(|->keys\(|[\"'\`]KEYS\*)" "$f" 2>/dev/null; then
    # Exclude obvious false friends: object key iteration like Object.keys(, dict.keys(), .Keys (Go map helpers vary; conservative).
    if grep -Eniq "([\"'\`][[:space:]]*KEYS[[:space:]]|[\"'\`]KEYS\*|redis[^.]*\.keys\(|client\.keys\(|->keys\()" "$f" 2>/dev/null; then
      err "$f: uses Redis KEYS (O(N), blocks the single thread). Use SCAN MATCH ... COUNT ... instead."
      KEYS_HIT=1
    fi
  fi
done
[ "$KEYS_HIT" -eq 0 ] && ok "no Redis KEYS in non-test source"

# ---- 2. FLUSHALL / FLUSHDB in non-test source -> warn ----
for f in "${SCAN_FILES[@]}"; do
  is_test_path "$f" && continue
  if grep -Eniq "FLUSHALL|FLUSHDB|\.flushall\(|\.flushdb\(" "$f" 2>/dev/null; then
    note "$f: FLUSHALL/FLUSHDB present — wipes the instance; never run on a shared/prod Redis."
  fi
done

# ---- 3. Lock release via DEL near a lock key without a token compare -> warn ----
for f in "${SCAN_FILES[@]}"; do
  is_test_path "$f" && continue
  if grep -Eniq "lock" "$f" 2>/dev/null \
     && grep -Eniq "(\.del\(|\.delete\(|->del\(|[\"'\`]DEL[\"'\` ])" "$f" 2>/dev/null \
     && ! grep -Eiq "get'?\)?[[:space:]]*==[[:space:]]*ARGV|get'?[^=]*==[^=]*token|compare.?and.?del|redis\.call\('get'" "$f" 2>/dev/null; then
    note "$f: lock + DEL but no visible token compare-and-delete — a bare DEL can release another owner's lock. Use a Lua GET==token then DEL."
  fi
done

# ---- 4. SET ... NX for a lock with no PX/EX -> warn (lock that can't expire) ----
for f in "${SCAN_FILES[@]}"; do
  is_test_path "$f" && continue
  # A SET with NX but neither PX nor EX on the same line/call is a lock that never auto-frees.
  if grep -Eni "set[^\n]*\bNX\b" "$f" 2>/dev/null | grep -Eivq "\bP?X\b|expire|ttl" 2>/dev/null; then
    if grep -Eni "set[^\n]*\bNX\b" "$f" 2>/dev/null | grep -Eiq "lock" 2>/dev/null; then
      note "$f: SET ... NX on a lock with no PX/EX — a crashed owner holds it forever. Add PX <ttl-ms>."
    fi
  fi
done

# ---- 5. INCR not followed by an EXPIRE (counter with no TTL) -> warn ----
for f in "${SCAN_FILES[@]}"; do
  is_test_path "$f" && continue
  if grep -Eniq "(\.incr\(|->incr\(|[\"'\`]INCR[\"'\` ])" "$f" 2>/dev/null \
     && ! grep -Eniq "(expire|EXPIRE|pexpire|PEXPIRE|EX[[:space:]]|setex|SETEX)" "$f" 2>/dev/null; then
    note "$f: INCR with no EXPIRE in the same file — a rate-limit counter with no TTL counts forever. Set EXPIRE atomically (Lua, or only when n==1)."
  fi
done

# ---- 6/7. redis.conf eviction checks -> warn ----
for f in ${CONF_FILES[@]+"${CONF_FILES[@]}"}; do
  if grep -Eiq "^[[:space:]]*maxmemory[[:space:]]" "$f" 2>/dev/null \
     && ! grep -Eiq "^[[:space:]]*maxmemory-policy" "$f" 2>/dev/null; then
    note "$f: maxmemory set without maxmemory-policy — defaults to noeviction, which 500s a full cache. Set allkeys-lru/lfu for a cache."
  fi
  if grep -Eiq "^[[:space:]]*maxmemory-policy[[:space:]]+noeviction" "$f" 2>/dev/null; then
    case "$f" in
      *cache*|*Cache*) note "$f: maxmemory-policy noeviction on a file that looks like a cache config — a cache must evict (allkeys-lru/lfu), not fail writes." ;;
    esac
  fi
done

# ---- 8. while/long loop inside an inline Lua EVAL string -> warn ----
for f in "${SCAN_FILES[@]}"; do
  is_test_path "$f" && continue
  if grep -Eniq "EVAL|eval" "$f" 2>/dev/null \
     && grep -Eniq "while[[:space:]].*do|for[[:space:]].*=.*,.*do" "$f" 2>/dev/null \
     && grep -Eniq "redis\.call" "$f" 2>/dev/null; then
    note "$f: a loop inside Lua run via EVAL blocks ALL clients while it runs (Redis is single-threaded). Keep each EVAL a short bounded step."
  fi
done

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
