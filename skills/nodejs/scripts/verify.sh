#!/usr/bin/env bash
# verify.sh — static lint for a plain Node.js / Express service scaffold.
# Read-only. No install or run required. Heuristic and advisory.
#
# HARD-FAILS (exit 1) only on:
#   - app.ts calls .listen( (app construction not split from server)
#   - no 4-arg (err,req,res,next) error middleware found anywhere
# Everything else is a WARNING. Exits 0 on a clean/empty target (no false failure).
#
# Usage: scripts/verify.sh [dir]   (defaults to current directory)
set -euo pipefail

DIR="${1:-.}"
HARD_FAIL=0
WARN=0

if [ ! -d "$DIR" ]; then
  echo "verify.sh: '$DIR' is not a directory" >&2
  exit 2
fi

warn() { echo "WARN: $*"; WARN=$((WARN + 1)); }
fail() { echo "FAIL: $*"; HARD_FAIL=$((HARD_FAIL + 1)); }

# Collect JS/TS source files, skipping deps, build output and test files.
# bash 3.2 (macOS) friendly: newline-delimited, no mapfile.
SRC_FILES="$(
  find "$DIR" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.mjs' \) \
    -not -path '*/node_modules/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -not -path '*/.git/*' \
    2>/dev/null
)"

if [ -z "$SRC_FILES" ]; then
  echo "verify.sh: no JS/TS source files under '$DIR' — nothing to check."
  exit 0
fi

is_test_file() {
  case "$1" in
    *.spec.*|*.test.*|*/test/*|*/tests/*|*/__tests__/*) return 0 ;;
    *) return 1 ;;
  esac
}

ERROR_HANDLER_FOUND=0
ERROR_HANDLER_LAST=1   # assume ok until a route appears after it in any app file

while IFS= read -r f; do
  [ -z "$f" ] && continue
  is_test_file "$f" && continue

  base="$(basename "$f")"

  # 1. HARD: app.ts (or app.js/mjs) must not call .listen(
  case "$base" in
    app.ts|app.js|app.mjs)
      if grep -Eq '\.listen\(' "$f"; then
        fail "$f calls .listen() — split app construction from server.ts (server should listen, not app)."
      fi
      ;;
  esac

  # 2. Detect a 4-arg error middleware: (err, req, res, next) used with app.use.
  if grep -Eq '\(\s*err\s*,\s*[A-Za-z_]+\s*,\s*[A-Za-z_]+\s*,\s*[A-Za-z_]+\s*\)' "$f"; then
    ERROR_HANDLER_FOUND=1
    # Heuristic: warn if a 4-arg error handler line precedes a route registration
    # in the same file (app.get/post/.../use("/...")) — handler should be LAST.
    err_line="$(grep -nE 'use\(\s*\(\s*err\s*,' "$f" | head -1 | cut -d: -f1 || true)"
    if [ -n "${err_line:-}" ]; then
      route_after="$(grep -nE 'app\.(get|post|put|patch|delete|use\("/)' "$f" \
        | awk -F: -v e="$err_line" '$1 > e {print; exit}' || true)"
      if [ -n "${route_after:-}" ]; then
        warn "$f registers a route AFTER the 4-arg error handler — the error handler must be LAST."
      fi
    fi
  fi

  # 3. WARN: global unhandledRejection that does not exit/shutdown (used as control flow).
  if grep -Eq "on\(\s*['\"]unhandledRejection['\"]" "$f"; then
    if ! grep -Eq "(process\.exit|shutdown)" "$f"; then
      warn "$f handles 'unhandledRejection' but never exits/shuts down — do not use it as control flow."
    fi
  fi

  # 4. WARN: floating-promise heuristic in controllers/routes/services — a statement-position
  # call to an async-looking name with no await/return/.then/.catch on the line.
  case "$f" in
    */controllers/*|*/routes/*|*/services/*)
      if grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_.]*\(' "$f" \
        | grep -vE '(await|return|=>|\.then|\.catch|=|const|let|var|if|for|while|res\.|console\.|logger\.|app\.|router\.)' \
        | grep -qE '(save|fetch|find|create|update|delete|send|publish|notify|query)[A-Za-z]*\('; then
        warn "$f has a statement-position call to an async-looking function with no await/return — possible floating promise."
      fi
      ;;
  esac
done <<EOF
$SRC_FILES
EOF

if [ "$ERROR_HANDLER_FOUND" -eq 0 ]; then
  fail "no 4-arg (err,req,res,next) error middleware found — register exactly one, LAST."
fi

# 5. WARN: engines.node should pin a supported LTS (>=22).
PKG="$(find "$DIR" -maxdepth 2 -name package.json -not -path '*/node_modules/*' 2>/dev/null | head -1 || true)"
if [ -n "${PKG:-}" ]; then
  if grep -Eq '"engines"' "$PKG"; then
    if ! grep -Eq '"node"\s*:\s*"[^"]*(2[2-9]|[3-9][0-9])' "$PKG"; then
      warn "$PKG engines.node does not clearly pin a supported LTS (>=22; prefer 24)."
    fi
  else
    warn "$PKG has no engines.node — pin a supported Node LTS (>=24)."
  fi
fi

echo
echo "verify.sh: $HARD_FAIL hard failure(s), $WARN warning(s)."
[ "$HARD_FAIL" -gt 0 ] && exit 1
exit 0
