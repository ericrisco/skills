#!/usr/bin/env bash
# verify.sh — static linter for ClickHouse DDL/queries emitted by the
# clickhouse-analytics skill. Read-only: it greps candidate .sql text for
# anti-patterns from SKILL.md. It does NOT connect to any cluster.
#
# Usage:
#   scripts/verify.sh [PATH ...]      # lint given .sql files
#   scripts/verify.sh                 # lint *.sql under the current dir
#   cat x.sql | scripts/verify.sh -   # lint stdin
#
# Exit: 0 when nothing flagged (also on empty/no input — no false failure).
#       1 when at least one anti-pattern line is found.

set -u

findings=0

# Emit a finding line and bump the counter.
flag() { # file line_no message line_text
  printf '%s:%s: %s\n    %s\n' "$1" "$2" "$3" "$(printf '%s' "$4" | sed 's/^[[:space:]]*//')"
  findings=$((findings + 1))
}

# Lint one already-collected buffer. Args: label, full-text-in-$2.
lint_buffer() {
  local label="$1" text="$2"
  [ -z "${text//[[:space:]]/}" ] && return 0   # empty buffer: nothing to flag

  local lineno=0 line lower
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    # Strip trailing line comments so they don't trip the matchers.
    local code="${line%%--*}"
    lower="$(printf '%s' "$code" | tr '[:upper:]' '[:lower:]')"
    [ -z "${lower//[[:space:]]/}" ] && continue

    # 1. Over-fine partitioning: per-day / per-hour buckets.
    case "$lower" in
      *partition\ by*toyyyymmdd*|*partition\ by*tostartofhour*|*partition\ by*tostartofminute*|*partition\ by*todate\(*)
        flag "$label" "$lineno" "fine PARTITION BY (per-day/hour) — partition coarsely (toYYYYMM); the sparse index does the speed" "$line" ;;
    esac

    # 2. Single-row INSERT ... VALUES (...) on one line — tiny parts.
    case "$lower" in
      *insert\ into*values*\(*\)*)
        flag "$label" "$lineno" "single-row INSERT ... VALUES — batch 10k-100k+ rows or rely on async inserts" "$line" ;;
    esac

    # 3. POPULATE on a materialized view — blocks/OOM on big tables.
    case "$lower" in
      *materialized\ view*populate*|*populate*as\ select*)
        flag "$label" "$lineno" "POPULATE on a materialized view — create it empty and backfill in bounded windows" "$line" ;;
    esac

    # 4. SELECT * — defeats columnar storage on wide tables.
    case "$lower" in
      *select\ \**) flag "$label" "$lineno" "SELECT * — name only the columns you need (columnar store reads per-column)" "$line" ;;
    esac

    # 5. FINAL — merges at query time, keep off hot paths.
    case "$lower" in
      *\ final\ *|*\ final\;*|*\ final|*\)final*)
        flag "$label" "$lineno" "FINAL — merges at query time; keep it off dashboard/hot-path queries" "$line" ;;
    esac
  done <<EOF
$text
EOF

  # 6. MergeTree-family ENGINE with no ORDER BY anywhere in the statement set.
  #    Whole-buffer check because ORDER BY may sit lines below ENGINE.
  if printf '%s' "$text" | grep -iqE 'engine[[:space:]]*=[[:space:]]*[a-z]*mergetree'; then
    if ! printf '%s' "$text" | grep -iqE 'order[[:space:]]+by[[:space:]]+[^t]'; then
      flag "$label" "0" "MergeTree-family ENGINE with no usable ORDER BY — define a 3-5 col sort key (ORDER BY tuple() leaves no sparse index)" "ENGINE = *MergeTree"
    fi
  fi
}

# Collect input sources.
inputs=()
if [ "$#" -eq 0 ]; then
  while IFS= read -r f; do inputs+=("$f"); done < <(find . -type f -name '*.sql' 2>/dev/null)
else
  for arg in "$@"; do inputs+=("$arg"); done
fi

# Nothing to lint at all: clean exit, no false failure.
if [ "${#inputs[@]}" -eq 0 ]; then
  echo "clickhouse-analytics verify: no .sql input found — nothing to check."
  exit 0
fi

for src in "${inputs[@]}"; do
  if [ "$src" = "-" ]; then
    lint_buffer "(stdin)" "$(cat)"
  elif [ -f "$src" ]; then
    lint_buffer "$src" "$(cat "$src")"
  else
    echo "clickhouse-analytics verify: skip (not a file): $src" >&2
  fi
done

if [ "$findings" -gt 0 ]; then
  echo "---"
  echo "clickhouse-analytics verify: $findings anti-pattern line(s) flagged. See SKILL.md."
  exit 1
fi

echo "clickhouse-analytics verify: clean — no anti-patterns found."
exit 0
