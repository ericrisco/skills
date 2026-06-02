#!/usr/bin/env bash
#
# verify.sh — compliance/resilience linter for the `data-scraper` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Statically lints a candidate scraper (a file or directory of source) for the
#   four properties the skill insists on before a scrape ships. It greps source
#   for signal patterns — it does not run the scraper or hit any network.
#
#   Per-file scan of *.py *.js *.ts *.mjs *.cjs (the languages the starters use).
#   A file with no scraping signal at all is skipped, so this never false-fails
#   on an unrelated repo (and an empty/clean target exits 0).
#
#   Checks (a FAILURE is only ever an unbounded scrape or a circumvention call —
#   those are not judgement calls):
#     1. Compliance preflight present  -> robots.txt / ToS / ai.txt / robotparser
#        / ROBOTSTXT_OBEY reference somewhere in the target.   (missing -> warn)
#     2. Per-host pacing present       -> a delay/sleep/throttle/concurrency/
#        rate-limit/Crawl-delay/AUTOTHROTTLE signal.           (missing -> FAIL)
#     3. Retry / backoff present       -> backoff/retry/Retry-After/max_retries
#        /exponential signal.                                  (missing -> warn)
#     4. No circumvention              -> a CAPTCHA-solver call (2captcha,
#        twocaptcha, anticaptcha, capsolver, deathbycaptcha, solve_captcha) or an obvious
#        auth-bypass marker.                                   (present -> FAIL)
#
#   "Scraping signal" = the file imports/uses one of: requests, httpx, curl_cffi,
#   playwright, crawlee, scrapy, beautifulsoup/bs4, selectolax, puppeteer, cheerio.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                 # scan ./ for scraper source
#   ./verify.sh --path src      # scan a subdirectory or a single file
#   ./verify.sh --strict        # treat any warning as a failure (exit 1)
#
# EXIT CODES
#   0  clean, or warnings only without --strict (also: nothing to check)
#   1  an unbounded scrape (no pacing) or a circumvention call, or --strict + warn
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

usage() { sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'; }

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

# --- collect candidate source files -----------------------------------------
TMPDIR_V="$(mktemp -d 2>/dev/null || printf '/tmp/dscrape-verify.%s' "$$")"
mkdir -p "$TMPDIR_V" 2>/dev/null || true
cleanup() { rm -rf "$TMPDIR_V" 2>/dev/null || true; }
trap cleanup EXIT
ALL="$TMPDIR_V/all"
TARGETS="$TMPDIR_V/targets"

find "$SCAN_PATH" -type f \
  \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.mjs' -o -name '*.cjs' \) \
  2>/dev/null > "$ALL" || true

if [ ! -s "$ALL" ]; then
  skip "no source files (*.py *.js *.ts *.mjs *.cjs) under: $SCAN_PATH"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# Keep only files that look like scrapers (import/use an HTTP/scrape library).
SCRAPE_LIB='requests|httpx|curl_cffi|playwright|crawlee|scrapy|bs4|beautifulsoup|selectolax|puppeteer|cheerio'
: > "$TARGETS"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -iEq "$SCRAPE_LIB" "$f" 2>/dev/null; then
    printf '%s\n' "$f" >> "$TARGETS"
  fi
done < "$ALL"

if [ ! -s "$TARGETS" ]; then
  skip "no scraper source detected (no requests/httpx/playwright/crawlee/scrapy/... usage)"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

n_targets="$(wc -l < "$TARGETS" | tr -dc '0-9')"
ok "scraper source detected in $n_targets file(s)"

# Helper: does ANY target file match a (case-insensitive) ERE pattern?
any_match() {
  pattern="$1"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if grep -iEq "$pattern" "$f" 2>/dev/null; then return 0; fi
  done < "$TARGETS"
  return 1
}

# Helper: list target files that match (for FAIL detail).
list_match() {
  pattern="$1"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if grep -iEq "$pattern" "$f" 2>/dev/null; then printf '  %s\n' "$f"; fi
  done < "$TARGETS"
}

# --- 1. compliance preflight -------------------------------------------------
PREFLIGHT='robots\.txt|robotstxt_obey|robotfileparser|robotparser|can_fetch|ai\.txt|terms of service|tos preflight|compliance preflight'
if any_match "$PREFLIGHT"; then
  ok "compliance preflight present (robots.txt / ToS / robotparser reference)"
else
  warn "no robots.txt / ToS / compliance preflight found — add the legal gate before requests"
fi

# --- 2. per-host pacing (the hard one) ---------------------------------------
PACING='download_delay|crawl[_-]?delay|autothrottle|rate[_-]?limit|ratelimit|max_concurrency|concurrent_requests|max_requests_per|throttle|time\.sleep|asyncio\.sleep|setTimeout|sleep\('
if any_match "$PACING"; then
  ok "per-host pacing / concurrency cap present (delay / throttle / concurrency)"
else
  fail "no rate limit, delay, or concurrency cap found — unbounded scrape will get blocked/banned:"
  list_match "$SCRAPE_LIB"
fi

# --- 3. retry / backoff ------------------------------------------------------
BACKOFF='backoff|retry|retries|retry-after|retry_after|max_request_retries|exponential|tenacity'
if any_match "$BACKOFF"; then
  ok "retry / backoff present"
else
  warn "no retry/backoff found — transient errors will drop records; honor 429/Retry-After"
fi

# --- 4. no circumvention (the other hard one) --------------------------------
CIRCUMVENT='2captcha|twocaptcha|anti-?captcha|anticaptcha|capsolver|deathbycaptcha|captcha[_-]?solver|solve[_-]?captcha|bypass[_-]?(auth|login|captcha|block)'
if any_match "$CIRCUMVENT"; then
  fail "circumvention call detected (CAPTCHA solver / auth-or-block bypass) — this is the legal line you do not cross:"
  list_match "$CIRCUMVENT"
else
  ok "no CAPTCHA-solver / auth-bypass call detected"
fi

printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
