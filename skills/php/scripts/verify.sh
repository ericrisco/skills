#!/usr/bin/env bash
#
# verify.sh - local quality gate for a PHP project (superset of CI).
#
# Usage:
#   cd <your-php-project-root>   # the directory containing composer.json
#   ./verify.sh
#
# Runs: composer validate, php -l syntax lint, Pint/PHP-CS-Fixer (style, dry-run),
# PHPStan analyse, and PHPUnit/Pest - each only if the tool/config is present.
# Missing tools are skipped with a yellow warning (not a failure).
# Real problems (invalid composer.json, syntax errors, style/analysis/test failures)
# exit non-zero. Read-only: never mutates your source or runs a formatter in fix mode.
#
# Portability: stock macOS bash 3.2 (no mapfile, no associative arrays, no unguarded
# array expansion under `set -u`). Exits 0 on a clean project and on an empty src tree.

set -euo pipefail

# Colors only when stdout is a TTY (keeps logs/CI output clean).
if [ -t 1 ]; then
  YELLOW=$'\033[33m'; RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  YELLOW=''; RED=''; GREEN=''; RESET=''
fi

failed=0

have()  { command -v "$1" >/dev/null 2>&1; }
warn()  { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail()  { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; failed=1; }
ok()    { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
info()  { printf -- '----- %s\n' "$*"; }

# A binary may be a global on PATH or a project-local vendor/bin script. Resolve either.
binof() {
  if [ -x "vendor/bin/$1" ]; then printf 'vendor/bin/%s' "$1"; return 0; fi
  if have "$1"; then printf '%s' "$1"; return 0; fi
  return 1
}

# Must run from a project root.
if [ ! -f composer.json ]; then
  printf '%serror:%s no composer.json in %s - cd into your project root first.\n' \
    "$RED" "$RESET" "$(pwd)" >&2
  exit 2
fi

# Directories we lint/analyse, only those that exist.
SRC_DIRS=""
for d in src app lib tests; do
  [ -d "$d" ] && SRC_DIRS="$SRC_DIRS $d"
done

# 1. composer validate - the manifest must be well-formed.
info "composer validate"
if have composer; then
  if composer validate --strict --no-check-publish >/dev/null 2>&1; then
    ok "composer.json valid"
  else
    # Re-run to surface the message, but a lockfile drift is a warning, not a hard fail.
    if composer validate --no-check-publish >/dev/null 2>&1; then
      warn "composer.json valid but not strict-clean (lock drift / metadata) - run: composer validate --strict"
    else
      fail "composer validate reported errors (run: composer validate)"
    fi
  fi
else
  warn "composer not found (https://getcomposer.org)"
fi

# 2. php -l syntax lint across the source tree. No files = nothing to do (clean exit).
info "php -l (syntax lint)"
if have php; then
  if [ -z "$SRC_DIRS" ]; then
    warn "no src/app/lib/tests directory to lint"
  else
    lint_failed=0
    file_count=0
    # find with -print0 + a while/read loop is bash-3.2 safe and space-safe.
    while IFS= read -r -d '' f; do
      file_count=$((file_count + 1))
      if ! php -l "$f" >/dev/null 2>&1; then
        php -l "$f" || true
        lint_failed=1
      fi
    done < <(find $SRC_DIRS -name '*.php' -type f -print0 2>/dev/null)

    if [ "$file_count" -eq 0 ]; then
      warn "no .php files found under:$SRC_DIRS"
    elif [ "$lint_failed" -ne 0 ]; then
      fail "PHP syntax errors found"
    else
      ok "syntax clean ($file_count files)"
    fi
  fi
else
  warn "php not found - cannot lint/analyse/test"
fi

# 3. Style: Pint preferred, else PHP-CS-Fixer. Always dry-run / test mode (read-only).
info "style (Pint / PHP-CS-Fixer)"
if pint_bin="$(binof pint)"; then
  if $pint_bin --test >/dev/null 2>&1; then
    ok "pint clean"
  else
    fail "pint reports style issues (run: $pint_bin)"
  fi
elif fixer_bin="$(binof php-cs-fixer)"; then
  if $fixer_bin fix --dry-run >/dev/null 2>&1; then
    ok "php-cs-fixer clean"
  else
    fail "php-cs-fixer reports style issues (run: $fixer_bin fix)"
  fi
else
  warn "no formatter found (composer require --dev laravel/pint)"
fi

# 4. PHPStan - only if a config exists (else we cannot know the intended level).
info "phpstan"
if [ -f phpstan.neon ] || [ -f phpstan.neon.dist ] || [ -f phpstan.dist.neon ]; then
  if stan_bin="$(binof phpstan)"; then
    if $stan_bin analyse --no-progress >/dev/null 2>&1; then
      ok "phpstan clean"
    else
      $stan_bin analyse --no-progress || true
      fail "phpstan reported issues"
    fi
  else
    warn "phpstan config present but binary not found (composer require --dev phpstan/phpstan)"
  fi
else
  warn "no phpstan.neon - skipping static analysis"
fi

# 5. Tests: Pest preferred, else PHPUnit - only if a test config/dir exists.
info "tests (Pest / PHPUnit)"
if [ -f phpunit.xml ] || [ -f phpunit.xml.dist ] || [ -f Pest.php ] || [ -d tests ]; then
  if pest_bin="$(binof pest)"; then
    if $pest_bin >/dev/null 2>&1; then ok "pest green"; else fail "pest failed (run: $pest_bin)"; fi
  elif phpunit_bin="$(binof phpunit)"; then
    if $phpunit_bin >/dev/null 2>&1; then ok "phpunit green"; else fail "phpunit failed (run: $phpunit_bin)"; fi
  else
    warn "tests present but no runner found (composer require --dev pestphp/pest)"
  fi
else
  warn "no phpunit.xml / tests dir - skipping tests"
fi

echo
if [ "$failed" -ne 0 ]; then
  printf '%sFAIL:%s one or more checks failed.\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s all checks passed.\n' "$GREEN" "$RESET"
