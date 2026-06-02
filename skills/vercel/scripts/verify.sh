#!/usr/bin/env bash
# verify.sh — lint a target vercel.json against the 2025-2026 platform rules.
#
# Usage:
#   bash scripts/verify.sh [path/to/vercel.json]
#
# With no arg it discovers ./vercel.json (then a shallow search). If no vercel.json
# exists anywhere in range, that is NOT a failure — exit 0 (read-only, no false alarm).
#
# Checks (FAIL = exit 1; WARN = advisory, still exit 0 if nothing failed):
#   1. valid JSON
#   2. FAIL if both `builds` and `functions` are present (mutually exclusive)
#   3. FAIL if any `functions.*.memory` is set (Fluid caveat — memory is a dashboard setting)
#   4. WARN if `$schema` is missing (lose autocomplete/validation)
#   5. for each `crons[]`: FAIL if `path` is missing or does not start with `/`, or `schedule` missing
#
# Pure jq/node/python3 — no network, no auth, no mutation. Runs on macOS bash 3.2 and CI bash 5.
set -euo pipefail

if [[ -n "${NO_COLOR:-}" ]]; then YEL=""; GRN=""; RED=""; RST=""
else YEL=$'\033[33m'; GRN=$'\033[32m'; RED=$'\033[31m'; RST=$'\033[0m'; fi
warn() { printf '%s[warn]%s %s\n' "$YEL" "$RST" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$GRN" "$RST" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED" "$RST" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Resolve target.
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  if [[ -f vercel.json ]]; then
    TARGET="vercel.json"
  else
    TARGET=$(find . -maxdepth 2 -name 'vercel.json' -not -path '*/node_modules/*' 2>/dev/null | head -n1 || true)
  fi
fi

if [[ -z "$TARGET" || ! -f "$TARGET" ]]; then
  ok "no vercel.json found in range — nothing to verify"
  exit 0
fi

# Need a JSON engine. Prefer node (rich logic), then python3. jq optional fallback for validity only.
ENGINE=""
if have node; then ENGINE="node"
elif have python3; then ENGINE="python3"
elif have jq; then ENGINE="jq"
else
  warn "no node/python3/jq available — cannot lint $TARGET (skipping, not a failure)"
  exit 0
fi

FAILED=0

if [[ "$ENGINE" == "jq" ]]; then
  # jq-only: can only confirm validity. Use -e (some jq builds exit 0 on parse error without it).
  if jq -e . "$TARGET" >/dev/null 2>&1; then
    ok "valid JSON ($TARGET)"
    warn "only jq available — skipping builds/memory/crons rules (install node or python3 for full lint)"
  else
    fail "not valid JSON ($TARGET)"; FAILED=1
  fi
  if [[ $FAILED -eq 0 ]]; then ok "all checks passed"; else fail "checks failed"; fi
  exit "$FAILED"
fi

# Full lint via node or python3. The runner prints lines: "OK …", "WARN …", "FAIL …".
run_node() {
node - "$TARGET" <<'JS'
const fs = require("fs");
const path = process.argv[2];
let cfg;
try { cfg = JSON.parse(fs.readFileSync(path, "utf8")); }
catch (e) { console.log("FAIL not valid JSON: " + e.message); process.exit(0); }
console.log("OK valid JSON (" + path + ")");

const hasBuilds = Object.prototype.hasOwnProperty.call(cfg, "builds");
const hasFns = Object.prototype.hasOwnProperty.call(cfg, "functions");
if (hasBuilds && hasFns) console.log("FAIL `builds` and `functions` are mutually exclusive — remove `builds`");

if (hasFns && cfg.functions && typeof cfg.functions === "object") {
  for (const [glob, val] of Object.entries(cfg.functions)) {
    if (val && typeof val === "object" && Object.prototype.hasOwnProperty.call(val, "memory")) {
      console.log("FAIL functions[\"" + glob + "\"].memory is set — under Fluid, memory is a dashboard setting, not vercel.json");
    }
  }
}

if (!Object.prototype.hasOwnProperty.call(cfg, "$schema")) {
  console.log("WARN missing `$schema` — add \"https://openapi.vercel.sh/vercel.json\" for validation");
}

if (Object.prototype.hasOwnProperty.call(cfg, "crons")) {
  const crons = cfg.crons;
  if (!Array.isArray(crons)) {
    console.log("FAIL `crons` must be an array");
  } else {
    crons.forEach((c, i) => {
      if (!c || typeof c !== "object") { console.log("FAIL crons[" + i + "] is not an object"); return; }
      if (typeof c.path !== "string" || c.path.length === 0) console.log("FAIL crons[" + i + "] missing `path`");
      else if (c.path[0] !== "/") console.log("FAIL crons[" + i + "] path must start with `/` (got \"" + c.path + "\")");
      if (typeof c.schedule !== "string" || c.schedule.length === 0) console.log("FAIL crons[" + i + "] missing `schedule`");
    });
  }
}
JS
}

run_python() {
python3 - "$TARGET" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        cfg = json.load(f)
except Exception as e:
    print("FAIL not valid JSON: %s" % e); sys.exit(0)
print("OK valid JSON (%s)" % path)

has_builds = "builds" in cfg
has_fns = "functions" in cfg
if has_builds and has_fns:
    print("FAIL `builds` and `functions` are mutually exclusive — remove `builds`")

if has_fns and isinstance(cfg.get("functions"), dict):
    for glob, val in cfg["functions"].items():
        if isinstance(val, dict) and "memory" in val:
            print('FAIL functions["%s"].memory is set — under Fluid, memory is a dashboard setting, not vercel.json' % glob)

if "$schema" not in cfg:
    print('WARN missing `$schema` — add "https://openapi.vercel.sh/vercel.json" for validation')

if "crons" in cfg:
    crons = cfg["crons"]
    if not isinstance(crons, list):
        print("FAIL `crons` must be an array")
    else:
        for i, c in enumerate(crons):
            if not isinstance(c, dict):
                print("FAIL crons[%d] is not an object" % i); continue
            p = c.get("path")
            if not isinstance(p, str) or not p:
                print("FAIL crons[%d] missing `path`" % i)
            elif not p.startswith("/"):
                print('FAIL crons[%d] path must start with `/` (got "%s")' % (i, p))
            if not isinstance(c.get("schedule"), str) or not c.get("schedule"):
                print("FAIL crons[%d] missing `schedule`" % i)
PY
}

if [[ "$ENGINE" == "node" ]]; then OUT=$(run_node); else OUT=$(run_python); fi

# Render results and set exit status.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  case "$line" in
    OK\ *)   ok   "${line#OK }" ;;
    WARN\ *) warn "${line#WARN }" ;;
    FAIL\ *) fail "${line#FAIL }"; FAILED=1 ;;
    *)       printf '%s\n' "$line" ;;
  esac
done <<EOF
$OUT
EOF

if [[ $FAILED -eq 0 ]]; then ok "all checks passed (warnings are not failures)"
else fail "one or more checks failed"; fi
exit "$FAILED"
