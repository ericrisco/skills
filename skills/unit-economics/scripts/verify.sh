#!/usr/bin/env bash
#
# verify.sh - re-derive a unit-economics worksheet and fail if the arithmetic lies.
#
# Usage:
#   cd <dir containing unit-economics.yaml|.csv|.md>
#   ./verify.sh [path-to-worksheet]
#
# Read-only: never mutates anything. Parses named inputs/outputs and checks:
#   - cac                 == period_sm_spend / new_customers
#   - contribution_margin == monthly_arpa * gross_margin_pct
#   - payback_months      == cac / (monthly_arpa * gross_margin_pct)
#   - ltv  uses gross-margin form (ARPA*GM)/churn, NOT revenue form ARPA/churn
#   - ltv_cac             == ltv / cac          (within 0.05)
#   - implied lifetime (1/monthly_churn) <= 48 months unless lifetime_cap_override set
#
# Tolerance: +/-0.5% on money figures, +/-0.05 on ratios.
# Exits 0 on a clean worksheet AND on no worksheet found (no false failure).
# Exits 1 with the specific failing check on any violation.
#
# Portable: stock macOS bash 3.2 + awk. No associative arrays, no mapfile.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi

fail() { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; failed=1; }
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }

# --- locate the worksheet ----------------------------------------------------
file="${1:-}"
if [ -z "$file" ]; then
  for cand in unit-economics.yaml unit-economics.yml unit-economics.csv unit-economics.md; do
    if [ -f "$cand" ]; then file="$cand"; break; fi
  done
fi

if [ -z "$file" ] || [ ! -f "$file" ]; then
  printf '%s[skip]%s no unit-economics.{yaml,csv,md} found - nothing to verify.\n' "$YELLOW" "$RESET"
  exit 0
fi

# --- extract a numeric field by key (yaml-ish, csv-ish, or "key: value") -----
# Matches lines like "  cac: 1500", "cac,1500", "cac = 1500", "| cac | 1500 |".
# Strips $ , % and surrounding noise; takes the first number after the key.
getnum() {
  key="$1"
  awk -v k="$key" '
    { line=$0
      # normalise separators to spaces, drop currency/percent/comma noise
      gsub(/[,$%|{}\[\]]/, " ", line)
      gsub(/[:=]/, " ", line)
    }
    line ~ ("(^|[^a-zA-Z_])" k "([^a-zA-Z_]|$)") {
      n=split(line, a, " ")
      seen=0
      for (i=1;i<=n;i++){
        if (a[i]==k){ seen=1; continue }
        if (seen && a[i] ~ /^-?[0-9]+(\.[0-9]+)?$/){ print a[i]; exit }
      }
    }
  ' "$file"
}

spend=$(getnum period_sm_spend)
newc=$(getnum new_customers)
arpa=$(getnum monthly_arpa)
gm=$(getnum gross_margin_pct)
churn=$(getnum monthly_churn)
override=$(getnum lifetime_cap_override)

cac=$(getnum cac)
cm=$(getnum contribution_margin)
ltv=$(getnum ltv)
payback=$(getnum payback_months)
ltvcac=$(getnum ltv_cac)

failed=0

require() { # name value
  if [ -z "$2" ]; then fail "missing required input '$1' in $file"; fi
}
require period_sm_spend "$spend"
require new_customers "$newc"
require monthly_arpa "$arpa"
require gross_margin_pct "$gm"
require monthly_churn "$churn"
if [ "$failed" -ne 0 ]; then
  printf '\n%sFAIL:%s worksheet is missing inputs needed to verify.\n' "$RED" "$RESET"
  exit 1
fi

# gross_margin_pct may be given as 0.75 or 75; normalise to a fraction.
gm=$(awk -v g="$gm" 'BEGIN{ if (g>1.0001) g=g/100; printf "%.6f", g }')

printf -- '----- verifying %s\n' "$file"

# helper: are two numbers within tolerance? tol is a fraction of |expected|.
close() { # actual expected tol
  awk -v a="$1" -v e="$2" -v t="$3" 'BEGIN{
    d=a-e; if(d<0)d=-d;
    lim=e; if(lim<0)lim=-lim;
    lim=lim*t; if(lim<0.0001)lim=0.0001;   # floor so exact zeros still compare
    exit (d<=lim)?0:1
  }'
}

