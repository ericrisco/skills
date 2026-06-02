#!/usr/bin/env bash
#
# verify.sh — milestone-file structural linter for the `project-ops` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Lints the milestone artifact the skill produces — a markdown table OR a CSV
#   whose header is, in order:
#       id | milestone | owner | target | status | done_test | depends_on
#   It checks structure and consistency, NOT whether the plan is any good:
#     1. Each row has a unique, non-empty id.
#     2. owner is exactly ONE token (no comma, no second @handle, non-empty).
#     3. target is a parseable ISO date YYYY-MM-DD.
#     4. status is one of {green, amber, red, done} (case-insensitive).
#     5. done_test is non-empty.
#     6. Every depends_on id resolves to a real id in the same file
#        (no dangling refs) and a row may not depend on itself (trivial cycle).
#   If a status report file is present (a *.md with a "## Status" heading), it
#   must name >=1 non-green item OR state "all green" — so the honesty rule is
#   auditable. A missing report is fine.
#
#   Every check is opt-in by content: a file with no milestone header is skipped,
#   so this never false-fails on an unrelated repo and exits 0 on an empty target.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                  # scan ./ for milestone + status files
#   ./verify.sh --path plans     # scan a subdirectory or a single file
#   ./verify.sh --strict         # treat warnings as failures (exit 1)
#
# EXIT CODES
#   0  clean, or warnings only without --strict (also: nothing to check)
#   1  a structural failure, or --strict with a warning
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

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

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

TMPDIR_V="$(mktemp -d 2>/dev/null || printf '/tmp/project-ops-verify.%s' "$$")"
mkdir -p "$TMPDIR_V" 2>/dev/null || true
cleanup() { rm -rf "$TMPDIR_V" 2>/dev/null || true; }
trap cleanup EXIT
FILES="$TMPDIR_V/files"

find "$SCAN_PATH" -type f \( -name '*.md' -o -name '*.csv' \) 2>/dev/null > "$FILES" || true

if [ ! -s "$FILES" ]; then
  skip "no candidate files (*.md *.csv) under: $SCAN_PATH"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# Normalise a table/csv data row into pipe-delimited fields, trimming spaces and
# stripping leading/trailing pipes. Echoes the 7 fields separated by a tab.
# Returns non-zero (prints nothing) if the row does not have >=7 fields.
split_row() {
  raw="$1" sep="$2"
  # strip a leading and trailing pipe for markdown tables
  if [ "$sep" = "|" ]; then
    raw="${raw#|}"; raw="${raw%|}"
  fi
  # replace the separator with a tab via awk so we can trim each field
  printf '%s' "$raw" | awk -v FS="$sep" 'BEGIN{OFS="\t"}{
    for (i=1;i<=NF;i++){ gsub(/^[[:space:]]+|[[:space:]]+$/,"",$i) }
    $1=$1   # force field rebuild so OFS (tab) replaces FS even when no field was trimmed
    print
  }'
}

is_iso_date() {
  case "$1" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) return 0 ;;
    *) return 1 ;;
  esac
}

# Detect whether a header line is the milestone contract (order-flexible on
# spacing). Must contain id, milestone, owner, target, status, done_test.
is_milestone_header() {
  h="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
  case "$h" in *id*milestone*owner*target*status*done_test*depends_on*) return 0 ;; esac
  return 1
}

milestone_files=0
report_files=0

