#!/usr/bin/env bash
#
# verify.sh — static lint for Notion connector code (outbound Notion API).
#
# WHAT IT DOES (read-only; never edits, never hits the network, no token needed)
#   Greps target .py/.ts/.tsx/.js/.jsx files that touch the Notion API and flags
#   the classic post-2025-09-03 mistakes:
#     1. No pinned Notion-Version / notionVersion -> FAIL (rides the moving
#        default; behavior drifts across versions).
#     2. A deprecated databases/:id/query query path -> FAIL (that endpoint 404s
#        on 2025-09-03+; query against /v1/data_sources/:id/query instead).
#     3. A data-source query with no pagination loop (no has_more AND no
#        next_cursor) -> FAIL (silently drops every row past 100).
#     4. No 429 / Retry-After handling anywhere in a file that queries -> WARN
#        (the integration is capped at ~3 req/s; over-limit returns 429).
#     5. A hardcoded Notion token literal (ntn_.../secret_...) -> FAIL
#        (committed bearer secret = full workspace access; read it from env).
#
# EXIT CODES
#   0  clean, or no relevant file to inspect (empty/clean target is NOT a failure)
#   1  at least one [fail] finding
#   2  bad usage
#
# HOW TO RUN (point it at YOUR code, not the skills repo)
#   ./verify.sh app.ts                 # lint one file
#   ./verify.sh --path src/            # lint every supported file under a dir
#   ./verify.sh                        # scan ./ ; if nothing matches, skip + exit 0
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }

usage() { sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; }

# --- arg parse --------------------------------------------------------------
SCAN_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --path)    SCAN_PATH="${2:?--path needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)        printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
    *)         SCAN_PATH="$1"; shift ;;
  esac
done
[ -z "$SCAN_PATH" ] && SCAN_PATH="."

if [ ! -e "$SCAN_PATH" ]; then
  printf '%sPath not found: %s%s\n' "$RED" "$SCAN_PATH" "$NC"; exit 2
fi

# --- collect candidate source files ----------------------------------------
if [ -f "$SCAN_PATH" ]; then
  FILES="$SCAN_PATH"
else
  FILES="$(find "$SCAN_PATH" -type f \
    \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) \
    2>/dev/null || true)"
fi

# Keep only files that actually touch the Notion API (so we never false-fail on
# unrelated code).
RELEVANT=""
if [ -n "$FILES" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if grep -iEq '@notionhq/client|api\.notion\.com|notionVersion|Notion-Version|data_sources|NOTION_TOKEN' "$f" 2>/dev/null; then
      RELEVANT="$RELEVANT$f
"
    fi
  done <<EOF
$FILES
EOF
fi

# Empty / clean target is NOT a failure.
if [ -z "$RELEVANT" ]; then
  skip "no Notion connector code found under '$SCAN_PATH' — nothing to lint"
  exit 0
fi

n_files="$(printf '%s' "$RELEVANT" | grep -c . || true)"
printf 'Linting %s Notion connector file(s) under: %s\n\n' "$n_files" "$SCAN_PATH"

fail_total=0

while IFS= read -r f; do
  [ -z "$f" ] && continue
  printf '%s— %s%s\n' "$YELLOW" "$f" "$NC"

  # 1. pinned version present? (notionVersion option or Notion-Version header)
  if grep -iEq 'notionVersion|Notion-Version' "$f" 2>/dev/null; then
    ok "  Notion version is pinned"
  else
    fail "  no pinned Notion-Version / notionVersion — pin it (e.g. 2025-09-03):"
    fail_total=$((fail_total + 1))
  fi

  # 2. deprecated databases/:id/query path -> FAIL
  if grep -inE 'databases/[^"'\'' ]*/query|databases\.query' "$f" 2>/dev/null | grep -vq 'data_sources'; then
    hits="$(grep -inE 'databases/[^"'\'' ]*/query|databases\.query' "$f" 2>/dev/null | grep -v 'data_sources' || true)"
    fail "  deprecated databases/:id/query path — 404s on 2025-09-03+; use data_sources/:id/query:"
    printf '%s\n' "$hits" | head -n 5 | sed 's/^/        /'
    fail_total=$((fail_total + 1))
  else
    ok "  no deprecated databases/:id/query path"
  fi

  # Does this file query a data source at all?
  queries=0
  grep -iEq 'data_sources/[^"'\'' ]*/query|dataSources\.query|/v1/data_sources' "$f" 2>/dev/null && queries=1

  if [ "$queries" -eq 1 ]; then
    # 3. pagination loop present? need has_more AND next_cursor referenced
    if grep -q 'has_more' "$f" 2>/dev/null && grep -q 'next_cursor' "$f" 2>/dev/null; then
      ok "  query paginates (has_more + next_cursor)"
    else
      fail "  data-source query without a pagination loop — drops rows past 100; loop on has_more + next_cursor:"
      fail_total=$((fail_total + 1))
    fi

    # 4. 429 / Retry-After handling -> WARN
    if grep -iEq '429|Retry-After|retry-after|retryAfter' "$f" 2>/dev/null; then
      ok "  handles 429 / Retry-After"
    else
      warn "  no 429 / Retry-After handling found — the integration is capped at ~3 req/s"
    fi
  fi

  # 5. hardcoded Notion token literal -> FAIL
  hard="$(grep -inE '["'\''](ntn_|secret_)[A-Za-z0-9]{8,}' "$f" 2>/dev/null \
            | grep -viE 'os\.environ|process\.env|getenv|(^|[[:space:]])//|(^|[[:space:]])#' || true)"
  if [ -n "$hard" ]; then
    fail "  hardcoded Notion token literal — read it from an env var instead:"
    printf '%s\n' "$hard" | head -n 5 | sed 's/^/        /'
    fail_total=$((fail_total + 1))
  else
    ok "  Notion token is read from an env var (no inline literal)"
  fi

  printf '\n'
done <<EOF
$RELEVANT
EOF

cat <<'NOTE'
Note: [fail] = a bug that breaks the call, drops data, or leaks a secret (fix it).
      [warn] = resilience gap (confirm 429/Retry-After is handled somewhere upstream).
NOTE

if [ "$fail_total" -gt 0 ]; then exit 1; fi
exit 0
