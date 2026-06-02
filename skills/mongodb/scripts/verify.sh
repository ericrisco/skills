#!/usr/bin/env bash
set -euo pipefail

# verify.sh — mongodb skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, never writes, never connects to a database):
#   1. Discovers .js / .mongodb.js files (excluding vendor dirs).
#   2. Foot-gun scan (advisory [warn] unless noted):
#        - committed plaintext credential: mongodb://user:pass@ ...      <- the ONLY hard fail
#        - createIndex(...) with no options object                       <- [warn]
#        - redundant compound-index prefix (one index is a left prefix of another in the same file)
#        - $where JS predicate                                           <- [warn]
#        - unbounded $lookup (a $lookup with no sub-pipeline)            <- [warn]
#        - allowDiskUse: true (may be masking a missing $match index)    <- [warn]
#        - money as a JS number in a seed/insert (heuristic)             <- [warn]
#   3. If `node` is present, runs `node --check` on each file for a syntax pass; else [skip].
#
# Exit code: non-zero ONLY when a committed plaintext credential is found. Everything else —
# missing tools, every heuristic warning, an empty target — is advisory and exits 0.
#
# Portability: stock macOS bash 3.2 (no mapfile, no associative arrays). Arrays are initialised
# so they expand safely under `set -u`.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# Discover JS / mongosh files. bash 3.2 has no mapfile; read NUL-delimited names into an
# explicitly-initialised array so expansion is safe under `set -u`.
JS_FILES=()
while IFS= read -r -d '' f; do
  JS_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/dist/*' -o -path '*/build/*' \) -prune -o \
    \( -type f \( -name '*.mongodb.js' -o -name '*.js' \) \) -print0 2>/dev/null
)

if [ "${#JS_FILES[@]}" -eq 0 ]; then
  skip "no .js / .mongodb.js files found — nothing to scan"
  ok "verify.sh passed"
  exit 0
fi

# ---- 1. Hard fail: committed plaintext credential in a connection string ----
# Matches mongodb://user:password@ or mongodb+srv://user:password@ with a literal (non-empty,
# non-placeholder) password. We treat ${...}, <...>, and process.env as NOT a literal.
for f in "${JS_FILES[@]}"; do
  while IFS= read -r line; do
    case "$line" in
      *mongodb://*:*@*|*mongodb+srv://*:*@*)
        # Ignore obvious placeholders / env interpolation.
        case "$line" in
          *'${'*|*'<'*'>'*|*process.env*|*':@'*|*'://user:pass@localhost'*) continue ;;
        esac
        # Re-confirm there is a colon-delimited secret between scheme and @ that isn't empty.
        if printf '%s' "$line" | grep -Eq 'mongodb(\+srv)?://[^:/@[:space:]]+:[^@/[:space:]]+@'; then
          err "$f: plaintext credential in a mongodb connection string — move it to a secret/env var"
        fi
        ;;
    esac
  done < "$f"
done

# ---- 2. Advisory foot-gun scan ----
for f in "${JS_FILES[@]}"; do
  # createIndex with no options object: createIndex({...})  with no trailing ", { ... }"
  if grep -Eq 'createIndex\(' "$f" \
     && ! grep -Eq 'createIndex\([^)]*\},[[:space:]]*\{' "$f"; then
    note "$f: createIndex(...) with no options object — consider name/partialFilterExpression/unique/expireAfterSeconds"
  fi

  # $where JS predicate — no index, server-side injection surface.
  if grep -Eq '\$where' "$f"; then
    note "$f: \$where runs JS per document (no index, injection surface) — use query operators / \$expr"
  fi

  # Unbounded $lookup: a $lookup that has no sub-pipeline to project/filter the foreign side.
  if grep -Eq '\$lookup' "$f" \
     && ! grep -Eq '\$lookup[^}]*pipeline' "$f"; then
    note "$f: \$lookup with no sub-pipeline — project/filter the foreign side, or model it away (extended reference)"
  fi

  # allowDiskUse: true — may be masking a missing $match index.
  if grep -Eq 'allowDiskUse[[:space:]]*:[[:space:]]*true' "$f"; then
    note "$f: allowDiskUse:true — confirm via explain it isn't masking a missing \$match index"
  fi

  # Money as a JS number heuristic: a price/amount/balance/total field assigned a bare number
  # literal (not NumberDecimal). Catches "amount: 9.99" / "price: 100".
  if grep -Eiq '(amount|price|balance|total|cost)[[:space:]]*:[[:space:]]*-?[0-9]+(\.[0-9]+)?[[:space:]]*[,}]' "$f" \
     && ! grep -q 'NumberDecimal' "$f"; then
    note "$f: money-like field stored as a JS number — use NumberDecimal(\"...\") (Decimal128), floats drift"
  fi
done

# Redundant compound-index prefix: within one file, if index keys A are a left prefix of keys B,
# A is likely redundant. Heuristic on the key-list text between the first {...} of createIndex.
for f in "${JS_FILES[@]}"; do
  KEYS=()
  while IFS= read -r kl; do
    [ -n "$kl" ] && KEYS+=("$kl")
  done < <(grep -Eo 'createIndex\([[:space:]]*\{[^}]*\}' "$f" 2>/dev/null \
            | sed -E 's/.*\{([^}]*)\}.*/\1/' \
            | tr -d ' ' )
  n="${#KEYS[@]}"
  if [ "$n" -ge 2 ]; then
    i=0
    while [ "$i" -lt "$n" ]; do
      j=$((i + 1))
      while [ "$j" -lt "$n" ]; do
        a="${KEYS[$i]}"; b="${KEYS[$j]}"
        # Report once per pair: whichever is the strict left-prefix of the other is redundant.
        short=""; long=""
        case "$b" in "$a"*) short="$a"; long="$b" ;; esac
        case "$a" in "$b"*) short="$b"; long="$a" ;; esac
        if [ -n "$short" ] && [ "${#short}" -lt "${#long}" ]; then
          note "$f: index {$short} is a left prefix of {$long} — the longer one likely covers it"
        fi
        j=$((j + 1))
      done
      i=$((i + 1))
    done
  fi
done

ok "foot-gun scan complete (${#JS_FILES[@]} files)"

# ---- 3. node --check syntax pass ----
if command -v node >/dev/null 2>&1; then
  bad=0
  for f in "${JS_FILES[@]}"; do
    # mongosh files use shell-only globals (db, ObjectId); node --check only parses syntax, which is fine.
    if ! node --check "$f" >/dev/null 2>&1; then
      note "$f: node --check reported a syntax issue (mongosh globals are expected; check real syntax)"
      bad=$((bad + 1))
    fi
  done
  if [ "$bad" -eq 0 ]; then ok "node --check: all files parse"; fi
else
  skip "node not installed — skipping syntax check"
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found a committed credential"; fi
exit "$EXIT"
