#!/usr/bin/env bash
# verify.sh — static checks for NestJS DI hygiene. No Nest install required.
# Read-only. Hard-fails ONLY on a DI bypass (`new XxxService(`/`new XxxRepository(`)
# outside test files. Everything else is a warning. Exits 0 on a clean/empty target.
#
# Usage: scripts/verify.sh [dir]   (defaults to current directory)
set -euo pipefail

DIR="${1:-.}"
HARD_FAIL=0

if [ ! -d "$DIR" ]; then
  echo "verify.sh: '$DIR' is not a directory" >&2
  exit 2
fi

# Collect TypeScript source files, skipping deps and build output.
# Portable to bash 3.2 (macOS) — no mapfile; newline-delimited list.
TS_FILES="$(
  find "$DIR" -type f -name '*.ts' \
    -not -path '*/node_modules/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    2>/dev/null
)"

if [ -z "$TS_FILES" ]; then
  echo "verify.sh: no .ts files found under '$DIR' — nothing to check."
  exit 0
fi

is_test_file() {
  case "$1" in
    *.spec.ts|*.e2e-spec.ts|*.test.ts|*/test/*|*/__tests__/*) return 0 ;;
    *) return 1 ;;
  esac
}

SPEC_PRESENT=0
TESTING_MODULE_PRESENT=0
MAIN_HAS_GLOBALS=0

# main.ts global config detection (any file named main.ts).
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    */main.ts|main.ts)
      if grep -Eq 'useGlobal(Pipes|Filters|Guards|Interceptors)\(' "$f"; then
        MAIN_HAS_GLOBALS=1
      fi
      ;;
  esac
done <<EOF
$TS_FILES
EOF

while IFS= read -r f; do
  [ -z "$f" ] && continue
  if is_test_file "$f"; then
    SPEC_PRESENT=1
    if grep -q 'Test.createTestingModule' "$f"; then
      TESTING_MODULE_PRESENT=1
    fi
    # e2e bootstrap that does not replicate main.ts globals.
    if [ "$MAIN_HAS_GLOBALS" -eq 1 ] && grep -q 'createNestApplication' "$f"; then
      if ! grep -Eq 'useGlobal(Pipes|Filters|Guards|Interceptors)\(' "$f"; then
        echo "WARN  $f: createNestApplication() but no useGlobal* — main.ts sets globals; replicate them or the e2e diverges from prod."
      fi
    fi
    continue
  fi

  # HARD: manual instantiation of a Service/Repository bypasses DI.
  while IFS=: read -r ln _; do
    [ -z "$ln" ] && continue
    echo "FAIL  $f:$ln: 'new ...Service('/'new ...Repository(' bypasses the DI container — constructor-inject instead."
    HARD_FAIL=1
  done < <(grep -nE 'new [A-Za-z0-9_]+(Service|Repository)\(' "$f" | cut -d: -f1 | sed 's/$/:/')

  # WARN: useGlobalPipes/Guards(new X(...)) — cannot inject deps; prefer APP_* token.
  if grep -Eq 'useGlobal(Pipes|Guards|Interceptors|Filters)\(\s*new ' "$f"; then
    echo "WARN  $f: useGlobal*(new X()) cannot inject dependencies — if the pipe/guard needs DI, bind it via an APP_* token in a module's providers."
  fi
done <<EOF
$TS_FILES
EOF

if [ "$SPEC_PRESENT" -eq 1 ] && [ "$TESTING_MODULE_PRESENT" -eq 0 ]; then
  echo "WARN  spec files present but no Test.createTestingModule found — Nest tests should build a TestingModule."
fi

if [ "$HARD_FAIL" -ne 0 ]; then
  echo "verify.sh: DI bypass detected — see FAIL lines above." >&2
  exit 1
fi

echo "verify.sh: OK (warnings above are advisory)."
exit 0
