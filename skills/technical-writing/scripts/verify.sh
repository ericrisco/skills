#!/usr/bin/env bash
#
# verify.sh — structural + prose-banlist lint for the technical-writing skill.
#
# Usage:
#   scripts/verify.sh                 # structure check of the skill itself
#   scripts/verify.sh path/to/doc.md  # also lint a produced doc against the banlist
#
# Read-only. It never edits a file. This mirrors the Vale gate the skill
# preaches, using pure grep so it needs no dependencies. It lints PHRASING
# and STRUCTURE, not whether the writing is good — that is the capability
# eval's job.
#
# Exit 0 = clean (or nothing to lint). Exit 1 = a banned term in the target
# doc, or a missing required reference file. Empty/clean targets never fail.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

fail=0

# --- 1. Structure: the two references the skill points to must exist. -------
for ref in references/diataxis-modes.md references/vale-starter.md; do
  if [ -f "$SKILL_DIR/$ref" ]; then
    echo "ok   present: $ref"
  else
    echo "FAIL missing: $ref"
    fail=1
  fi
done

# --- 2. Structure: SKILL.md must carry the required sections. ---------------
SKILL_MD="$SKILL_DIR/SKILL.md"
if [ -f "$SKILL_MD" ]; then
  for heading in "## Anti-patterns" "## Before you ship"; do
    if grep -qF "$heading" "$SKILL_MD"; then
      echo "ok   section: $heading"
    else
      echo "FAIL section missing in SKILL.md: $heading"
      fail=1
    fi
  done
else
  echo "FAIL missing: SKILL.md"
  fail=1
fi

# --- 3. Banlist: only applied to a produced doc passed as $1. ---------------
# The skill's own files document the banned words as examples, so we do NOT
# lint them — we lint the doc the agent ships. A whole-word, case-insensitive
# grep keeps it dependency-free.
BANNED='simply|just|easily|effortless|effortlessly|seamless|seamlessly|blazing-fast|blazing fast|supercharge|leverage|utilize|in order to'

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  echo "note no doc path given — skipping banlist (structure-only run)."
elif [ ! -f "$TARGET" ]; then
  echo "note '$TARGET' is not a file — nothing to lint. PASS"
elif [ ! -s "$TARGET" ]; then
  echo "note '$TARGET' is empty — nothing to lint. PASS"
else
  # -E extended regex, -i case-insensitive, -w-ish via word boundaries in -E,
  # -n for line numbers. Banned terms inside the banlist file would false-fail,
  # but we never pass the skill's own files here.
  hits="$(grep -Ein "\b(${BANNED})\b" "$TARGET" || true)"
  if [ -n "$hits" ]; then
    echo "FAIL banned terms in $TARGET:"
    echo "$hits"
    fail=1
  else
    echo "ok   banlist clean: $TARGET"
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
fi
echo "FAILED"
exit 1
