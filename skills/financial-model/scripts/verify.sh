#!/usr/bin/env bash
#
# verify.sh — internal-consistency gate for the `financial-model` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static checks over a generated model CSV (assumptions + monthly projection
#   grid). It validates that the model COMPUTES AND TIES OUT — never whether the
#   forecast is wise. For each model.csv found:
#     1. Required columns present: month, revenue, cogs, gross_margin, opex,
#        net_burn, ending_cash, runway_months (headcount/starting_cash/gross_burn
#        checked when present).
#     2. Cash continuity: ending_cash[m] == starting_cash[m+1].
#     3. Recompute (no hardcoded outputs):
#        gross_margin == (revenue-cogs)/revenue; net_burn == gross_burn-revenue;
#        runway_months == starting_cash/net_burn (when net_burn>0).
#     4. Scenario coverage: >=1 scenario present; if a `scenario` column exists
#        and the file claims multiple, expect >=3 distinct values.
#     5. Defect lint: placeholders (TBD, XX, #REF, [assumption], ???) -> fail;
#        impossible values (gross_margin >1 or <-1, negative headcount) -> fail.
#
#   A missing/empty target is a SKIP, never a failure. Numeric checks tolerate
#   small rounding (default 1%). Floating math uses awk (POSIX), so no bc needed.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                      # scan ./ for *model*.csv
#   ./verify.sh --path model.csv     # check one file
#   ./verify.sh --path build/        # scan a directory of model CSVs
#   ./verify.sh --tol 0.02           # widen the recompute tolerance to 2%
#   ./verify.sh --strict             # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, empty target, or warnings only without --strict
#   1  a real failure (broken tie-out, placeholder, impossible value)
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
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; skip_count=$((skip_count + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

SCAN_PATH="."
STRICT=0
TOL="0.01"
while [ $# -gt 0 ]; do
  case "$1" in
    --path)   SCAN_PATH="${2:?--path needs a value}"; shift 2 ;;
    --tol)    TOL="${2:?--tol needs a value}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
  esac
done

if [ ! -e "$SCAN_PATH" ]; then
  skip "path not found: $SCAN_PATH — nothing to check"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

have() { command -v "$1" >/dev/null 2>&1; }
if ! have awk; then
  skip "awk not found — cannot parse CSV; install awk"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# Collect candidate model CSVs.
FILES=""
if [ -f "$SCAN_PATH" ]; then
  case "$SCAN_PATH" in *.csv) FILES="$SCAN_PATH" ;; *) FILES="$SCAN_PATH" ;; esac
else
  FILES="$(find "$SCAN_PATH" -type f -name '*.csv' \( -iname '*model*' -o -iname '*projection*' -o -iname '*forecast*' \) 2>/dev/null || true)"
  if [ -z "$FILES" ]; then
    FILES="$(find "$SCAN_PATH" -type f -name '*.csv' 2>/dev/null || true)"
  fi
fi

if [ -z "$FILES" ]; then
  skip "no model CSV found under $SCAN_PATH — nothing to check (clean)"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# check_one <file>: runs all checks, prints findings, returns nothing.
