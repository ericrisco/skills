#!/usr/bin/env bash
#
# verify.sh — structural linter for podcast publish artifacts.
#
# WHAT IT DOES (read-only; never edits or writes anything)
#   Static, network-free checks over the artifacts you point it at. Give it ONE
#   file or a DIRECTORY (it will pick up *.json / *.xml|*.rss / *.vtt inside).
#     chapters.json   -> parses; has `version` + `chapters[]`; each chapter has a
#                        numeric `startTime`; startTimes are monotonically
#                        non-decreasing.                                  (FAIL)
#     RSS feed/<item> -> every <enclosure> has url + length + type attributes;
#                        an <itunes:duration> is present; every
#                        <podcast:transcript> carries a `type` attribute; any
#                        <itunes:image>/<podcast:chapters> referenced artwork
#                        filename hinting a size >=1400 (best-effort).      (FAIL)
#     transcript.vtt  -> first non-empty line is `WEBVTT`.                  (FAIL)
#
#   Artifacts that are ABSENT are skipped (pass) so partial-phase work is not
#   penalized. A clean OR empty target exits 0 — never a false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh ./episode-12/                 # lint every artifact in a dir
#   ./verify.sh ep12.chapters.json            # lint one file
#   ./verify.sh feed.xml ep12.vtt             # lint several files
#
# EXIT CODES
#   0  all present artifacts pass, or nothing to check (empty/clean target)
#   1  a hard failure in at least one artifact
#   2  bad usage (no target, target missing, or python3 unavailable)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

TARGETS=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) TARGETS="$TARGETS
$1"; shift ;;
  esac
done

if [ -z "$TARGETS" ]; then
  printf '%sno target given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '%spython3 not found — required to parse artifacts%s\n' "$RED" "$NC" >&2; exit 2
fi

