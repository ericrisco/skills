#!/usr/bin/env bash
#
# verify.sh — structural lint for a proposal / SOW markdown draft.
#
# WHAT IT DOES (read-only; never edits a file)
#   Greps a generated proposal/SOW markdown for its required-section contract and
#   flags scope-creep and smuggled-legal language. It is a STRUCTURE check, not a
#   quality judgement — the persuasion rigor lives in the capability eval.
#     1. Required proposal sections present: executive summary, scope, pricing/
#        investment, timeline, next step.
#     2. If the doc looks like a SOW, its required clauses are present:
#        exclusions, acceptance criteria, change order, payment schedule.
#     3. Weasel / scope-creep ban-list ABSENT: "etc.", "as needed", "and more",
#        "TBD" (in scope), unbounded "ongoing".  -> FAIL (these lose free-work fights)
#     4. Binding-legal smuggle WARNING: "indemnif", "governing law",
#        "limitation of liability", "intellectual property assigns/assignment".
#        -> warn "route to contracts" (do not draft binding terms here).
#     5. Executive-summary length 200–400 words -> warn if outside.
#
# EXIT CODES
#   0  clean, or no target file to inspect (empty target is NOT a failure),
#      or warn-only findings
#   1  a required section is missing, or a banned weasel word is present
#   2  bad usage
#
# HOW TO RUN (point it at YOUR draft, not the skills repo)
#   ./verify.sh proposal.md            # lint one file
#   ./verify.sh --path proposals/      # lint every *.md / *.markdown under a dir
#   ./verify.sh                        # scan ./ ; if nothing matches, skip + exit 0
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

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

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

# --- arg parse --------------------------------------------------------------
SCAN_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --path)    SCAN_PATH="${2:?--path needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)        printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
    *)         SCAN_PATH="$1"; shift ;;
  esac
done
[ -z "$SCAN_PATH" ] && SCAN_PATH="."

if [ ! -e "$SCAN_PATH" ]; then
  printf '%sPath not found: %s%s\n' "$RED" "$SCAN_PATH" "$NC"; exit 2
fi

have() { command -v "$1" >/dev/null 2>&1; }

# --- collect candidate markdown files --------------------------------------
# A single file is used as-is; a directory is searched for *.md / *.markdown.
FILES=""
if [ -f "$SCAN_PATH" ]; then
  FILES="$SCAN_PATH"
else
  FILES="$(find "$SCAN_PATH" -type f \( -name '*.md' -o -name '*.markdown' \) 2>/dev/null || true)"
fi

# Empty / clean target is NOT a failure — nothing to lint, exit 0.
if [ -z "$FILES" ]; then
  skip "no proposal/SOW markdown found under '$SCAN_PATH' — nothing to lint"
  printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"
  exit 0
fi

# gci <pattern> <file>: case-insensitive grep, swallow no-match (so set -e is safe).
gci() { grep -iE -e "$1" "$2" >/dev/null 2>&1; }

# word_count_section <file> <start-heading-regex>: words from the first matching
# heading until the next markdown "## " heading. 0 if the heading is absent.
exec_summary_words() {
  awk '
    BEGIN { inseg=0; words=0 }
    tolower($0) ~ /^#+ +(executive summary|exec summary|resumen ejecutivo|resum executiu)/ { inseg=1; next }
    inseg && /^#{1,6} / { inseg=0 }
    inseg { words += NF }
    END { print words+0 }
  ' "$1"
}

printf 'Linting %d file(s) under: %s\n\n' "$(printf '%s\n' "$FILES" | grep -c .)" "$SCAN_PATH"

