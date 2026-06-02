#!/usr/bin/env bash
set -euo pipefail

# verify.sh — duckdb skill smoke test. Run from anywhere.
#
# Proves the documented DuckDB commands actually execute on the installed version:
#   1. Prefer the `duckdb` CLI if on PATH; else `python3 -c "import duckdb"`.
#   2. If NEITHER is available -> print SKIP and exit 0 (never a false failure).
#   3. Otherwise: generate a tiny CSV in a temp dir, run an aggregate over a VALUES
#      table AND over read_csv_auto on that file, and assert both equal a known scalar.
#
# Read-only with respect to your project: it only writes inside a private mktemp dir,
# which it removes on exit. No network, no large downloads, deterministic.
#
# Exit code: 0 on pass or skip; non-zero ONLY when DuckDB is present but a documented
# command returns the wrong scalar (a real regression).

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t duckdb_verify)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

CSV="$TMP/sales.csv"
printf 'region,amount\nEU,10\nEU,20\nUS,30\n' > "$CSV"
# Known answers: total sum = 60; EU sum = 30.

run_cli() {
  # Aggregate over an inline VALUES table (no file): expect 60.
  local a b
  a="$(duckdb -noheader -list -c \
        "SELECT sum(amount) FROM (VALUES (10),(20),(30)) AS t(amount)" 2>/dev/null)"
  # Aggregate over the generated CSV via read_csv_auto, filtered to EU: expect 30.
  b="$(duckdb -noheader -list -c \
        "SELECT sum(amount) FROM read_csv_auto('$CSV') WHERE region = 'EU'" 2>/dev/null)"
  [ "$a" = "60" ] && [ "$b" = "30" ]
}

run_py() {
  python3 - "$CSV" <<'PY'
import sys, duckdb
csv = sys.argv[1]
a = duckdb.sql("SELECT sum(amount) FROM (VALUES (10),(20),(30)) AS t(amount)").fetchone()[0]
b = duckdb.sql(f"SELECT sum(amount) FROM read_csv_auto('{csv}') WHERE region = 'EU'").fetchone()[0]
sys.exit(0 if (a == 60 and b == 30) else 1)
PY
}

if command -v duckdb >/dev/null 2>&1; then
  if run_cli; then
    ok "duckdb CLI: VALUES aggregate = 60 and read_csv_auto(EU) = 30"
    exit 0
  else
    err "duckdb CLI ran but returned an unexpected scalar"
    exit 1
  fi
elif command -v python3 >/dev/null 2>&1 && python3 -c "import duckdb" >/dev/null 2>&1; then
  if run_py; then
    ok "python duckdb: VALUES aggregate = 60 and read_csv_auto(EU) = 30"
    exit 0
  else
    err "python duckdb ran but returned an unexpected scalar"
    exit 1
  fi
else
  skip "neither the duckdb CLI nor the python duckdb module is installed — nothing to verify"
  exit 0
fi
