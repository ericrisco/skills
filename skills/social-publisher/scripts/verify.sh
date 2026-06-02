#!/usr/bin/env bash
#
# verify.sh — structural linter for a social-publisher content calendar.
#
# WHAT IT DOES (read-only; never edits or writes the calendar)
#   Static, network-free checks over ONE calendar file you point it at — a CSV or
#   a JSON array of post rows (see references/calendar-schema.md):
#     1. Required columns/keys present: date, time, platform, format, body, status
#        -> FAIL if any is missing.
#     2. Per-platform char cap: each row's `body` longer than its platform cap
#        (x 280, linkedin 3000, instagram 2200, threads 500, bluesky 300,
#        tiktok 2200, facebook 63206, youtube 5000) -> FAIL.
#     3. `status` is one of draft|scheduled|posted -> FAIL otherwise.
#     4. A `scheduled` row whose date+time is unparseable or in the PAST -> FAIL.
#     5. Two rows byte-identical in `body` across DIFFERENT platforms (the
#        copy-paste anti-pattern) -> WARN.
#
#   Parsing is delegated to python3 (stdlib only: csv, json, datetime). Hard
#   failures (1-4) exit 1; the identical-body check (5) only warns. A clean OR
#   empty calendar exits 0 — never a false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh calendar.csv
#   ./verify.sh calendar.json
#   ./verify.sh calendar.csv --strict     # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/contentless file
#   1  a hard failure (missing column, over-cap body, bad status/datetime)
#      — or any warning under --strict
#   2  bad usage (no file, file missing, or python3 unavailable)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays, no bc.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

usage() { sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --strict) STRICT=1; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

if [ -z "$FILE" ]; then
  printf '%sno calendar file given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '%spython3 not found — required to parse the calendar%s\n' "$RED" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  printf '%s[ ok ]%s empty file — nothing to check\n' "$GREEN" "$NC"
  exit 0
fi

printf 'social-publisher verify — %s\n\n' "$FILE"

# All parsing + checking happens in python3 (stdlib only). It prints lines tagged
# OK:/WARN:/FAIL: and exits 0 (no hard failures) or 1 (>=1 hard failure). The
# identical-body check emits WARN only. STRICT is applied here in bash.
PY_OUT="$(STRICT="$STRICT" python3 - "$FILE" <<'PY'
import csv, json, os, sys
from datetime import datetime

path = sys.argv[1]
strict = os.environ.get("STRICT", "0") == "1"

CAPS = {
    "x": 280, "twitter": 280,
    "linkedin": 3000,
    "instagram": 2200, "ig": 2200,
    "threads": 500,
    "bluesky": 300,
    "tiktok": 2200,
    "facebook": 63206, "fb": 63206,
    "youtube": 5000,
}
REQUIRED = ["date", "time", "platform", "format", "body", "status"]
STATUSES = {"draft", "scheduled", "posted"}

lines = []
hard = 0
warn = 0

def ok(m):   lines.append("OK:" + m)
def warn_(m):
    global warn
    lines.append("WARN:" + m); warn += 1
def fail(m):
    global hard
    lines.append("FAIL:" + m); hard += 1

# --- load rows as a list of dicts ---------------------------------------------
rows = []
load_err = None
try:
    with open(path, "r", encoding="utf-8") as fh:
        head = fh.read(1)
        fh.seek(0)
        text = fh.read()
    stripped = text.lstrip()
    if stripped.startswith("[") or stripped.startswith("{"):
        data = json.loads(text)
        if isinstance(data, dict):
            data = [data]
        rows = [dict(r) for r in data if isinstance(r, dict)]
    else:
        reader = csv.DictReader(text.splitlines())
        rows = [ {(k or "").strip(): v for k, v in r.items()} for r in reader ]
except Exception as e:
    load_err = str(e)

