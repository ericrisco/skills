#!/usr/bin/env bash
#
# verify.sh — provenance + triangulation gate for the `market-research` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static checks over a produced market memo (Markdown). It validates that the
#   memo is CROSS-CHECKED AND SOURCED — never whether the market is attractive.
#   For each memo found:
#     1. TAM / SAM / SOM all present with a parseable numeric value, AND the
#        nesting SOM <= SAM <= TAM holds. (Units like $, €, K/M/B/k/m/b/bn are
#        normalized so 1.4M < 9.5M < 15.8M compares correctly.)
#     2. Triangulation: evidence of BOTH a top-down and a bottom-up figure, PLUS
#        a stated convergence/divergence note. A lone method fails.
#     3. Provenance: a sources section exists, and every figure line in it carries
#        a citation/URL AND a date (YYYY-MM-DD or a year 19xx/20xx). An undated
#        load-bearing number fails.
#
#   A missing/empty target is a SKIP, never a failure. Floating math uses awk
#   (POSIX), so no bc needed.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                      # scan ./ for *memo*/*market*.md
#   ./verify.sh --path memo.md       # check one memo
#   ./verify.sh --path research/     # scan a directory of memos
#   ./verify.sh --strict             # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, empty target, or warnings only without --strict
#   1  a real failure (broken nesting, missing method, undated source)
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
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }

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
  skip "path not found: $SCAN_PATH — nothing to check"
  skip_count=1; summary; exit 0
fi

have() { command -v "$1" >/dev/null 2>&1; }
if ! have awk; then
  skip "awk not found — cannot parse memo; install awk"
  skip_count=1; summary; exit 0
fi

# Collect candidate memo files: prefer named memos/market files, else any .md.
FILES=""
if [ -f "$SCAN_PATH" ]; then
  FILES="$SCAN_PATH"
else
  FILES="$(find "$SCAN_PATH" -type f -name '*.md' \( -iname '*memo*' -o -iname '*market*' -o -iname '*sizing*' \) 2>/dev/null || true)"
  if [ -z "$FILES" ]; then
    FILES="$(find "$SCAN_PATH" -type f -name '*.md' 2>/dev/null || true)"
  fi
fi

if [ -z "$FILES" ]; then
  skip "no market memo found under $SCAN_PATH — nothing to check (clean)"
  skip_count=1; summary; exit 0
fi

