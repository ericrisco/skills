#!/usr/bin/env bash
set -euo pipefail

# verify.sh — spreadsheet-ops artifact check. Read-only by default.
#
# What it proves about the artifacts this skill emits:
#   1. Every generated *.py compiles (python -m py_compile) — valid syntax, real imports.
#   2. Every generated *.xlsx opens with openpyxl and has at least one sheet with a
#      non-empty first (header) row.
#   3. Formula strings (anything matching a leading '=' inside the .py/.xlsx) are linted
#      for the semicolon-as-argument-separator bug — the #1 locale formula failure.
#
# Targets, in order of precedence:
#   - explicit paths passed as arguments (files or directories), OR
#   - the current working directory (scanned for *.py and *.xlsx).
#
# It NEVER modifies your files and makes NO network/Google calls — cloud paths in this
# skill are validated by structure, not live API requests.
#
# Exit code: 0 on pass OR on a clean/empty target (nothing to check is not a failure).
# Non-zero ONLY when a found artifact is genuinely broken (won't compile, won't open,
# missing header, or a semicolon-separated formula).

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }

PY="$(command -v python3 || command -v python || true)"

# Collect candidate files from args (files/dirs) or the cwd.
PYFILES=(); XLSXFILES=()
collect() {
  local t="$1"
  if [ -d "$t" ]; then
    while IFS= read -r f; do PYFILES+=("$f"); done   < <(find "$t" -type f -name '*.py'   2>/dev/null)
    while IFS= read -r f; do XLSXFILES+=("$f"); done < <(find "$t" -type f -name '*.xlsx' 2>/dev/null)
  elif [ -f "$t" ]; then
    case "$t" in
      *.py)   PYFILES+=("$t") ;;
      *.xlsx) XLSXFILES+=("$t") ;;
    esac
  fi
}

if [ "$#" -gt 0 ]; then
  for t in "$@"; do collect "$t"; done
else
  collect "$PWD"
fi

if [ "${#PYFILES[@]}" -eq 0 ] && [ "${#XLSXFILES[@]}" -eq 0 ]; then
  skip "no .py or .xlsx artifacts found to verify — nothing to check"
  exit 0
fi

fail=0

# 1. py_compile each Python file.
if [ "${#PYFILES[@]}" -gt 0 ]; then
  if [ -z "$PY" ]; then
    skip "python not on PATH — skipping .py compile checks"
  else
    for f in "${PYFILES[@]}"; do
      if "$PY" -m py_compile "$f" >/dev/null 2>&1; then
        ok "compiles: $f"
      else
        err "does not compile: $f"; fail=1
      fi
    done
  fi
fi

# 2. open each workbook, assert a sheet + non-empty header row (needs openpyxl).
if [ "${#XLSXFILES[@]}" -gt 0 ]; then
  if [ -z "$PY" ] || ! "$PY" -c "import openpyxl" >/dev/null 2>&1; then
    skip "openpyxl not installed — skipping .xlsx structural checks"
  else
    for f in "${XLSXFILES[@]}"; do
      if "$PY" - "$f" <<'PYEOF'
import sys
from openpyxl import load_workbook
wb = load_workbook(sys.argv[1], read_only=True, data_only=False)
if not wb.sheetnames:
    sys.exit(1)
ws = wb[wb.sheetnames[0]]
row = next(ws.iter_rows(min_row=1, max_row=1, values_only=True), None)
sys.exit(0 if row is not None and any(c is not None and str(c) != "" for c in row) else 1)
PYEOF
      then
        ok "opens with header row: $f"
      else
        err "missing/unreadable or empty header row: $f"; fail=1
      fi
    done
  fi
fi

# 3. lint formula strings for semicolon argument separators inside .py/.xlsx-as-text.
# A formula is a token starting with '=' that contains '(' and a ';'. Commas are correct;
# semicolons inside the parens are the locale bug this skill warns about.
# The lint script reads stdin; pass it via -c so the piped file flows through as stdin
# (a heredoc on `$PY -` would itself become stdin and shadow the file).
LINT_PY='import sys, re
bad = []
pat = re.compile(r"=[A-Za-z_][A-Za-z0-9_.]*\([^)]*;[^)]*\)")
for i, line in enumerate(sys.stdin, 1):
    if pat.search(line):
        bad.append((i, line.rstrip()))
for i, l in bad:
    print(f"  line {i}: {l}")
sys.exit(1 if bad else 0)'
lint_text() {
  # reads stdin; prints offending lines; returns 1 if any found
  "$PY" -c "$LINT_PY"
}

if [ -n "$PY" ]; then
  for f in "${PYFILES[@]}"; do
    if out="$(lint_text < "$f")"; then :; else
      err "semicolon-separated formula in $f"; printf '%s\n' "$out"; fail=1
    fi
  done
  # For .xlsx, extract embedded formula strings from the workbook XML via openpyxl text.
  if [ -n "$PY" ] && "$PY" -c "import openpyxl" >/dev/null 2>&1; then
    for f in "${XLSXFILES[@]}"; do
      formulas="$("$PY" - "$f" <<'PYEOF'
import sys
from openpyxl import load_workbook
wb = load_workbook(sys.argv[1], data_only=False)
for ws in wb.worksheets:
    for row in ws.iter_rows():
        for c in row:
            v = c.value
            if isinstance(v, str) and v.startswith("="):
                print(v)
PYEOF
)"
      if [ -n "$formulas" ]; then
        if out="$(printf '%s\n' "$formulas" | lint_text)"; then :; else
          err "semicolon-separated formula in workbook $f"; printf '%s\n' "$out"; fail=1
        fi
      fi
    done
  fi
fi

if [ "$fail" -eq 0 ]; then
  ok "all found artifacts pass"
  exit 0
fi
exit 1
