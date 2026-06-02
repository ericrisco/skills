#!/usr/bin/env bash
# verify.sh — lint every render.yaml Blueprint in a target directory against the
# correctness rules that cause real Render deploy failures. Read-only: parses YAML,
# checks rules, prints findings. No network, no Render account.
#
# Usage:
#   bash scripts/verify.sh [TARGET_DIR]   # default: current directory
#
# Checks per service:
#   - has `name` and a valid `type` (web|pserv|worker|cron|keyvalue)
#   - `runtime` present for every non-keyvalue service and is a valid enum
#   - `schedule` present iff `type: cron`
#   - `plan` / `region` (if set) are valid enums
#   - WARN if a `web` service `startCommand` hardcodes a numeric port without $PORT
#
# Exit codes: 0 = clean OR no render.yaml found (never a false failure);
#             1 = at least one hard error. Warnings never fail the run.
#
# Portable to macOS bash 3.2 and CI bash 5. NO_COLOR=1 disables color.
set -euo pipefail

TARGET="${1:-.}"

if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
  RED=""; YEL=""; GRN=""; RST=""
else
  RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
fi

have() { command -v "$1" >/dev/null 2>&1; }

# Discover render.yaml / render.yml files. No matches -> clean exit 0.
FILES=""
while IFS= read -r f; do
  FILES="$FILES$f
"
done < <(find "$TARGET" -type f \( -name 'render.yaml' -o -name 'render.yml' \) 2>/dev/null)

if [ -z "${FILES%$'\n'}" ]; then
  echo "${GRN}OK${RST} no render.yaml found under '$TARGET' — nothing to verify."
  exit 0
fi

ERRORS=0

if have python3; then
  while IFS= read -r FILE; do
    [ -z "$FILE" ] && continue
    echo "→ $FILE"
    OUT="$(
      RENDER_FILE="$FILE" python3 - <<'PY'
import os, sys
try:
    import yaml
except Exception:
    print("WARN\tPyYAML not installed; skipped deep checks (heuristics only)")
    sys.exit(3)

path = os.environ["RENDER_FILE"]
try:
    with open(path) as fh:
        doc = yaml.safe_load(fh) or {}
except Exception as e:
    print(f"ERROR\tYAML parse failed: {e}")
    sys.exit(0)

VALID_TYPE = {"web", "pserv", "worker", "cron", "keyvalue"}
VALID_RUNTIME = {"node","python","docker","image","static","go","ruby","elixir","rust"}
VALID_PLAN = {"free","starter","standard","pro","pro plus","pro max","pro ultra"}
VALID_REGION = {"oregon","ohio","virginia","frankfurt","singapore"}

services = doc.get("services") or []
if not isinstance(services, list):
    print("ERROR\t`services` must be a list")
    services = []

for i, svc in enumerate(services):
    if not isinstance(svc, dict):
        print(f"ERROR\tservices[{i}] is not a mapping")
        continue
    label = svc.get("name") or f"services[{i}]"
    stype = svc.get("type")

    if not svc.get("name"):
        print(f"ERROR\t{label}: missing `name`")
    if stype not in VALID_TYPE:
        print(f"ERROR\t{label}: invalid/missing `type` ({stype!r}); expected one of {sorted(VALID_TYPE)}")

    if stype != "keyvalue":
        rt = svc.get("runtime")
        if not rt:
            print(f"ERROR\t{label}: missing `runtime` (required for type {stype!r})")
        elif rt not in VALID_RUNTIME:
            print(f"ERROR\t{label}: invalid `runtime` ({rt!r})")

    if stype == "cron" and not svc.get("schedule"):
        print(f"ERROR\t{label}: type cron requires a `schedule:`")
    if stype and stype != "cron" and svc.get("schedule"):
        print(f"WARN\t{label}: `schedule:` is only used by type cron; ignored here")

    plan = svc.get("plan")
    if plan is not None and plan not in VALID_PLAN:
        print(f"ERROR\t{label}: invalid `plan` ({plan!r})")
    region = svc.get("region")
    if region is not None and region not in VALID_REGION:
        print(f"ERROR\t{label}: invalid `region` ({region!r})")

    if stype == "web":
        cmd = str(svc.get("startCommand") or "")
        import re
        if cmd and "$PORT" not in cmd and "${PORT}" not in cmd and re.search(r":\d{2,5}\b", cmd):
            print(f"WARN\t{label}: web startCommand looks like it hardcodes a port without $PORT — Render may report 'no open ports detected'")

dbs = doc.get("databases") or []
if not isinstance(dbs, list):
    print("ERROR\t`databases` must be a list")
    dbs = []
for i, db in enumerate(dbs):
    if isinstance(db, dict) and db.get("plan") == "free":
        print(f"WARN\tdatabase {db.get('name', i)!r}: free Postgres is deleted 30 days after creation — use starter for production")
PY
    )" || true

    # Surface findings; count hard errors.
    if [ -n "$OUT" ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in
          ERROR*) echo "  ${RED}${line}${RST}"; ERRORS=$((ERRORS + 1)) ;;
          WARN*)  echo "  ${YEL}${line}${RST}" ;;
          *)      echo "  $line" ;;
        esac
      done <<EOF
$OUT
EOF
    else
      echo "  ${GRN}OK${RST}"
    fi
  done <<EOF
$FILES
EOF
else
  # No python3: fall back to a shallow grep-based sanity pass (heuristic only).
  echo "${YEL}WARN${RST} python3 not found — running shallow grep checks only."
  while IFS= read -r FILE; do
    [ -z "$FILE" ] && continue
    echo "→ $FILE"
    if grep -Eq '^\s*type:\s*cron' "$FILE" && ! grep -Eq '^\s*schedule:' "$FILE"; then
      echo "  ${RED}ERROR\ta cron service appears to be missing a schedule:${RST}"
      ERRORS=$((ERRORS + 1))
    fi
    if grep -Eq 'startCommand:.*:[0-9]{2,5}\b' "$FILE" && ! grep -q '\$PORT' "$FILE"; then
      echo "  ${YEL}WARN\tstartCommand may hardcode a port without \$PORT${RST}"
    fi
    echo "  ${GRN}OK${RST} (shallow)"
  done <<EOF
$FILES
EOF
fi

echo
if [ "$ERRORS" -gt 0 ]; then
  echo "${RED}FAIL${RST} $ERRORS error(s) found."
  exit 1
fi
echo "${GRN}PASS${RST} render.yaml checks clean."
exit 0