if load_err is not None:
    fail("could not parse file as CSV or JSON: %s" % load_err)
    print("\n".join(lines))
    sys.exit(1)

if not rows:
    print("OK:no rows — nothing to check")
    sys.exit(0)

# --- 1. required columns present ----------------------------------------------
present = set()
for r in rows:
    present.update(r.keys())
missing = [c for c in REQUIRED if c not in present]
if missing:
    fail("missing required column(s): %s" % ", ".join(missing))
else:
    ok("all required columns present (%s)" % ", ".join(REQUIRED))

# --- per-row checks -----------------------------------------------------------
bodies = {}  # body text -> set of platforms
for i, r in enumerate(rows, start=1):
    plat = (r.get("platform") or "").strip().lower()
    body = r.get("body")
    body = "" if body is None else str(body)
    status = (r.get("status") or "").strip().lower()

    # 2. char cap
    cap = CAPS.get(plat)
    if cap is None:
        if plat:
            warn_("row %d: unknown platform '%s' — no char cap checked" % (i, plat))
    elif len(body) > cap:
        fail("row %d (%s): body is %d chars, over the %d cap" % (i, plat, len(body), cap))

    # 3. status valid
    if status not in STATUSES:
        fail("row %d: status '%s' not one of draft|scheduled|posted" % (i, status or "<empty>"))

    # 4. scheduled rows need a parseable future datetime
    if status == "scheduled":
        d = (r.get("date") or "").strip()
        t = (r.get("time") or "").strip()
        dt = None
        for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%d %H:%M:%S"):
            try:
                dt = datetime.strptime((d + " " + t).strip(), fmt)
                break
            except ValueError:
                continue
        if dt is None:
            fail("row %d: scheduled but date/time '%s %s' is unparseable (want YYYY-MM-DD HH:MM)" % (i, d, t))
        elif dt <= datetime.now():
            fail("row %d: scheduled for %s %s which is not in the future" % (i, d, t))

    # 5. collect bodies for the identical-cross-post check
    key = body.strip()
    if key:
        bodies.setdefault(key, set()).add(plat or "<none>")

# --- 5. byte-identical body across different platforms ------------------------
dupes = [(b, plats) for b, plats in bodies.items() if len(plats) > 1]
if dupes:
    for b, plats in dupes:
        snippet = (b[:48] + "…") if len(b) > 48 else b
        warn_("identical body across %s — reshape per platform: \"%s\"" %
              (", ".join(sorted(plats)), snippet.replace("\n", " ")))
else:
    ok("no byte-identical bodies across platforms")

print("\n".join(lines))
sys.exit(1 if hard > 0 else 0)
PY
)" && PY_RC=0 || PY_RC=$?

# Render python's tagged output with colors and tally.
warn_count=0; fail_count=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    OK:*)   printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "${line#OK:}" ;;
    WARN:*) printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "${line#WARN:}"; warn_count=$((warn_count + 1)) ;;
    FAIL:*) printf '%s[fail]%s %s\n' "$RED"    "$NC" "${line#FAIL:}"; fail_count=$((fail_count + 1)) ;;
    *) printf '%s\n' "$line" ;;
  esac
done <<EOF
$PY_OUT
EOF

printf '\n'
if [ "$fail_count" -gt 0 ] || [ "$PY_RC" -ne 0 ]; then
  printf '%s%d hard failure(s), %d warning(s)%s\n' "$RED" "$fail_count" "$warn_count" "$NC"
  exit 1
fi
if [ "$warn_count" -gt 0 ]; then
  if [ "$STRICT" -eq 1 ]; then
    printf '%s%d warning(s) — failing under --strict%s\n' "$YELLOW" "$warn_count" "$NC"
    exit 1
  fi
  printf '%s%d warning(s), 0 hard failures%s\n' "$YELLOW" "$warn_count" "$NC"
  exit 0
fi
printf '%sall checks passed%s\n' "$GREEN" "$NC"
exit 0
