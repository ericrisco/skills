#!/usr/bin/env bash
#
# verify.sh — structural lint for the `investor-materials` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Detects the artifact type from its section headers and asserts the required
#   structure, then flags defects. Structural lint ONLY — it does not judge
#   persuasion, metric selection, or framing (that is the capability eval's job).
#
#   Data-room index (dataroom*/data-room*/*index*): all 8 numbered categories
#     (01..08 Corporate..Tax) present.
#   One-pager / teaser (one-pager*/onepager*/teaser*): the 7 blocks
#     (problem, solution, traction, market, team, ask) + a numeric funding ask;
#     and for a TEASER, FAILS if confidential P&L / cap-table detail leaked in.
#   Investor update (*update*): the 6 sections (headline, highlights, a metrics
#     table, challenges, asks, runway/cash).
#   Global: flags placeholder tokens (TBD, XX, [amount], [company], [role]) and
#     vague asks ("let me know if you can help", "any help appreciated").
#
# HOW TO RUN (against YOUR generated artifact, not the skills repo)
#   ./verify.sh path/to/one-pager.md
#   ./verify.sh path/to/dataroom-index.md
#   ./verify.sh path/to/investor-update.md
#   ./verify.sh                          # scans ./ for matching *.md files
#
# EXIT CODES
#   0  clean, OR nothing to check (empty/clean target — never a false failure)
#   1  a structural defect was found
#   2  bad usage
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }
info() { printf '%s..%s %s\n'     "$YELLOW" "$NC" "$*"; }

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

# case-insensitive fixed-ish grep helper (returns 0 if pattern found in file)
has() { grep -iq "$1" "$2" 2>/dev/null; }

# --- collect targets --------------------------------------------------------
TARGETS=""
if [ $# -eq 0 ]; then
  # no arg: scan cwd for candidate markdown artifacts
  for f in ./*.md; do
    [ -e "$f" ] || continue
    case "$(basename "$f" | tr 'A-Z' 'a-z')" in
      *dataroom*|*data-room*|*one-pager*|*onepager*|*teaser*|*investor-update*|*update*|*index*)
        TARGETS="$TARGETS $f" ;;
    esac
  done
else
  case "$1" in -h|--help) usage;; esac
  for f in "$@"; do
    if [ ! -f "$f" ]; then fail "not a file: $f"; else TARGETS="$TARGETS $f"; fi
  done
fi

if [ -z "${TARGETS// /}" ]; then
  # Empty / clean target: nothing to lint is not a failure.
  ok "no investor-materials artifact found to check — nothing to lint"
  exit 0
fi

# --- global defect checks (applied to every target) -------------------------
check_global() {
  local f="$1"
  if grep -Eiq '\bTBD\b|\bXX+\b|\[amount\]|\[company\]|\[role\]|\[founder\]|FINAL_FINAL' "$f"; then
    fail "$f: placeholder token left in (TBD / XX / [amount] / [company] / [role])"
  fi
  if grep -Eiq 'let me know if you can help|any (help|introductions?) appreciated|help us grow|feedback welcome|spread the word' "$f"; then
    fail "$f: vague ask detected — name the intro/role/company instead"
  fi
}

# --- per-type structural checks ---------------------------------------------
check_dataroom() {
  local f="$1"; info "$f: data-room index"
  local n
  for n in 01 02 03 04 05 06 07 08; do
    if grep -Eq "(^|[^0-9])${n}[_ -]" "$f" || has "${n}_" "$f"; then :; else
      fail "$f: data-room category ${n} missing"
    fi
  done
  grep -Eiq 'cap.?table' "$f" || warn "$f: no cap table referenced (most-scrutinized doc)"
  [ "$fail_count" -eq 0 ] && ok "$f: 8 numbered categories present"
}

check_onepager() {
  local f="$1"; info "$f: one-pager / teaser"
  local b
  local missing=0
  for b in problem solution traction market team; do
    has "$b" "$f" || { fail "$f: one-pager block '$b' missing"; missing=1; }
  done
  grep -Eiq 'ask|raising|use of funds' "$f" || { fail "$f: no 'ask' block"; missing=1; }
  grep -Eq '\$[0-9]' "$f" || { fail "$f: ask has no numeric funding amount (e.g. \$1.5M)"; missing=1; }
  [ "$missing" -eq 0 ] && ok "$f: 7 blocks present with a numeric ask"
  # teaser must not leak confidential financials
  case "$(basename "$f" | tr 'A-Z' 'a-z')" in
    *teaser*)
      if grep -Eiq 'p&l|profit (and|&) loss|balance sheet|fully.?diluted cap table|bank statement' "$f"; then
        fail "$f: teaser leaks confidential financials (P&L / balance sheet / full cap table)"
      else
        ok "$f: teaser carries no confidential financials"
      fi ;;
  esac
}

check_update() {
  local f="$1"; info "$f: investor update"
  local missing=0
  has "headline" "$f"   || warn "$f: no explicit headline section"
  has "highlight" "$f"  || { fail "$f: highlights section missing"; missing=1; }
  grep -Eq '\|.*\|.*\|' "$f" || { fail "$f: no metrics table (markdown | table |)"; missing=1; }
  has "challenge" "$f"  || { fail "$f: challenges section missing"; missing=1; }
  has "ask" "$f"        || { fail "$f: asks section missing"; missing=1; }
  grep -Eiq 'runway|burn|cash:' "$f" || { fail "$f: no cash/runway line"; missing=1; }
  [ "$missing" -eq 0 ] && ok "$f: 6 sections present incl. metrics table + runway"
}

# --- dispatch ---------------------------------------------------------------
for f in $TARGETS; do
  check_global "$f"
  case "$(basename "$f" | tr 'A-Z' 'a-z')" in
    *dataroom*|*data-room*|*index*)            check_dataroom "$f" ;;
    *one-pager*|*onepager*|*teaser*)           check_onepager "$f" ;;
    *update*)                                  check_update   "$f" ;;
    *) warn "$f: type not recognized from filename — ran global checks only" ;;
  esac
done

printf '\n%s%d ok%s · %s%d warn%s · %s%d fail%s\n' \
  "$GREEN" "$ok_count" "$NC" "$YELLOW" "$warn_count" "$NC" "$RED" "$fail_count" "$NC"

[ "$fail_count" -eq 0 ] || exit 1
exit 0
