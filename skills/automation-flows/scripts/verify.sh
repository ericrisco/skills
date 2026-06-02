#!/usr/bin/env bash
# verify.sh — read-only validator for n8n workflow JSON emitted by automation-flows.
# Checks every *.json under the target: parses as JSON, non-empty `nodes` array,
# `connections` object, and >=1 trigger node. No network, no credentials.
# Exits 0 when there is nothing to check (empty/clean target is not a failure).
set -euo pipefail

TARGET="${1:-.}"

if [ ! -e "$TARGET" ]; then
  echo "verify: target not found: $TARGET (nothing to check)"
  exit 0
fi

# Collect candidate JSON files (files or a directory tree).
files=()
if [ -d "$TARGET" ]; then
  while IFS= read -r f; do files+=("$f"); done < <(find "$TARGET" -type f -name '*.json' 2>/dev/null)
elif [ -f "$TARGET" ]; then
  files+=("$TARGET")
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "verify: no *.json workflow files found under $TARGET (nothing to check)"
  exit 0
fi

PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then
  echo "verify: python not found; cannot validate JSON" >&2
  exit 2
fi

rc=0
for f in "${files[@]}"; do
  if "$PY" - "$f" <<'PYEOF'
import json, sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as e:
    print(f"FAIL {path}: not valid JSON ({e})")
    sys.exit(1)

# Only judge files that look like n8n workflows (have a nodes key).
if not isinstance(data, dict) or "nodes" not in data:
    print(f"skip {path}: not an n8n workflow (no top-level 'nodes')")
    sys.exit(0)

errs = []
nodes = data.get("nodes")
if not isinstance(nodes, list) or len(nodes) == 0:
    errs.append("`nodes` must be a non-empty array")

conns = data.get("connections")
if not isinstance(conns, dict):
    errs.append("`connections` must be an object")

def is_trigger(n):
    t = (n.get("type") or "").lower() if isinstance(n, dict) else ""
    return t.endswith("webhook") or t.endswith("trigger") or t.endswith("cron")

if isinstance(nodes, list) and not any(is_trigger(n) for n in nodes):
    errs.append("no trigger node found (type ending in webhook/trigger/cron)")

if errs:
    print(f"FAIL {path}: " + "; ".join(errs))
    sys.exit(1)

print(f"ok   {path}: {len(nodes)} nodes, trigger present, connections object")
sys.exit(0)
PYEOF
  then :; else rc=1; fi
done

exit "$rc"
