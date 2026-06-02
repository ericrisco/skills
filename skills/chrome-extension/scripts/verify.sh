#!/usr/bin/env bash
# verify.sh — lint a Manifest V3 manifest.json against MV3 invariants.
# Read-only. Exits 0 on a clean/empty target (no manifest = nothing to check).
# Usage: scripts/verify.sh [target-dir]   (defaults to current directory)
set -euo pipefail

TARGET="${1:-.}"

if ! command -v node >/dev/null 2>&1; then
  echo "verify.sh: node not found; skipping manifest lint." >&2
  exit 0
fi

# Find manifest.json files, ignoring build/vendor dirs. No matches => clean pass.
MANIFESTS="$(
  find "$TARGET" \
    -type d \( -name node_modules -o -name dist -o -name .git \) -prune -o \
    -type f -name manifest.json -print 2>/dev/null
)"

if [ -z "$MANIFESTS" ]; then
  echo "verify.sh: no manifest.json under '$TARGET' — nothing to check."
  exit 0
fi

FAIL=0
while IFS= read -r m; do
  [ -z "$m" ] && continue
  node - "$m" <<'NODE' || FAIL=1
const fs = require("fs");
const path = process.argv[2];
const errs = [];
let mf;
try {
  mf = JSON.parse(fs.readFileSync(path, "utf8"));
} catch (e) {
  console.error(`FAIL ${path}: invalid JSON — ${e.message}`);
  process.exit(1);
}
if (mf.manifest_version !== 3) errs.push(`manifest_version must be 3 (got ${JSON.stringify(mf.manifest_version)})`);
const bg = mf.background || {};
if ("scripts" in bg) errs.push("background.scripts is MV2; use background.service_worker (string)");
if ("page" in bg) errs.push("background.page is MV2; use background.service_worker (string)");
if ("persistent" in bg) errs.push("background.persistent does not exist in MV3; remove it");
if (mf.background !== undefined) {
  if (typeof bg.service_worker !== "string") errs.push("background.service_worker must be a string");
}
if (typeof mf.name !== "string" || !mf.name) errs.push("missing name");
if (typeof mf.version !== "string" || !mf.version) errs.push("missing version");
if (mf.icons === undefined || typeof mf.icons !== "object") errs.push("missing icons");
if (errs.length) {
  console.error(`FAIL ${path}:`);
  for (const e of errs) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`OK   ${path}`);
NODE
done <<EOF
$MANIFESTS
EOF

exit "$FAIL"
