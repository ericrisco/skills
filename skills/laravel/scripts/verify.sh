#!/usr/bin/env bash
#
# verify.sh - local quality gate for a Laravel (11/12) project.
#
# Usage:
#   cd <your-laravel-project-root>   # the directory containing composer.json + artisan
#   ./verify.sh
#
# Runs (each only if applicable): composer validate, a framework-version sanity check,
# Pint style in read-only --test mode, the test runner (Pest or `php artisan test`), and a
# grep guard against `protected $guarded = []` under app/Models.
# Read-only: never mutates source, never runs a formatter/migration in write mode.
#
# Degrades gracefully: if there is no Laravel project (no composer.json, or composer.json
# without laravel/framework) or no vendor/ dir, it prints a skip notice and EXITS 0 so it
# never blocks a non-Laravel repo. Portable to stock macOS bash 3.2.

set -euo pipefail

if [ -t 1 ]; then
  YELLOW=$'\033[33m'; RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  YELLOW=''; RED=''; GREEN=''; RESET=''
fi

failed=0

have() { command -v "$1" >/dev/null 2>&1; }
warn() { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; failed=1; }
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
info() { printf -- '----- %s\n' "$*"; }

# Resolve a binary either as a project-local vendor/bin script or a global on PATH.
binof() {
  if [ -x "vendor/bin/$1" ]; then printf 'vendor/bin/%s' "$1"; return 0; fi
  if have "$1"; then printf '%s' "$1"; return 0; fi
  return 1
}

# --- Applicability gate: bail out cleanly when this is not a Laravel project. ---
if [ ! -f composer.json ]; then
  warn "no composer.json in $(pwd) - not a Laravel project, nothing to verify."
  exit 0
fi
if ! grep -q 'laravel/framework' composer.json 2>/dev/null; then
  warn "composer.json has no laravel/framework dependency - skipping Laravel checks."
  exit 0
fi
if [ ! -d vendor ]; then
  warn "no vendor/ dir - run 'composer install' first. Skipping (exit 0)."
  exit 0
fi

# 1. composer validate - the manifest must be well-formed.
info "composer validate"
if have composer; then
  if composer validate --strict --no-check-publish >/dev/null 2>&1; then
    ok "composer.json valid"
  elif composer validate --no-check-publish >/dev/null 2>&1; then
    warn "composer.json valid but not strict-clean (lock drift / metadata) - run: composer validate --strict"
  else
    fail "composer validate reported errors (run: composer validate)"
  fi
else
  warn "composer not found (https://getcomposer.org)"
fi

# 2. Framework version sanity. Prefer artisan; fall back to composer.lock.
info "framework version"
if [ -f artisan ] && have php; then
  ver="$(php artisan --version 2>/dev/null || true)"
  if [ -n "$ver" ]; then ok "$ver"; else warn "could not read 'php artisan --version'"; fi
elif [ -f composer.lock ]; then
  lver="$(grep -A2 '"name": "laravel/framework"' composer.lock 2>/dev/null | grep '"version"' | head -n1 || true)"
  if [ -n "$lver" ]; then ok "composer.lock laravel/framework:$lver"; else warn "version not found in composer.lock"; fi
else
  warn "no artisan / composer.lock - cannot determine framework version"
fi

# 3. Mass-assignment guard: flag `protected $guarded = []` under app/Models.
info "mass-assignment guard (no \$guarded = [])"
if [ -d app/Models ]; then
  # Match an empty-array $guarded with any inner whitespace; ignore commented lines best-effort.
  if grep -REn 'protected[[:space:]]+\$guarded[[:space:]]*=[[:space:]]*\[[[:space:]]*\]' app/Models 2>/dev/null \
       | grep -v '^[^:]*:[0-9]*:[[:space:]]*//' >/dev/null; then
    grep -REn 'protected[[:space:]]+\$guarded[[:space:]]*=[[:space:]]*\[[[:space:]]*\]' app/Models 2>/dev/null \
      | grep -v '^[^:]*:[0-9]*:[[:space:]]*//' || true
    fail "found 'protected \$guarded = []' (mass-assignment footgun) - use an explicit \$fillable allowlist"
  else
    ok "no open \$guarded found in app/Models"
  fi
else
  warn "no app/Models dir - skipping mass-assignment guard"
fi

# 4. Style: Pint in read-only --test mode (never fixes).
info "style (Pint)"
if pint_bin="$(binof pint)"; then
  if $pint_bin --test >/dev/null 2>&1; then
    ok "pint clean"
  else
    fail "pint reports style issues (run: $pint_bin)"
  fi
else
  warn "no pint binary (composer require --dev laravel/pint) - skipping style"
fi

# 5. Tests: Pest preferred, else `php artisan test`.
info "tests (Pest / artisan test)"
if [ -f phpunit.xml ] || [ -f phpunit.xml.dist ] || [ -d tests ]; then
  if pest_bin="$(binof pest)"; then
    if $pest_bin >/dev/null 2>&1; then ok "pest green"; else fail "pest failed (run: $pest_bin)"; fi
  elif [ -f artisan ] && have php; then
    if php artisan test >/dev/null 2>&1; then ok "artisan test green"; else fail "artisan test failed (run: php artisan test)"; fi
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
