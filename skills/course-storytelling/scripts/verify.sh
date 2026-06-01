#!/usr/bin/env bash
#
# verify.sh — "did it land?" QA gate for the `course-storytelling` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static, network-free heuristics over your lesson/course source files. For each
#   concept section it checks that the teaching has the ingredients that make it land:
#     1. Story presence    — a section that teaches a concept but has no narrative
#        markers (no "I", no "story", no time/place setup) is a `no-story` lesson.
#     2. Named model       — a memorable, ownable name (a "The X" handle / bolded coinage).
#     3. Grounded analogy  — an analogy marker ("like", "imagine", "think of it as").
#     4. Application step   — a do-this-now action ("try this", "do this", "your turn").
#     5. So-what payoff     — a future-paced close ("next time", "you'll be able to", "so that").
#     6. Abstraction / jargon density — flags sections heavy on abstract nouns
#        (-tion/-ity/-ность style) with no analogy nearby.
#     7. markdownlint of lesson sources, if markdownlint is installed.
#
#   Every finding is a WARNING by default (teaching is judgement, not pass/fail).
#   Use --strict to turn warnings into a failure (exit 1) so CI can gate on it.
#   A missing tool is reported yellow and SKIPPED — never a failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                 # scan ./ for lesson sources (*.md, *.mdx, *.txt)
#   ./verify.sh --path lessons  # scan a subdirectory
#   ./verify.sh --strict        # treat any warning as a failure (exit 1)
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
  # print the header comment block (lines 2..44), stripping the leading "# "
  sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//'
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
# Robust across BSD/GNU: wc -l can print leading spaces, so strip non-digits.
count_lines() {
  if [ -s "$1" ]; then
    wc -l < "$1" 2>/dev/null | tr -dc '0-9'
  else
    printf '0'
  fi
}

# find lesson source files (markdown / text). Prints one path per line.
# Excludes the conventional 02-DOCS wiki/raw so we lint LESSONS, not the profile.
list_lessons() {
  find "$SCAN_PATH" \
    \( -name '*.md' -o -name '*.mdx' -o -name '*.txt' \) \
    -type f \
    ! -path '*/node_modules/*' \
    ! -path '*/.git/*' \
    ! -path '*/02-DOCS/*' \
    2>/dev/null || true
}

# search <pattern>: case-insensitive whole-tree search over lesson files only.
# ripgrep if present (faster), else portable grep -rnE. A no-match returns 1; swallow it.
search() {
  pattern="$1"
  if have rg; then
    rg -n --no-heading -i -e "$pattern" \
       -g '*.md' -g '*.mdx' -g '*.txt' \
       -g '!02-DOCS/**' -g '!node_modules/**' \
       "$SCAN_PATH" 2>/dev/null || true
  else
    grep -rniE \
      --include='*.md' --include='*.mdx' --include='*.txt' \
      --exclude-dir='02-DOCS' --exclude-dir='node_modules' --exclude-dir='.git' \
      -e "$pattern" "$SCAN_PATH" 2>/dev/null || true
  fi
}

# file_has <file> <pattern>: 0 if the (case-insensitive) pattern appears in the file.
file_has() { grep -iqE "$2" "$1" 2>/dev/null; }

# --- ensure we have a searcher ----------------------------------------------
if ! have rg && ! have grep; then
  skip "neither ripgrep nor grep found — cannot scan; install ripgrep or grep"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# --- gather lesson files ----------------------------------------------------
TMPDIR_V="$(mktemp -d 2>/dev/null || printf '/tmp/verify-cs.%s' "$$")"
mkdir -p "$TMPDIR_V" 2>/dev/null || true
cleanup() { rm -rf "$TMPDIR_V" 2>/dev/null || true; }
trap cleanup EXIT

LESSONS="$TMPDIR_V/lessons"
list_lessons > "$LESSONS" 2>/dev/null || true
n_lessons="$(count_lines "$LESSONS")"

if [ "$n_lessons" -eq 0 ]; then
  skip "no lesson sources (*.md, *.mdx, *.txt) found under $SCAN_PATH"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

printf 'Scanning %s lesson file(s) under: %s\n\n' "$n_lessons" "$SCAN_PATH"

