#!/usr/bin/env bash
#
# verify.sh - read-only quality gate for plain-Ruby sources.
#
# Usage:
#   cd <dir-with-ruby-sources>   # e.g. a gem root or a scripts directory
#   /path/to/verify.sh [TARGET_DIR]
#
# Checks, all guarded so a Ruby-less box still passes:
#   1. `ruby -c` syntax-checks every *.rb (and *.gemspec) found.
#   2. If a Gemfile exists, `ruby -c` it too (it is Ruby).
#   3. If rubocop or standardrb is present, lint (report only, never fatal).
#
# Read-only: never writes, formats, or mutates your source.
# Exit codes: 0 = clean OR toolchain/target absent; 1 = a real syntax error.
# Portable to stock macOS bash 3.2 (no mapfile, no associative arrays).

set -euo pipefail

target="${1:-.}"

if [ -t 1 ]; then
  YELLOW=$'\033[33m'; RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  YELLOW=''; RED=''; GREEN=''; RESET=''
fi

have() { command -v "$1" >/dev/null 2>&1; }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }

if [ ! -d "$target" ]; then
  printf '%serror:%s target dir not found: %s\n' "$RED" "$RESET" "$target" >&2
  exit 2
fi

if ! have ruby; then
  skip "ruby not found - skipping syntax check (clean pass on a Ruby-less box)"
  exit 0
fi

failed=0
checked=0

# 1 + 2. Syntax-check Ruby sources, gemspecs, and any Gemfile.
#        -print0 / read -d keeps paths-with-spaces safe; no mapfile needed.
while IFS= read -r -d '' file; do
  checked=$((checked + 1))
  if ruby -c "$file" >/dev/null 2>err.$$; then
    ok "ruby -c $file"
  else
    fail "syntax error: $file"
    sed 's/^/      /' err.$$ || true
    failed=1
  fi
  rm -f err.$$
done < <(find "$target" \( -name '*.rb' -o -name '*.gemspec' -o -name 'Gemfile' \) \
          -type f -print0 2>/dev/null)

if [ "$checked" -eq 0 ]; then
  skip "no .rb / .gemspec / Gemfile under $target - nothing to check"
  exit 0
fi

# 3. Optional lint, report-only (style is advisory, not a gate here).
if have standardrb; then
  printf -- '----- standardrb (report only)\n'
  standardrb "$target" || skip "standardrb reported style issues (non-fatal)"
elif have rubocop; then
  printf -- '----- rubocop (report only)\n'
  rubocop "$target" || skip "rubocop reported style issues (non-fatal)"
else
  skip "no rubocop/standardrb - skipping lint"
fi

if [ "$failed" -ne 0 ]; then
  printf '%sverify failed:%s syntax errors above.\n' "$RED" "$RESET" >&2
  exit 1
fi

printf '%sall %d Ruby file(s) parse.%s\n' "$GREEN" "$checked" "$RESET"
exit 0
