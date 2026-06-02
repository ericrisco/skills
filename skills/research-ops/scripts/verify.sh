#!/usr/bin/env bash
#
# verify.sh — provenance gate for the `research-ops` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static checks over a produced research memo (Markdown). It validates that the
#   memo is SOURCED, DATED, and REVIEW-READY — never whether the answer is correct.
#   For each memo found:
#     1. Structure: an Answer/Summary section AND an Open-questions/Unverified
#        section both exist. A memo with no stated boundary of the evidence fails.
#     2. Findings carry citations: under the Findings section, lines that state a
#        claim carry a citation token (a Markdown link or a bare URL).
#     3. Dates: every cited finding line carries a date — YYYY-MM-DD, "pub", or
#        "accessed". An undated citation is a fail.
#     4. Confidence: a confidence tier token (high|med|medium|low) appears among
#        the findings. A memo that never tiers its claims fails.
#
#   A missing/empty target is a SKIP, never a failure. grep/awk only; no network.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                      # scan ./ for *memo*/*research* .md
#   ./verify.sh --path memo.md       # check one memo
#   ./verify.sh --path research/     # scan a directory of memos
#   ./verify.sh --strict             # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, empty target, or warnings only without --strict
#   1  a real failure (no answer section, undated citation, no confidence tier)
#   2  bad usage
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

usage() { sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; }

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

ok_count=0; skip_count=0; warn_count=0; fail_count=0
summary() { printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"; }

if [ ! -e "$SCAN_PATH" ]; then
  printf '%s[skip]%s path not found: %s — nothing to check\n' "$YELLOW" "$NC" "$SCAN_PATH"
  skip_count=1; summary; exit 0
fi

have() { command -v "$1" >/dev/null 2>&1; }
if ! have awk; then
  printf '%s[skip]%s awk not found — cannot parse memo\n' "$YELLOW" "$NC"
  skip_count=1; summary; exit 0
fi

# Collect candidate memo files: prefer named memos/research files, else any .md.
FILES=""
if [ -f "$SCAN_PATH" ]; then
  FILES="$SCAN_PATH"
else
  FILES="$(find "$SCAN_PATH" -type f -name '*.md' \( -iname '*memo*' -o -iname '*research*' -o -iname '*findings*' \) 2>/dev/null || true)"
  if [ -z "$FILES" ]; then
    FILES="$(find "$SCAN_PATH" -type f -name '*.md' 2>/dev/null || true)"
  fi
fi

if [ -z "$FILES" ]; then
  printf '%s[skip]%s no research memo found under %s — nothing to check (clean)\n' "$YELLOW" "$NC" "$SCAN_PATH"
  skip_count=1; summary; exit 0
fi

# check_one <file>: one awk pass emits "LEVEL message" lines; the shell tallies.
check_one() {
  f="$1"
  [ -s "$f" ] || { printf '%s[skip]%s empty file: %s\n' "$YELLOW" "$NC" "$f"; return; }
  printf '%s—— %s%s\n' "$YELLOW" "$f" "$NC"

  awk '
    # BSD awk: no IGNORECASE, no \b. Lowercase with tolower(); explicit boundaries.
    {
      lc=tolower($0)

      # --- section detection (headings) ---
      if (lc ~ /^#+/) {
        infind=0
        if (lc ~ /(answer|summary|bottom line|tl;dr|tldr)/) hasanswer=1
        if (lc ~ /(open question|unverified|could not verify|couldnt verify|not verified|limitations)/) hasopen=1
        if (lc ~ /(finding|claim|evidence)/) infind=1
      }

      # --- a finding line: a bullet/numbered claim, inside findings or anywhere ---
      isbullet = ($0 ~ /^[ \t]*([-*]|[0-9]+\.)[ \t]+/)
      if (isbullet && (infind || lc ~ /confidence:/)) {
        findlines++
        haslink = ($0 ~ /\]\(http/ || $0 ~ /https?:\/\//)
        hasdate = ($0 ~ /(19|20)[0-9][0-9]-[0-1][0-9]-[0-3][0-9]/ || lc ~ /pub /|| lc ~ /accessed/ || lc ~ /pub n\/a/)
        if (haslink) {
          citedlines++
          if (!hasdate) {
            undated++
            if (undated <= 3) print "DETAIL cited finding with no date: " substr($0,1,80)
          }
        } else {
          uncited++
          if (uncited <= 3) print "DETAIL finding with no citation token: " substr($0,1,80)
        }
      }

      if (lc ~ /confidence: *(high|med|medium|low)/) tiers++
    }
    END {
      if (hasanswer) print "OK answer/summary section present"
      else           print "FAIL no Answer/Summary section found"

      if (hasopen) print "OK open-questions/unverified section present"
      else         print "FAIL no Open-questions/Unverified section found"

      if (findlines == 0) {
        print "WARN no finding/claim bullet lines detected — nothing to check provenance on"
      } else {
        if (uncited > 0) print "FAIL "uncited" finding line(s) carry no citation token"
        else             print "OK every finding line carries a citation token ("citedlines" cited)"

        if (undated > 0) print "FAIL "undated" cited finding(s) carry no date"
        else if (citedlines > 0) print "OK "citedlines" cited finding(s); all dated"

        if (tiers > 0) print "OK "tiers" confidence tier token(s) present"
        else           print "FAIL no confidence tier (high|med|low) found on any finding"
      }
    }
  ' "$f" 2>/dev/null
}

printf 'Checking research memos under: %s\n\n' "$SCAN_PATH"
printf '%s\n' "$FILES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  check_one "$f"
done > "/tmp/ro_verify.$$" 2>&1 || true

while IFS= read -r line; do
  case "$line" in
    FAIL*)   printf '%s[fail]%s %s\n' "$RED"    "$NC" "${line#FAIL }" ;;
    WARN*)   printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "${line#WARN }" ;;
    OK*)     printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "${line#OK }" ;;
    DETAIL*) printf '        %s\n' "${line#DETAIL }" ;;
    *)       printf '%s\n' "$line" ;;
  esac
done < "/tmp/ro_verify.$$"

tally() { { grep -c "$1" "/tmp/ro_verify.$$" 2>/dev/null || true; } | tr -dc '0-9'; }
fail_count=$(tally '^FAIL'); fail_count=${fail_count:-0}
warn_count=$(tally '^WARN'); warn_count=${warn_count:-0}
ok_count=$(tally '^OK');     ok_count=${ok_count:-0}
sk=$(tally '\[skip\]');      skip_count=$((skip_count + ${sk:-0}))
rm -f "/tmp/ro_verify.$$" 2>/dev/null || true

summary

cat <<'EOF'

Note: this gate proves the memo is SOURCED, DATED, and REVIEW-READY (answer section,
cited + dated findings, confidence tiers, an open-questions section). It does NOT judge
whether the answer is correct — that is the capability eval's and the researcher's job.
Re-run with --strict to gate CI on a clean pass.
EOF

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
