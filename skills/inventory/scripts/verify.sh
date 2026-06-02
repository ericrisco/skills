#!/usr/bin/env bash
# verify.sh — structural check for inventory artifacts (read-only).
#
# Validates the SHAPE and structural invariants of:
#   - a reorder-policy table CSV  (sku,abc_class,avg_demand,lead_time,safety_stock,reorder_point,order_qty,review_mode)
#   - a replenishment trigger-list CSV (sku,on_hand,reorder_point,suggested_order_qty)
# It does NOT judge whether buffer sizes are commercially optimal — that is the capability eval's job.
#
# Usage:
#   scripts/verify.sh                              # auto-discover *.csv under cwd
#   scripts/verify.sh policy.csv trigger.csv       # check explicit files
#
# Exit 0 when nothing is wrong (including an empty/clean target — no false failure).
# Exit 1 with a readable message naming the FIRST violated invariant.
#
# Portable to bash 3.2 (macOS default): no associative arrays.

set -eu

fail() { echo "verify.sh: FAIL — $1" >&2; exit 1; }

POLICY_COLS="sku,abc_class,avg_demand,lead_time,safety_stock,reorder_point,order_qty,review_mode"
TRIGGER_COLS="sku,on_hand,reorder_point,suggested_order_qty"

# --- collect candidate files (read-only discovery) ---------------------------
files=""
if [ "$#" -gt 0 ]; then
  for f in "$@"; do files="$files$f
"; done
else
  files="$(find . -type f -name '*.csv' 2>/dev/null | sort)"
fi

# Empty/clean target → nothing to validate → success.
if [ -z "$files" ]; then
  echo "verify.sh: OK — no CSV artifacts found, nothing to check."
  exit 0
fi

# strip CR, collapse spaces around commas, trim ends of a header line
norm_header() { head -n1 "$1" | tr -d '\r' | sed 's/[[:space:]]*,[[:space:]]*/,/g; s/^[[:space:]]*//; s/[[:space:]]*$//'; }

POLICY_FILES=""
TRIGGER_FILES=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || fail "file not found: $f"
  hdr="$(norm_header "$f")"
  if [ "$hdr" = "$POLICY_COLS" ]; then
    POLICY_FILES="$POLICY_FILES$f
"
  elif [ "$hdr" = "$TRIGGER_COLS" ]; then
    TRIGGER_FILES="$TRIGGER_FILES$f
"
  fi   # unknown headers ignored silently
done <<EOF
$files
EOF

checked_any=0
KNOWN_SKUS=""   # newline list of skus seen in policy tables (for trigger cross-check)

# --- validate policy tables --------------------------------------------------
while IFS= read -r f; do
  [ -n "$f" ] || continue
  checked_any=1
  seen=""
  ln=0
  while IFS= read -r raw || [ -n "$raw" ]; do
    raw="${raw%$'\r'}"
    ln=$((ln+1))
    [ "$ln" -eq 1 ] && continue                 # header
    [ -z "$(printf '%s' "$raw" | tr -d ',')" ] && continue   # blank line
    IFS=',' read -r sku abc_class avg_demand lead_time safety_stock reorder_point order_qty review_mode <<EOL
$raw
EOL
    [ -n "$sku" ]       || fail "$f line $ln: empty sku"
    [ -n "$abc_class" ] || fail "$f line $ln: sku '$sku' has empty abc_class"
    case "$review_mode" in
      continuous|periodic|ddmrp) : ;;
      *) fail "$f line $ln: sku '$sku' has review_mode '$review_mode' (expected continuous|periodic|ddmrp)" ;;
    esac
    case "
$seen" in
      *"
$sku
"*) fail "$f: duplicate sku '$sku'" ;;
    esac
    seen="$seen$sku
"
    awk -v ss="$safety_stock" -v rop="$reorder_point" -v oq="$order_qty" 'BEGIN{
      if (ss=="" || rop=="" || oq=="") exit 2;
      if (ss+0 < 0) exit 3;
      if (rop+0 < ss+0) exit 4;
      if (oq+0 <= 0) exit 5;
    }' || case "$?" in
        2) fail "$f line $ln: sku '$sku' has a missing numeric field" ;;
        3) fail "$f line $ln: sku '$sku' has negative safety_stock" ;;
        4) fail "$f line $ln: sku '$sku' has reorder_point < safety_stock (ROP must sit at or above the buffer)" ;;
        5) fail "$f line $ln: sku '$sku' has order_qty <= 0" ;;
      esac
    KNOWN_SKUS="$KNOWN_SKUS$sku
"
  done < "$f"
done <<EOF
$POLICY_FILES
EOF

have_policy=0
[ -n "$(printf '%s' "$KNOWN_SKUS" | tr -d '[:space:]')" ] && have_policy=1

# --- validate trigger lists --------------------------------------------------
while IFS= read -r f; do
  [ -n "$f" ] || continue
  checked_any=1
  ln=0
  while IFS= read -r raw || [ -n "$raw" ]; do
    raw="${raw%$'\r'}"
    ln=$((ln+1))
    [ "$ln" -eq 1 ] && continue
    [ -z "$(printf '%s' "$raw" | tr -d ',')" ] && continue
    IFS=',' read -r sku on_hand reorder_point suggested_order_qty <<EOL
$raw
EOL
    [ -n "$sku" ] || fail "$f line $ln: empty sku"
    if [ "$have_policy" -eq 1 ]; then
      case "
$KNOWN_SKUS" in
        *"
$sku
"*) : ;;
        *) fail "$f line $ln: trigger sku '$sku' is not present in any policy table" ;;
      esac
    fi
    awk -v oh="$on_hand" -v rop="$reorder_point" -v soq="$suggested_order_qty" 'BEGIN{
      if (oh=="" || rop=="" || soq=="") exit 2;
      if (oh+0 > rop+0) exit 3;
      if (soq+0 <= 0) exit 4;
    }' || case "$?" in
        2) fail "$f line $ln: sku '$sku' has a missing numeric field" ;;
        3) fail "$f line $ln: sku '$sku' is a FALSE TRIGGER — on_hand > reorder_point" ;;
        4) fail "$f line $ln: sku '$sku' has suggested_order_qty <= 0" ;;
      esac
  done < "$f"
done <<EOF
$TRIGGER_FILES
EOF

if [ "$checked_any" -eq 0 ]; then
  echo "verify.sh: OK — no inventory policy/trigger CSVs recognized (by header), nothing to check."
  exit 0
fi

echo "verify.sh: OK — all inventory artifacts pass structural invariants."
exit 0
