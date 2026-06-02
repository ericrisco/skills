#!/usr/bin/env bash
#
# verify.sh — connector-module structure/banlist linter for `api-connector-builder`.
#
# WHAT IT DOES (read-only; never edits a file)
#   Lints the connector source the skill produces against the four-pillar shape:
#   secrets, retries, pagination, timeouts. It checks the artifact's STRUCTURE,
#   not its runtime behavior — appropriate for a connector emitted into an
#   arbitrary target repo. It never false-fails: a repo with no connector-like
#   source is simply skipped.
#
#   A connector file = a .py / .ts / .js / .mjs / .tsx file that looks like an
#   HTTP client (mentions a base URL, fetch/httpx/requests/undici/axios, or an
#   Authorization/Bearer header). Other files are ignored.
#
#   Checks per connector file:
#     1. FAIL  hardcoded secret  — an inline API key / bearer literal / long
#              token-looking string assigned in source (not read from env).
#     2. FAIL  no retry wired    — no tenacity import, no backoff loop, and no
#              undici/axios retry interceptor anywhere in the file.
#     3. FAIL  no pagination loop — uses pagination-style params (cursor/offset/
#              page/after/Link) but has no loop (while/for/async generator) to
#              walk them: a lone "get first page" that ignores the next cursor.
#     4. FAIL  no request timeout — issues HTTP calls but sets no timeout /
#              AbortSignal.timeout on them.
#     5. FAIL  token in localStorage  — long-lived token stored in localStorage.
#     6. WARN  token logging      — a log/console call that emits the token,
#              Authorization header, or Bearer value.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                 # scan ./ for connector source
#   ./verify.sh --path src      # scan a subdirectory
#   ./verify.sh --strict        # treat any warning as a failure (exit 1)
#
# EXIT CODES
#   0  clean, or warnings only without --strict (also: nothing to check)
#   1  a structural failure, or --strict with a warning
#   2  bad usage
#
# Runs on stock macOS bash 3.2 — no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; skip_count=0; warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; skip_count=$((skip_count + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

SCAN_PATH="."
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --path)    SCAN_PATH="${2:?--path needs a value}"; shift 2 ;;
    --strict)  STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
  esac
done

if [ ! -e "$SCAN_PATH" ]; then
  printf '%sPath not found: %s%s\n' "$RED" "$SCAN_PATH" "$NC"; exit 2
fi

TMPDIR_V="$(mktemp -d 2>/dev/null || printf '/tmp/apiconn-verify.%s' "$$")"
mkdir -p "$TMPDIR_V" 2>/dev/null || true
cleanup() { rm -rf "$TMPDIR_V" 2>/dev/null || true; }
trap cleanup EXIT

ALL="$TMPDIR_V/all"
FILES="$TMPDIR_V/files"

# Candidate source files (skip node_modules / vendored / build dirs).
find "$SCAN_PATH" -type f \
  \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.mjs' \) \
  2>/dev/null \
  | grep -Ev '/(node_modules|\.git|dist|build|\.venv|venv|__pycache__)/' \
  > "$ALL" || true

# Keep only files that look like an HTTP client (a connector).
: > "$FILES"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -Eiq 'https?://|\bfetch\(|\bhttpx\b|\brequests\.|\bundici\b|\baxios\b|Authorization|Bearer ' "$f" 2>/dev/null; then
    printf '%s\n' "$f" >> "$FILES"
  fi
done < "$ALL"

if [ ! -s "$FILES" ]; then
  skip "no connector-like source (.py/.ts/.js with an HTTP client) under: $SCAN_PATH"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# --- per-file checks ---------------------------------------------------------
while IFS= read -r f; do
  [ -z "$f" ] && continue
  file_ok=1

  # 1. Hardcoded secret: an inline literal assigned to a key/token/secret-looking
  #    name, OR a Bearer/sk- literal embedded in source. Reading from env is fine.
  if grep -Eni \
      '(api[_-]?key|secret|token|bearer|password|client[_-]?secret)[[:space:]]*[:=][[:space:]]*["'\''][A-Za-z0-9_\-]{16,}["'\'']' \
      "$f" 2>/dev/null | grep -Eiv 'process\.env|os\.environ|getenv|import\.meta\.env|<[^>]*>|YOUR_|EXAMPLE|xxxx|\.\.\.' >/dev/null; then
    fail "hardcoded secret literal: $f"
    file_ok=0
  fi
  if grep -Eni '["'\''](sk_live_|sk_test_|ghp_|xox[baprs]-|AKIA)[A-Za-z0-9_\-]{8,}' "$f" 2>/dev/null >/dev/null; then
    fail "hardcoded provider token literal: $f"
    file_ok=0
  fi

  # 2. Retry mechanism wired somewhere in the file.
  if grep -Eiq 'tenacity|@retry|wait_exponential|backoff|retry_if|maxRetries|max_retries|interceptors\.|retry[_-]?interceptor|exponential' "$f" 2>/dev/null; then
    : # has a retry primitive
  elif grep -Eiq 'for[[:space:]].*attempt|while[[:space:]].*attempt|range\([[:space:]]*[0-9]|attempt[[:space:]]*[+<]' "$f" 2>/dev/null \
       && grep -Eiq 'sleep|setTimeout|delay|backoff' "$f" 2>/dev/null; then
    : # has a hand-rolled retry loop with a delay
  else
    fail "no retry mechanism wired (no tenacity/backoff/interceptor or retry loop): $f"
    file_ok=0
  fi

  # 3. Pagination loop, only required when the file uses pagination params.
  if grep -Eiq 'cursor|next[_-]?cursor|endCursor|hasNextPage|pageInfo|offset|\bpage\b|\bafter\b|rel="next"|Link' "$f" 2>/dev/null; then
    if grep -Eiq 'while[[:space:]]|for[[:space:]]|yield|async[[:space:]]*function\*|def[[:space:]]+iter|->[[:space:]]*Generator|AsyncIterator' "$f" 2>/dev/null; then
      : # walks the pages
    else
      fail "pagination params used but no loop to walk them (first-page-only): $f"
      file_ok=0
    fi
  fi

  # 4. Request timeout set on the HTTP calls.
  if grep -Eiq 'timeout|AbortSignal\.timeout|AbortController|signal[[:space:]]*[:=]|connect_timeout|read_timeout' "$f" 2>/dev/null; then
    : # a timeout is configured
  else
    fail "no request timeout set (a hung socket will stall the run): $f"
    file_ok=0
  fi

  # 5. Token in localStorage (long-lived secret in an XSS-readable store).
  if grep -Eiq 'localStorage\.(setItem|getItem)?[[:space:]]*\(?[^)]*\b(token|bearer|access[_-]?token|refresh[_-]?token|api[_-]?key)\b' "$f" 2>/dev/null \
     || grep -Eiq 'localStorage[^;]*\b(token|access_token|refresh_token|apiKey)\b' "$f" 2>/dev/null; then
    fail "token stored in localStorage (XSS-readable): $f"
    file_ok=0
  fi

  # 6. WARN: logging the token / Authorization header.
  if grep -Eni '(console\.(log|info|debug|warn|error)|logg?(er)?\.|print|logging\.)[^;\n]*\b(token|bearer|authorization)\b' "$f" 2>/dev/null \
     | grep -Eiv 'x-request-id|status|attempt|request[_-]?id|//|#' >/dev/null; then
    warn "possible token/Authorization logging: $f"
  fi

  if [ "$file_ok" -eq 1 ]; then
    ok "connector shape ok: $f"
  fi
done < "$FILES"

printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
