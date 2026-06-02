#!/usr/bin/env bash
# verify.sh — read-only sanity check for semantic-model definitions.
# Stock macOS bash 3.2 compatible. Never connects to a warehouse.
# Exits non-zero ONLY on unparseable YAML; every metric-modeling check is advisory [warn].
# Empty / no-candidate target passes clean.
set -u

TARGET="${1:-.}"
WARN=0
FAIL=0
CHECKED=0

note() { printf '%s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*"; WARN=$((WARN + 1)); }
fail() { printf '[fail] %s\n' "$*"; FAIL=$((FAIL + 1)); }
ok()   { printf '[ok] %s\n' "$*"; }

if [ ! -e "$TARGET" ]; then
  note "[skip] target not found: $TARGET"
  exit 0
fi

# Discover candidate semantic-model files: YAML containing layer keywords,
# or Cube .js/.yml files declaring cube(/measures:.
CANDIDATES=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -Eqi '(^|[[:space:]])(semantic_models|metrics|measures)[[:space:]]*:' "$f" 2>/dev/null \
     || grep -Eqi 'cube\(' "$f" 2>/dev/null; then
    CANDIDATES="$CANDIDATES$f"$'\n'
  fi
done <<EOF
$(find "$TARGET" -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.js' \) 2>/dev/null)
EOF

CANDIDATES="$(printf '%s' "$CANDIDATES" | grep -v '^$' || true)"

if [ -z "$CANDIDATES" ]; then
  note "[skip] no semantic-model candidates under: $TARGET"
  exit 0
fi

# Pick a YAML parser if available.
YAML_CHECK=""
if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
  YAML_CHECK="python3"
elif command -v yq >/dev/null 2>&1; then
  YAML_CHECK="yq"
fi

ALL_METRIC_NAMES=""

while IFS= read -r f; do
  [ -z "$f" ] && continue
  CHECKED=$((CHECKED + 1))
  note "--- $f"

  case "$f" in
    *.yml|*.yaml)
      if [ "$YAML_CHECK" = "python3" ]; then
        if ! python3 -c "import sys,yaml; list(yaml.safe_load_all(open(sys.argv[1])))" "$f" >/dev/null 2>&1; then
          fail "YAML does not parse"
          continue
        fi
      elif [ "$YAML_CHECK" = "yq" ]; then
        if ! yq -e '.' "$f" >/dev/null 2>&1; then
          fail "YAML does not parse"
          continue
        fi
      else
        # No parser: brace/indent sanity check (tabs are illegal in YAML).
        if grep -Pq '\t' "$f" 2>/dev/null || grep -q "$(printf '\t')" "$f" 2>/dev/null; then
          warn "tab character in YAML (use spaces) — install python3+pyyaml or yq for a real parse"
        fi
      fi
      ;;
  esac

  # --- Advisory metric-modeling checks (line-grep heuristics) ---

  # A metrics: block but no underlying measure/agg anywhere in the file.
  if grep -Eqi '(^|[[:space:]])metrics[[:space:]]*:' "$f"; then
    if ! grep -Eqi '(measure|agg|aggregation)[[:space:]]*:' "$f"; then
      warn "has a metrics: block but no measure/agg in the same file — is the metric grounded in a measure?"
    fi
  fi

  # A measures: block but at least one measure may lack an agg.
  if grep -Eqi '(^|[[:space:]])measures[[:space:]]*:' "$f"; then
    MEAS_NAMES=$(grep -Ec '^[[:space:]]*-[[:space:]]*(name|name:)' "$f" 2>/dev/null || echo 0)
    if ! grep -Eqi '(^|[[:space:]])(agg|aggregation)[[:space:]]*:' "$f"; then
      warn "measures: block with no agg/aggregation declared — every measure needs an explicit aggregation"
    fi
  fi

  # Time dimension with no grain/granularity.
  if grep -Eqi 'type[[:space:]]*:[[:space:]]*time' "$f"; then
    if ! grep -Eqi '(time_granularity|granularity|grain)[[:space:]]*:' "$f"; then
      warn "time dimension present but no grain/granularity declared — undeclared grain causes daily-vs-monthly mismatches"
    fi
  fi

  # Hand-rolled aggregate in a .sql beside the model.
  DIR=$(dirname "$f")
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    if grep -Eqi '(sum|count|avg|min|max)[[:space:]]*\(' "$s" 2>/dev/null; then
      warn "hand-rolled aggregate in $(basename "$s") beside the model — the layer should own this aggregation"
    fi
  done <<INNER
$(find "$DIR" -maxdepth 1 -type f -name '*.sql' 2>/dev/null)
INNER

  # Collect metric names for duplicate detection across files.
  NAMES=$(grep -A1 -Ei '(^|[[:space:]])metrics[[:space:]]*:' "$f" 2>/dev/null \
          | grep -Eoi '^[[:space:]]*-[[:space:]]*name:[[:space:]]*[A-Za-z0-9_]+' \
          | sed -E 's/.*name:[[:space:]]*//' 2>/dev/null || true)
  if grep -Eqi '(^|[[:space:]])metrics[[:space:]]*:' "$f"; then
    NAMES=$(awk '/[[:space:]]*metrics[[:space:]]*:/{inm=1} inm && /name:/{print $NF}' "$f" 2>/dev/null || true)
    ALL_METRIC_NAMES="$ALL_METRIC_NAMES$NAMES"$'\n'
  fi
done <<EOF
$CANDIDATES
EOF

# Duplicate metric names across all candidates.
DUPES=$(printf '%s' "$ALL_METRIC_NAMES" | grep -v '^$' | sort | uniq -d || true)
if [ -n "$DUPES" ]; then
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    warn "duplicate metric name '$d' — a metric must be defined exactly once"
  done <<EOF
$DUPES
EOF
fi

note "---"
note "checked $CHECKED file(s); $WARN warning(s); $FAIL failure(s)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
