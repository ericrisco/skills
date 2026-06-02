#!/usr/bin/env bash
# verify.sh — lint a produced video-shorts script (.md) for the structure rules.
#
# Usage:
#   bash scripts/verify.sh path/to/script.md     # lint one emitted script
#   bash scripts/verify.sh                        # no target -> nothing to check, exit 0
#
# What it checks against a timecoded beat-sheet table (the script artifact):
#   1. A hook beat exists covering 0:00 (the first timecode row starts at zero).
#   2. Every beat row carries non-empty on-screen text (the sound-off rule).
#   3. The derived runtime sits in a sane short band (warn >180s, nudge to 15-30s).
#   4. A loop or CTA beat closes the script (last beat mentions loop / CTA / match-cut).
#
# Read-only: it never writes, installs, or touches the network. Pure text parsing.
# Exits 0 on a clean script AND on an empty/clean target (no false failure):
#   - no argument given                -> "nothing to check", exit 0
#   - argument is a directory with no   -> scans *.md; if none found, exit 0
#     matching script files
# Exits non-zero only when a real, parseable script breaks a rule.
#
# Portability: stock macOS bash 3.2. No mapfile, no associative arrays, set -u on,
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
targets=""
if [ "$#" -eq 0 ]; then
  printf '%s\n' "${YELLOW}Nothing to check (no script path given). Pass a script .md to lint.${RESET}"
  exit 0
fi

for arg in "$@"; do
  if [ -d "$arg" ]; then
    for f in "$arg"/*.md; do
      [ -e "$f" ] && targets="${targets}${targets:+
}$f"
    done
  elif [ -f "$arg" ]; then
    targets="${targets}${targets:+
}$arg"
  else
    printf '%s\n' "${YELLOW}Skipping '$arg' (not a file or directory).${RESET}"
  fi
done

if [ -z "$targets" ]; then
  printf '%s\n' "${YELLOW}No .md script files found in the target(s). Nothing to check.${RESET}"
  exit 0
fi

# --- parse one timecode "M:SS" or "MM:SS" into total seconds ----------------
to_seconds() {
  # echoes seconds, or empty if it does not match
  case "$1" in
    [0-9]*:[0-9][0-9])
      m="${1%%:*}"; s="${1##*:}"
      printf '%s' "$(( m * 60 + 10#$s ))"
      ;;
    *) printf '' ;;
  esac
}

# first_tc <cell>  -> the START timecode (M:SS) of a "0:00-0:03"-style cell.
first_tc_of() { printf '%s' "$1" | grep -oE '[0-9]+:[0-9][0-9]' | head -1; }
# last_tc <cell>   -> the END timecode (the last M:SS token in the cell).
last_tc_of()  { printf '%s' "$1" | grep -oE '[0-9]+:[0-9][0-9]' | tail -1; }

failures=0
clean_targets=0

for file in $targets; do
  # A "beat row" is a markdown table row whose first cell starts with a timecode
  # like 0:00 or 0:00-0:03. Grab those rows only.
  rows="$(grep -nE '^\|[[:space:]]*[0-9]+:[0-9][0-9]' "$file" 2>/dev/null || true)"

  if [ -z "$rows" ]; then
    warn "$file: no timecoded beat rows found (expected a '| Time | ... |' table) — not a script artifact, skipping."
    continue
  fi

  clean_targets=$((clean_targets + 1))
  file_fail_start=$failures
  printf '\n%s\n' "Checking: $file"

  # ---- rule 1: a hook beat at 0:00 ----------------------------------------
  first_row_body="$(printf '%s\n' "$rows" | head -1)"
  first_row_body="${first_row_body#*:}"
  first_cell="$(printf '%s' "$first_row_body" | awk -F'|' '{print $2}')"
  first_start="$(first_tc_of "$first_cell")"
  if [ "$(to_seconds "$first_start")" = "0" ]; then
    ok "hook beat starts at 0:00"
  else
    fail "first beat starts at '$first_start', not 0:00 — the hook must own the first frame."
  fi

  # ---- rule 2 + 3: every beat has on-screen text; track max end time ------
  max_end=0
  missing_text=0
  beat_count=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    beat_count=$((beat_count + 1))
    # strip the "lineno:" prefix grep -n added
    body="${line#*:}"
    # split the table row into cells: | Time | VO | On-screen text | Visual |
    tc="$(printf '%s' "$body" | awk -F'|' '{print $2}' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    onscreen="$(printf '%s' "$body" | awk -F'|' '{print $4}' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    if [ -z "$onscreen" ]; then
      missing_text=$((missing_text + 1))
      warn "beat at '$tc' has no on-screen text (sound-off rule: every beat needs burned-in text)."
    fi
    # end time = the last M:SS token in the cell (or the start if there is only one)
    endpart="$(last_tc_of "$tc")"
    esec="$(to_seconds "$endpart")"
    [ -n "$esec" ] && [ "$esec" -gt "$max_end" ] && max_end="$esec"
  done <<EOF
$rows
EOF

  if [ "$missing_text" -eq 0 ]; then
    ok "all $beat_count beats carry on-screen text"
  else
    fail "$missing_text of $beat_count beats lack on-screen text — fails the sound-off rule."
  fi

  # ---- rule 3: runtime band -----------------------------------------------
  if [ "$max_end" -gt 0 ]; then
    if [ "$max_end" -gt 180 ]; then
      warn "runtime ~${max_end}s exceeds the 180s ceiling — this is not a short."
    elif [ "$max_end" -gt 45 ]; then
      warn "runtime ~${max_end}s is past the 15-30s sweet spot — make sure every second escalates."
    else
      ok "runtime ~${max_end}s is within the short band"
    fi
  fi

  # ---- rule 4: a loop / CTA closes it -------------------------------------
  last_row="$(printf '%s\n' "$rows" | tail -1)"
  if printf '%s' "$last_row" | grep -qiE 'loop|cta|match[ -]?cut|replay|seam'; then
    ok "closing beat signals a loop / CTA"
  else
    fail "last beat does not signal a loop or CTA (loop|cta|match-cut|seam) — a short should replay, not end on an outro."
  fi

  if [ "$failures" -eq "$file_fail_start" ]; then
    ok "$file passed"
  fi
done

if [ "$clean_targets" -eq 0 ]; then
  printf '\n%s\n' "${YELLOW}No parseable script artifacts among the target(s). Nothing to verify.${RESET}"
  exit 0
fi

printf '\n'
if [ "$failures" -gt 0 ]; then
  printf '%s\n' "${RED}$failures check(s) failed.${RESET}"
  exit 1
fi
printf '%s\n' "${GREEN}All checks passed.${RESET}"
exit 0
