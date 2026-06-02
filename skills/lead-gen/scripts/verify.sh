#!/usr/bin/env bash
#
# verify.sh — scored-list QA gate for the `lead-gen` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Lints a produced scored-list CSV against the schema in
#   references/scoring-model.md. Per file it checks:
#     1. Header carries the required columns:
#        account, contact, source, fit, intent, engagement, total, tier, opt_out
#     2. Every data row: account/contact/source/opt_out non-empty (provenance +
#        compliance flag present).
#     3. fit/intent/engagement are integers >= 0 and sum to total.
#     4. total is an integer in 0..100.
#     5. tier label matches its score band (A 90-100, B 75-89, C 60-74).
#   A list missing scoring or compliance fields FAILS the build.
#
# HOW TO RUN (inside YOUR project, pointing at a produced list)
#   ./verify.sh                       # scan ./ for *.csv that look like lists
#   ./verify.sh path/to/list.csv      # lint one file
#   ./verify.sh --path lists/         # scan a directory of lists
#
# EXIT CODES
#   0  clean, or nothing to check (empty/clean target — never a false failure)
#   1  a real schema/compliance failure
#   2  bad usage
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; skip_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; skip_count=$((skip_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --path)    TARGET="${2:?--path needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)        printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
    *)         TARGET="$1"; shift ;;
  esac
done
[ -z "$TARGET" ] && TARGET="."

if [ ! -e "$TARGET" ]; then
  printf '%sPath not found: %s%s\n' "$RED" "$TARGET" "$NC"; exit 2
fi

# Required columns, in any order.
REQUIRED="account contact source fit intent engagement total tier opt_out"

# Collect candidate CSV files.
FILES=""
if [ -f "$TARGET" ]; then
  FILES="$TARGET"
else
  FILES="$(find "$TARGET" -type f -name '*.csv' 2>/dev/null || true)"
fi

if [ -z "$FILES" ]; then
  skip "no .csv list files found under $TARGET — nothing to lint"
  printf '\nok=%d skip=%d fail=%d\n' "$ok_count" "$skip_count" "$fail_count"
  exit 0
fi

# col_index <header_line> <name> : 1-based index of a column, or empty.
col_index() {
  printf '%s' "$1" | tr ',' '\n' | grep -niE "^[[:space:]]*$2[[:space:]]*$" 2>/dev/null \
    | head -n1 | cut -d: -f1
}

# field <line> <index> : the Nth comma-separated field, trimmed.
field() {
  printf '%s' "$1" | cut -d',' -f"$2" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

is_int() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

for f in $FILES; do
  [ -s "$f" ] || { skip "$f is empty — skipped"; continue; }

  header="$(head -n1 "$f")"

  # Skip non-list CSVs gracefully: if it has none of our key columns, it is not
  # a scored list — do not fail an unrelated CSV.
  if ! printf '%s' "$header" | grep -qiE '(^|,)[[:space:]]*total[[:space:]]*(,|$)'; then
    skip "$f has no 'total' column — not a scored list, skipped"
    continue
  fi

  # 1. required columns present
  missing=""
  for col in $REQUIRED; do
    [ -z "$(col_index "$header" "$col")" ] && missing="$missing $col"
  done
  if [ -n "$missing" ]; then
    fail "$f missing required column(s):$missing"
    continue
  fi

  i_acc="$(col_index "$header" account)"
  i_con="$(col_index "$header" contact)"
  i_src="$(col_index "$header" source)"
  i_fit="$(col_index "$header" fit)"
  i_int="$(col_index "$header" intent)"
  i_eng="$(col_index "$header" engagement)"
  i_tot="$(col_index "$header" total)"
  i_tier="$(col_index "$header" tier)"
  i_opt="$(col_index "$header" opt_out)"

  row_errs=0
  lineno=1
  # Read data rows (skip header). tail -n +2 is portable on macOS.
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    [ -z "$line" ] && continue

    acc="$(field "$line" "$i_acc")"
    con="$(field "$line" "$i_con")"
    src="$(field "$line" "$i_src")"
    fit="$(field "$line" "$i_fit")"
    int="$(field "$line" "$i_int")"
    eng="$(field "$line" "$i_eng")"
    tot="$(field "$line" "$i_tot")"
    tier="$(field "$line" "$i_tier")"
    opt="$(field "$line" "$i_opt")"

    # 2. non-empty account/contact/provenance/compliance
    if [ -z "$acc" ] || [ -z "$con" ]; then
      fail "$f:$lineno empty account or contact"; row_errs=$((row_errs + 1)); continue
    fi
    if [ -z "$src" ]; then
      fail "$f:$lineno empty source/provenance"; row_errs=$((row_errs + 1)); continue
    fi
    if [ -z "$opt" ]; then
      fail "$f:$lineno empty opt_out compliance flag"; row_errs=$((row_errs + 1)); continue
    fi

    # 3. subscores integers and sum to total
    if ! is_int "$fit" || ! is_int "$int" || ! is_int "$eng" || ! is_int "$tot"; then
      fail "$f:$lineno fit/intent/engagement/total must be integers (got $fit/$int/$eng/$tot)"
      row_errs=$((row_errs + 1)); continue
    fi
    sum=$((fit + int + eng))
    if [ "$sum" -ne "$tot" ]; then
      fail "$f:$lineno subscores $fit+$int+$eng=$sum != total $tot"
      row_errs=$((row_errs + 1)); continue
    fi

    # 4. total in 0..100
    if [ "$tot" -lt 0 ] || [ "$tot" -gt 100 ]; then
      fail "$f:$lineno total $tot out of range 0..100"; row_errs=$((row_errs + 1)); continue
    fi

    # 5. tier matches band
    case "$tier" in
      A|a) [ "$tot" -ge 90 ] || { fail "$f:$lineno tier A but total $tot < 90"; row_errs=$((row_errs + 1)); } ;;
      B|b) { [ "$tot" -ge 75 ] && [ "$tot" -le 89 ]; } || { fail "$f:$lineno tier B but total $tot not in 75..89"; row_errs=$((row_errs + 1)); } ;;
      C|c) { [ "$tot" -ge 60 ] && [ "$tot" -le 74 ]; } || { fail "$f:$lineno tier C but total $tot not in 60..74"; row_errs=$((row_errs + 1)); } ;;
      *)   fail "$f:$lineno unknown tier '$tier' (expected A/B/C)"; row_errs=$((row_errs + 1)) ;;
    esac
  done < <(tail -n +2 "$f")

  [ "$row_errs" -eq 0 ] && ok "$f passes scored-list schema + compliance checks"
done

printf '\nok=%d skip=%d fail=%d\n' "$ok_count" "$skip_count" "$fail_count"
[ "$fail_count" -gt 0 ] && exit 1
exit 0
