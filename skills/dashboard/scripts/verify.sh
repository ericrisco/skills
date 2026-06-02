#!/usr/bin/env bash
# verify.sh — check a dashboard.yaml for SHAPE and DISCIPLINE, not correctness.
# Read-only. Exits 0 on a clean/empty target (no false failures).
#
# Checks:
#   1. file parses as YAML
#   2. tiles: exists and holds 1-9 entries (fail if >9 — the budget rule)
#   3. exactly one tile has north_star: true
#   4. every tile has non-empty: metric, chart, comparison, owner, refresh, decision
#   5. banned charts: no pie with >5 categories; no gauge/dial
#
# Does NOT judge metric choice or numeric values.
#
# Usage: verify.sh [path/to/dashboard.yaml]   (default: ./dashboard.yaml)

set -euo pipefail

TARGET="${1:-./dashboard.yaml}"

if [[ ! -e "$TARGET" ]]; then
  echo "verify: no dashboard.yaml at '$TARGET' — nothing to check. PASS (empty target)."
  exit 0
fi

if [[ ! -s "$TARGET" ]]; then
  echo "verify: '$TARGET' is empty — nothing to check. PASS (empty target)."
  exit 0
fi

# Need a YAML parser. Prefer python3; fall back gracefully if absent.
if ! command -v python3 >/dev/null 2>&1; then
  echo "verify: python3 not found — cannot parse YAML on this machine."
  echo "        Install python3 (with PyYAML) to run shape checks. SKIP (no false failure)."
  exit 0
fi

python3 - "$TARGET" <<'PY'
import sys

path = sys.argv[1]

try:
    import yaml
except ModuleNotFoundError:
    print("verify: PyYAML not installed — cannot parse YAML.")
    print("        Run: python3 -m pip install pyyaml  then re-run. SKIP (no false failure).")
    sys.exit(0)

errors = []
warnings = []

try:
    with open(path) as fh:
        doc = yaml.safe_load(fh)
except yaml.YAMLError as e:
    print(f"verify: FAIL — '{path}' is not valid YAML:\n{e}")
    sys.exit(1)

if doc is None:
    print(f"verify: '{path}' parsed as empty. PASS (empty target).")
    sys.exit(0)

if not isinstance(doc, dict):
    print("verify: FAIL — top level must be a mapping with a 'tiles:' key.")
    sys.exit(1)

tiles = doc.get("tiles")
if not isinstance(tiles, list) or not tiles:
    print("verify: FAIL — 'tiles:' must be a non-empty list.")
    sys.exit(1)

# Tile budget
n = len(tiles)
if n > 9:
    errors.append(f"tile budget: {n} tiles exceeds the 9-tile ceiling — tier the extras to a drill-down.")
elif n < 5:
    warnings.append(f"tile budget: only {n} tiles — fine, but exec dashboards usually carry 5-9.")

REQUIRED = ["metric", "chart", "comparison", "owner", "refresh", "decision"]
BANNED_CHARTS = {"gauge", "dial"}

north_star_count = 0
for i, tile in enumerate(tiles):
    label = f"tile[{i}]"
    if not isinstance(tile, dict):
        errors.append(f"{label}: not a mapping.")
        continue
    tid = tile.get("id", label)
    label = f"tile '{tid}'"

    if tile.get("north_star") is True:
        north_star_count += 1

    for key in REQUIRED:
        val = tile.get(key)
        if val is None or (isinstance(val, str) and not val.strip()) or val == {} or val == []:
            errors.append(f"{label}: missing or empty required field '{key}'.")

    chart = tile.get("chart")
    if isinstance(chart, str):
        c = chart.strip().lower()
        if c in BANNED_CHARTS:
            errors.append(f"{label}: chart '{chart}' is banned — use a bullet chart instead.")
        if c == "pie":
            cats = tile.get("categories")
            if isinstance(cats, int) and cats > 5:
                errors.append(f"{label}: pie with {cats} categories — over 5 is unreadable; use a sorted bar.")
            elif isinstance(cats, list) and len(cats) > 5:
                errors.append(f"{label}: pie with {len(cats)} categories — over 5 is unreadable; use a sorted bar.")
            else:
                warnings.append(f"{label}: pie chart — keep it to 3-5 slices or switch to a sorted bar.")

if north_star_count == 0:
    errors.append("north_star: no tile flagged 'north_star: true' — a dashboard needs one entry point.")
elif north_star_count > 1:
    errors.append(f"north_star: {north_star_count} tiles flagged 'north_star: true' — there must be exactly one.")

for w in warnings:
    print(f"verify: warn — {w}")

if errors:
    print()
    for e in errors:
        print(f"verify: FAIL — {e}")
    print(f"\nverify: {len(errors)} problem(s) found in '{path}'.")
    sys.exit(1)

print(f"verify: PASS — '{path}' has {n} tile(s), one north-star, all required fields, no banned charts.")
sys.exit(0)
PY
