#!/usr/bin/env bash
# verify.sh — read-only shape/consistency checks for finance-ops artifacts.
#
# Validates the THREE artifacts this skill emits, by filename convention under TARGET:
#   *forecast*.csv  -> 13-week rolling forecast (columns + net + rolling continuity)
#   *recon*.csv     -> reconciliation report (every line classified, no orphans)
#   *close*.csv     -> month-close checklist (required gates present + marked)
#
# It checks SHAPE and INTERNAL CONSISTENCY, never whether the dollar figures are correct.
# Read-only. Exits 0 on an empty or clean target (no false failure). Exits 1 on any broken invariant.

set -euo pipefail

TARGET="${1:-.}"
fail=0

err() { printf 'FAIL: %s\n' "$1" >&2; fail=1; }
note() { printf '%s\n' "$1"; }

if [ ! -d "$TARGET" ]; then
  err "target is not a directory: $TARGET"
  exit 1
fi

# Collect candidate artifacts. No matches => clean target => exit 0.
shopt -s nullglob
forecasts=()
recons=()
closes=()
while IFS= read -r f; do
  base=$(basename "$f" | tr '[:upper:]' '[:lower:]')
  case "$base" in
    *forecast*.csv) forecasts+=("$f") ;;
    *recon*.csv)    recons+=("$f") ;;
    *close*.csv)    closes+=("$f") ;;
  esac
done < <(find "$TARGET" -type f -name '*.csv' 2>/dev/null)

total=$(( ${#forecasts[@]} + ${#recons[@]} + ${#closes[@]} ))
if [ "$total" -eq 0 ]; then
  note "verify: no finance-ops artifacts found under $TARGET — nothing to check."
  exit 0
fi

# --- helpers -------------------------------------------------------------

# index of a column name in a comma header; echoes 1-based index or empty.
col_idx() {
  local header="$1" name="$2"
  awk -v h="$header" -v n="$name" 'BEGIN{
    m=split(h, a, ",");
    for (i=1;i<=m;i++){ gsub(/^[ \t]+|[ \t\r]+$/,"",a[i]); if (a[i]==n){ print i; exit } }
  }'
}

# --- forecast checks -----------------------------------------------------
for f in "${forecasts[@]}"; do
  note "checking forecast: $f"
  header=$(head -n1 "$f" | tr -d '\r')
  required=(week_start starting_cash inflows outflows net ending_cash)
  miss=""
  for c in "${required[@]}"; do
    [ -z "$(col_idx "$header" "$c")" ] && miss="$miss $c"
  done
  if [ -n "$miss" ]; then
    err "$f: missing required columns:$miss"
    continue
  fi

  i_start=$(col_idx "$header" starting_cash)
  i_in=$(col_idx "$header" inflows)
  i_out=$(col_idx "$header" outflows)
  i_net=$(col_idx "$header" net)
  i_end=$(col_idx "$header" ending_cash)

  awk -F',' -v s="$i_start" -v in_="$i_in" -v o="$i_out" -v n="$i_net" -v e="$i_end" -v file="$f" '
    NR==1 { next }
    NF==0 { next }
    {
      starting=$s+0; inflows=$in_+0; outflows=$o+0; net=$n+0; ending=$e+0;
      # net = inflows - outflows  (tolerance for float)
      if ((net - (inflows - outflows)) > 0.01 || (net - (inflows - outflows)) < -0.01) {
        printf("FAIL: %s row %d: net (%.2f) != inflows-outflows (%.2f)\n", file, NR, net, inflows-outflows) > "/dev/stderr"; bad=1
      }
      # ending = starting + net
      if ((ending - (starting + net)) > 0.01 || (ending - (starting + net)) < -0.01) {
        printf("FAIL: %s row %d: ending_cash (%.2f) != starting_cash+net (%.2f)\n", file, NR, ending, starting+net) > "/dev/stderr"; bad=1
      }
      # rolling continuity: ending[n] == starting[n+1]
      if (have_prev) {
        if ((starting - prev_end) > 0.01 || (starting - prev_end) < -0.01) {
          printf("FAIL: %s row %d: starting_cash (%.2f) != previous ending_cash (%.2f) — rolling continuity broken\n", file, NR, starting, prev_end) > "/dev/stderr"; bad=1
        }
      }
      prev_end=ending; have_prev=1; rows++
    }
    END {
      if (rows==0) { print "FAIL: " file ": no data rows" > "/dev/stderr"; bad=1 }
      exit bad?1:0
    }
  ' "$f" || fail=1
done

# --- reconciliation checks ----------------------------------------------
for f in "${recons[@]}"; do
  note "checking reconciliation: $f"
  header=$(head -n1 "$f" | tr -d '\r')
  i_status=$(col_idx "$header" status)
  if [ -z "$i_status" ]; then
    err "$f: missing required column: status"
    continue
  fi
  awk -F',' -v st="$i_status" -v file="$f" '
    NR==1 { next }
    NF==0 { next }
    {
      v=$st; gsub(/^[ \t]+|[ \t\r]+$/,"",v);
      if (v=="") { printf("FAIL: %s row %d: bank line has no status (orphan)\n", file, NR) > "/dev/stderr"; bad=1; next }
      if (v!="matched" && v!="unmatched" && v!="needs-review") {
        printf("FAIL: %s row %d: invalid status \"%s\" (must be matched|unmatched|needs-review)\n", file, NR, v) > "/dev/stderr"; bad=1
      }
      rows++
    }
    END {
      if (rows==0) { print "FAIL: " file ": no classified lines" > "/dev/stderr"; bad=1 }
      exit bad?1:0
    }
  ' "$f" || fail=1
done

# --- close checklist checks ---------------------------------------------
for f in "${closes[@]}"; do
  note "checking close checklist: $f"
  header=$(head -n1 "$f" | tr -d '\r')
  i_gate=$(col_idx "$header" gate)
  i_cstatus=$(col_idx "$header" status)
  if [ -z "$i_gate" ] || [ -z "$i_cstatus" ]; then
    err "$f: missing required column(s): need both gate and status"
    continue
  fi
  awk -F',' -v g="$i_gate" -v st="$i_cstatus" -v file="$f" '
    NR==1 { next }
    NF==0 { next }
    {
      gate=$g; gsub(/^[ \t]+|[ \t\r]+$/,"",gate);
      v=$st;  gsub(/^[ \t]+|[ \t\r]+$/,"",v);
      seen[gate]=1;
      if (v!="done" && v!="blocked") {
        printf("FAIL: %s gate \"%s\": status \"%s\" must be done|blocked (missing gate is a failure, not a pass)\n", file, gate, v) > "/dev/stderr"; bad=1
      }
    }
    END {
      req["transaction_cleanup"]=1; req["bank_reconciliation"]=1; req["payroll_journals"]=1;
      req["ar_ap_review"]=1; req["expense_categorization"]=1; req["reporting_final_close"]=1;
      for (k in req) if (!(k in seen)) { printf("FAIL: %s: required gate \"%s\" is missing\n", file, k) > "/dev/stderr"; bad=1 }
      exit bad?1:0
    }
  ' "$f" || fail=1
done

if [ "$fail" -ne 0 ]; then
  note "verify: artifact checks FAILED."
  exit 1
fi
note "verify: all finance-ops artifacts pass shape/consistency checks."
exit 0
