#!/usr/bin/env bash
# verify.sh — structurally lint emitted shortform-ideation artifacts.
#
# Usage:
#   bash scripts/verify.sh 02-DOCS/shortform/            # lint a directory tree
#   bash scripts/verify.sh 02-DOCS/shortform/backlog.md  # lint one file
#   bash scripts/verify.sh                               # no target -> exit 0
#
# It checks STRUCTURE and LEGALITY, never idea quality (that is the capability eval):
#
#   Backlog files   (a markdown table mentioning the required header columns):
#     - the header row names: id, idea, hook, trend, score, status
#     - at least one data row exists under it
#   Experiment files (under an experiments/ path, or any .md with a Hypothesis):
#     - a "Hypothesis" line/heading is present
#     - a dated trend signal is present (a YYYY-MM-DD date)
#     - result fields are present (a "result:" / "## Result" marker)
#   ALL artifacts:
#     - no baked-in scraping command targeting creativecenter / ads.tiktok.com
#       (curl|wget|fetch|scrape|headless against those hosts) — a ToS violation.
#
# Read-only: never writes, installs, or touches the network. Pure text parsing.
# Exits 0 on clean artifacts AND on an empty/clean target (no false failure):
#   - no argument                         -> "nothing to check", exit 0
#   - directory with no relevant .md      -> "nothing to check", exit 0
#   - a .md that is neither a backlog nor an experiment -> skipped, not failed
# Exits non-zero only when a real, recognizable artifact breaks a rule.
#
# Portability: stock macOS bash 3.2. No mapfile, no associative arrays. set -u on,
# set -e intentionally off (each check owns its exit handling).

set -u

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

fail() { printf '%s\n' "${RED}FAIL: $1${RESET}"; failures=$((failures + 1)); }
warn() { printf '%s\n' "${YELLOW}WARN: $1${RESET}"; }
ok()   { printf '%s\n' "${GREEN}OK: $1${RESET}"; }

# --- collect targets -------------------------------------------------------
if [ "$#" -eq 0 ]; then
  printf '%s\n' "${YELLOW}Nothing to check (no path given). Pass a backlog/experiment .md or the 02-DOCS/shortform/ dir.${RESET}"
  exit 0
fi

targets=""
add_target() { targets="${targets}${targets:+
}$1"; }

for arg in "$@"; do
  if [ -d "$arg" ]; then
    # gather .md files recursively without relying on globstar
    while IFS= read -r f; do
      [ -n "$f" ] && add_target "$f"
    done <<EOF
$(find "$arg" -type f -name '*.md' 2>/dev/null)
EOF
  elif [ -f "$arg" ]; then
    add_target "$arg"
  else
    warn "Skipping '$arg' (not a file or directory)."
  fi
done

if [ -z "$targets" ]; then
  printf '%s\n' "${YELLOW}No .md files found in the target(s). Nothing to check.${RESET}"
  exit 0
fi

failures=0
recognized=0

# A scraping command baked at an off-limits host = a hard fail (ToS violation).
SCRAPE_HOSTS='creativecenter|ads\.tiktok\.com'
SCRAPE_VERBS='curl|wget|fetch|scrape|puppeteer|playwright|selenium|headless'

for file in $targets; do
  [ -f "$file" ] || continue

  is_backlog=0
  is_experiment=0

  # Backlog: a markdown header row naming all the required columns (any order).
  header="$(grep -iE '^\|.*\|' "$file" 2>/dev/null \
            | grep -iE 'id' | grep -iE 'hook' | grep -iE 'trend' \
            | grep -iE 'score' | grep -iE 'status' | grep -iE 'idea' | head -1)"
  [ -n "$header" ] && is_backlog=1

  # Experiment: lives under experiments/, or carries a Hypothesis marker.
  case "$file" in
    *experiments/*) is_experiment=1 ;;
  esac
  if grep -qiE '(^|[^a-z])hypothesis' "$file" 2>/dev/null; then
    is_experiment=1
  fi

  if [ "$is_backlog" -eq 0 ] && [ "$is_experiment" -eq 0 ]; then
    # Not a recognizable artifact — but still enforce the no-scrape rule on it,
    # because a scraper hidden in a stray .md is still a problem if it's ours.
    if grep -niE "($SCRAPE_VERBS).*($SCRAPE_HOSTS)" "$file" >/dev/null 2>&1; then
      printf '\n%s\n' "Checking: $file"
      fail "$file contains a scraping command against a TikTok surface — that violates ToS. Use manual/assisted capture or a sanctioned API."
      recognized=$((recognized + 1))
    fi
    continue
  fi

  recognized=$((recognized + 1))
  file_fail_start=$failures
  printf '\n%s\n' "Checking: $file"

  # ---- no-scrape rule (all artifacts) -------------------------------------
  if grep -niE "($SCRAPE_VERBS).*($SCRAPE_HOSTS)" "$file" >/dev/null 2>&1; then
    fail "scraping command against a TikTok surface present — ToS violation; use manual/assisted capture or a sanctioned API."
  else
    ok "no scraping command baked in"
  fi

  if [ "$is_backlog" -eq 1 ]; then
    # data row = a table row after the header that is not the header and not a
    # separator (---). Count rows starting with '|' that contain a digit.
    data_rows="$(grep -E '^\|' "$file" 2>/dev/null \
                 | grep -vE '^\|[[:space:]:|-]+\|?[[:space:]]*$' \
                 | grep -iE '[0-9]' | grep -ivE '^\|[[:space:]]*id[[:space:]]*\|')"
    if [ -n "$data_rows" ]; then
      ok "backlog table has the required columns (id, idea, hook, trend, score, status) and >=1 data row"
    else
      fail "backlog table has the required header but no data rows — an empty backlog ranks nothing."
    fi
  fi

  if [ "$is_experiment" -eq 1 ]; then
    if grep -qiE '(^|[^a-z])hypothesis' "$file" 2>/dev/null; then
      ok "hypothesis present"
    else
      fail "experiment file has no Hypothesis — every bet needs one falsifiable sentence."
    fi

    if grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$file" 2>/dev/null; then
      ok "dated trend signal present (YYYY-MM-DD)"
    else
      fail "no dated trend signal (YYYY-MM-DD) — an undated signal cannot be scored for freshness."
    fi

    if grep -qiE '(^|[^a-z])result' "$file" 2>/dev/null; then
      ok "result fields present (even if pending)"
    else
      fail "no result fields — the loop never learns if the outcome is never recorded (use 'result: pending')."
    fi
  fi

  if [ "$failures" -eq "$file_fail_start" ]; then
    ok "$file passed"
  fi
done

if [ "$recognized" -eq 0 ]; then
  printf '\n%s\n' "${YELLOW}No backlog or experiment artifacts among the target(s). Nothing to verify.${RESET}"
  exit 0
fi

printf '\n'
if [ "$failures" -gt 0 ]; then
  printf '%s\n' "${RED}$failures check(s) failed.${RESET}"
  exit 1
fi
printf '%s\n' "${GREEN}All checks passed.${RESET}"
exit 0
