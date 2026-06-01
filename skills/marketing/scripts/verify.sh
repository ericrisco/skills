#!/usr/bin/env bash
#
# verify.sh — copy QA gate for the `marketing` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static, network-free grep checks over the copy in your project:
#     1. Ban-list hype words (revolutionary, game-changer, cutting-edge, world-class,
#        seamless, unlock, supercharge, "Excited to share", "not just X", "In today's …").
#     2. Generic / un-earned CTAs ("Learn more", "Click here", "Submit").
#     3. Weasel words / vague benefits (very, really, world-class, "best-in-class",
#        "thousands trust", "industry-leading", "robust solution").
#     4. Passive-voice flags (heuristic: "is/are/was/were/be/been + past participle").
#     5. Structure heuristics on HTML/JSX/MD pages: missing <h1>, more than one <h1>,
#        no obvious CTA verb.
#     6. Brand-grounding presence: warns if no 02-DOCS/wiki/brand/ study is found.
#
#   Every finding is a WARNING by default (copy is judgement, not pass/fail).
#   Use --strict to turn warnings into a failure (exit 1) so CI can gate on it.
#   A missing tool is reported yellow and SKIPPED — never a failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                 # scan ./ for copy in *.{md,mdx,html,tsx,jsx,vue,svelte,txt}
#   ./verify.sh --path src      # scan a subdirectory
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
  # print the header comment block (lines 2..40), stripping the leading "# "
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
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

# count_lines <file>: number of non-empty-aware lines in a file; 0 if missing/empty.
# Robust across BSD/GNU: wc -l can print leading spaces, so strip non-digits.
count_lines() {
  if [ -s "$1" ]; then
    wc -l < "$1" 2>/dev/null | tr -dc '0-9'
  else
    printf '0'
  fi
}

# Copy-bearing extensions are restricted via glob flags in search() below.
# JSX/TSX/Vue/Svelte/HTML carry on-page copy; md/mdx/txt carry content + references.

# search <pattern>: case-insensitive, whole-tree, copy files only. Prints file:line:match.
# Uses ripgrep if present (faster, respects .gitignore), else portable grep -rnE.
# Never errors out the script: a no-match grep returns 1, which we swallow.
search() {
  pattern="$1"
  if have rg; then
    rg -n --no-heading -i -e "$pattern" \
       -g '*.md' -g '*.mdx' -g '*.html' -g '*.htm' \
       -g '*.tsx' -g '*.jsx' -g '*.vue' -g '*.svelte' -g '*.txt' \
       "$SCAN_PATH" 2>/dev/null || true
  else
    # --include globs restrict to copy files by filename (BSD + GNU grep);
    # this avoids matching the extension against the file:line:content output.
    grep -rniE \
      --include='*.md' --include='*.mdx' --include='*.html' --include='*.htm' \
      --include='*.tsx' --include='*.jsx' --include='*.vue' --include='*.svelte' \
      --include='*.txt' \
      -e "$pattern" "$SCAN_PATH" 2>/dev/null || true
  fi
}

# report <label> <pattern>: warn (with up to 5 example lines) if the pattern is found.
report() {
  label="$1"; pattern="$2"
  hits="$(search "$pattern")"
  if [ -n "$hits" ]; then
    warn "$label:"
    printf '%s\n' "$hits" | head -n 5 | sed 's/^/        /'
  else
    ok "no $label"
  fi
}

# --- ensure we have a searcher ----------------------------------------------
if ! have rg && ! have grep; then
  skip "neither ripgrep nor grep found — cannot scan; install ripgrep or grep"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

printf 'Scanning copy under: %s\n\n' "$SCAN_PATH"

# --- 1. ban-list hype words -------------------------------------------------
report "ban-list hype words" \
  'revolutionary|game.?changer|cutting.edge|world.class|next.level|seamless|supercharge|elevate|unlock|excited to share|not just |in today.?s (landscape|fast.paced|competitive|digital)'

# --- 2. generic / un-earned CTAs --------------------------------------------
report "generic CTAs (use a value verb instead)" \
  '>[[:space:]]*(learn more|click here|submit|read more|find out more)[[:space:]]*<|"(learn more|click here|submit)"'

