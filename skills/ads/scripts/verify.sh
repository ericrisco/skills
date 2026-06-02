#!/usr/bin/env bash
#
# verify.sh — paid-ads asset/plan linter for the `ads` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Lints the ad-asset/plan files the skill produces against hard platform limits
#   and ROAS sanity. Looks for simple, machine-checkable tags in *.md / *.txt /
#   *.yaml / *.yml / *.csv files. Every tag is optional — a file with none is
#   simply skipped, so this never false-fails on an unrelated repo.
#
#   Checks (a finding is a FAILURE only when copy overflows a hard limit or a
#   target ROAS sits below break-even — those are not judgement calls):
#     1. Headline length per surface tag:
#          [PMAX-HEADLINE]  / [SEARCH-HEADLINE]   limit 30 char
#          [DG-HEADLINE]    (Demand Gen)          limit 40 char
#        and description tags:
#          [DESCRIPTION] / [DG-DESCRIPTION] / [PMAX-DESCRIPTION]  limit 90 char
#     2. Headline COUNT per surface, per file:
#          PMax/Search <= 15 headlines, Demand Gen <= 5 headlines.
#     3. ROAS sanity: a line tagged
#          [ROAS] target=<x> margin=<0..1 or pct>
#        must have target >= break-even (1 / margin). Below break-even FAILS.
#     4. Advantage+ existing-customer cap: a file that mentions Advantage+
#        (case-insensitive) but has no [EXISTING-CUSTOMER-CAP] / "existing customer
#        cap" line gets a WARNING (acquisition risk), not a failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                 # scan ./ for ad asset/plan files
#   ./verify.sh --path plans    # scan a subdirectory
#   ./verify.sh --strict        # treat any warning as a failure (exit 1)
#
# EXIT CODES
#   0  clean, or warnings only without --strict (also: nothing to check)
#   1  a hard-limit overflow / below-break-even ROAS, or --strict with a warning
#   2  bad usage
#
# Runs on stock macOS bash 3.2 — no mapfile, no associative arrays.

set -euo pipefail

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

SCAN_PATH="."
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --path)    SCAN_PATH="${2:?--path needs a value}"; shift 2 ;;
    --strict)  STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
  esac
done

if [ ! -e "$SCAN_PATH" ]; then
  printf '%sPath not found: %s%s\n' "$RED" "$SCAN_PATH" "$NC"; exit 2
fi

have() { command -v "$1" >/dev/null 2>&1; }

# Collect candidate files (asset/plan-bearing extensions only).
TMPDIR_V="$(mktemp -d 2>/dev/null || printf '/tmp/ads-verify.%s' "$$")"
mkdir -p "$TMPDIR_V" 2>/dev/null || true
cleanup() { rm -rf "$TMPDIR_V" 2>/dev/null || true; }
trap cleanup EXIT
FILES="$TMPDIR_V/files"

find "$SCAN_PATH" -type f \
  \( -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' -o -name '*.csv' \) \
  2>/dev/null > "$FILES" || true

if [ ! -s "$FILES" ]; then
  skip "no asset/plan files (*.md *.txt *.yaml *.yml *.csv) under: $SCAN_PATH"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# visible length of the text after a tag on a line (strip the tag, trim, drop a
# leading "= " or ": ", strip surrounding quotes), printed as an integer.
text_after_tag() {
  # $1 = full line, $2 = tag token (e.g. [PMAX-HEADLINE])
  line="$1"; tag="$2"
  rest="${line#*"$tag"}"
  # drop a leading separator
  rest="${rest#:}"; rest="${rest#=}"
  # trim leading/trailing whitespace
  rest="$(printf '%s' "$rest" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  # strip one layer of surrounding quotes
  rest="${rest#\"}"; rest="${rest%\"}"
  rest="${rest#\'}"; rest="${rest%\'}"
  printf '%s' "$rest"
}

# --- per-tag length checks ---------------------------------------------------
# args: <tag> <limit> <human label>
check_len_tag() {
  tag="$1"; limit="$2"; label="$3"
  found=0; bad=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    while IFS= read -r ln; do
      case "$ln" in *"$tag"*) : ;; *) continue ;; esac
      found=1
      txt="$(text_after_tag "$ln" "$tag")"
      n=${#txt}
      if [ "$n" -gt "$limit" ]; then
        fail "$label over $limit char ($n): $f :: $txt"
        bad=1
      fi
    done < "$f"
  done < "$FILES"
  if [ "$found" -eq 0 ]; then
    skip "no $tag tags to check"
  elif [ "$bad" -eq 0 ]; then
    ok "$label: all within $limit char"
  fi
}

