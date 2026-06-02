#!/usr/bin/env bash
#
# verify.sh — structural + legal lint for a `case-studies` markdown artifact.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static, network-free checks on a single generated case-study markdown file.
#     1. Quantified hero — at least one number+unit / `%` in the first heading
#        or the lines just under it (HARD FAIL if absent).
#     2. Required sections — a snapshot/at-a-glance box AND challenge, solution,
#        result headings (HARD FAIL on a missing core section).
#     3. Consent marker — a `consent:` or `approved:` flag, ideally in front-matter
#        (HARD FAIL if unmarked: publishing an un-consented named quote is the legal risk).
#     4. Attributed quote — a blockquote followed by an attribution line with a name
#        (warn if a quote is present but unattributed).
#     5. Before/after signal — a `from X to Y`, `->`, `→`, or `X% ` comparative
#        (warn if no comparative metric is found).
#     6. CTA — a call-to-action line near the end (warn if absent).
#     7. Superlative banlist — revolutionary, best-in-class, game-changer,
#        world-class, seamless, cutting-edge (warn each).
#
#   Hard failures exit 1. A missing/empty file (or no target) is reported and
#   exits 0 — no false failure on a clean/empty target. Pure bash + grep/awk.
#   It is a lint, not a persuasion oracle: it gates structure and the legal
#   contract, nothing about whether the story actually converts.
#
# HOW TO RUN
#   ./verify.sh path/to/case-study.md     # lint one case study
#   ./verify.sh                           # no target -> nothing to check, exit 0
#
# EXIT CODES
#   0  clean, or nothing to check
#   1  a hard structural/legal failure
#   2  bad usage
#
# Runs on stock macOS bash 3.2.

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

usage() { sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; }

# --- arg parse --------------------------------------------------------------
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -*) printf 'unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

# No target, or empty/missing file -> nothing to check, clean exit (no false fail).
if [ -z "$TARGET" ]; then
  ok "no case-study path given — nothing to lint"
  printf '\nok=%d warn=%d fail=%d\n' "$ok_count" "$warn_count" "$fail_count"
  exit 0
fi
if [ ! -f "$TARGET" ]; then
  warn "file not found: $TARGET — nothing to lint"
  printf '\nok=%d warn=%d fail=%d\n' "$ok_count" "$warn_count" "$fail_count"
  exit 0
fi
if [ ! -s "$TARGET" ]; then
  warn "file is empty: $TARGET — nothing to lint"
  printf '\nok=%d warn=%d fail=%d\n' "$ok_count" "$warn_count" "$fail_count"
  exit 0
fi

# --- 1. quantified hero -----------------------------------------------------
# The hero = first H1 plus the next ~5 non-blank content lines under it.
HERO="$(awk '
  /^# [^#]/ { grab=1; print; n=0; next }
  grab && NF { print; n++; if (n>=5) grab=0 }
' "$TARGET")"
if [ -z "$HERO" ]; then
  fail "no H1/hero heading found (need a results headline)"
elif printf '%s' "$HERO" | grep -qE '[0-9]+([.,][0-9]+)?[[:space:]]*(%|x|×|k|K|M|min|h|hours?|days?|weeks?|months?|€|\$|£)|[€\$£][0-9]'; then
  ok "hero carries a quantified metric"
else
  fail "hero headline has no number+unit (lead with the result, e.g. 'Churn cut 40% in one quarter')"
fi

# --- 2. required sections ---------------------------------------------------
sect() { grep -qiE "^#{1,4}[[:space:]].*(${1})" "$TARGET"; }
# Snapshot box: a heading OR a blockquote labelled snapshot/at-a-glance.
if sect 'snapshot|at[ -]?a[ -]?glance|overview' \
   || grep -qiE '^>[[:space:]]*(snapshot|at[ -]?a[ -]?glance|overview)' "$TARGET"; then
  ok "snapshot / at-a-glance box present"
else
  fail "no snapshot/at-a-glance box (need industry/region/products/KPIs above the fold)"
fi
if sect 'challenge|problem|reto|desafí'; then ok "challenge section present"; else fail "no challenge section"; fi
if sect 'solution|solució|solucion';    then ok "solution section present";  else fail "no solution section";  fi
if sect 'result|outcome|resultat|resultado'; then ok "result section present"; else fail "no result section"; fi

# --- 3. consent marker (HARD) ----------------------------------------------
if grep -qiE '^[[:space:]]*(consent|approved)[[:space:]]*:' "$TARGET"; then
  ok "consent/approval marker present"
else
  fail "no consent: or approved: marker — un-consented named quotes are the legal risk; add the front-matter flag"
fi

# --- 4. attributed quote ----------------------------------------------------
# A blockquote line, then somewhere a `— Name, Title` attribution.
if grep -qE '^>[[:space:]]*"' "$TARGET" || grep -qE '^>[[:space:]]*[A-Za-z]' "$TARGET"; then
  if grep -qE '^>?[[:space:]]*[—-][[:space:]]*[A-Z]' "$TARGET"; then
    ok "attributed quote present (blockquote + attribution line)"
  else
    warn "quote present but no attribution line found (need '— Name, Title, Company')"
  fi
else
  warn "no blockquote testimonial found"
fi

# --- 5. before/after signal -------------------------------------------------
if grep -qiE 'from[[:space:]]+[^ ]+[[:space:]]+to[[:space:]]|->|→|[0-9]+([.,][0-9]+)?[[:space:]]*%' "$TARGET"; then
  ok "before/after or comparative metric signal found"
else
  warn "no baseline→result signal (pair every number with a baseline and a timeframe)"
fi

# --- 6. CTA -----------------------------------------------------------------
if grep -qiE "(book|schedule|get started|see pricing|request|contact|talk to|sign up|learn more|demo|read the|what's next|próxim|next step)" "$TARGET"; then
  ok "a CTA-shaped line is present"
else
  warn "no decision-stage CTA found near the end"
fi

# --- 7. superlative banlist -------------------------------------------------
# Scan body outside fenced code blocks (Bad/Good examples sit in fences).
BODY="$(awk '/^```/{f=!f; next} !f{print}' "$TARGET")"
ban_hits=0
for phrase in "revolutionary" "best-in-class" "game-changer" "game changer" \
              "world-class" "world class" "seamless" "cutting-edge" "cutting edge"; do
  if printf '%s\n' "$BODY" | grep -iqF "$phrase"; then
    warn "unsubstantiated superlative: \"$phrase\" — replace with a verifiable specific"
    ban_hits=$((ban_hits + 1))
  fi
done
[ "$ban_hits" -eq 0 ] && ok "superlative banlist clean"

# --- summary ----------------------------------------------------------------
printf '\nok=%d warn=%d fail=%d\n' "$ok_count" "$warn_count" "$fail_count"
cat <<'EOF'

Note: this lints structure and the legal contract only — it does not judge whether
the story actually persuades. That is the capability eval's job, and yours.
EOF

if [ "$fail_count" -gt 0 ]; then exit 1; fi
exit 0
