#!/usr/bin/env bash
#
# verify.sh — brand-token gate for the `brand-identity` skill.
#
# WHAT IT DOES (read-only; never writes or mutates anything)
#   Given a W3C design-tokens.json path, validates the brand book's
#   machine-readable artifact:
#     1. File exists and parses as JSON (fail loud otherwise).
#     2. Required color roles present: primary, neutral, accent (anywhere in
#        the color tree).
#     3. Every color token carries a HEX value (in its `$value.hex`).
#     4. For each documented text/background pair under
#        $extensions["com.risco.contrast"], computes the WCAG 2 relative-
#        luminance contrast ratio and FAILS any normal-text pair < 4.5:1.
#        Pairs flagged "logo": true are exempt (WCAG 1.4.3 logo exemption).
#     5. Prints an ok/skip/warn/fail summary naming the failing pairs.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh path/to/design-tokens.json
#   ./verify.sh                  # no arg: auto-discovers design-tokens.json,
#                                #   clean exit 0 if none found (no false fail)
#   ./verify.sh --help
#
# EXIT CODES
#   0  no failures (also: empty/clean target — nothing to check)
#   1  a real failure (bad JSON, missing role, color w/o hex, AA pair < 4.5:1)
#   2  bad usage
#
# Dependency-light: prefers python3 (stdlib only) for JSON + contrast math.
# If python3 is absent, JSON-dependent checks are SKIPPED, never failed.

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  printf 'This script requires bash (any version >= 3.2). Run: bash %s\n' "$0" >&2
  exit 2
fi

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; skip_count=0; warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; skip_count=$((skip_count + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- arg parse --------------------------------------------------------------
TOKENS=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -*) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
    *) TOKENS="$1"; shift ;;
  esac
done

# --- locate the tokens file (clean exit if none — no false failure) ---------
if [ -z "$TOKENS" ]; then
  # search common spots; pick the first match. Never fail when absent.
  for cand in \
    ./design-tokens.json \
    ./tokens/design-tokens.json \
    ./02-DOCS/wiki/brand/design-tokens.json; do
    if [ -f "$cand" ]; then TOKENS="$cand"; break; fi
  done
  if [ -z "$TOKENS" ]; then
    found="$(find . -maxdepth 4 -name 'design-tokens.json' -type f 2>/dev/null | head -n1 || true)"
    [ -n "$found" ] && TOKENS="$found"
  fi
fi

if [ -z "$TOKENS" ]; then
  skip "no design-tokens.json found — nothing to verify (pass a path to check one)"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

if [ ! -f "$TOKENS" ]; then
  fail "tokens file not found: $TOKENS"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 1
fi

# --- the JSON + contrast checks (python3 stdlib) ----------------------------
if ! have python3; then
  skip "python3 not found — JSON/contrast checks skipped (install python3 to enable)"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# python prints lines prefixed OK:/FAIL:/WARN:/SKIP: which we route to the
# bash counters so the summary + exit code stay in one place.
REPORT="$(python3 - "$TOKENS" <<'PY'
import json, sys

path = sys.argv[1]
out = []

try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except json.JSONDecodeError as e:
    print(f"FAIL:tokens file does not parse as JSON: {e}")
    sys.exit(0)
except OSError as e:
    print(f"FAIL:cannot read tokens file: {e}")
    sys.exit(0)

print("OK:tokens file parses as JSON")

# --- walk: collect every color token (node with $type==color or $value w/ hex)
colors = []          # (dotted_path, hex_or_None)
role_names = set()   # leaf + group key names seen, lowercased

def walk(node, trail, inherited_type=None):
    if not isinstance(node, dict):
        return
    ntype = node.get("$type", inherited_type)
    if "$value" in node:
        if ntype == "color" or isinstance(node["$value"], dict):
            val = node["$value"]
            hexv = val.get("hex") if isinstance(val, dict) else None
            if isinstance(val, str) and val.startswith("#"):
                hexv = val
            if ntype == "color" or (isinstance(val, dict) and "colorSpace" in val):
                colors.append((".".join(trail), hexv))
        return
    for k, v in node.items():
        if k.startswith("$"):
            continue
        role_names.add(k.lower())
        walk(v, trail + [k], ntype)

walk(data.get("color", {}), ["color"], None)

# --- required roles present
for role in ("primary", "neutral", "accent"):
    if role in role_names:
        print(f"OK:required color role present: {role}")
    else:
        print(f"FAIL:required color role missing: {role}")

# --- every color token carries a hex
if not colors:
    print("WARN:no color tokens found under 'color'")
else:
    missing = [p for p, h in colors if not h]
    if missing:
        for p in missing:
            print(f"FAIL:color token has no hex value: {p}")
    else:
        print(f"OK:all {len(colors)} color tokens carry a hex value")

# --- WCAG 2 contrast on documented pairs
def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

def luminance(hexstr):
    h = hexstr.lstrip("#")
    if len(h) == 3:
        h = "".join(ch * 2 for ch in h)
    if len(h) != 6:
        return None
    try:
        r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    except ValueError:
        return None
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

def ratio(fg, bg):
    lf, lb = luminance(fg), luminance(bg)
    if lf is None or lb is None:
        return None
    hi, lo = max(lf, lb), min(lf, lb)
    return (hi + 0.05) / (lo + 0.05)

pairs = (data.get("$extensions", {}) or {}).get("com.risco.contrast", [])
if not pairs:
    print("SKIP:no documented text/background pairs ($extensions.com.risco.contrast) — contrast not checked")
else:
    for p in pairs:
        fg, bg = p.get("fg"), p.get("bg")
        use = p.get("use", "text")
        is_logo = bool(p.get("logo"))
        r = ratio(fg, bg) if fg and bg else None
        if r is None:
            print(f"WARN:could not compute contrast for pair {fg} on {bg} ({use})")
            continue
        if is_logo:
            print(f"SKIP:logo-exempt pair {fg} on {bg} ({use}): {r:.2f}:1 (WCAG 1.4.3 logo exemption)")
        elif r < 4.5:
            print(f"FAIL:contrast {r:.2f}:1 < 4.5:1 AA — {fg} on {bg} ({use})")
        else:
            print(f"OK:contrast {r:.2f}:1 >= 4.5:1 AA — {fg} on {bg} ({use})")
PY
)"

while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    OK:*)   ok   "${line#OK:}" ;;
    FAIL:*) fail "${line#FAIL:}" ;;
    WARN:*) warn "${line#WARN:}" ;;
    SKIP:*) skip "${line#SKIP:}" ;;
    *)      printf '%s\n' "$line" ;;
  esac
done <<EOF
$REPORT
EOF

printf '\nverified: %s\n' "$TOKENS"
printf 'ok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

[ "$fail_count" -gt 0 ] && exit 1
exit 0
