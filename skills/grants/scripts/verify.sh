#!/usr/bin/env bash
#
# verify.sh — structural guardrail for a `grants` application draft.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free checks over ONE application file you point it at:
#     1. Output-as-outcome leak: output verbs (held, conducted, produced,
#        delivered, trained, "number of", "workshops held") appearing inside an
#        OUTCOMES / RESULTS block -> warn.
#     2. SMART gap: lines under an OBJECTIVES heading that lack BOTH a number and
#        a date/timeframe token (month, by 20xx, quarter, %, weeks) -> warn.
#     3. Indirect-rate breach: an indirect/overhead line whose percentage > 15
#        when the file does not declare a "negotiated rate" -> warn.
#     4. Rubric coverage: each criterion passed via --criteria must have a
#        matching heading in the file -> FAIL if any is missing.
#     5. Page-limit hint: with --max-pages N, warn if the draft's word count
#        roughly exceeds N pages (~500 words/page).
#
#   Warnings never fail the run. The ONLY hard failure is a missing rubric
#   criterion (#4). A clean OR empty file exits 0.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh app.md                                   # warnings only
#   ./verify.sh app.md --criteria "Excellence,Impact,Implementation"
#   ./verify.sh app.md --max-pages 40
#
# EXIT CODES
#   0  clean, or warnings only, or empty/missing-content file
#   1  a missing rubric criterion (hard failure)
#   2  bad usage (no file given, or file does not exist)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

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

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
CRITERIA=""
MAX_PAGES=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --criteria) CRITERIA="${2:-}"; shift 2 ;;
    --max-pages) MAX_PAGES="${2:-}"; shift 2 ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

if [ -z "$FILE" ]; then
  printf '%sno application file given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  ok "empty file — nothing to check"
  exit 0
fi

# --- 1. Output-as-outcome leak (only inside an OUTCOMES/RESULTS block) -------
# Extract lines from an OUTCOMES|RESULTS heading until the next heading.
OUTCOME_BLOCK="$(awk '
  /^#{1,6}[[:space:]].*([Oo]utcome|OUTCOME|[Rr]esult|RESULT)/ {inblk=1; next}
  /^#{1,6}[[:space:]]/ {inblk=0}
  inblk {print}
' "$FILE" 2>/dev/null || true)"

if [ -n "$OUTCOME_BLOCK" ]; then
  if printf '%s\n' "$OUTCOME_BLOCK" | grep -Eiq '\b(held|conducted|produced|delivered|trained|number of|workshops held|sessions held)\b'; then
    warn "output verb (held/conducted/produced/delivered/trained/number of) found inside an OUTCOMES block — outcomes describe a changed state, not an activity"
  else
    ok "outcomes block reads as outcomes, not outputs"
  fi
else
  warn "no OUTCOMES/RESULTS heading found — reviewers score outcomes; add one"
fi

# --- 2. SMART gap (objectives need a number AND a date/timeframe) ------------
OBJ_BLOCK="$(awk '
  /^#{1,6}[[:space:]].*([Oo]bjective|OBJECTIVE)/ {inblk=1; next}
  /^#{1,6}[[:space:]]/ {inblk=0}
  inblk {print}
' "$FILE" 2>/dev/null || true)"

if [ -n "$OBJ_BLOCK" ]; then
  smart_gap=0
  # Inspect bullet/numbered objective lines only.
  while IFS= read -r line; do
    case "$line" in
      [-*]\ *|[0-9]*.\ *|[0-9]*\)\ *)
        has_num=0; has_time=0
        printf '%s' "$line" | grep -Eq '[0-9]' && has_num=1
        printf '%s' "$line" | grep -Eiq '(month|quarter|week|year|by[[:space:]]+20[0-9][0-9]|%|days)' && has_time=1
        if [ "$has_num" -eq 0 ] || [ "$has_time" -eq 0 ]; then
          smart_gap=$((smart_gap + 1))
        fi
        ;;
    esac
  done <<EOF
$OBJ_BLOCK
EOF
  if [ "$smart_gap" -gt 0 ]; then
    warn "$smart_gap objective line(s) missing a numeric target and/or a date/timeframe — make them SMART"
  else
    ok "objectives carry a target and a timeframe"
  fi
else
  warn "no OBJECTIVES heading found — add SMART objectives"
fi

# --- 3. Indirect-rate breach (>15% with no negotiated rate declared) --------
NEGOTIATED=0
grep -Eiq 'negotiated[[:space:]-]*rate' "$FILE" && NEGOTIATED=1
if [ "$NEGOTIATED" -eq 0 ]; then
  # Find percentages on lines mentioning indirect/overhead/F&A/de minimis.
  breach=0
  while IFS= read -r pct; do
    [ -z "$pct" ] && continue
    # strip a trailing % and any decimals -> integer compare
    intpct="${pct%%.*}"
    case "$intpct" in
      ''|*[!0-9]*) continue ;;
    esac
    if [ "$intpct" -gt 15 ]; then breach=1; fi
  done <<EOF
$(grep -Ei '(indirect|overhead|F&A|de[[:space:]]*minimis)' "$FILE" 2>/dev/null \
   | grep -Eo '[0-9]+(\.[0-9]+)?[[:space:]]*%' | grep -Eo '[0-9]+(\.[0-9]+)?')
EOF
  if [ "$breach" -eq 1 ]; then
    warn "an indirect/overhead line exceeds 15% with no 'negotiated rate' declared — de minimis ceiling is 15% of MTDC"
  else
    ok "indirect rate within the 15% de minimis (or none present)"
  fi
else
  ok "negotiated indirect rate declared — 15% de minimis ceiling does not apply"
fi

# --- 4. Rubric coverage (hard failure on a missing criterion) ---------------
if [ -n "$CRITERIA" ]; then
  OLDIFS="$IFS"; IFS=','
  for crit in $CRITERIA; do
    IFS="$OLDIFS"
    # trim surrounding spaces
    c="$(printf '%s' "$crit" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$c" ] && continue
    if grep -Eiq "^#{1,6}[[:space:]].*${c}" "$FILE"; then
      ok "rubric criterion covered by a heading: $c"
    else
      fail "rubric criterion has no matching heading: $c"
    fi
    IFS=','
  done
  IFS="$OLDIFS"
fi

# --- 5. Page-limit hint -----------------------------------------------------
if [ -n "$MAX_PAGES" ]; then
  case "$MAX_PAGES" in
    ''|*[!0-9]*) warn "--max-pages must be an integer; skipping page-limit check" ;;
    *)
      words="$(wc -w < "$FILE" | tr -d '[:space:]')"
      est_pages=$(( (words + 499) / 500 ))
      if [ "$est_pages" -gt "$MAX_PAGES" ]; then
        warn "draft ~${est_pages} pages (${words} words @ ~500/pg) exceeds --max-pages ${MAX_PAGES}; content beyond the limit is disregarded"
      else
        ok "draft ~${est_pages} pages within the ${MAX_PAGES}-page limit"
      fi
      ;;
  esac
fi

echo
if [ "$fail_count" -gt 0 ]; then
  printf '%s%d failure(s), %d warning(s)%s\n' "$RED" "$fail_count" "$warn_count" "$NC"
  exit 1
fi
printf '%s%d warning(s), no failures%s\n' "$YELLOW" "$warn_count" "$NC"
exit 0
