#!/usr/bin/env bash
# verify.sh — heuristic, advisory static lint for htmx templates.
# Read-only. Scans *.html and common template files for the highest-signal mistakes
# this skill prohibits. Echoes PASS / WARN / FAIL lines. Exits non-zero only on FAIL.
# Empty or clean targets exit 0 (no false failure).
#
# Usage: scripts/verify.sh [DIR]   (default: current directory)
# This is grep/awk-based, not a real HTML parser. Treat output as advisory.

set -u

TARGET="${1:-.}"
FAIL=0
WARN=0
CHECKED=0

# Valid hx-swap base strategies (modifiers after a space/colon are stripped before checking).
VALID_SWAP="innerHTML outerHTML textContent beforebegin afterbegin beforeend afterend delete none"

is_valid_swap() {
  local v="$1"
  for s in $VALID_SWAP; do [ "$v" = "$s" ] && return 0; done
  return 1
}

# Collect candidate template files. Null-delimited to survive spaces.
FILES=()
while IFS= read -r -d '' f; do FILES+=("$f"); done < <(
  find "$TARGET" -type f \( \
      -name '*.html' -o -name '*.htm' -o -name '*.jinja' -o -name '*.jinja2' \
      -o -name '*.j2' -o -name '*.twig' -o -name '*.erb' -o -name '*.blade.php' \
      -o -name '*.ejs' -o -name '*.hbs' \
    \) -not -path '*/node_modules/*' -not -path '*/.git/*' -print0 2>/dev/null
)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "PASS: no HTML/template files found under '$TARGET' — nothing to check."
  exit 0
fi

for f in "${FILES[@]}"; do
  # Only inspect files that actually use htmx attributes.
  grep -Eq 'hx-(get|post|put|patch|delete|target|swap|trigger|swap-oob|boost)' "$f" 2>/dev/null || continue
  CHECKED=$((CHECKED + 1))

  # 1. Invalid hx-swap base value (strip modifiers after whitespace).
  while IFS= read -r raw; do
    base="${raw%%[[:space:]]*}"
    if [ -n "$base" ] && ! is_valid_swap "$base"; then
      echo "FAIL: $f — invalid hx-swap value '$base' (allowed: $VALID_SWAP)"
      FAIL=$((FAIL + 1))
    fi
  done < <(grep -Eo 'hx-swap[[:space:]]*=[[:space:]]*"[^"]*"' "$f" 2>/dev/null \
            | sed -E 's/.*=[[:space:]]*"([^"]*)"/\1/')

  # 2. hx-trigger modifier typos: catch 'dela:', 'delay' w/o colon, 'throtle', 'evry'.
  if grep -Eq 'hx-trigger[[:space:]]*=[[:space:]]*"[^"]*(dela:|delay[^:"]|throtle|throttle[^:"]|evry|revaled)' "$f" 2>/dev/null; then
    echo "WARN: $f — possible hx-trigger modifier typo (check delay:/throttle:/every/revealed spelling)"
    WARN=$((WARN + 1))
  fi

  # 3. hx-target='#id' referencing an id not defined in the same file (best-effort, same-file).
  while IFS= read -r tid; do
    [ -z "$tid" ] && continue
    if ! grep -Eq "id[[:space:]]*=[[:space:]]*[\"']${tid}[\"']" "$f" 2>/dev/null; then
      echo "WARN: $f — hx-target='#${tid}' but no id='${tid}' in the same file (may live elsewhere/OOB)"
      WARN=$((WARN + 1))
    fi
  done < <(grep -Eo 'hx-target[[:space:]]*=[[:space:]]*"#[A-Za-z0-9_-]+"' "$f" 2>/dev/null \
            | sed -E 's/.*"#([A-Za-z0-9_-]+)"/\1/')

  # 4. Uses hx-* attributes but no htmx script include detected (heuristic warn).
  if ! grep -Eq 'htmx(\.org|\.min)?\.js|htmx@|unpkg\.com/htmx|cdn[^"]*htmx' "$f" 2>/dev/null; then
    echo "WARN: $f — hx-* attributes present but no htmx <script> include detected (may be in a layout)"
    WARN=$((WARN + 1))
  fi

  # 5. Raw/unescaped output near content (XSS warn): | safe, |safe, |raw, {!! !!} (Blade), == (ERB raw via raw()).
  if grep -Eq '\|[[:space:]]*safe|\|[[:space:]]*raw|\{!![^}]*!!\}|<%==' "$f" 2>/dev/null; then
    echo "WARN: $f — raw/unescaped template output (| safe / |raw / {!! !!} / <%==) — ensure it is not user content (XSS)"
    WARN=$((WARN + 1))
  fi
done

echo "----"
echo "Checked $CHECKED htmx file(s) of ${#FILES[@]} template file(s). FAIL=$FAIL WARN=$WARN"

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: $FAIL hard violation(s) found."
  exit 1
fi
echo "PASS: no hard violations."
exit 0