check_len_tag "[PMAX-HEADLINE]"     30 "PMax headline"
check_len_tag "[SEARCH-HEADLINE]"   30 "Search headline"
check_len_tag "[DG-HEADLINE]"       40 "Demand Gen headline"
check_len_tag "[DESCRIPTION]"       90 "Description"
check_len_tag "[PMAX-DESCRIPTION]"  90 "PMax description"
check_len_tag "[DG-DESCRIPTION]"    90 "Demand Gen description"

# --- headline COUNT per surface, per file ------------------------------------
# args: <tag> <max> <label>
check_count_tag() {
  tag="$1"; max="$2"; label="$3"
  any=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    c="$( { grep -F -c "$tag" "$f" 2>/dev/null || true; } | tr -dc '0-9')"
    [ -z "$c" ] && c=0
    [ "$c" -eq 0 ] && continue
    any=1
    if [ "$c" -gt "$max" ]; then
      fail "$label count $c exceeds max $max: $f"
    fi
  done < "$FILES"
  if [ "$any" -eq 0 ]; then skip "no $tag tags to count"; fi
}

check_count_tag "[PMAX-HEADLINE]"   15 "PMax headline"
check_count_tag "[SEARCH-HEADLINE]" 15 "Search headline"
check_count_tag "[DG-HEADLINE]"      5 "Demand Gen headline"

# --- ROAS sanity: target >= 1/margin ----------------------------------------
# Matches a line containing [ROAS] with target=<num> and margin=<num|pct>.
roas_any=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  while IFS= read -r ln; do
    case "$ln" in *"[ROAS]"*) : ;; *) continue ;; esac
    target="$(printf '%s' "$ln" | sed -n 's/.*[Tt]arget[[:space:]]*=[[:space:]]*\([0-9.]*\).*/\1/p')"
    margin_raw="$(printf '%s' "$ln" | sed -n 's/.*[Mm]argin[[:space:]]*=[[:space:]]*\([0-9.]*%\{0,1\}\).*/\1/p')"
    [ -z "$target" ] && continue
    [ -z "$margin_raw" ] && continue
    roas_any=1
    # normalise margin to a fraction 0..1
    case "$margin_raw" in
      *%) mfrac="$(awk -v m="${margin_raw%\%}" 'BEGIN{printf "%.6f", m/100}')" ;;
      *)  mfrac="$(awk -v m="$margin_raw" 'BEGIN{ if (m>1) printf "%.6f", m/100; else printf "%.6f", m }')" ;;
    esac
    # break-even = 1/mfrac; guard divide-by-zero
    verdict="$(awk -v t="$target" -v m="$mfrac" 'BEGIN{
      if (m<=0) { print "skip"; exit }
      be=1/m;
      if (t+0.0001 < be) printf "fail %.2f", be; else printf "ok %.2f", be;
    }')"
    case "$verdict" in
      fail*) be="${verdict#fail }"; fail "target ROAS $target below break-even $be (margin $margin_raw): $f" ;;
      ok*)   be="${verdict#ok }";   ok   "target ROAS $target >= break-even $be (margin $margin_raw)" ;;
      *)     warn "ROAS line has non-positive margin, cannot check: $f" ;;
    esac
  done < "$f"
done < "$FILES"
if [ "$roas_any" -eq 0 ]; then skip "no [ROAS] target/margin lines to check"; fi

# --- Advantage+ existing-customer cap presence -------------------------------
adv_any=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -iE 'advantage\+|advantage plus' "$f" >/dev/null 2>&1; then
    adv_any=1
    if grep -iE 'existing[- ]customer cap|\[EXISTING-CUSTOMER-CAP\]' "$f" >/dev/null 2>&1; then
      ok "Advantage+ plan declares an existing-customer cap: $f"
    else
      warn "Advantage+ plan with no existing-customer cap (acquisition will drift to retargeting): $f"
    fi
  fi
done < "$FILES"
if [ "$adv_any" -eq 0 ]; then skip "no Advantage+ plan to check for an existing-customer cap"; fi

printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
