#!/usr/bin/env bash
#
# verify.sh — STRUCTURE/ALIGNMENT QA gate for the `course-builder` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static, network-free heuristics over your curriculum/syllabus source files. It
#   checks the SKELETON is defensible — not whether the teaching lands (that is
#   course-storytelling's job). Per scanned file it checks:
#     1. Banlist verbs   — outcome-ish lines using "understand / know / learn about /
#        appreciate / be aware / be familiar" (a vanity verb you cannot assess).
#     2. Alignment matrix — a section mapping outcomes to modules/assessment.
#     3. Proven outcomes  — every declared outcome id (O1, LO2, Outcome 3...) is
#        referenced somewhere in an assessment context (flag unproven outcomes).
#     4. Formative + summative — BOTH assessment kinds are present (flag if missing).
#     5. Modules present  — module sections exist and reference outcomes (orphans).
#
#   Every finding is a WARNING by default (course design is judgement, not pass/fail).
#   Use --strict to turn any warning into a failure (exit 1) so CI can gate on it.
#   A missing tool is reported yellow and SKIPPED — never a failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                  # scan ./ for curriculum sources (*.md, *.mdx, *.txt)
#   ./verify.sh --path course    # scan a subdirectory
#   ./verify.sh --strict         # treat any warning as a failure (exit 1)
#
# EXIT CODES
#   0  clean, or warnings only without --strict
#   1  a real failure, or --strict with any warning
#   2  bad usage
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays, arrays are
# initialised and only expanded when non-empty under `set -u`.

set -euo pipefail

# --- portability: runs on stock macOS bash 3.2 ------------------------------
if [ -z "${BASH_VERSION:-}" ]; then
  printf 'This script requires bash (any version >= 3.2). Run: bash %s\n' "$0" >&2
  exit 2
fi

# --- color helpers (no escape codes when not a TTY) -------------------------
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

usage() {
  # print the header comment block (lines 2..43), stripping the leading "# "
  sed -n '2,43p' "$0" | sed 's/^# \{0,1\}//'
}

# --- arg parse --------------------------------------------------------------
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

# count_lines <file>: number of lines in a file; 0 if missing/empty.
count_lines() {
  if [ -s "$1" ]; then
    wc -l < "$1" 2>/dev/null | tr -dc '0-9'
  else
    printf '0'
  fi
}

# find curriculum source files (markdown / text). Prints one path per line.
# Excludes the conventional 02-DOCS wiki/raw so we lint the CURRICULUM, not the profile.
list_curricula() {
  find "$SCAN_PATH" \
    \( -name '*.md' -o -name '*.mdx' -o -name '*.txt' \) \
    -type f \
    ! -path '*/node_modules/*' \
    ! -path '*/.git/*' \
    ! -path '*/02-DOCS/*' \
    2>/dev/null || true
}

# file_has <file> <pattern>: 0 if the (case-insensitive) ERE pattern appears in the file.
file_has() { grep -iqE "$2" "$1" 2>/dev/null; }

# --- ensure we have a searcher ----------------------------------------------
if ! have grep; then
  skip "grep not found — cannot scan curriculum sources; install grep"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# --- gather curriculum files ------------------------------------------------
TMPDIR_V="$(mktemp -d 2>/dev/null || printf '/tmp/verify-cb.%s' "$$")"
mkdir -p "$TMPDIR_V" 2>/dev/null || true
cleanup() { rm -rf "$TMPDIR_V" 2>/dev/null || true; }
trap cleanup EXIT

DOCS="$TMPDIR_V/docs"
list_curricula > "$DOCS" 2>/dev/null || true
n_docs="$(count_lines "$DOCS")"

if [ "$n_docs" -eq 0 ]; then
  skip "no curriculum sources (*.md, *.mdx, *.txt) found under $SCAN_PATH"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

printf 'Scanning %s curriculum file(s) under: %s\n\n' "$n_docs" "$SCAN_PATH"

# --- heuristic markers (case-insensitive ERE) -------------------------------
# A "curriculum-ish" file is one that talks about outcomes/objectives at all.
# Files with no outcome language are skipped silently from the alignment checks.
OUTCOME_LANG_RE='outcome|objective|resultado|objetiu|objectiu|learning goal'
BANLIST_RE='\b(understand|understands|understanding|knows?|know about|learn about|learns about|appreciate|appreciates|be aware|are aware|be familiar|familiar with)\b'
MATRIX_RE='alignment matrix|outcome.*(module|assessment)|module.*outcome|matrix'
FORMATIVE_RE='\bformativ|quiz|checklist|exit ticket|draft|peer review|self.?check|practice'
SUMMATIVE_RE='\bsummativ|capstone|final (project|exam)|portfolio|certif|graded (build|project)'
MODULE_RE='^#{1,6}.*\bmodule\b|^#{1,6}.*\bunit\b|^#{1,6}.*\bweek\b|\bmódulo\b|\bmòdul\b'
# An outcome ID like O1 / LO2 / Outcome 3 / Objetivo 1 (at most-ish line starts).
OUTCOME_ID_RE='\b(O|LO|OBJ)[- ]?[0-9]+\b|\boutcome[- ]?[0-9]+\b|\bobjetivo[- ]?[0-9]+\b|\bobjectiu[- ]?[0-9]+\b'