# Uses a single awk pass that emits "LEVEL message" lines; the shell tallies.
check_one() {
  f="$1"
  [ -s "$f" ] || { skip "empty file: $f"; return; }
  printf '%s—— %s%s\n' "$YELLOW" "$f" "$NC"

  # Placeholder lint (whole file, case-insensitive).
  if grep -niE 'TBD|#REF|\[assumption\]|\?\?\?|(^|[,;[:space:]])XX([,;[:space:]]|$)' "$f" >/dev/null 2>&1; then
    fail "$f: placeholder token (TBD/XX/#REF/[assumption]/???) present"
    grep -niE 'TBD|#REF|\[assumption\]|\?\?\?' "$f" 2>/dev/null | head -n 3 | sed 's/^/        /'
  else
    ok "$f: no placeholder tokens"
  fi

  out="$(awk -v tol="$TOL" '
    BEGIN { FS=","; }
    NR==1 {
      for (i=1;i<=NF;i++){ h=tolower($i); gsub(/^[ \t"]+|[ \t"]+$/,"",h); col[h]=i }
      # required columns
      req="month revenue cogs gross_margin opex net_burn ending_cash runway_months"
      n=split(req,r," ")
      miss=""
      for (k=1;k<=n;k++){ if(!(r[k] in col)) miss=miss" "r[k] }
      if(miss!="") print "FAIL missing required column(s):"miss
      else print "OK all required columns present"
      next
    }
    # skip blank lines
    NF<2 { next }
    {
      rows++
      # helper to fetch a numeric cell by header name
      mrev=val("revenue"); mcogs=val("cogs"); mgm=val("gross_margin");
      mnb=val("net_burn"); mec=val("ending_cash"); msc=val("starting_cash");
      mgb=val("gross_burn"); mhc=val("headcount"); mrm=val("runway_months");

      # impossible: gross margin out of [-1,1]
      if (("gross_margin" in col) && mgm!="" && (mgm>1.0000001 || mgm< -1.0000001))
        print "FAIL row "rows": gross_margin "mgm" outside [-1,1]"
      # impossible: negative headcount
      if (("headcount" in col) && mhc!="" && mhc < -0.0000001)
        print "FAIL row "rows": negative headcount "mhc

      # recompute gross_margin
      if (("revenue" in col)&&("cogs" in col)&&("gross_margin" in col)&&mrev!=""&&mrev!=0&&mcogs!=""&&mgm!="") {
        xp=(mrev-mcogs)/mrev
        if (reldiff(xp,mgm) > tol)
          print "FAIL row "rows": gross_margin "mgm" != (rev-cogs)/rev "xp
      }
      # recompute net_burn = gross_burn - revenue
      if (("gross_burn" in col)&&("revenue" in col)&&("net_burn" in col)&&mgb!=""&&mrev!=""&&mnb!="") {
        xp=mgb-mrev
        if (absdiff(xp,mnb) > tol*(absv(exp)+1))
          print "FAIL row "rows": net_burn "mnb" != gross_burn-revenue "xp
      }
      # recompute runway_months = starting_cash / net_burn (net_burn>0)
      if (("starting_cash" in col)&&("net_burn" in col)&&("runway_months" in col)&&msc!=""&&mnb!=""&&mnb>0&&mrm!="") {
        xp=msc/mnb
        if (reldiff(xp,mrm) > tol*5)   # runway often rounded to 1dp; loosen
          print "FAIL row "rows": runway_months "mrm" != cash/net_burn "xp
      }
      # cash continuity: ending_cash[m] == starting_cash[m+1]
      if (("ending_cash" in col)&&("starting_cash" in col)) {
        if (rows>1 && prev_ec!="" && msc!="") {
          if (absdiff(prev_ec,msc) > tol*(absv(prev_ec)+1))
            print "FAIL row "rows": starting_cash "msc" != prior ending_cash "prev_ec
        }
        prev_ec=mec
      }
      # scenario tracking
      if ("scenario" in col) { sc=raw("scenario"); if(sc!=""){ if(!(sc in seen)){seen[sc]=1; nsc++} } }
    }
    END {
      if (rows==0) { print "WARN no data rows"; }
      else print "OK "rows" data rows parsed"
      if ("scenario" in col) {
        if (nsc>=1) print "OK scenario column present ("nsc" distinct)"
        if (nsc==2) print "WARN only 2 scenarios; base/downside/upside expects 3"
      } else {
        print "WARN no scenario column — at least a base scenario should be labeled"
      }
    }
    function val(name,   v){ if(!(name in col)) return ""; v=$(col[name]); gsub(/[ \t"$,%]/,"",v); if(v=="")return ""; if(v+0==v) return v+0; return "" }
    function raw(name,   v){ if(!(name in col)) return ""; v=$(col[name]); gsub(/^[ \t"]+|[ \t"]+$/,"",v); return v }
    function absv(x){ return x<0?-x:x }
    function absdiff(a,b){ return absv(a-b) }
    function reldiff(a,b){ d=absv(a-b); m=absv(a); if(m<1) m=1; return d/m }
  ' "$f" 2>/dev/null)"

  # tally awk findings
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | while IFS= read -r line; do
      case "$line" in
        FAIL*) printf '%s[fail]%s %s: %s\n' "$RED" "$NC" "$f" "${line#FAIL }" ;;
        WARN*) printf '%s[warn]%s %s: %s\n' "$YELLOW" "$NC" "$f" "${line#WARN }" ;;
        OK*)   printf '%s[ ok ]%s %s: %s\n' "$GREEN" "$NC" "$f" "${line#OK }" ;;
      esac
    done
    nf=$(printf '%s\n' "$out" | grep -c '^FAIL' || true)
    nw=$(printf '%s\n' "$out" | grep -c '^WARN' || true)
    no=$(printf '%s\n' "$out" | grep -c '^OK'   || true)
    fail_count=$((fail_count + nf))
    warn_count=$((warn_count + nw))
    ok_count=$((ok_count + no))
  fi
}

printf 'Checking model CSVs under: %s (tol=%s)\n\n' "$SCAN_PATH" "$TOL"
printf '%s\n' "$FILES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  check_one "$f"
done > /tmp/fm_verify.$$ 2>&1 || true
cat /tmp/fm_verify.$$
# re-tally from the captured output (subshell counters don't propagate under bash 3.2).
# grep -c always prints a count but exits 1 on zero matches, so swallow status and
# strip to digits to avoid concatenating a fallback.
tally() { { grep -c "$1" /tmp/fm_verify.$$ 2>/dev/null || true; } | tr -dc '0-9'; }
fail_count=$(tally '\[fail\]'); fail_count=${fail_count:-0}
warn_count=$(tally '\[warn\]'); warn_count=${warn_count:-0}
ok_count=$(tally '\[ ok \]');   ok_count=${ok_count:-0}
skip_count=$(tally '\[skip\]'); skip_count=${skip_count:-0}
rm -f /tmp/fm_verify.$$ 2>/dev/null || true

printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

cat <<'EOF'

Note: this gate proves the model COMPUTES AND TIES OUT (continuity, recompute,
no placeholders). It does NOT judge whether the assumptions are wise — that is
the capability eval's job. Re-run with --strict to gate CI on a clean pass.
EOF

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