exp_cac=$(awk -v s="$spend" -v n="$newc" 'BEGIN{ if(n==0){print "NaN"} else printf "%.6f", s/n }')
exp_cm=$(awk  -v a="$arpa" -v g="$gm" 'BEGIN{ printf "%.6f", a*g }')
exp_pay=$(awk -v c="$exp_cac" -v a="$arpa" -v g="$gm" 'BEGIN{ d=a*g; if(d==0){print "NaN"} else printf "%.6f", c/d }')
exp_ltv=$(awk -v a="$arpa" -v g="$gm" -v ch="$churn" 'BEGIN{ if(ch==0){print "NaN"} else printf "%.6f", (a*g)/ch }')
rev_ltv=$(awk -v a="$arpa" -v ch="$churn" 'BEGIN{ if(ch==0){print "NaN"} else printf "%.6f", a/ch }')

# 1. CAC
if [ -n "$cac" ]; then
  if close "$cac" "$exp_cac" 0.005; then ok "CAC $cac == spend/new ($exp_cac)";
  else fail "CAC $cac != spend/new_customers ($exp_cac)"; fi
else
  fail "stated output 'cac' missing"
fi

# 2. contribution margin
if [ -n "$cm" ]; then
  if close "$cm" "$exp_cm" 0.005; then ok "contribution_margin $cm == ARPA*GM ($exp_cm)";
  else fail "contribution_margin $cm != ARPA*GM% ($exp_cm)"; fi
fi

# 3. payback
if [ -n "$payback" ]; then
  if close "$payback" "$exp_pay" 0.005; then ok "payback_months $payback == CAC/(ARPA*GM) ($exp_pay)";
  else fail "payback_months $payback != CAC/(ARPA*GM%) ($exp_pay)"; fi
fi

# 4. LTV must be gross-margin form, not revenue form
if [ -n "$ltv" ]; then
  if close "$ltv" "$exp_ltv" 0.005; then
    ok "LTV $ltv == (ARPA*GM)/churn ($exp_ltv)"
  elif close "$ltv" "$rev_ltv" 0.005; then
    fail "LTV $ltv uses REVENUE form ARPA/churn ($rev_ltv); use gross-margin (ARPA*GM)/churn ($exp_ltv)"
  else
    fail "LTV $ltv != (ARPA*GM)/churn ($exp_ltv)"
  fi
fi

# 5. LTV:CAC
if [ -n "$ltvcac" ] && [ -n "$cac" ] && [ -n "$ltv" ]; then
  exp_ratio=$(awk -v l="$ltv" -v c="$cac" 'BEGIN{ if(c==0){print "NaN"} else printf "%.6f", l/c }')
  # absolute 0.05 tolerance on the ratio
  if awk -v a="$ltvcac" -v e="$exp_ratio" 'BEGIN{ d=a-e; if(d<0)d=-d; exit (d<=0.05)?0:1 }'; then
    ok "ltv_cac $ltvcac == LTV/CAC ($exp_ratio)"
  else
    fail "ltv_cac $ltvcac != LTV/CAC ($exp_ratio)"
  fi
fi

# 6. lifetime cap
life=$(awk -v ch="$churn" 'BEGIN{ if(ch==0){print "999999"} else printf "%.2f", 1/ch }')
cap=48
if [ -n "$override" ]; then cap="$override"; fi
if awk -v l="$life" -v c="$cap" 'BEGIN{ exit (l<=c)?0:1 }'; then
  ok "implied lifetime ${life}mo <= cap ${cap}mo"
else
  if [ -n "$override" ]; then
    fail "implied lifetime ${life}mo exceeds override cap ${cap}mo"
  else
    fail "implied lifetime ${life}mo exceeds 48mo cap; set lifetime_cap_override to justify"
  fi
fi

echo
if [ "$failed" -ne 0 ]; then
  printf '%sFAIL:%s worksheet arithmetic is inconsistent.\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s worksheet is self-consistent.\n' "$GREEN" "$RESET"
