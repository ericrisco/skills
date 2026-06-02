#!/usr/bin/env bash
#
# verify.sh — competitor-tracker / change-log / monitoring-config linter for the
# `competitor-watch` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Lints the structured artifacts this skill emits against the rules in SKILL.md.
#   It keys off filenames and CSV headers, so any unrelated file is simply skipped
#   and an empty/clean target never false-fails.
#
#   Checks:
#     1. CHANGE LOG — any CSV whose header contains both `axis` and `materiality`
#        (e.g. change-log.csv). Per data row:
#          - `axis`        must be one of pricing|feature|positioning|messaging|team|other  (FAIL)
#          - `materiality` must be one of high|medium|low                                   (FAIL)
#          - `url`  must be non-empty                                                       (FAIL)
#          - `date` must be non-empty                                                       (FAIL)
#     2. FEATURE MATRIX — any CSV with paired `<x>_value` + `<x>_source_url` +
#        `<x>_date` columns. A non-empty value with an empty source_url OR empty
#        date is an invented fact                                                            (FAIL)
#     3. MONITORING CONFIG — cadence sanity (WARN, never fail). In any *.md/*.yaml/
#        *.yml/*.txt file, a line that names an axis and a cadence where:
#          - a slow axis (positioning|careers|team|reviews|social) is paired with a
#            sub-15-minute cadence  -> noise/cost                                            (WARN)
#          - the pricing axis is paired with a slower-than-daily cadence (weekly/
#            monthly)                -> a missed move                                        (WARN)
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                 # scan ./ for tracker / change-log / config files
#   ./verify.sh --path 02-DOCS  # scan a subdirectory
#   ./verify.sh --strict        # treat any warning as a failure (exit 1)
#
# EXIT CODES
#   0  clean, or warnings only without --strict (also: nothing to check)
#   1  a structural violation (bad axis/materiality, missing url/date, unsourced
#      value), or --strict with a warning
#   2  bad usage
#
# Runs on stock macOS bash 3.2 — no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; skip_count=0; warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; skip_count=$((skip_count + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'; }

SCAN_PATH="."
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --path)    SCAN_PATH="${2:?--path needs a value}"; shift 2 ;;
    --strict)  STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
  esac
done

if [ ! -e "$SCAN_PATH" ]; then
  printf '%sPath not found: %s%s\n' "$RED" "$SCAN_PATH" "$NC"; exit 2
fi

TMPDIR_V="$(mktemp -d 2>/dev/null || printf '/tmp/cw-verify.%s' "$$")"
mkdir -p "$TMPDIR_V" 2>/dev/null || true
cleanup() { rm -rf "$TMPDIR_V" 2>/dev/null || true; }
trap cleanup EXIT

CSV_FILES="$TMPDIR_V/csv"
CFG_FILES="$TMPDIR_V/cfg"
find "$SCAN_PATH" -type f -name '*.csv' 2>/dev/null > "$CSV_FILES" || true
find "$SCAN_PATH" -type f \
  \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' -o -name '*.txt' \) \
  2>/dev/null > "$CFG_FILES" || true

# Allowed sets (whitespace-padded for safe substring match).
AXES=" pricing feature positioning messaging team other "
MATS=" high medium low "

# Find the 0-based index of a column name in a comma-separated header line.
# Echoes -1 if absent.
col_index() {
  header="$1"; want="$2"
  idx=-1; i=0
  oldifs="$IFS"; IFS=','
  for c in $header; do
    # trim spaces and a trailing CR
    c="$(printf '%s' "$c" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [ "$c" = "$want" ]; then idx=$i; fi
    i=$((i + 1))
  done
  IFS="$oldifs"
  printf '%s' "$idx"
}

# Echo the Nth (0-based) field of a CSV row. Simple split on comma — values in this
# schema do not contain commas; quoted commas would need a real parser, which is out
# of scope for a lint (we only read low-structure tracker cells).
field_at() {
  row="$1"; n="$2"
  i=0
  oldifs="$IFS"; IFS=','
  for c in $row; do
    if [ "$i" -eq "$n" ]; then
      printf '%s' "$c" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
      IFS="$oldifs"; return 0
    fi
    i=$((i + 1))
  done
  IFS="$oldifs"
  printf ''
}

