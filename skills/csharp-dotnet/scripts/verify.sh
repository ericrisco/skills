#!/usr/bin/env bash
#
# verify.sh - local quality gate for a .NET solution or project (superset of CI).
#
# Usage:
#   cd <your-solution-or-project-root>   # dir with a .sln or .csproj
#   ./verify.sh
#
# Runs: dotnet format --verify-no-changes (style), dotnet build -warnaserror
# (compile + analyzers + NRT warnings as errors), dotnet test (xUnit/NUnit),
# and dotnet list package --vulnerable --include-transitive (NuGet vuln scan).
# A missing `dotnet` is skipped with a yellow warning (not a failure).
# Real problems (unformatted code, build/test failures, known vulnerabilities)
# exit non-zero. Read-only: never mutates your source.
#
# Portability: runs on stock macOS bash 3.2 (no mapfile, no associative arrays).

set -euo pipefail

# Colors only when stdout is a TTY (keeps logs/CI output clean).
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

# Must run from a solution or project root. An empty/clean dir with no project
# is not a failure - nothing to check, exit 0.
sln_count=$( (ls ./*.sln ./*.slnx 2>/dev/null || true) | wc -l | tr -d ' ')
csproj_count=$( (ls ./*.csproj 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "$sln_count" = "0" ] && [ "$csproj_count" = "0" ]; then
  warn "no .sln/.slnx or .csproj in $(pwd) - nothing to verify."
  exit 0
fi

# The whole pipeline needs the dotnet SDK; without it, skip cleanly.
if ! have dotnet; then
  warn "dotnet SDK not found - install .NET 10 SDK to run any checks. Skipping."
  exit 0
fi

# 1. dotnet format --verify-no-changes - style/whitespace/import order, read-only.
info "dotnet format --verify-no-changes"
if dotnet format --verify-no-changes; then
  ok "format clean"
else
  fail "formatting issues (run: dotnet format)"
fi

# 2. dotnet build -warnaserror - compile + analyzers + nullable warnings as errors.
info "dotnet build -warnaserror"
if dotnet build -warnaserror --nologo; then
  ok "build clean (analyzers + NRT)"
else
  fail "build failed or emitted warnings (analyzers/NRT)"
fi

# 3. dotnet test - unit + integration tests.
info "dotnet test"
if dotnet test --nologo; then
  ok "tests pass"
else
  fail "tests failed"
fi

# 4. dotnet list package --vulnerable - known NuGet vulnerabilities are a real failure.
#    The command exits 0 even when vulns exist, so grep the output to decide.
info "dotnet list package --vulnerable --include-transitive"
vuln_out="$(dotnet list package --vulnerable --include-transitive 2>&1 || true)"
if printf '%s' "$vuln_out" | grep -qiE 'has the following vulnerable|Severity'; then
  fail "vulnerable NuGet packages found:"
  printf '%s\n' "$vuln_out"
else
  ok "no known vulnerable packages"
fi

echo
if [ "$failed" -ne 0 ]; then
  printf '%sFAIL:%s one or more checks failed.\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s all checks passed.\n' "$GREEN" "$RESET"
