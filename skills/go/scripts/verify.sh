#!/usr/bin/env bash
#
# verify.sh - local quality gate for a Go module (superset of CI).
#
# Usage:
#   cd <your-go-module-root>   # the directory containing go.mod
#   ./verify.sh
#
# Runs: gofmt, go vet, staticcheck, golangci-lint, go test -race -cover, govulncheck.
# Tools that are not installed are skipped with a yellow warning (not a failure).
# Real problems (unformatted code, vet/test/vuln failures) exit non-zero.
# Read-only: never mutates your source.

set -euo pipefail

readonly YELLOW=$'\033[33m'
readonly RED=$'\033[31m'
readonly GREEN=$'\033[32m'
readonly RESET=$'\033[0m'

failed=0

have()  { command -v "$1" >/dev/null 2>&1; }
warn()  { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail()  { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; failed=1; }
ok()    { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
info()  { printf '----- %s\n' "$*"; }

# Must run from a module root.
if [[ ! -f go.mod ]]; then
  printf '%serror:%s no go.mod in %s - cd into your module root first.\n' \
    "$RED" "$RESET" "$(pwd)" >&2
  exit 2
fi

# 1. gofmt - always available with the Go toolchain; formatting is non-negotiable.
info "gofmt"
if have gofmt; then
  fmt_out="$(gofmt -l .)"
  if [[ -n "$fmt_out" ]]; then
    fail "unformatted files (run: gofmt -w .):"
    printf '%s\n' "$fmt_out"
  else
    ok "gofmt clean"
  fi
else
  warn "gofmt not found (is Go installed?)"
fi

# 2. go vet - always available with the Go toolchain.
info "go vet"
if have go; then
  if go vet ./...; then ok "go vet clean"; else fail "go vet reported issues"; fi
else
  warn "go not found - cannot run go vet/test"
fi

# 3. staticcheck - optional.
info "staticcheck"
if have staticcheck; then
  if staticcheck ./...; then ok "staticcheck clean"; else fail "staticcheck reported issues"; fi
else
  warn "staticcheck not found (go install honnef.co/go/tools/cmd/staticcheck@latest)"
fi

# 4. golangci-lint - optional.
info "golangci-lint"
if have golangci-lint; then
  if golangci-lint run; then ok "golangci-lint clean"; else fail "golangci-lint reported issues"; fi
else
  warn "golangci-lint not found (https://golangci-lint.run/usage/install/)"
fi

# 5. go test -race -cover. -race needs a C toolchain; detect and degrade gracefully.
info "go test -race -cover"
if have go; then
  if CGO_ENABLED=1 go env >/dev/null 2>&1 && have cc; then
    if go test -race -cover ./...; then ok "tests pass (race+cover)"; else fail "tests failed"; fi
  else
    warn "no C compiler for -race; running plain go test -cover"
    if go test -cover ./...; then ok "tests pass (no race)"; else fail "tests failed"; fi
  fi
else
  warn "go not found - skipping tests"
fi

# 6. govulncheck - optional; findings are a real failure.
info "govulncheck"
if have govulncheck; then
  if govulncheck ./...; then ok "no known vulnerabilities"; else fail "govulncheck found vulnerabilities"; fi
else
  warn "govulncheck not found (go install golang.org/x/vuln/cmd/govulncheck@latest)"
fi

echo
if [[ "$failed" -ne 0 ]]; then
  printf '%sFAIL:%s one or more checks failed.\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s all checks passed.\n' "$GREEN" "$RESET"
