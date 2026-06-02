#!/usr/bin/env bash
# verify.sh — static, no-network checker for the linkedin-api feedback log + secret guard.
# Read-only. Confirms each 02-DOCS/wiki/linkedin/*.md carries the required metric front-matter,
# and fails if a LinkedIn token / client secret is committed anywhere in the target tree.
# Exits 0 on a clean or not-yet-run target (no false failure), non-zero on a real issue.
#
# Usage: scripts/verify.sh [TARGET_DIR]   (default: current directory)

set -euo pipefail

TARGET="${1:-.}"
fails=0

if [ ! -d "$TARGET" ]; then
  echo "verify.sh: target '$TARGET' is not a directory" >&2
  exit 2
fi

fail() { echo "FAIL [$1] $2"; fails=$((fails + 1)); }
pass() { echo "PASS [$1] $2"; }
note() { echo "NOTE [$1] $2"; }

# ---------------------------------------------------------------------------
# (1) Feedback-log front-matter check.
# ---------------------------------------------------------------------------
WIKI_DIR="$TARGET/02-DOCS/wiki/linkedin"
REQUIRED_KEYS="post_urn captured_at impressions engagement"

if [ ! -d "$WIKI_DIR" ]; then
  note "wiki" "$WIKI_DIR not present — skill not yet run; nothing to check"
else
  LOG_FILES=()
  while IFS= read -r _f; do
    [ -n "$_f" ] && LOG_FILES+=("$_f")
  done < <(find "$WIKI_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null)

  if [ "${#LOG_FILES[@]}" -eq 0 ]; then
    note "wiki" "$WIKI_DIR exists but holds no *.md feedback files yet"
  else
    for f in "${LOG_FILES[@]}"; do
      missing=""
      for key in $REQUIRED_KEYS; do
        if ! grep -Eq "^${key}:" "$f" 2>/dev/null; then
          missing="$missing $key"
        fi
      done
      if [ -n "$missing" ]; then
        fail "front-matter" "$f missing required key(s):$missing"
      else
        pass "front-matter" "$f has all required metric keys"
      fi
    done
  fi
fi

# ---------------------------------------------------------------------------
# (2) Committed-secret guard. Scans source/config text, skips VCS/vendor dirs.
# ---------------------------------------------------------------------------
SCAN_FILES=()
while IFS= read -r _f; do
  [ -n "$_f" ] && SCAN_FILES+=("$_f")
done < <(
  find "$TARGET" \
    \( -path '*/.git/*' -o -path '*/node_modules/*' -o -path '*/dist/*' \
       -o -path '*/build/*' -o -path '*/.venv/*' -o -path '*/venv/*' \) -prune -o \
    -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.mjs' \
       -o -name '*.json' -o -name '*.env' -o -name '*.yaml' -o -name '*.yml' \
       -o -name '*.md' -o -name '*.sh' \) -print 2>/dev/null
)

secret_hit=0
for f in ${SCAN_FILES[@]+"${SCAN_FILES[@]}"}; do
  [ -f "$f" ] || continue
  # client_secret assigned a literal (not an env reference or a doc placeholder).
  while IFS= read -r line; do
    case "$line" in
      *process.env*|*os.environ*|*ENV[*|*getenv*) continue ;;   # env-injected, fine
      *...*|*Bad:*|*Good:*|*YOUR_*|*example*|*EXAMPLE*) continue ;;  # teaching placeholder, not a real secret
    esac
    fail "secret" "$f: $line"
    secret_hit=1
  done < <(grep -nE 'client_secret[[:space:]]*[=:][[:space:]]*["'"'"'][A-Za-z0-9_.-]{6,}' "$f" 2>/dev/null)

  # AQED-style LinkedIn access-token literal.
  while IFS= read -r line; do
    fail "secret" "$f: $line (LinkedIn access-token literal)"
    secret_hit=1
  done < <(grep -nE 'AQ[ED][A-Za-z0-9_-]{20,}' "$f" 2>/dev/null)
done
[ "$secret_hit" -eq 0 ] && pass "secret" "no committed token / client_secret literals found"

# ---------------------------------------------------------------------------
if [ "$fails" -gt 0 ]; then
  echo "verify.sh: $fails issue(s) in '$TARGET'"
  exit 1
fi
echo "OK: linkedin-api checks passed for '$TARGET'"
exit 0
