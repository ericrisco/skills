#!/usr/bin/env bash
#
# verify.sh — structural guardrail for an emitted short-form package file.
#
# WHAT IT DOES (read-only; never edits, writes, or hits the network)
#   Static lint over ONE package draft you point it at. The draft is plain text /
#   markdown with labeled sections. Recognized labels (any case, English or ES/CA),
#   one per line; list items are lines starting with "-". Recognized labels:
#     Hook:        hook / gancho / ganxo            (one variant per "- " line)
#     On-screen:   on-screen text / texto en pantalla / text en pantalla / overlay
#     Caption:     caption / pie de foto / descripcion / descripció / peu de foto
#     Hashtags:    hashtags
#     Cover:       cover / portada
#     Feedback:    feedback
#
#   Checks (only present-but-broken sections FAIL; empty file is clean):
#     1. Hook: >= 2 variants                         -> FAIL if < 2.
#     2. On-screen text: present, each line <= 7 words -> FAIL per over-long line.
#     3. Caption: first non-empty line <= 150 chars
#        and does NOT open with a banned teaser
#        ("wait for it", "in this video",
#         "you won't believe", "watch till the end") -> FAIL.
#     4. Hashtags: count between 3 and 5 inclusive    -> FAIL if <3 or >5.
#     5. Cover: a frame + an overlay line present     -> FAIL if missing.
#     6. Feedback: block has intro_retention,
#        sends_per_reach, saves                       -> FAIL per missing key;
#        warn if "likes" is logged as a metric.
#
#   A clean OR empty/whitespace-only file exits 0 — never a false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh package.md            # run all checks
#   ./verify.sh package.md --strict   # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/missing-content file
#   1  a hard failure — or any warning under --strict
#   2  bad usage (no file given, or file does not exist)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays, no bc.

set -u

FAIL=0
WARN=0
STRICT=0
FILE=""

for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    -*) echo "usage: verify.sh <package-file> [--strict]" >&2; exit 2 ;;
    *) FILE="$arg" ;;
  esac
done

if [ -z "$FILE" ]; then
  echo "usage: verify.sh <package-file> [--strict]" >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  echo "verify.sh: file not found: $FILE" >&2
  exit 2
fi

fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { echo "WARN: $1"; WARN=$((WARN + 1)); }

# Empty / whitespace-only file is clean — never a false failure.
if ! grep -q '[^[:space:]]' "$FILE"; then
  echo "OK: empty file, nothing to lint."
  exit 0
fi

# --- helpers ---------------------------------------------------------------
# Lower-case a string (bash 3.2 has no ${x,,}).
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Extract the list-item lines ("- ...") belonging to a section, by label regex.
# Section ends at the next non-indented label line or EOF.
section_items() { # $1 = label-regex
  awk -v re="$1" '
    BEGIN { inb = 0 }
    {
      line = $0
      low = tolower(line)
      # A label line: starts at column 0 (no indent), letters then a colon.
      if (line ~ /^[^[:space:]].*:/) {
        inb = (low ~ re) ? 1 : 0
        next
      }
      if (inb && line ~ /^[[:space:]]*-[[:space:]]*/) {
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        if (line ~ /[^[:space:]]/) print line
      }
    }
  ' "$FILE"
}

# Raw body lines of a section (non-list, e.g. caption / cover / feedback).
section_body() { # $1 = label-regex
  awk -v re="$1" '
    BEGIN { inb = 0 }
    {
      line = $0
      low = tolower(line)
      if (line ~ /^[^[:space:]].*:/) {
        if (low ~ re) { inb = 1; next }
        inb = 0; next
      }
      if (inb && line ~ /[^[:space:]]/) print line
    }
  ' "$FILE"
}

# --- 1. Hook: >= 2 variants -----------------------------------------------
HOOK_RE='^(hook|gancho|ganxo) *:'
hook_count=$(section_items "$HOOK_RE" | grep -c '.')
if [ "$hook_count" -ge 1 ]; then
  if [ "$hook_count" -lt 2 ]; then
    fail "Hook: ship a SET — found $hook_count variant(s), need >= 2."
  fi