# --- per-file checks --------------------------------------------------------
printf '%s\n' "$FILES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  printf '%s— %s%s\n' "$YELLOW" "$f" "$NC"

  # 1. required proposal sections
  gci 'executive summary|exec summary|resumen ejecutivo|resum executiu' "$f" \
    && ok "  exec summary present" || fail "  missing executive summary"
  gci '(^|[^a-z])scope([^a-z]|$)|what.?s included|abast|alcance' "$f" \
    && ok "  scope present" || fail "  missing scope section"
  gci 'pricing|investment|tiers?|inversi|preu|precio' "$f" \
    && ok "  pricing/investment present" || fail "  missing pricing/investment section"
  gci 'timeline|milestones?|calendari|cronograma' "$f" \
    && ok "  timeline/milestones present" || fail "  missing timeline section"
  gci 'next steps?|mutual action|propers passos|pr.ximos pasos|call to action' "$f" \
    && ok "  next-step/close present" || fail "  missing next-step/close"

  # 2. SOW-specific clauses (only if the doc declares itself a SOW)
  if gci 'statement of work|scope of work|^#.*\bsow\b|abast del projecte' "$f"; then
    ok "  detected SOW — checking SOW clauses"
    gci 'exclud|exclusion|not (in scope|included)|out of scope|fora d.abast|excluido' "$f" \
      && ok "    explicit exclusions present" || fail "    SOW missing explicit EXCLUSIONS"
    gci 'acceptance criteria|accept(ed|ance)|criteris d.acceptaci|criterios de aceptaci' "$f" \
      && ok "    acceptance criteria present" || fail "    SOW missing acceptance criteria"
    gci 'change order|change.?request|written approval|ordre de canvi|orden de cambio' "$f" \
      && ok "    change-order clause present" || fail "    SOW missing change-order clause"
    gci 'payment (schedule|milestones?|terms)|on signature|on acceptance|calendari de pagament' "$f" \
      && ok "    payment schedule present" || fail "    SOW missing payment schedule"
  else
    skip "  not a SOW (skipping SOW-specific clause checks)"
  fi

  # 3. weasel / scope-creep ban-list -> FAIL
  weasel="$(grep -inE 'etc\.|[^a-z]as needed|and more|[^a-z]tbd[^a-z]|ongoing (support|work|maintenance)' "$f" 2>/dev/null || true)"
  if [ -n "$weasel" ]; then
    fail "  weasel / scope-creep words (bound them with a quantity):"
    printf '%s\n' "$weasel" | head -n 5 | sed 's/^/        /'
  else
    ok "  no weasel / scope-creep words"
  fi

  # 4. binding-legal smuggle -> WARN (route to contracts)
  legal="$(grep -inE 'indemnif|governing law|limitation of liability|intellectual property (assigns|assignment)|liability cap' "$f" 2>/dev/null || true)"
  if [ -n "$legal" ]; then
    warn "  binding-legal language found — route these to the contracts skill / MSA:"
    printf '%s\n' "$legal" | head -n 5 | sed 's/^/        /'
  else
    ok "  no smuggled binding-legal clauses"
  fi

  # 5. exec-summary length 200–400 words -> WARN
  w="$(exec_summary_words "$f")"
  if [ "$w" -eq 0 ]; then
    : # absence already reported in check 1
  elif [ "$w" -lt 200 ] || [ "$w" -gt 400 ]; then
    warn "  exec summary is $w words (aim 200–400)"
  else
    ok "  exec summary length ok ($w words)"
  fi
  printf '\n'
done

# The while-pipe runs in a subshell under bash 3.2, so its counters don't survive.
# Re-derive the pass/fail decision from a second, quiet aggregate pass.
agg_fail=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  for p in \
    'executive summary|exec summary|resumen ejecutivo|resum executiu' \
    '(^|[^a-z])scope([^a-z]|$)|what.?s included|abast|alcance' \
    'pricing|investment|tiers?|inversi|preu|precio' \
    'timeline|milestones?|calendari|cronograma' \
    'next steps?|mutual action|propers passos|pr.ximos pasos|call to action'
  do
    gci "$p" "$f" || agg_fail=$((agg_fail + 1))
  done
  if gci 'statement of work|scope of work|^#.*\bsow\b|abast del projecte' "$f"; then
    for p in \
      'exclud|exclusion|not (in scope|included)|out of scope|fora d.abast|excluido' \
      'acceptance criteria|accept(ed|ance)|criteris d.acceptaci|criterios de aceptaci' \
      'change order|change.?request|written approval|ordre de canvi|orden de cambio' \
      'payment (schedule|milestones?|terms)|on signature|on acceptance|calendari de pagament'
    do
      gci "$p" "$f" || agg_fail=$((agg_fail + 1))
    done
  fi
  if grep -iE 'etc\.|[^a-z]as needed|and more|[^a-z]tbd[^a-z]|ongoing (support|work|maintenance)' "$f" >/dev/null 2>&1; then
    agg_fail=$((agg_fail + 1))
  fi
done <<EOF
$FILES
EOF

printf 'Done. (re-run after fixing any [fail] lines above)\n'
cat <<'NOTE'

Note: [fail] = a broken section contract or scope-creep word (fix before sending).
      [warn] = binding-legal language or an off-length exec summary (review/justify).
NOTE

if [ "$agg_fail" -gt 0 ]; then exit 1; fi
exit 0
