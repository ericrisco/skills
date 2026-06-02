#!/usr/bin/env bash
# verify.sh — validate a pricing price card. READ-ONLY: never writes or edits.
#
# Usage:   verify.sh [path/to/price-card.csv]
# Default: ./price-card.csv if no path is given.
#
# Expects a CSV with a header containing the columns: tier,price,cost,value_metric,margin
# (column order is detected from the header; extra columns are ignored).
#
# Checks per row:
#   FAIL  stated margin disagrees with recomputed (price-cost)/price by > 0.5pt (0.005)
#   FAIL  price <= cost (zero or negative margin)
#   FAIL  value_metric empty
#   WARN  stated "margin" actually equals the MARKUP (price-cost)/cost  (the classic conflation)
# Exits 0 on a clean OR empty/missing card (no false failure); exits 1 if any FAIL fired.

set -euo pipefail

CARD="${1:-./price-card.csv}"

if [ ! -f "$CARD" ]; then
  echo "verify.sh: no price card at '$CARD' — nothing to check."
  exit 0
fi

# Empty or header-only file -> clean by definition.
data_rows="$(grep -cve '^[[:space:]]*$' "$CARD" || true)"
if [ "${data_rows:-0}" -le 1 ]; then
  echo "verify.sh: '$CARD' has no data rows — nothing to check."
  exit 0
fi

awk -F',' '
  function trim(s){ gsub(/^[ \t\r"]+|[ \t\r"]+$/, "", s); return s }
  NR==1 {
    for (i=1; i<=NF; i++) {
      h=tolower(trim($i))
      if (h=="tier")         ct=i
      else if (h=="price")   cp=i
      else if (h=="cost")    cc=i
      else if (h=="margin")  cm=i
      else if (h=="value_metric") cv=i
    }
    if (!cp || !cc || !cm || !cv) {
      print "verify.sh: header missing required columns (need price,cost,margin,value_metric)."
      exit 2
    }
    next
  }
  trim($0)=="" { next }
  {
    rows++
    tier   = (ct ? trim($ct) : ("row " rows))
    price  = trim($cp) + 0
    cost   = trim($cc) + 0
    stated = trim($cm) + 0
    vmetric= trim($cv)

    if (vmetric == "") {
      printf "FAIL  %-12s value_metric is empty\n", tier
      fail++
      next
    }
    if (price <= cost) {
      printf "FAIL  %-12s price (%.2f) <= cost (%.2f): zero or negative margin\n", tier, price, cost
      fail++
      next
    }

    margin = (price - cost) / price
    markup = (price - cost) / cost
    diff   = stated - margin; if (diff < 0) diff = -diff

    # Conflation check: stated value matches markup but NOT margin.
    md = stated - markup; if (md < 0) md = -md
    if (md <= 0.005 && diff > 0.005) {
      printf "WARN  %-12s stated %.1f%% equals the MARKUP, not the margin (true margin %.1f%%)\n", tier, stated*100, margin*100
      warn++
    } else if (diff > 0.005) {
      printf "FAIL  %-12s stated margin %.1f%% != recomputed %.1f%% (price %.2f, cost %.2f)\n", tier, stated*100, margin*100, price, cost
      fail++
    } else {
      printf "ok    %-12s margin %.1f%%  (price %.2f, cost %.2f, metric %s)\n", tier, margin*100, price, cost, vmetric
    }
  }
  END {
    if (rows == 0) { print "verify.sh: no data rows parsed — nothing to check."; exit 0 }
    printf "verify.sh: %d tier(s), %d fail, %d warn\n", rows, fail+0, warn+0
    if (fail+0 > 0) exit 1
  }
' "$CARD"
