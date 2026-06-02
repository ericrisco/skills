#!/usr/bin/env bash
#
# verify.sh — structural lint for the `youtube-ideation` idea ledger + outcome log.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static checks over a produced idea ledger (Markdown). It validates the SHAPE of
#   the decision, never whether the ideas are good. For each ledger found:
#     1. Every scored idea row (a table row with seven 1-5 cells) has all 7 rubric
#        dimensions filled 1-5 AND a /35 total that equals their sum.
#     2. The /35 total matches its verdict band:
#          >=30 produce | 24-29 improve | 18-23 gray | <18 abandon
#        A mismatch (e.g. total 31 tagged "abandon") fails; the 18-23 gray band warns.
#     3. Every "produce" idea has demand evidence on the row (non-empty Evidence).
#     4. If a hypothesis/outcome log section is present, it is append-only-shaped:
#        each dated bet is either "status: pending" OR carries actual + a verdict of
#        validated|killed|inconclusive + a lesson. A bet that is neither fails.
#
#   A missing/empty target is a SKIP, never a failure. Pure text/awk, no deps.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                      # scan ./ for *ledger*/*idea*.md
#   ./verify.sh --path ledger.md     # check one ledger
#   ./verify.sh --path 02-DOCS/      # scan a directory
#   ./verify.sh --strict             # treat warnings (gray-band rows) as failures
#
# EXIT CODES
#   0  clean, empty target, or warnings only without --strict
#   1  a real failure (bad row, band mismatch, broken hypothesis/outcome shape)
#   2  bad usage
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; skip_count=0; warn_count=0; fail_count=0

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

SCAN_PATH="."
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --path)   SCAN_PATH="${2:?--path needs a value}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
  esac
done