# --- 3. weasel words / vague benefits ---------------------------------------
report "weasel words / vague benefits (replace with a number or mechanism)" \
  'industry.leading|best.in.class|robust solution|powerful (platform|solution|tool)|thousands (of teams )?(trust|use)|trusted by thousands|very (fast|easy|powerful|simple)|really (fast|easy|good)'

# --- 4. passive-voice flags (heuristic) -------------------------------------
report "possible passive voice (prefer active: who does what)" \
  '\b(is|are|was|were|be|been|being)\b +([a-z]+ed|built|made|done|driven|shipped|run|known|seen|given)\b'

# --- 5. structure heuristics (per page) -------------------------------------
# Subshells in a pipe can't mutate warn_count under bash 3.2, so each per-file
# loop appends one line per finding to a temp file, then we add the line count
# to warn_count in the parent shell. Each scan runs exactly once.
TMPDIR_V="$(mktemp -d 2>/dev/null || printf '/tmp/verify.%s' "$$")"
mkdir -p "$TMPDIR_V" 2>/dev/null || true
H1_HITS="$TMPDIR_V/h1"; CTA_HITS="$TMPDIR_V/cta"
: > "$H1_HITS"; : > "$CTA_HITS"
cleanup() { rm -rf "$TMPDIR_V" 2>/dev/null || true; }
trap cleanup EXIT

# Duplicate <h1> in HTML/JSX-ish pages (should be exactly one per page).
h1_files="$(search '<h1' | sed 's/:.*//' | sort -u)"
if [ -z "$h1_files" ]; then
  ok "h1 check: no HTML/JSX pages with <h1> to inspect"
else
  printf '%s\n' "$h1_files" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in *.tsx|*.jsx|*.html|*.htm|*.vue|*.svelte) : ;; *) continue ;; esac
    n="$(grep -c '<h1' "$f" 2>/dev/null || printf '0')"
    if [ "$n" -gt 1 ]; then
      printf '%s[warn]%s multiple <h1> in one page (should be exactly one): %s\n' "$YELLOW" "$NC" "$f"
      printf '%s\n' "$f" >> "$H1_HITS"
    fi
  done
  n_h1="$(count_lines "$H1_HITS")"
  if [ "$n_h1" -gt 0 ]; then warn_count=$((warn_count + n_h1)); else ok "h1 check: exactly one <h1> per page"; fi
fi

# Landing-style pages (have <section>) with no clear CTA verb anywhere.
cta_verbs='start free|get started|book a demo|see (it|a) (live|demo)|get my|try it|sign up|join the'
pages="$(search '<section' | sed 's/:.*//' | sort -u)"
if [ -z "$pages" ]; then
  ok "CTA check: no landing-style pages (<section>) to inspect"
else
  printf '%s\n' "$pages" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! grep -iE "$cta_verbs" "$f" >/dev/null 2>&1; then
      printf '%s[warn]%s page has <section> markup but no clear CTA verb: %s\n' "$YELLOW" "$NC" "$f"
      printf '%s\n' "$f" >> "$CTA_HITS"
    fi
  done
  n_cta="$(count_lines "$CTA_HITS")"
  if [ "$n_cta" -gt 0 ]; then warn_count=$((warn_count + n_cta)); else ok "CTA check: every landing page has a CTA verb"; fi
fi

# --- 6. brand-grounding presence --------------------------------------------
if [ -d "$SCAN_PATH/02-DOCS/wiki/brand" ] || [ -d "02-DOCS/wiki/brand" ]; then
  ok "brand study found under 02-DOCS/wiki/brand/"
else
  warn "no brand study at 02-DOCS/wiki/brand/ — run the brand-grounding gate before shipping copy"
fi

# --- summary ----------------------------------------------------------------
printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

cat <<'EOF'

Note: every finding above is a heuristic WARNING — copy is judgement, not pass/fail.
Review each, then fix or justify. Re-run with --strict to gate CI on a clean pass.
EOF

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
