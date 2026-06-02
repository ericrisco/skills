#!/usr/bin/env bash
# verify.sh — prove the TS toolchain enforces strictness + exhaustiveness.
# Read-only on the target: writes ONLY to its own temp dir. Exits 0 with a clear
# message when no TS/node is available (no false failure on a clean machine).
set -euo pipefail

# Resolve a type-checker: prefer tsgo (TS7 preview), else npx typescript's tsc.
# Strict flags are passed on the CLI because naming files on the CLI bypasses tsconfig.
FLAGS="--noEmit --strict --noUncheckedIndexedAccess --target esnext --module nodenext --moduleResolution nodenext"
if command -v tsgo >/dev/null 2>&1; then
  CHECK="tsgo"
elif command -v npx >/dev/null 2>&1; then
  CHECK="npx -y -p typescript tsc"
else
  echo "SKIP: no tsgo and no npx on PATH — cannot type-check. (exit 0)"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# good.ts: exhaustive never guard MUST pass.
cat > "$TMP/good.ts" <<'TS'
type S = { k: "a" } | { k: "b" };
export function f(s: S): number {
  switch (s.k) {
    case "a": return 1;
    case "b": return 2;
    default: { const _: never = s; return _; }
  }
}
TS

# bad.ts: missing "b" case -> never guard MUST fail to compile.
cat > "$TMP/bad.ts" <<'TS'
type S = { k: "a" } | { k: "b" };
export function f(s: S): number {
  switch (s.k) {
    case "a": return 1;
    default: { const _: never = s; return _; }
  }
}
TS

run() { ( cd "$TMP" && $CHECK $FLAGS "$1" ) >/dev/null 2>&1; }

fail=0
if run good.ts; then echo "PASS: good.ts type-checks"; else echo "FAIL: good.ts should compile"; fail=1; fi
if run bad.ts;  then echo "FAIL: bad.ts should NOT compile (exhaustiveness)"; fail=1; else echo "PASS: bad.ts rejected"; fi

if [ "$fail" -ne 0 ]; then echo "verify.sh: FAILED"; exit 1; fi
echo "verify.sh: OK — strict + exhaustiveness enforced"
