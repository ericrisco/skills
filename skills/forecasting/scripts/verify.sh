#!/usr/bin/env bash
# verify.sh — validate forecast artifacts produced by the forecasting skill.
#
# Read-only by default: it inspects forecast CSV/Parquet-as-CSV files and checks
# they honor the deliverable contract. It writes nothing and changes nothing.
#
# A valid forecast artifact must:
#   1. have a header containing `ds` and `forecast`
#   2. have at least one interval column (lo/hi, or *-lo-*/*-hi-* from statsforecast)
#   3. have at least one data row (the horizon)
# An accompanying accuracy readout (WAPE / MASE / bias) is checked if present
# next to the artifact (e.g. forecast.csv + accuracy.txt / *.md).
#
# Usage:
#   scripts/verify.sh [TARGET_DIR]   (default: current directory)
#
# Exit 0 when every found artifact is valid, OR when no artifact exists yet
# (a clean/empty target is not a failure). Exit 1 only on a malformed artifact.

set -euo pipefail

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "verify: target '$TARGET' is not a directory" >&2
  exit 1
fi

# Candidate artifacts: CSVs whose name suggests a forecast, plus any CSV whose
# header literally contains a `forecast` column. Read-only discovery; no writes.
# Portable to bash 3.2 (no mapfile).
all_csv="$(find "$TARGET" -type f -name '*.csv' 2>/dev/null || true)"

by_name="$(printf '%s\n' "$all_csv" | grep -Ei 'forecast|prevision|prediccion|prediccio|demand' || true)"

by_header=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if head -n 1 "$f" 2>/dev/null | grep -qiE '(^|,)forecast(,|$)'; then
    by_header="$by_header$f
"
  fi
done <<EOF
$all_csv
EOF

# Merge and de-duplicate the two lists.
artifacts=$(printf '%s\n%s\n' "$by_name" "$by_header" | sed '/^$/d' | sort -u || true)

if [ -z "$artifacts" ]; then
  echo "verify: no forecast artifact found under '$TARGET' — nothing to check (clean)."
  exit 0
fi

fail=0
checked=0

while IFS= read -r f; do
  [ -z "$f" ] && continue
  checked=$((checked + 1))
  header="$(head -n 1 "$f" 2>/dev/null || true)"
  total_lines="$(wc -l < "$f" 2>/dev/null | tr -d '[:space:]')"
  [ -z "$total_lines" ] && total_lines=1
  rows=$((total_lines - 1))  # minus header
  lc_header="$(printf '%s' "$header" | tr '[:upper:]' '[:lower:]')"

  problems=()

  # 1. ds + forecast columns
  printf '%s' "$lc_header" | grep -qE '(^|,)ds(,|$)' || problems+=("missing 'ds' column")
  printf '%s' "$lc_header" | grep -qE '(^|,)forecast(,|$)' || problems+=("missing 'forecast' column")

  # 2. at least one interval column: lo/hi or statsforecast *-lo-*/*-hi-*
  if ! printf '%s' "$lc_header" | grep -qE '(^|,)(lo|hi)(,|$)|-lo-|-hi-'; then
    problems+=("no interval column (expected lo/hi or *-lo-*/*-hi-*)")
  fi

  # 3. at least one data row
  if [ "$rows" -lt 1 ]; then
    problems+=("no data rows (header only)")
  fi

  if [ "${#problems[@]}" -eq 0 ]; then
    echo "verify: OK  $f  ($rows row(s))"
  else
    fail=1
    echo "verify: FAIL $f" >&2
    for p in "${problems[@]}"; do echo "         - $p" >&2; done
  fi
done <<< "$artifacts"

# Accuracy readout check (advisory): warn, do not fail, if no WAPE/MASE/bias text
# accompanies the artifacts. The forecast itself is the hard contract.
if ! grep -rqiE 'wape|wmape|\bmase\b|\bbias\b' "$TARGET" 2>/dev/null; then
  echo "verify: note — no accuracy readout (WAPE/MASE/bias) found near artifacts; ship one." >&2
fi

echo "verify: checked $checked artifact(s)."
exit "$fail"