# ---------------------------------------------------------------------------
# 1 + 2. CSV checks
# ---------------------------------------------------------------------------
csv_change_log_seen=0
csv_matrix_seen=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  header="$(head -n 1 "$f" 2>/dev/null | tr -d '\r')"
  [ -z "$header" ] && continue

  # --- change log: header has both axis and materiality ---
  ai="$(col_index "$header" axis)"
  mi="$(col_index "$header" materiality)"
  ui="$(col_index "$header" url)"
  di="$(col_index "$header" date)"
  if [ "$ai" -ge 0 ] && [ "$mi" -ge 0 ]; then
    csv_change_log_seen=1
    rownum=0; bad=0
    while IFS= read -r row; do
      rownum=$((rownum + 1))
      [ "$rownum" -le 1 ] && continue   # skip header
      # skip blank lines
      [ -z "$(printf '%s' "$row" | tr -d ', \r')" ] && continue

      axv="$(field_at "$row" "$ai")"
      mav="$(field_at "$row" "$mi")"
      case "$AXES" in *" $axv "*) : ;; *) fail "$f row $rownum: axis '$axv' not in {pricing,feature,positioning,messaging,team,other}"; bad=1 ;; esac
      case "$MATS" in *" $mav "*) : ;; *) fail "$f row $rownum: materiality '$mav' not in {high,medium,low}"; bad=1 ;; esac
      if [ "$ui" -ge 0 ]; then
        urv="$(field_at "$row" "$ui")"
        [ -z "$urv" ] && { fail "$f row $rownum: empty url"; bad=1; }
      fi
      if [ "$di" -ge 0 ]; then
        dtv="$(field_at "$row" "$di")"
        [ -z "$dtv" ] && { fail "$f row $rownum: empty date"; bad=1; }
      fi
    done < "$f"
    [ "$bad" -eq 0 ] && ok "change log clean: $f"
  fi

  # --- feature matrix: any <x>_value with a PAIRED <x>_source_url column ---
  # discover candidate prefixes that have a *_value column, then keep only those
  # that also declare a *_source_url column (so change-log old_value/new_value,
  # which have no paired source column, are not mistaken for matrix cells).
  cand="$(printf '%s' "$header" | tr ',' '\n' | sed 's/\r//' | sed -n 's/^[[:space:]]*\([A-Za-z0-9_]*\)_value[[:space:]]*$/\1/p')"
  prefixes=""
  for pre in $cand; do
    if [ "$(col_index "$header" "${pre}_source_url")" -ge 0 ]; then
      prefixes="$prefixes $pre"
    fi
  done
  if [ -n "$(printf '%s' "$prefixes" | tr -d ' ')" ]; then
    csv_matrix_seen=1
    bad=0
    for pre in $prefixes; do
      vi="$(col_index "$header" "${pre}_value")"
      si="$(col_index "$header" "${pre}_source_url")"
      pi="$(col_index "$header" "${pre}_date")"
      rownum=0
      while IFS= read -r row; do
        rownum=$((rownum + 1))
        [ "$rownum" -le 1 ] && continue   # skip header
        [ -z "$(printf '%s' "$row" | tr -d ', \r')" ] && continue
        val="$(field_at "$row" "$vi")"
        [ -z "$val" ] && continue   # blank value is honest; nothing to source
        src=""; dat=""
        [ "$si" -ge 0 ] && src="$(field_at "$row" "$si")"
        [ "$pi" -ge 0 ] && dat="$(field_at "$row" "$pi")"
        if [ -z "$src" ] || [ -z "$dat" ]; then
          fail "$f row $rownum: '${pre}' value '$val' has no source_url+date (invented fact)"
          bad=1
        fi
      done < "$f"
    done
    [ "$bad" -eq 0 ] && ok "feature-matrix cells all sourced+dated: $f"
  fi
done < "$CSV_FILES"

[ "$csv_change_log_seen" -eq 0 ] && skip "no change-log CSV (header with axis+materiality) found"
[ "$csv_matrix_seen" -eq 0 ] && skip "no feature-matrix CSV (<x>_value/_source_url/_date) found"

# ---------------------------------------------------------------------------
# 3. Monitoring-config cadence sanity (WARN only)
# ---------------------------------------------------------------------------
SLOW_AXES="positioning careers team reviews review social"
cfg_seen=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # only consider files that look like config (mention a cadence keyword)
  grep -iqE 'cadence|every|min|hour|daily|weekly|monthly' "$f" 2>/dev/null || continue
  while IFS= read -r ln; do
    low="$(printf '%s' "$ln" | tr 'A-Z' 'a-z')"
    case "$low" in *axis*|*cadence*|*pricing*|*positioning*|*careers*) : ;; *) continue ;; esac

    # sub-15-minute cadence present on the line?
    sub15=0
    # patterns like 5m, 10 min, 00:10:00, "5 minutes", "every 10 min"
    if printf '%s' "$low" | grep -Eq '(^|[^0-9])(0?[0-9]|1[0-4])[[:space:]]*m(in)?([^a-z]|$)'; then sub15=1; fi
    if printf '%s' "$low" | grep -Eq '00:0[0-9]:00|00:1[0-4]:00'; then sub15=1; fi
    if printf '%s' "$low" | grep -Eq '(0?[0-9]|1[0-4])[[:space:]]*minute'; then sub15=1; fi

    slower_than_daily=0
    if printf '%s' "$low" | grep -Eq 'weekly|monthly|[0-9]+[[:space:]]*(day|days)'; then
      # >1 day or weekly/monthly
      if printf '%s' "$low" | grep -Eq 'weekly|monthly|([2-9]|[1-9][0-9]+)[[:space:]]*day'; then slower_than_daily=1; fi
    fi

    # pricing axis with a slower-than-daily cadence -> missed move
    if printf '%s' "$low" | grep -q 'pricing' && [ "$slower_than_daily" -eq 1 ]; then
      cfg_seen=1
      warn "$f: pricing axis on a slower-than-daily cadence — risks a missed move :: $ln"
    fi

    # slow axis with a sub-15-min cadence -> noise/cost
    if [ "$sub15" -eq 1 ]; then
      for sa in $SLOW_AXES; do
        if printf '%s' "$low" | grep -q "$sa"; then
          cfg_seen=1
          warn "$f: '$sa' axis on a sub-15-min cadence — noise and cost :: $ln"
          break
        fi
      done
    fi
  done < "$f"
done < "$CFG_FILES"
[ "$cfg_seen" -eq 0 ] && skip "no monitoring-config cadence mismatches found"

printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