else
  warn "Hook section not found (label 'Hook:'); skipping hook check."
fi

# --- 2. On-screen text: present, each <= 7 words --------------------------
OS_RE='^(on-screen text|on-screen|texto en pantalla|text en pantalla|overlay) *:'
os_items=$(section_items "$OS_RE")
if [ -n "$os_items" ]; then
  printf '%s\n' "$os_items" | while IFS= read -r ln; do
    [ -z "$ln" ] && continue
    w=$(printf '%s\n' "$ln" | wc -w | tr -d ' ')
    if [ "$w" -gt 7 ]; then
      echo "FAIL: On-screen text over 7 words ($w): $ln"
    fi
  done
  # re-count failures from the subshell via a marker grep
  os_fails=$(printf '%s\n' "$os_items" | awk '{ if (NF>7) c++ } END { print c+0 }')
  FAIL=$((FAIL + os_fails))
else
  warn "On-screen text section not found; skipping word-count check."
fi

# --- 3. Caption: first line <= 150 chars, no banned teaser ----------------
CAP_RE='^(caption|pie de foto|peu de foto|descripcion|descripció) *:'
cap_first=$(section_body "$CAP_RE" | grep -m1 '[^[:space:]]')
if [ -n "$cap_first" ]; then
  cap_trim=$(printf '%s' "$cap_first" | sed 's/^[[:space:]]*//')
  len=$(printf '%s' "$cap_trim" | wc -c | tr -d ' ')
  if [ "$len" -gt 150 ]; then
    fail "Caption first line is $len chars (> 150 visible budget)."
  fi
  cap_lc=$(lc "$cap_trim")
  for bad in "wait for it" "in this video" "you won't believe" "watch till the end"; do
    case "$cap_lc" in
      "$bad"*) fail "Caption opens with banned teaser: \"$bad\". Lead with the keyword." ;;
    esac
  done
else
  warn "Caption section not found; skipping caption checks."
fi

# --- 4. Hashtags: 3-5 inclusive -------------------------------------------
HT_RE='^hashtags *:'
ht_body=$(section_body "$HT_RE")
if [ -n "$ht_body" ]; then
  ht_count=$(printf '%s\n' "$ht_body" | grep -o '#[[:alnum:]_]\{1,\}' | grep -c '.')
  if [ "$ht_count" -lt 3 ] || [ "$ht_count" -gt 5 ]; then
    fail "Hashtags: found $ht_count — use 3-5 (Instagram hard-caps at 5)."
  fi
else
  warn "Hashtags section not found; skipping count check."
fi

# --- 5. Cover: frame + overlay present ------------------------------------
COV_RE='^(cover|portada) *:'
cov_body=$(section_body "$COV_RE")
if [ -n "$cov_body" ]; then
  cov_lc=$(lc "$cov_body")
  printf '%s' "$cov_lc" | grep -q 'frame' || fail "Cover: no 'frame:' specified."
  printf '%s' "$cov_lc" | grep -q 'overlay' || fail "Cover: no 'overlay:' line specified."
else
  warn "Cover section not found; skipping cover check."
fi

# --- 6. Feedback block: required keys -------------------------------------
FB_RE='^feedback *:'
fb_body=$(section_body "$FB_RE")
if [ -n "$fb_body" ]; then
  fb_lc=$(lc "$fb_body")
  for key in intro_retention sends_per_reach saves; do
    printf '%s' "$fb_lc" | grep -q "$key" || fail "Feedback block missing key: $key."
  done
  if printf '%s' "$fb_lc" | grep -Eq '^[[:space:]]*likes[[:space:]]*:'; then
    warn "Feedback logs 'likes' as a metric — track intro_retention/sends/saves instead."
  fi
else
  warn "Feedback section not found; skipping key check."
fi

# --- verdict ---------------------------------------------------------------
echo "----"
echo "checks done: $FAIL failure(s), $WARN warning(s)."
if [ "$FAIL" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$WARN" -gt 0 ]; then
  echo "strict mode: warnings treated as failures."
  exit 1
fi
exit 0
