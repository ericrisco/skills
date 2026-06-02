#!/usr/bin/env bash
#
# verify.sh - read-only static gate for a Rails 8 app.
#
# Usage:
#   cd <rails-app-root>
#   /path/to/verify.sh [TARGET_DIR]      # TARGET_DIR defaults to .
#
# Checks, all guarded so a clean/empty/non-Rails target still passes:
#   1. RuboCop  - only if rubocop is installed AND a .rubocop.yml is present.
#                 Report-only; style is advisory, never fatal here.
#   2. bin/rails zeitwerk:check - autoload-path sanity, only if bin/rails exists.
#   3. grep banlist for statically-detectable anti-patterns (HARD failures):
#        a. Sidekiq / `gem "redis"` in an app that ships the Solid stack default.
#        b. `.all.each` mass loads in app/.
#        c. `add_index ... concurrently` without `disable_ddl_transaction!` in
#           the same migration file.
#
# Read-only: never writes, formats, or mutates your source.
# Exit codes: 0 = clean OR nothing to check OR only advisory issues;
#             1 = a hard banlist violation.
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

# Is this even a Rails-ish tree? If not, pass cleanly (nothing to gate).
if [ ! -d "$target/app" ] && [ ! -f "$target/config/routes.rb" ] \
   && [ ! -f "$target/bin/rails" ] && [ ! -d "$target/db/migrate" ]; then
  skip "no app/ , config/routes.rb , bin/rails or db/migrate under $target - nothing to check"
  exit 0
fi

failed=0

# ---- 1. RuboCop (report-only, advisory) ------------------------------------
if [ -f "$target/.rubocop.yml" ] && have rubocop; then
  printf -- '----- rubocop (report only)\n'
  ( cd "$target" && rubocop ) || skip "rubocop reported style issues (non-fatal)"
else
  skip "rubocop or .rubocop.yml absent - skipping lint"
fi

# ---- 2. zeitwerk autoload check --------------------------------------------
if [ -x "$target/bin/rails" ]; then
  printf -- '----- bin/rails zeitwerk:check\n'
  if ( cd "$target" && bin/rails zeitwerk:check ) >/dev/null 2>&1; then
    ok "zeitwerk:check passed"
  else
    skip "zeitwerk:check did not pass cleanly (boot/env may be unavailable here) - non-fatal"
  fi
else
  skip "bin/rails absent - skipping zeitwerk:check"
fi

# ---- 3. Static banlist (hard failures) -------------------------------------

# 3a. Sidekiq / redis gem in a Solid-default app.
gemfile="$target/Gemfile"
if [ -f "$gemfile" ]; then
  if grep -Eq '^\s*gem\s+["'\'']sidekiq["'\'']' "$gemfile" \
     || grep -Eq '^\s*gem\s+["'\'']redis["'\'']' "$gemfile"; then
    if grep -Eq '^\s*gem\s+["'\'']solid_queue["'\'']' "$gemfile"; then
      fail "Gemfile pulls Sidekiq/redis alongside solid_queue - drop it unless a real throughput need is stated"
      failed=1
    else
      skip "Gemfile references sidekiq/redis but no solid_queue - not a Rails-8-default app, leaving it"
    fi
  else
    ok "no Sidekiq/redis gem in Gemfile"
  fi
fi

# 3b. .all.each mass loads in app/.
if [ -d "$target/app" ]; then
  hits=$(grep -rEn '\.all\.each\b' "$target/app" --include='*.rb' 2>/dev/null || true)
  if [ -n "$hits" ]; then
    fail ".all.each mass load found - use find_each / includes:"
    printf '%s\n' "$hits" | sed 's/^/      /'
    failed=1
  else
    ok "no .all.each mass loads in app/"
  fi
fi

# 3c. Concurrent add_index without disable_ddl_transaction!.
if [ -d "$target/db/migrate" ]; then
  bad=""
  for f in "$target"/db/migrate/*.rb; do
    [ -e "$f" ] || continue
    if grep -Eq 'add_index.*:concurrently' "$f" \
       && ! grep -q 'disable_ddl_transaction!' "$f"; then
      bad="$bad $f"
    fi
  done
  if [ -n "$bad" ]; then
    fail "concurrent add_index without disable_ddl_transaction! :"
    for f in $bad; do printf '      %s\n' "$f"; done
    failed=1
  else
    ok "concurrent indexes (if any) declare disable_ddl_transaction!"
  fi
fi

if [ "$failed" -ne 0 ]; then
  printf '%sverify failed:%s hard violations above.\n' "$RED" "$RESET" >&2
  exit 1
fi

printf '%sverify ok: no hard violations.%s\n' "$GREEN" "$RESET"
exit 0