# check_one <file>: one awk pass emits "LEVEL message" lines; the shell tallies.
check_one() {
  f="$1"
  [ -s "$f" ] || { printf '%s[skip]%s empty file: %s\n' "$YELLOW" "$NC" "$f"; return; }
  printf '%s—— %s%s\n' "$YELLOW" "$f" "$NC"

  awk '
    # NOTE: stock macOS BSD awk has no IGNORECASE and no \b — we lowercase with
    # tolower() and use explicit (^|non-letter) boundaries instead.
    # parse_num(s): pull first number with optional $/€ and K/M/B/bn suffix -> value, or "" if none.
    function parse_num(s,   t,mult,num) {
      t=s
      # find a numeric token possibly with thousands separators and a magnitude suffix
      if (match(t, /[0-9][0-9.,]*[ ]*(bn|[kmbKMB])?/)) {
        num=substr(t, RSTART, RLENGTH)
        mult=1
        if (num ~ /bn/)      { mult=1000000000; sub(/bn/,"",num) }
        else if (num ~ /[bB]$/) { mult=1000000000; sub(/[bB]$/,"",num) }
        else if (num ~ /[mM]$/) { mult=1000000;    sub(/[mM]$/,"",num) }
        else if (num ~ /[kK]$/) { mult=1000;       sub(/[kK]$/,"",num) }
        gsub(/[ ,]/,"",num)
        if (num ~ /^[0-9.]+$/ && num != "" && num != ".") return num*mult
      }
      return ""
    }
    {
      line=$0
      lc=tolower($0)

      # --- sizing: capture first numeric value on a line that names the metric ---
      if (tam=="" && lc ~ /(^|[^a-z])tam([^a-z]|$)/) { v=parse_num($0); if(v!="") tam=v }
      if (sam=="" && lc ~ /(^|[^a-z])sam([^a-z]|$)/) { v=parse_num($0); if(v!="") sam=v }
      if (som=="" && lc ~ /(^|[^a-z])som([^a-z]|$)/) { v=parse_num($0); if(v!="") som=v }

      # --- method evidence ---
      if (lc ~ /top[ -]?down/)  topdown=1
      if (lc ~ /bottom[ -]?up/) bottomup=1
      if (lc ~ /converg|diverg|within [0-9]|[0-9] *x|triangulat/) converge=1

      # --- sources section detection ---
      if (lc ~ /^#+.*source|^#+.*provenance|^\| *figure|^sources/) insrc=1
      else if (lc ~ /^#+ /) insrc=0   # a new heading ends the sources block

      # within sources, a row that carries a number should also carry a date
      if (insrc) {
        srcseen=1
        if ($0 ~ /[0-9]/ && ($0 ~ /http/ || $0 ~ /\|/)) {
          # does this line carry a date? YYYY-MM-DD or a 4-digit year
          if ($0 ~ /(19|20)[0-9][0-9]-[0-1][0-9]-[0-3][0-9]/ || $0 ~ /(19|20)[0-9][0-9]/) {
            datedrows++
          } else {
            undated++
            if (undated <= 3) print "DETAIL undated source line: " substr($0,1,80)
          }
        }
      }
    }
    END {
      # 1. TAM/SAM/SOM present + nesting
      miss=""
      if (tam=="") miss=miss" TAM"
      if (sam=="") miss=miss" SAM"
      if (som=="") miss=miss" SOM"
      if (miss!="") print "FAIL missing sizing value(s):"miss
      else {
        print "OK TAM/SAM/SOM all present (" tam " / " sam " / " som ")"
        if (som <= sam+0.0001 && sam <= tam+0.0001) print "OK nesting SOM<=SAM<=TAM holds"
        else print "FAIL nesting broken: need SOM(" som ")<=SAM(" sam ")<=TAM(" tam ")"
      }

      # 2. triangulation
      if (topdown && bottomup) {
        print "OK both top-down and bottom-up figures present"
        if (converge) print "OK convergence/divergence note present"
        else print "FAIL no convergence/divergence note for the two methods"
      } else {
        m=""
        if (!topdown)  m=m" top-down"
        if (!bottomup) m=m" bottom-up"
        print "FAIL triangulation incomplete — missing method(s):"m
      }

      # 3. provenance
      if (!srcseen) print "FAIL no sources/provenance section found"
      else if (undated>0) print "FAIL "undated" source line(s) carry a figure with no date"
      else if (datedrows>0) print "OK "datedrows" dated source line(s); none undated"
      else print "WARN sources section present but no figure+date rows detected"
    }
  ' "$f" 2>/dev/null
}

printf 'Checking market memos under: %s\n\n' "$SCAN_PATH"
printf '%s\n' "$FILES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  check_one "$f"
done > "/tmp/mr_verify.$$" 2>&1 || true

# Render with colored tags.
while IFS= read -r line; do
  case "$line" in
    FAIL*)   printf '%s[fail]%s %s\n' "$RED"    "$NC" "${line#FAIL }" ;;
    WARN*)   printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "${line#WARN }" ;;
    OK*)     printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "${line#OK }" ;;
    DETAIL*) printf '        %s\n' "${line#DETAIL }" ;;
    *)       printf '%s\n' "$line" ;;
  esac
done < "/tmp/mr_verify.$$"

tally() { { grep -c "$1" "/tmp/mr_verify.$$" 2>/dev/null || true; } | tr -dc '0-9'; }
fail_count=$(tally '^FAIL'); fail_count=${fail_count:-0}
warn_count=$(tally '^WARN'); warn_count=${warn_count:-0}
ok_count=$(tally '^OK');     ok_count=${ok_count:-0}
skip_count=$(tally '\[skip\]'); skip_count=${skip_count:-0}
rm -f "/tmp/mr_verify.$$" 2>/dev/null || true

summary

cat <<'EOF'

Note: this gate proves the memo is CROSS-CHECKED AND SOURCED (TAM/SAM/SOM nesting,
both methods + a convergence note, dated sources). It does NOT judge whether the
market is attractive — that is the capability eval's job. Re-run with --strict to
gate CI on a clean pass.
EOF

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