# Expand targets: a directory contributes its json/xml/rss/vtt files; a file is
# itself. Missing paths are a usage error.
FILES=""
while IFS= read -r t; do
  [ -z "$t" ] && continue
  if [ -d "$t" ]; then
    for f in "$t"/*.json "$t"/*.xml "$t"/*.rss "$t"/*.vtt; do
      [ -e "$f" ] && FILES="$FILES
$f"
    done
  elif [ -f "$t" ]; then
    FILES="$FILES
$t"
  else
    printf '%starget not found: %s%s\n' "$RED" "$t" "$NC" >&2; exit 2
  fi
done <<EOF
$TARGETS
EOF

# Nothing matched (e.g. empty dir): not a failure.
if [ -z "$(printf '%s' "$FILES" | tr -d '[:space:]')" ]; then
  printf '%s[ ok ]%s no podcast artifacts found — nothing to check\n' "$GREEN" "$NC"
  exit 0
fi

printf 'podcast verify\n\n'

# Stock macOS bash 3.2 mis-scans $( ... ) when the embedded heredoc contains
# apostrophes, so we write the linter to a temp file and run it normally.
PY_SCRIPT="$(mktemp -t podcast_verify.XXXXXX)"
trap 'rm -f "$PY_SCRIPT"' EXIT
cat > "$PY_SCRIPT" <<'PY'
import json, os, re, sys

files = [l for l in os.environ.get("FILES", "").splitlines() if l.strip()]
# de-dup, keep order
seen = set(); ordered = []
for f in files:
    if f not in seen:
        seen.add(f); ordered.append(f)

lines = []
hard = 0
def ok(m):  lines.append("OK:" + m)
def warn(m):lines.append("WARN:" + m)
def fail(m):
    global hard
    lines.append("FAIL:" + m); hard += 1

def looks_chapters(text):
    try:
        d = json.loads(text)
    except Exception:
        return False
    return isinstance(d, dict) and "chapters" in d

def check_chapters(path, text):
    try:
        d = json.loads(text)
    except Exception as e:
        fail("%s: not valid JSON: %s" % (path, e)); return
    if "version" not in d:
        fail("%s: missing `version`" % path)
    ch = d.get("chapters")
    if not isinstance(ch, list):
        fail("%s: `chapters` must be an array" % path); return
    if not ch:
        ok("%s: parses, empty chapters[] (nothing to order)" % path); return
    last = None; bad = False
    for i, c in enumerate(ch):
        st = c.get("startTime") if isinstance(c, dict) else None
        if not isinstance(st, (int, float)):
            fail("%s: chapter %d has non-numeric startTime (%r)" % (path, i, st)); bad = True; continue
        if last is not None and st < last:
            fail("%s: chapter %d startTime %s < previous %s (not monotonic)" % (path, i, st, last)); bad = True
        last = st
    if not bad:
        ok("%s: %d chapters, version present, startTimes monotonic" % (path, len(ch)))

def check_feed(path, text):
    encs = re.findall(r"<enclosure\b[^>]*>", text, re.I)
    if encs:
        for e in encs:
            for attr in ("url", "length", "type"):
                if not re.search(r'\b%s\s*=' % attr, e, re.I):
                    fail("%s: <enclosure> missing %s attribute" % (path, attr))
        if not [1 for e in encs if all(re.search(r'\b%s\s*='%a,e,re.I) for a in ("url","length","type"))]:
            pass
        else:
            ok("%s: <enclosure> has url+length+type" % path)
    if re.search(r"<item\b", text, re.I):
        if not re.search(r"<itunes:duration\b", text, re.I):
            fail("%s: <item> present but no <itunes:duration>" % path)
        if not re.search(r"<guid\b", text, re.I):
            fail("%s: <item> present but no <guid>" % path)
    # transcript tags must carry type=
    for tr in re.findall(r"<podcast:transcript\b[^>]*>", text, re.I):
        if not re.search(r'\btype\s*=', tr, re.I):
            fail("%s: <podcast:transcript> missing required type attribute" % path)
        else:
            ok("%s: <podcast:transcript> carries type=" % path)
    # best-effort artwork size hint
    for img in re.findall(r'href\s*=\s*["\']([^"\']+)["\']', text, re.I):
        m = re.search(r'(\d{3,4})x(\d{3,4})', img)
        if m:
            w = int(m.group(1))
            if w < 1400:
                warn("%s: artwork '%s' hints %dpx wide, below the 1400px floor" % (path, os.path.basename(img), w))

def check_vtt(path, text):
    for ln in text.splitlines():
        if ln.strip() == "":
            continue
        if ln.strip().startswith("WEBVTT"):
            ok("%s: starts with WEBVTT" % path)
        else:
            fail("%s: transcript does not start with WEBVTT (first line: %r)" % (path, ln.strip()[:40]))
        return
    warn("%s: empty .vtt" % path)

checked = 0
for path in ordered:
    if not os.path.isfile(path):
        continue
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except Exception as e:
        fail("%s: cannot read: %s" % (path, e)); continue
    if not text.strip():
        ok("%s: empty file — skipped" % path); continue

    low = path.lower()
    if low.endswith(".json"):
        if looks_chapters(text):
            check_chapters(path, text); checked += 1
        else:
            ok("%s: JSON, not a chapters file — skipped" % path)
    elif low.endswith(".xml") or low.endswith(".rss"):
        check_feed(path, text); checked += 1
    elif low.endswith(".vtt"):
        check_vtt(path, text); checked += 1
    else:
        # unknown extension passed directly — sniff content
        stripped = text.lstrip()
        if stripped.startswith("WEBVTT"):
            check_vtt(path, text); checked += 1
        elif stripped.startswith("{") and looks_chapters(text):
            check_chapters(path, text); checked += 1
        elif re.search(r"<rss\b|<item\b|<enclosure\b", text, re.I):
            check_feed(path, text); checked += 1
        else:
            ok("%s: unrecognized artifact — skipped" % path)

if checked == 0 and hard == 0:
    print("OK:no recognized podcast artifacts — nothing to check")
print("\n".join(lines))
sys.exit(1 if hard > 0 else 0)
PY

PY_OUT="$(FILES="$FILES" python3 "$PY_SCRIPT")" && PY_RC=0 || PY_RC=$?

fail_count=0; warn_count=0
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
  printf '%s%d warning(s), 0 hard failures%s\n' "$YELLOW" "$warn_count" "$NC"
  exit 0
fi
printf '%sall checks passed%s\n' "$GREEN" "$NC"
exit 0