# Heuristic markers (case-insensitive ERE).
STORY_RE='\bi (was|had|remember|learned|realized|once)\b|\bstory\b|\bone (day|night|morning)\b|at the time|years? (ago|in)|epiphany|the moment (i|we|they)'
NAME_RE='\bthe [A-Z][a-z]+( [A-Z][a-z]+)?\b|\*\*[^*]+\*\*|call (it|this) the|i call (it|this)|known as the'
ANALOGY_RE='\blike (a|an|the|your)\b|\bimagine\b|\bthink of (it|this) as\b|\bit.?s (basically|essentially) (a|an|like)\b|analog|metaphor|as if'
APPLICATION_RE='\btry (this|it)\b|\bdo this\b|\byour turn\b|right now|before you (close|move|continue)|exercise|step 1|hands.?on|go (build|add|write|open)'
SOWHAT_RE='next time|you.?ll (be able|now|never)|so that you|what.?s now possible|from now on|imagine being able|future|the payoff'

# Per-file results (bash 3.2: append to temp files, count in parent shell).
NS="$TMPDIR_V/no_story";   : > "$NS"
NN="$TMPDIR_V/no_name";    : > "$NN"
NA="$TMPDIR_V/no_analogy"; : > "$NA"
NP="$TMPDIR_V/no_appl";    : > "$NP"
NW="$TMPDIR_V/no_sowhat";  : > "$NW"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  file_has "$f" "$STORY_RE"       || printf '%s\n' "$f" >> "$NS"
  file_has "$f" "$NAME_RE"        || printf '%s\n' "$f" >> "$NN"
  file_has "$f" "$ANALOGY_RE"     || printf '%s\n' "$f" >> "$NA"
  file_has "$f" "$APPLICATION_RE" || printf '%s\n' "$f" >> "$NP"
  file_has "$f" "$SOWHAT_RE"      || printf '%s\n' "$f" >> "$NW"
done < "$LESSONS"

report_files() {
  label="$1"; listfile="$2"
  n="$(count_lines "$listfile")"
  if [ "$n" -gt 0 ]; then
    warn "$label ($n file(s)):"
    head -n 8 "$listfile" | sed 's/^/        /'
    warn_count=$((warn_count + n - 1))   # warn() already counted 1
  else
    ok "no $label"
  fi
}

# --- 1..5 landing-ingredient checks -----------------------------------------
report_files "lessons with no story marker (add an Epiphany Bridge beat)"        "$NS"
report_files "lessons with no named mental model (name the concept)"             "$NN"
report_files "lessons with no grounded analogy (add a concrete metaphor)"        "$NA"
report_files "lessons with no application step (add a do-this-now)"              "$NP"
report_files "lessons with no so-what payoff (future-pace the close)"            "$NW"

# --- 6. abstraction / jargon density ----------------------------------------
# Heuristic: lines dense in abstract -tion/-ity/-ism nouns. Flag files where such
# lines appear AND the file has no analogy marker (analogy is the antidote).
ABSTRACT_RE='\b[a-z]{4,}(tion|ality|ility|ism|ance|ence)\b'
JARGON_HITS="$TMPDIR_V/jargon"; : > "$JARGON_HITS"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  dense="$(grep -ioE "$ABSTRACT_RE" "$f" 2>/dev/null | wc -l | tr -dc '0-9')"
  [ -z "$dense" ] && dense=0
  if [ "$dense" -ge 12 ] && ! file_has "$f" "$ANALOGY_RE"; then
    printf '%s (%s abstract nouns, no analogy)\n' "$f" "$dense" >> "$JARGON_HITS"
  fi
done < "$LESSONS"
n_jargon="$(count_lines "$JARGON_HITS")"
if [ "$n_jargon" -gt 0 ]; then
  warn "jargon/abstraction-dense lessons with no grounding analogy ($n_jargon file(s)):"
  head -n 8 "$JARGON_HITS" | sed 's/^/        /'
  warn_count=$((warn_count + n_jargon - 1))
else
  ok "no abstraction-dense, analogy-less lessons"
fi

# --- 7. markdownlint of lesson sources (if available) -----------------------
if have markdownlint; then
  # Lint only the lesson files; warn on findings, never fail the gate here.
  ml_out="$TMPDIR_V/mdlint"
  # shellcheck disable=SC2046  # word-splitting the file list is intended here
  markdownlint $(cat "$LESSONS") > "$ml_out" 2>&1 || true
  if [ -s "$ml_out" ]; then
    warn "markdownlint findings in lesson sources:"
    head -n 10 "$ml_out" | sed 's/^/        /'
  else
    ok "markdownlint clean on lesson sources"
  fi
else
  skip "markdownlint not found — skipping markdown lint (npm i -g markdownlint-cli)"
fi

# --- summary ----------------------------------------------------------------
printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

cat <<'EOF'

Note: every finding above is a heuristic WARNING — teaching is judgement, not pass/fail.
Review each: does the concept actually have a story, a named model, a grounded analogy, an
application step, and a so-what? Then fix or justify. Re-run with --strict to gate CI.
EOF

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
