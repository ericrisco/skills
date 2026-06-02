#!/usr/bin/env bash
#
# verify.sh — structural + arithmetic lint for a pipeline file.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free checks over ONE pipeline file you point it at — a CSV
#   (preferred) or a markdown table with the same column names:
#     1. Header has the required columns: id, value, stage, win_prob,
#        weighted_value, close_date, next_step, last_touch.  (missing -> FAIL)
#     2. Each non-Closed (open) deal has non-empty close_date, next_step,
#        last_touch.                                          (missing -> FAIL)
#     3. stage is in the allowed set: Prospecting, Qualification, Discovery,
#        Proposal/Demo (or "Proposal"/"Demo"), Negotiation, Closed
#        (incl. "Closed Won" / "Closed Lost").                (unknown -> FAIL)
#     4. win_prob is a number with 0 <= win_prob <= 1.        (out of range -> FAIL)
#     5. weighted_value == round(value * win_prob) within +/-1 tolerance.
#                                                             (mismatch -> FAIL)
#     6. A coverage summary line/row is present somewhere (a line matching
#        /coverage/i).                                         (absent -> FAIL)
#
#   A clean OR empty/missing-content file exits 0 — never a false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh pipeline.csv          # lint a CSV pipeline
#   ./verify.sh pipeline.md           # lint a markdown-table pipeline
#   ./verify.sh pipeline.csv --tol 2  # widen the weighted_value tolerance
#
# EXIT CODES
#   0  clean, or empty/missing-content file
#   1  one or more structural / arithmetic failures
#   2  bad usage (no file, file missing, header has no required columns at all)
#
# Runs on stock macOS bash 3.2 + awk: no mapfile, no bc, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; NC=''
fi

fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN" "$NC" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED"   "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
TOL=1
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --tol) TOL="${2:-1}"; shift 2 ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

if [ -z "$FILE" ]; then
  printf '%sno pipeline file given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  ok "empty file — nothing to check"
  exit 0
fi

printf 'sales-pipeline verify — %s (weighted_value tolerance=+/-%s)\n\n' "$FILE" "$TOL"