# per-file result buckets
BANHITS="$TMPDIR_V/banhits";       : > "$BANHITS"
NO_MATRIX="$TMPDIR_V/no_matrix";   : > "$NO_MATRIX"
NO_FORM="$TMPDIR_V/no_form";       : > "$NO_FORM"
NO_SUMM="$TMPDIR_V/no_summ";       : > "$NO_SUMM"
NO_MODULE="$TMPDIR_V/no_module";   : > "$NO_MODULE"
UNPROVEN="$TMPDIR_V/unproven";     : > "$UNPROVEN"
n_relevant=0

while IFS= read -r f; do
  [ -z "$f" ] && continue
  file_has "$f" "$OUTCOME_LANG_RE" || continue   # not a curriculum doc; skip quietly
  n_relevant=$((n_relevant + 1))

  # 1. banlist verbs on lines that look like outcomes/objectives.
  # An outcome line either carries outcome/objective language or an outcome ID
  # (O1/LO2/Outcome 3/Objetivo 1...). Flag the file if any such line uses a banlist verb.
  if grep -inE "$OUTCOME_LANG_RE|$OUTCOME_ID_RE" "$f" 2>/dev/null \
       | grep -iqE "$BANLIST_RE"; then
    printf '%s\n' "$f" >> "$BANHITS"
  fi

  # 2. alignment matrix / mapping present
  file_has "$f" "$MATRIX_RE" || printf '%s\n' "$f" >> "$NO_MATRIX"

  # 4. formative AND summative markers
  file_has "$f" "$FORMATIVE_RE" || printf '%s\n' "$f" >> "$NO_FORM"
  file_has "$f" "$SUMMATIVE_RE" || printf '%s\n' "$f" >> "$NO_SUMM"

  # 5. module sections exist
  file_has "$f" "$MODULE_RE" || printf '%s\n' "$f" >> "$NO_MODULE"

  # 3. proven outcomes: each outcome ID must also appear near assessment language.
  # Heuristic: collect distinct outcome IDs; for each, check it co-occurs in an
  # assessment-ish line (formative/summative/assess). If a file has IDs but none in
  # an assessment context, flag it as possibly-unproven.
  ids="$(grep -ioE "$OUTCOME_ID_RE" "$f" 2>/dev/null | tr '[:lower:]' '[:upper:]' \
         | tr -d ' -' | sort -u)"
  if [ -n "$ids" ]; then
    proven_any=0
    for id in $ids; do
      # normalise file IDs the same way, then look for the id on an assessment line
      if grep -iE "$FORMATIVE_RE|$SUMMATIVE_RE|\bassess" "$f" 2>/dev/null \
           | tr '[:lower:]' '[:upper:]' | tr -d ' -' | grep -qF "$id"; then
        proven_any=1
      fi
    done
    [ "$proven_any" -eq 0 ] && printf '%s\n' "$f" >> "$UNPROVEN"
  fi
done < "$DOCS" || true   # read returns 1 at EOF; harmless under set -e

if [ "$n_relevant" -eq 0 ]; then
  skip "no files contain outcome/objective language — nothing to check for alignment"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

printf 'Found %s file(s) with outcome/objective language.\n\n' "$n_relevant"

report_files() {
  label="$1"; listfile="$2"
  n="$(count_lines "$listfile")"
  if [ "$n" -gt 0 ]; then
    warn "$label ($n file(s)):"
    head -n 8 "$listfile" | sed 's/^/        /'
    if [ "$n" -gt 1 ]; then warn_count=$((warn_count + n - 1)); fi   # warn() already counted 1
  else
    ok "no $label"
  fi
}

# --- report ------------------------------------------------------------------
report_files "outcomes using a vanity/banlist verb (use a measurable Bloom verb)" "$BANHITS"
report_files "curricula with no alignment matrix (emit outcome x module x assessment)" "$NO_MATRIX"
report_files "curricula missing formative assessment (add during-learning checks)" "$NO_FORM"
report_files "curricula missing summative assessment (add an end-of-course artifact)" "$NO_SUMM"
report_files "curricula with no module/unit/week sections (sequence the build)" "$NO_MODULE"
report_files "outcomes not referenced in any assessment context (unproven outcomes)" "$UNPROVEN"

# --- markdownlint (optional) -------------------------------------------------
if have markdownlint; then
  ml_out="$TMPDIR_V/mdlint"
  # shellcheck disable=SC2046  # word-splitting the file list is intended here
  markdownlint $(cat "$DOCS") > "$ml_out" 2>&1 || true
  if [ -s "$ml_out" ]; then
    warn "markdownlint findings in curriculum sources:"
    head -n 10 "$ml_out" | sed 's/^/        /'
  else
    ok "markdownlint clean on curriculum sources"
  fi
else
  skip "markdownlint not found — skipping markdown lint (npm i -g markdownlint-cli)"
fi

# --- summary -----------------------------------------------------------------
printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

cat <<'EOF'

Note: every finding above is a heuristic WARNING — course design is judgement, not pass/fail.
This gate checks STRUCTURE and ALIGNMENT (measurable verbs, the matrix, proven outcomes,
formative + summative), NOT whether the teaching lands — that is course-storytelling's job.
Review each finding: fix the skeleton or justify it. Re-run with --strict to gate CI.
EOF

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
