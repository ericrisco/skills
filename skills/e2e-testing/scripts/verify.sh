#!/usr/bin/env bash
#
# verify.sh - read-only static lint for emitted Playwright test/config text.
#
# Usage:
#   /path/to/verify.sh [TARGET_DIR]   # defaults to .
#
# Greps the produced .ts/.js/.mjs/.cts test+config text for this skill's banlist.
# NO browser run, NO network, NO writes. Pure string checks.
#
# Banlist (each is a flake/anti-pattern this skill teaches against):
#   1. waitForTimeout(            -> sleep-based wait
#   2. xpath= or raw // locators  -> brittle XPath
#   3. page.$(  / page.$$(        -> legacy element handles over locators
#   4. expect(await              -> read-once assertion smell
#   5. a playwright.config.* that lacks BOTH `trace` and `retries`
#
# Exit codes: 0 = clean OR nothing to check (empty/clean target);
#             1 = a banned pattern was found.

set -euo pipefail

target="${1:-.}"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi

fail() { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$*"; }

if [ ! -d "$target" ]; then
  printf '%serror:%s target dir not found: %s\n' "$RED" "$RESET" "$target" >&2
  exit 2
fi

# Count candidate source files up front so an empty/clean target exits cleanly.
# Skip node_modules and Playwright's own output/report dirs - lint authored code only.
find_sources() {
  find "$target" \
    \( -name node_modules -o -name '.git' -o -name 'playwright-report' \
       -o -name 'blob-report' -o -name 'test-results' \) -prune -o \
    -type f \( -name '*.ts' -o -name '*.js' -o -name '*.mjs' -o -name '*.cts' \) -print0 \
    2>/dev/null
}

if [ "$(find_sources | tr -dc '\0' | wc -c)" -eq 0 ]; then
  skip "no .ts/.js test or config files under $target - nothing to lint (clean pass)"
  exit 0
fi

failed=0
checked=0

# grep -n on a single file; report each hit indented. Returns 0 if a hit found.
flag() { # $1 = pattern (fixed string), $2 = file, $3 = message
  local hits
  hits=$(grep -nF -- "$1" "$2" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    fail "$3 in $2"
    printf '%s\n' "$hits" | sed 's/^/        /'
    failed=1
  fi
}

# Regex variant (for XPath // and page.$/$$ shapes).
flag_re() { # $1 = ERE pattern, $2 = file, $3 = message
  local hits
  hits=$(grep -nE -- "$1" "$2" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    fail "$3 in $2"
    printf '%s\n' "$hits" | sed 's/^/        /'
    failed=1
  fi
}

while IFS= read -r -d '' file; do
  checked=$((checked + 1))

  # 1. sleep-based waits
  flag 'waitForTimeout(' "$file" "waitForTimeout (sleep-based wait)"

  # 2. XPath: explicit xpath= engine, or a locator string beginning with //
  flag 'xpath=' "$file" "xpath= locator engine"
  flag_re "(locator|getByTestId|click|fill)\([\"'\`]//" "$file" "raw // XPath locator"

  # 3. legacy element handles
  flag_re "page\.\\\$\\\$?\(" "$file" "page.\$ / page.\$\$ element handle (use locators)"

  # 4. read-once assertion smell
  flag 'expect(await ' "$file" "expect(await ...) read-once assertion"

  # 5. config files must declare both trace and retries
  case "$file" in
    *playwright.config.*)
      has_trace=$(grep -c 'trace' "$file" 2>/dev/null || true)
      has_retries=$(grep -c 'retries' "$file" 2>/dev/null || true)
      if [ "${has_trace:-0}" -eq 0 ] || [ "${has_retries:-0}" -eq 0 ]; then
        fail "playwright config missing trace and/or retries: $file"
        failed=1
      else
        ok "config declares trace + retries: $file"
      fi
      ;;
  esac
done < <(find_sources)

if [ "$failed" -ne 0 ]; then
  printf '%sverify failed:%s banned Playwright anti-patterns above.%s\n' "$RED" "$RESET" "$RESET" >&2
  exit 1
fi

printf '%s[ ok ] %d file(s) lint clean - no banned e2e anti-patterns.%s\n' "$GREEN" "$checked" "$RESET"
exit 0