# All checks run in one awk pass. It auto-detects delimiter: a pipe-table row
# (markdown) splits on '|'; otherwise CSV splits on ','. Quotes are tolerated
# (a quoted field with internal commas is rare in these columns; we strip
# surrounding quotes and trim spaces). The coverage check scans every raw line.
awk -v tol="$TOL" '
  function trim(s){ gsub(/^[ \t"]+/,"",s); gsub(/[ \t"]+$/,"",s); return s }
  function lc(s){ return tolower(s) }

  # detect coverage line anywhere; a coverage summary row is not a deal row
  tolower($0) ~ /coverage/ { cov=1; next }

  # skip markdown separator rows like |----|----|
  /^[ \t]*\|?[ \t:-]+\|[ \t:|-]*$/ { next }

  {
    raw=$0
    # choose delimiter
    if (raw ~ /\|/) { sep="|" } else { sep="," }
    n=split(raw, f, sep)
    # markdown tables have a leading/trailing pipe -> empty cells; trim all
    for (i=1;i<=n;i++) f[i]=trim(f[i])

    # locate header row: the first row containing "stage" and "win_prob"
    if (!have_header) {
      isheader=0
      for (i=1;i<=n;i++) {
        if (lc(f[i])=="stage") s_seen=1
        if (lc(f[i])=="win_prob") w_seen=1
      }
      if (s_seen && w_seen) {
        have_header=1
        for (i=1;i<=n;i++) { col[lc(f[i])]=i }
        next
      }
      s_seen=0; w_seen=0
      next
    }

    # data row
    # skip a row that is empty after trimming (markdown edge cells)
    nonempty=0
    for (i=1;i<=n;i++) if (f[i]!="") nonempty=1
    if (!nonempty) next

    rows++
    id    = (("id" in col)             ? f[col["id"]] : ("row " rows))
    stg   = (("stage" in col)          ? f[col["stage"]] : "")
    val   = (("value" in col)          ? f[col["value"]] : "")
    wp    = (("win_prob" in col)       ? f[col["win_prob"]] : "")
    wv    = (("weighted_value" in col) ? f[col["weighted_value"]] : "")
    cd    = (("close_date" in col)     ? f[col["close_date"]] : "")
    ns    = (("next_step" in col)      ? f[col["next_step"]] : "")
    lt    = (("last_touch" in col)     ? f[col["last_touch"]] : "")

    lstg = lc(stg)
    open_deal = (lstg !~ /closed|won|lost/)

    # 2 — required fields on open deals
    if (open_deal) {
      if (cd=="") { print "FAIL\t" id ": open deal missing close_date" ; bad++ }
      if (ns=="") { print "FAIL\t" id ": open deal missing next_step"  ; bad++ }
      if (lt=="") { print "FAIL\t" id ": open deal missing last_touch" ; bad++ }
    }

    # 3 — stage in allowed set
    allowed = (lstg ~ /^(prospecting|qualification|discovery|proposal\/demo|proposal|demo|negotiation|closed|closed won|closed lost)$/)
    if (stg!="" && !allowed) { print "FAIL\t" id ": unknown stage \"" stg "\"" ; bad++ }

    # 4 — win_prob numeric in [0,1]
    if (wp ~ /^[0-9]*\.?[0-9]+$/) {
      if (wp+0 < 0 || wp+0 > 1) { print "FAIL\t" id ": win_prob " wp " out of range [0,1]" ; bad++ }
    } else if (wp != "") {
      print "FAIL\t" id ": win_prob \"" wp "\" is not a number" ; bad++
    }

    # 5 — weighted_value == round(value * win_prob) within tol
    if (val ~ /^[0-9]*\.?[0-9]+$/ && wp ~ /^[0-9]*\.?[0-9]+$/ && wv ~ /^[0-9]*\.?[0-9]+$/) {
      expect = val*wp
      diff = wv - expect; if (diff<0) diff=-diff
      if (diff > tol) {
        print "FAIL\t" id ": weighted_value " wv " != value*win_prob (" expect ")"
        bad++
      }
    }
  }
  END {
    if (!have_header) { print "NOHEADER" ; exit 0 }
    print "META\t" rows "\t" bad+0 "\t" cov+0
  }
' "$FILE" > /tmp/sp_verify.$$ 2>/dev/null || true

# Replay awk output into the colored reporter.
NOHEADER=0; ROWS=0; BAD=0; COV=0
while IFS=$'\t' read -r kind a b c; do
  case "$kind" in
    FAIL) fail "$a" ;;
    NOHEADER) NOHEADER=1 ;;
    META) ROWS="$a"; BAD="$b"; COV="$c" ;;
  esac
done < /tmp/sp_verify.$$
rm -f /tmp/sp_verify.$$

if [ "$NOHEADER" -eq 1 ]; then
  printf '%sno header row with the required columns (need at least stage + win_prob)%s\n' "$RED" "$NC" >&2
  exit 2
fi

# 1 — required columns reported only if a deal referenced a missing one is moot;
# we re-derive column presence cheaply from the header line.
HEADER_LINE="$(grep -iE 'win_prob' "$FILE" | head -1)"
for c in id value stage win_prob weighted_value close_date next_step last_touch; do
  if printf '%s' "$HEADER_LINE" | grep -iqw "$c"; then
    :
  else
    fail "required column missing from header: $c"
  fi
done

# 6 — coverage summary present
if [ "$COV" -eq 1 ]; then
  ok "coverage summary line present"
else
  fail "no coverage summary line found (need a line matching /coverage/)"
fi

if [ "${ROWS:-0}" -gt 0 ] && [ "${BAD:-0}" -eq 0 ]; then
  ok "$ROWS deal row(s) — fields, stages, win_prob and weighted_value all valid"
fi

printf '\n'
if [ "$fail_count" -gt 0 ]; then
  printf '%s%d failure(s)%s\n' "$RED" "$fail_count" "$NC"
  exit 1
fi
printf '%sall checks passed%s\n' "$GREEN" "$NC"
exit 0
