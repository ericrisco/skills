#!/usr/bin/env bash
#
# verify.sh — structural guardrail for an emitted YouTube package file.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free checks over ONE package draft you point it at. The draft
#   is plain text / markdown with labeled sections. Recognized labels (any case,
#   English or ES/CA), one per line, the content following on the same or next
#   lines until the next label:
#     Titles:      title / titulo / títol / titulos / títols   (one title per line)
#     Description: description / descripcion / descripció
#     Tags:        tags / etiquetas / etiquetes
#     Hashtags:    hashtags
#     Chapters:    chapters / capitulos / capítols           (one "MM:SS Name" per line)
#
#   Checks:
#     1. ≥ 2 titles present (the A/B set rule)             -> FAIL if < 2.
#     2. Every title ≤ 100 chars                           -> FAIL per over-long title.
#        Warn if a title opens with filler ("In this video"/"Welcome").
#     3. Description above-fold first line present and
#        ≤ 150 chars                                       -> FAIL if missing/over.
#     4. Chapters: ≥ 3 timestamps, first is 0:00/00:00,
#        ascending, each gap ≥ 10s                          -> FAIL with the broken rule.
#     5. Hashtags: count ≥ 1 and ≤ 15 (>15 = all stripped) -> FAIL if > 15; warn if 0.
#     6. Tags: ≥ 1 and the joined field ≤ 500 chars        -> FAIL if over budget.
#
#   A clean OR empty/whitespace-only file exits 0 — never a false failure.
#   Missing OPTIONAL sections warn; only present-but-broken sections fail.
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

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//'; }

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
  printf '%sno package file given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  ok "empty file — nothing to check"
  exit 0
fi

printf 'youtube-packaging verify — %s\n\n' "$FILE"

# --- section splitter ---------------------------------------------------------
# Emit the content lines that belong to a given section label. Reads the file,
# turns "on" at a matching label line, "off" at the next recognized label.
LABELS_RE='^[[:space:]]*(titles?|titulos?|títols?|titulo|títol|description|descripcion|descripció|tags|etiquetas|etiquetes|hashtags|chapters|capitulos|capítols)[[:space:]]*:'

section() {
  # $1 = alternation of label tokens for the section to capture (no anchors)
  awk -v want="$1" -v anylabel="$LABELS_RE" '
    BEGIN { wantre = "^[[:space:]]*(" want ")[[:space:]]*:" }
    {
      line = $0
      low  = tolower(line)
      if (low ~ anylabel) {
        # is this the label we want? (anchored: the whole token before the colon)
        active = (low ~ wantre) ? 1 : 0
        # if the label line carries inline content after the colon, keep it
        rest = line
        sub(/^[^:]*:[[:space:]]*/, "", rest)
        if (active && rest ~ /[^[:space:]]/) print rest
        next
      }
      if (active && line ~ /[^[:space:]]/) print line
    }
  ' "$FILE"
}