while IFS= read -r f; do
  [ -z "$f" ] && continue

  # --- status-report honesty audit (any *.md with a "## Status" heading) -----
  if printf '%s' "$f" | grep -q '\.md$'; then
    if grep -qiE '^##[[:space:]]+status' "$f" 2>/dev/null; then
      report_files=$((report_files + 1))
      low="$(tr 'A-Z' 'a-z' < "$f")"
      if printf '%s' "$low" | grep -qE 'amber|red'; then
        ok "status report names a non-green item: $f"
      elif printf '%s' "$low" | grep -qE 'all green|all-green'; then
        ok "status report explicitly states all-green: $f"
      else
        warn "status report names no amber/red item and no explicit 'all green' (honesty rule): $f"
      fi
    fi
  fi

  # --- find a milestone table/csv header in this file ------------------------
  sep=""
  if grep -qE '\|[[:space:]]*[Ii][Dd][[:space:]]*\|' "$f" 2>/dev/null && \
     grep -iqE 'done_test' "$f" 2>/dev/null; then
    sep="|"
  elif head -n 1 "$f" 2>/dev/null | grep -iqE '(^|,)[[:space:]]*id[[:space:]]*,' && \
       head -n 1 "$f" 2>/dev/null | grep -iqE 'done_test'; then
    sep=","
  fi
  [ -z "$sep" ] && continue

  milestone_files=$((milestone_files + 1))
  file_fail=0
  IDS="$TMPDIR_V/ids.$milestone_files"
  : > "$IDS"
  DEPS="$TMPDIR_V/deps.$milestone_files"
  : > "$DEPS"
  in_table=0

  while IFS= read -r line; do
    # skip blank lines
    [ -z "$(printf '%s' "$line" | tr -d '[:space:]')" ] && { [ "$sep" = "|" ] && in_table=0; continue; }

    if [ "$sep" = "|" ]; then
      case "$line" in *"|"*) : ;; *) continue ;; esac
      # header / separator detection
      if is_milestone_header "$line"; then in_table=1; continue; fi
      case "$line" in *---*) continue ;; esac
      [ "$in_table" -eq 1 ] || continue
    else
      if is_milestone_header "$line"; then continue; fi   # csv header
    fi

    fields="$(split_row "$line" "$sep")"
    id="$(printf '%s' "$fields" | cut -f1)"
    owner="$(printf '%s' "$fields" | cut -f3)"
    target="$(printf '%s' "$fields" | cut -f4)"
    status="$(printf '%s' "$fields" | cut -f5 | tr 'A-Z' 'a-z')"
    done_test="$(printf '%s' "$fields" | cut -f6)"
    depends="$(printf '%s' "$fields" | cut -f7)"

    [ -z "$id" ] && continue   # not a data row

    # 1. unique id
    if grep -qxF "$id" "$IDS" 2>/dev/null; then
      fail "duplicate milestone id '$id' in $f"; file_fail=1
    else
      printf '%s\n' "$id" >> "$IDS"
    fi

    # 2. exactly one owner
    case "$owner" in
      "") fail "row '$id' has no owner in $f"; file_fail=1 ;;
      *,*|*" "*@*) fail "row '$id' owner is not a single person ('$owner') in $f"; file_fail=1 ;;
    esac

    # 3. parseable target date
    if ! is_iso_date "$target"; then
      fail "row '$id' target '$target' is not an ISO date YYYY-MM-DD in $f"; file_fail=1
    fi

    # 4. status in allowed set
    case "$status" in
      green|amber|red|done) : ;;
      *) fail "row '$id' status '$status' not in {green,amber,red,done} in $f"; file_fail=1 ;;
    esac

    # 5. non-empty done_test
    [ -z "$done_test" ] && { fail "row '$id' has an empty done_test in $f"; file_fail=1; }

    # 6. record deps (resolved after the full file is read)
    if [ -n "$depends" ]; then
      printf '%s\t%s\n' "$id" "$depends" >> "$DEPS"
    fi
  done < "$f"

  # 6. resolve depends_on against collected ids + self-dependency check.
  #     Split on comma with a `for` over an IFS-expanded word list (no inner
  #     pipeline — a piped `grep -q` can SIGPIPE and break the outer read loop).
  if [ -s "$DEPS" ]; then
    : > "$TMPDIR_V/depcheck.$milestone_files"
    while IFS=$'\t' read -r src deplist; do
      old_ifs="$IFS"; IFS=','
      for d in $deplist; do
        IFS="$old_ifs"
        d="$(printf '%s' "$d" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        IFS=','
        [ -z "$d" ] && continue
        if [ "$d" = "$src" ]; then
          printf 'SELF\t%s\n' "$src" >> "$TMPDIR_V/depcheck.$milestone_files"
        elif ! grep -qxF "$d" "$IDS" 2>/dev/null; then
          printf 'DANGLE\t%s\t%s\n' "$src" "$d" >> "$TMPDIR_V/depcheck.$milestone_files"
        fi
      done
      IFS="$old_ifs"
    done < "$DEPS"

    if [ -s "$TMPDIR_V/depcheck.$milestone_files" ]; then
      while IFS=$'\t' read -r kind a b; do
        case "$kind" in
          SELF)   fail "row '$a' depends on itself (cycle) in $f"; file_fail=1 ;;
          DANGLE) fail "row '$a' depends_on '$b' which is not a known id in $f"; file_fail=1 ;;
        esac
      done < "$TMPDIR_V/depcheck.$milestone_files"
    fi
  fi

  if [ "$file_fail" -eq 0 ]; then
    ok "milestone file structure valid: $f"
  fi
done < "$FILES"

if [ "$milestone_files" -eq 0 ]; then
  skip "no milestone table/CSV (id|milestone|owner|target|status|done_test|depends_on) found"
fi
if [ "$report_files" -eq 0 ]; then
  skip "no status report (## Status …) found to audit"
fi

printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
