#!/usr/bin/env bash
set -euo pipefail

# verify.sh — firebase skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, never writes):
#   1. Locates firestore.rules / storage.rules. FAILS if a rules file exists but is empty, or if it
#      carries an open catch-all (`allow read, write: if true;` — any whitespace, with read/write in
#      either order, or a bare `allow read: if true;` / `allow write: if true;`).
#   2. Validates firestore.indexes.json parses as JSON when present (uses node, python3, or jq —
#      whichever exists; skips the parse if none do).
#   3. If the Firebase CLI is present, prints the advisory rules-test path (firebase emulators:exec).
#
# Exit code: non-zero ONLY on a hard failure (open/empty rules, malformed indexes JSON). Missing
# tools and missing Firebase artifacts are skips, never failures. An empty/clean repo exits 0.
#
# Portability: stock macOS bash 3.2 — no mapfile, no associative arrays; arrays are initialised so
# they expand safely under `set -u`.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# ---- 1. Discover rules files ----
RULES_FILES=()
while IFS= read -r -d '' f; do
  RULES_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' -o -path '*/dist/*' \) -prune -o \
    -type f \( -name 'firestore.rules' -o -name 'storage.rules' -o -name '*.rules' \) -print0 2>/dev/null
)

if [ "${#RULES_FILES[@]}" -eq 0 ]; then
  skip "no *.rules files found — not a Firebase project (or rules not in this tree). Nothing to lint."
else
  for f in "${RULES_FILES[@]}"; do
    # strip comments so an example/comment doesn't trip the catch-all check
    body="$(sed -E 's://.*$::' "$f" 2>/dev/null | tr -d '\r' || true)"
    if [ -z "$(printf '%s' "$body" | tr -d '[:space:]')" ]; then
      err "$f: rules file is empty — that is fail-open at deploy time"
      continue
    fi
    # open catch-all: allow [read|write|read, write|write, read] : if true ;
    if printf '%s' "$body" | grep -Eiq 'allow[[:space:]]+(read|write)([[:space:]]*,[[:space:]]*(read|write))?[[:space:]]*:[[:space:]]*if[[:space:]]+true[[:space:]]*;'; then
      err "$f: contains an open rule (allow ...: if true;) — the database is open to the internet. Scope it to request.auth + ownership."
    else
      ok "$f: no open 'if true' catch-all"
    fi
  done
fi

# ---- 2. Validate firestore.indexes.json ----
INDEX_FILES=()
while IFS= read -r -d '' f; do
  INDEX_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' \) -prune -o \
    -type f -name 'firestore.indexes.json' -print0 2>/dev/null
)

if [ "${#INDEX_FILES[@]}" -eq 0 ]; then
  skip "no firestore.indexes.json found — skipping index JSON validation."
else
  parse_json() {
    if command -v jq >/dev/null 2>&1; then jq -e . "$1" >/dev/null 2>&1; return $?; fi
    if command -v node >/dev/null 2>&1; then node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$1" >/dev/null 2>&1; return $?; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" >/dev/null 2>&1; return $?; fi
    return 2
  }
  for f in "${INDEX_FILES[@]}"; do
    if parse_json "$f"; then
      ok "$f: valid JSON"
    elif [ $? -eq 2 ]; then
      skip "$f: no JSON parser (jq/node/python3) available — skipping validation"
    else
      err "$f: malformed JSON — firebase deploy --only firestore:indexes will reject it"
    fi
  done
fi

# ---- 3. Advisory: rules unit testing ----
if command -v firebase >/dev/null 2>&1; then
  note "Firebase CLI found. Run rules tests with: firebase emulators:exec --only firestore \"npm test\""
  note "Reminder: the emulator does NOT enforce composite indexes — keep firestore.indexes.json in sync and deploy it."
else
  skip "firebase CLI not installed — skipping the emulator rules-test hint."
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