summary() { printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"; }

if [ ! -e "$SCAN_PATH" ]; then
  printf '%s[skip]%s path not found: %s — nothing to check\n' "$YELLOW" "$NC" "$SCAN_PATH"
  skip_count=1; summary; exit 0
fi

have() { command -v "$1" >/dev/null 2>&1; }
if ! have awk; then
  printf '%s[skip]%s awk not found — cannot parse ledger\n' "$YELLOW" "$NC"
  skip_count=1; summary; exit 0
fi

# Collect candidate ledger files: prefer named ledger/idea files, else any .md.
FILES=""
if [ -f "$SCAN_PATH" ]; then
  FILES="$SCAN_PATH"
else
  FILES="$(find "$SCAN_PATH" -type f -name '*.md' \( -iname '*ledger*' -o -iname '*idea*' \) 2>/dev/null || true)"
  if [ -z "$FILES" ]; then
    FILES="$(find "$SCAN_PATH" -type f -name '*.md' 2>/dev/null || true)"
  fi
fi

if [ -z "$FILES" ]; then
  printf '%s[skip]%s no idea ledger found under %s — nothing to check (clean)\n' "$YELLOW" "$NC" "$SCAN_PATH"
  skip_count=1; summary; exit 0
fi

# check_one <file>: one awk pass emits "LEVEL message" lines; the shell tallies.
check_one() {
  f="$1"
  [ -s "$f" ] || { printf 'SKIP empty file: %s\n' "$f"; return; }
  printf 'HDR %s\n' "$f"

  awk '
    # Lowercase compare; BSD awk has no IGNORECASE.
    {
      line=$0
      lc=tolower($0)

      # ---- scored idea rows: a markdown table row with >=7 integer cells (1-5) ----
      # Heuristic: pipe-delimited row, not the header/separator, that contains a
      # verdict word AND a standalone /35-style total. We split on | and read cells.
      # separator row = only pipes, dashes, colons and spaces (no letters/digits)
      issep = (line ~ /^[ ]*\|[ |:-]*$/)
      if (line ~ /\|/ && !issep && (lc ~ /produce|improve|abandon|gray|grey/)) {
        n=split(line, c, "|")
        ints=0; sum=0; total=""; verdict=""; firstint=""
        for (i=1;i<=n;i++) {
          cell=c[i]; gsub(/[ \t*]/,"",cell)
          if (cell ~ /^[1-5]$/) { ints++; sum+=cell+0; if(firstint=="") firstint=cell+0 }
          else if (cell ~ /^[0-9]+$/ && (cell+0)>=0 && (cell+0)<=35) { total=cell+0 }
          lcell=tolower(cell)
          if (lcell ~ /^produce$/)  verdict="produce"
          if (lcell ~ /^improve$/)  verdict="improve"
          if (lcell ~ /^abandon$/)  verdict="abandon"
          if (lcell ~ /^gr[ae]y$/)  verdict="gray"
        }
        if (verdict=="") next   # not actually an idea row
        rows++

        # A leading "#" index column is itself a 1-5 integer; if we counted 8, the
        # first is the row index, not a rubric dimension — drop it from the sum.
        if (ints == 8) { ints=7; sum=sum-firstint }

        if (ints < 7) {
          print "FAIL row " rows ": only " ints " of 7 rubric dimensions are integers 1-5"
          next
        }
        if (ints > 7) {
          print "FAIL row " rows ": " ints " integer cells 1-5 — expected exactly 7 rubric dimensions"
          next
        }
        if (total=="") {
          print "FAIL row " rows ": no /35 total cell found"
          next
        }
        if (total != sum) {
          print "FAIL row " rows ": total " total " != sum of dimensions " sum
        } else {
          print "OK row " rows ": 7 dims, total " total " matches sum"
        }

        # band check against verdict
        band=""
        if (total>=30) band="produce"
        else if (total>=24) band="improve"
        else if (total>=18) band="gray"
        else band="abandon"
        if (band != verdict)
          print "FAIL row " rows ": total " total " is band \"" band "\" but verdict is \"" verdict "\""
        else if (verdict=="gray")
          print "WARN row " rows ": gray band (" total ") — re-angle or shelve, do not produce as-is"
        else
          print "OK row " rows ": verdict \"" verdict "\" matches band"

        # produce rows need demand evidence somewhere on the row
        if (verdict=="produce") {
          producerows++
          # crude evidence test: an outlier multiple like 3.4x or a digit-bearing note
          if (lc ~ /[0-9]+(\.[0-9]+)?x/ || lc ~ /outlier|trends|autocomplete|search/) {
            # ok
          } else {
            print "WARN row " rows ": produce idea has no visible demand evidence (outlier/search) on its row"
          }
        }
      }

      # ---- hypothesis/outcome log shape ----
      # A dated bet header: "## YYYY-MM-DD — <idea>"
      if (line ~ /^#+[ ]+(19|20)[0-9][0-9]-[0-1][0-9]-[0-3][0-9]/) {
        # close out the previous bet before opening a new one
        if (inbet) closebet()
        inbet=1; bettitle=$0; haspending=0; hasactual=0; hasverdict=0; haslesson=0
        bets++
      }
      else if (inbet) {
        if (lc ~ /status:[ ]*pending/) haspending=1
        if (lc ~ /actual:/) hasactual=1
        if (lc ~ /verdict:[ ]*(validated|killed|inconclusive)/) hasverdict=1
        if (lc ~ /lesson:/) haslesson=1
        # a non-date top-level heading also closes the bet
        if (line ~ /^#[ ]/ && line !~ /(19|20)[0-9][0-9]-/) { closebet(); inbet=0 }
      }
    }
    function closebet() {
      if (haspending) { print "OK bet pending: " substr(bettitle,1,60); return }
      if (hasactual && hasverdict && haslesson) { print "OK bet closed (actual+verdict+lesson): " substr(bettitle,1,60); return }
      m=""
      if (!hasactual)  m=m" actual"
      if (!hasverdict) m=m" verdict(validated|killed|inconclusive)"
      if (!haslesson)  m=m" lesson"
      print "FAIL bet neither pending nor complete — missing:" m " :: " substr(bettitle,1,60)
    }
    END {
      if (inbet) closebet()
      if (rows==0) print "WARN no scored idea rows detected (is this an idea ledger?)"
      if (rows>0)  print "OK " rows " scored idea row(s) parsed; " producerows " promoted to produce"
      if (bets>0)  print "OK " bets " hypothesis/outcome bet(s) parsed"
    }
  ' "$f" 2>/dev/null
}

printf 'Checking idea ledgers under: %s\n\n' "$SCAN_PATH"
printf '%s\n' "$FILES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  check_one "$f"
done > "/tmp/ytid_verify.$$" 2>&1 || true

# Render with colored tags.
while IFS= read -r line; do
  case "$line" in
    HDR*)  printf '%s—— %s%s\n' "$YELLOW" "${line#HDR }" "$NC" ;;
    FAIL*) printf '%s[fail]%s %s\n' "$RED"    "$NC" "${line#FAIL }" ;;
    WARN*) printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "${line#WARN }" ;;
    OK*)   printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "${line#OK }" ;;
    SKIP*) printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "${line#SKIP }" ;;
    *)     printf '%s\n' "$line" ;;
  esac
done < "/tmp/ytid_verify.$$"

tally() { { grep -c "$1" "/tmp/ytid_verify.$$" 2>/dev/null || true; } | tr -dc '0-9'; }
fail_count=$(tally '^FAIL'); fail_count=${fail_count:-0}
warn_count=$(tally '^WARN'); warn_count=${warn_count:-0}
ok_count=$(tally '^OK');     ok_count=${ok_count:-0}
skip_count=$(tally '^SKIP'); skip_count=${skip_count:-0}
rm -f "/tmp/ytid_verify.$$" 2>/dev/null || true

summary

cat <<'EOF'

Note: this gate proves the ledger is SHAPED RIGHT (7 dims sum to a /35 that matches its
verdict band, produce rows carry demand evidence, and every logged bet is pending or fully
graded). It does NOT judge whether the ideas are good — that is the capability eval's job.
Re-run with --strict to gate CI on a clean pass (gray-band rows then fail).
EOF

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