trim() { sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

# --- 1 + 2. titles ------------------------------------------------------------
TITLES="$(section 'titulos?|títols?|titles?|titulo|títol' | trim | grep -E '[^[:space:]]' || true)"
TITLE_COUNT=0
if [ -n "$TITLES" ]; then
  TITLE_COUNT="$(printf '%s\n' "$TITLES" | grep -c '[^[:space:]]' || true)"
fi

if [ "${TITLE_COUNT:-0}" -lt 2 ]; then
  fail "found ${TITLE_COUNT} title(s) — ship a SET of 2-3 titles for the A/B test, never one"
else
  ok "title set has ${TITLE_COUNT} titles (>= 2)"
fi

if [ -n "$TITLES" ]; then
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    tlen="$(printf '%s' "$t" | wc -m | tr -d '[:space:]')"
    if [ "${tlen:-0}" -gt 100 ]; then
      fail "title is ${tlen} chars (> 100 hard limit): ${t}"
    fi
    if printf '%s' "$t" | grep -Eiq '^[[:space:]]*(in this video|welcome to)'; then
      warn "title opens with filler — front-load the keyword + hook: ${t}"
    fi
  done <<EOF
$TITLES
EOF
fi

# --- 3. description above-fold ------------------------------------------------
DESC_FIRST="$(section 'description|descripcion|descripció' | grep -E '[^[:space:]]' | head -1 | trim || true)"
if [ -z "$DESC_FIRST" ]; then
  warn "no description section found — the above-fold line is the only part most viewers see"
else
  dlen="$(printf '%s' "$DESC_FIRST" | wc -m | tr -d '[:space:]')"
  if [ "${dlen:-0}" -gt 150 ]; then
    fail "description above-fold line is ${dlen} chars (> ~150) — only ~125 show before 'Show more'"
  else
    ok "description above-fold line present (${dlen} chars)"
  fi
fi

# --- 4. chapters --------------------------------------------------------------
CHAPTERS="$(section 'chapters|capitulos|capítols')"
# collect timestamps as total seconds, in order
STAMP_SECONDS=""
STAMP_COUNT=0
FIRST_STAMP=""
if [ -n "$CHAPTERS" ]; then
  while IFS= read -r line; do
    ts="$(printf '%s' "$line" | grep -oE '([0-9]+:)?[0-9]{1,2}:[0-9]{2}' | head -1 || true)"
    [ -n "$ts" ] || continue
    [ -z "$FIRST_STAMP" ] && FIRST_STAMP="$ts"
    # parse H:MM:SS or M:SS / MM:SS into seconds
    h=0; m=0; s=0
    case "$ts" in
      *:*:*) h="${ts%%:*}"; rest="${ts#*:}"; m="${rest%%:*}"; s="${rest#*:}" ;;
      *:*)   m="${ts%%:*}"; s="${ts#*:}" ;;
    esac
    total=$(( 10#$h * 3600 + 10#$m * 60 + 10#$s ))
    STAMP_SECONDS="${STAMP_SECONDS}${total} "
    STAMP_COUNT=$((STAMP_COUNT + 1))
  done <<EOF
$CHAPTERS
EOF
fi

if [ "$STAMP_COUNT" -eq 0 ]; then
  warn "no chapters section found — chapters lift watch time and add search jump-to targets"
else
  chap_fail=0
  if [ "$STAMP_COUNT" -lt 3 ]; then
    fail "chapters: only ${STAMP_COUNT} timestamp(s) — YouTube needs >= 3 or it ignores ALL chapters"
    chap_fail=1
  fi
  case "$FIRST_STAMP" in
    0:00|00:00|0:0|00:0|0:00:00) : ;;
    *) fail "chapters: first timestamp is '${FIRST_STAMP}', not 00:00 — without 0:00 YouTube ignores ALL chapters"; chap_fail=1 ;;
  esac
  # ascending + >=10s gaps
  prev=""
  for sec in $STAMP_SECONDS; do
    if [ -n "$prev" ]; then
      if [ "$sec" -le "$prev" ]; then
        fail "chapters: timestamps not strictly ascending (${prev}s then ${sec}s)"
        chap_fail=1
      elif [ $(( sec - prev )) -lt 10 ]; then
        fail "chapters: a chapter is shorter than 10s (${prev}s -> ${sec}s)"
        chap_fail=1
      fi
    fi
    prev="$sec"
  done
  [ "$chap_fail" -eq 0 ] && ok "chapters: ${STAMP_COUNT} timestamps, first 00:00, ascending, gaps >= 10s"
fi

# --- 5. hashtags --------------------------------------------------------------
HASHTAG_BLOCK="$(section 'hashtags' || true)"
# count '#word' tokens across the hashtag section (fallback: whole file's # tokens)
if [ -z "$(printf '%s' "$HASHTAG_BLOCK" | grep -E '[^[:space:]]' || true)" ]; then
  HASHTAG_BLOCK="$(grep -oE '#[A-Za-z0-9_]+' "$FILE" || true)"
fi
HASHTAG_COUNT="$(printf '%s\n' "$HASHTAG_BLOCK" | grep -oE '#[A-Za-z0-9_]+' | grep -c '#' || true)"
if [ "${HASHTAG_COUNT:-0}" -eq 0 ]; then
  warn "no hashtags found — 3-5 relevant hashtags help discovery; the first 3 show above the title"
elif [ "${HASHTAG_COUNT:-0}" -gt 15 ]; then
  fail "found ${HASHTAG_COUNT} hashtags (> 15) — YouTube strips ALL hashtags over 15"
else
  ok "hashtags within limit (${HASHTAG_COUNT}, 1-15)"
fi

# --- 6. tags ------------------------------------------------------------------
TAGS="$(section 'tags|etiquetas|etiquetes' | grep -E '[^[:space:]]' | trim || true)"
if [ -z "$TAGS" ]; then
  warn "no tags section found — add 5-8 tags, first = exact target phrase"
else
  # join into one field (comma or newline separated) and measure char budget
  TAGS_JOINED="$(printf '%s' "$TAGS" | tr '\n' ',')"
  TAGLEN="$(printf '%s' "$TAGS_JOINED" | wc -m | tr -d '[:space:]')"
  if [ "${TAGLEN:-0}" -gt 500 ]; then
    fail "tags field is ${TAGLEN} chars (> ~500 budget) — trim the tag list"
  else
    ok "tags present, field ${TAGLEN} chars (<= ~500)"
  fi
fi

# --- summary ------------------------------------------------------------------
printf '\n'
if [ "$fail_count" -gt 0 ]; then
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
