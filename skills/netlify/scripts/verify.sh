#!/usr/bin/env bash
# verify.sh — read-only sanity check for a Netlify config artifact.
# Usage: verify.sh [TARGET_DIR]   (default: current directory)
# Exits 0 on a clean OR empty target (no netlify.toml => nothing to check, not a failure).
# Exits 1 only when a netlify.toml is present AND structurally wrong.

set -uo pipefail

TARGET="${1:-.}"
TOML="$TARGET/netlify.toml"
fail=0

pass() { printf 'PASS: %s\n' "$1"; }
warn() { printf 'WARN: %s\n' "$1"; }
bad()  { printf 'FAIL: %s\n' "$1"; fail=1; }

if [ ! -f "$TOML" ]; then
  echo "INFO: no netlify.toml in '$TARGET' — nothing to verify."
  exit 0
fi
pass "found $TOML"

# 1. Does it parse as TOML?
if command -v python3 >/dev/null 2>&1; then
  if python3 - "$TOML" <<'PY' 2>/dev/null
import sys
try:
    import tomllib
except ModuleNotFoundError:
    sys.exit(42)  # signal "no tomllib" -> skip, not fail
with open(sys.argv[1], "rb") as f:
    tomllib.load(f)
PY
  then
    pass "netlify.toml parses as valid TOML"
  else
    rc=$?
    if [ "$rc" = "42" ]; then
      warn "python3 has no tomllib (Python < 3.11) — skipping parse check"
    else
      bad "netlify.toml does not parse as valid TOML"
    fi
  fi
else
  warn "python3 not found — skipping TOML parse check"
fi

# 2. SPA fallback (to "/index.html") must be status = 200, not a 3xx.
#    Scan each [[redirects]] block; if its `to` is /index.html, its status must be 200.
if command -v python3 >/dev/null 2>&1 && python3 -c "import tomllib" >/dev/null 2>&1; then
  python3 - "$TOML" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
reds = data.get("redirects", [])
ok = True
for r in reds:
    if "from" not in r or "to" not in r:
        print("FAIL: a [[redirects]] block is missing 'from' or 'to'")
        ok = False
    if r.get("to") == "/index.html" and r.get("status", 301) != 200:
        print("FAIL: SPA fallback (to=/index.html) must be status = 200, not %r" % r.get("status", 301))
        ok = False
if "build" not in data:
    print("WARN: no [build] table — builds will rely on dashboard settings")
if ok:
    print("PASS: redirects have from+to and any SPA fallback is status 200")
sys.exit(0 if ok else 1)
PY
  [ $? -ne 0 ] && fail=1
else
  # Fallback grep-based check when tomllib is unavailable.
  if grep -Eq 'to[[:space:]]*=[[:space:]]*"/index\.html"' "$TOML"; then
    # crude: ensure a status 200 appears near a /index.html target
    if grep -Eq 'status[[:space:]]*=[[:space:]]*200' "$TOML"; then
      pass "SPA fallback target present and a status = 200 is declared"
    else
      bad "SPA fallback to /index.html found but no status = 200 declared"
    fi
  fi
fi

# 3. Optional: if the netlify CLI is installed, surface its parse via build --dry (best-effort).
if command -v netlify >/dev/null 2>&1; then
  pass "netlify CLI available (run 'netlify build --dry' for a deeper check)"
else
  warn "netlify CLI not installed — CLI-level checks skipped"
fi

if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
