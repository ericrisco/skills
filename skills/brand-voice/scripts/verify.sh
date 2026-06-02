#!/usr/bin/env bash
#
# verify.sh — structural linter for a produced brand voice guide.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free checks over ONE voice-guide file you point it at
#   (markdown / plain text — e.g. 02-DOCS/wiki/brand/voice-guide.md):
#     1. Required sections present -> FAIL each missing:
#        traits, rules (with a Bad->Good), four-dimension ratios,
#        a word bank, a non-empty BAN list, a tone-by-context matrix,
#        an AI voice-DNA block.
#     2. Trait count outside 3-5 -> warn (heuristic; counts the trait block).
#     3. Brand-neutral filler used AS a trait ("innovative", "passionate",
#        "customer-focused", "cutting-edge") -> warn each hit.
#     4. Self-consistency: the guide's own prose uses a word it lists in its
#        own ban list -> warn each hit.
#
#   Only missing structure (#1, incl. an empty ban list) is a hard failure.
#   Everything else warns. A clean OR empty/whitespace file exits 0 — never a
#   false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh 02-DOCS/wiki/brand/voice-guide.md
#   ./verify.sh guide.md --strict        # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/missing-content file
#   1  a hard failure (missing required section / empty ban list) — or any
#      warning under --strict
#   2  bad usage (no file given, or file does not exist)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays, no bc.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --strict) STRICT=1; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

if [ -z "$FILE" ]; then
  printf '%sno guide file given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  ok "empty file — nothing to check"
  exit 0
fi

printf 'brand-voice verify — %s\n\n' "$FILE"

has() { grep -Eiq "$1" "$FILE" 2>/dev/null; }

# --- 1. required sections (hard) ----------------------------------------------
if has 'trait'; then ok "traits section present"
else fail "no traits section found (3-5 personality adjectives)"; fi

if has '(^|[^a-z])rules?([^a-z]|$)|this (does not|doesn.t) mean'; then ok "rules section present"
else fail "no rules section found (traits translated into linguistic rules)"; fi

# A Bad->Good rewrite somewhere proves the rules are concrete, not abstract.
if grep -Eiq '^[[:space:]]*bad[[:space:]]*:' "$FILE" && grep -Eiq '^[[:space:]]*good[[:space:]]*:' "$FILE"; then
  ok "Bad->Good rewrite(s) present"
else
  fail "no Bad->Good rewrite found — rules must show a concrete before/after"
fi

# Four-dimension ratios: a ratio token (NN/NN or NN-NN) near a dimension name.
if grep -Eiq 'formal|serious|respectful|matter-of-fact|enthusiastic' "$FILE" \
   && grep -Eq '[0-9]{1,3}[[:space:]]*[/-][[:space:]]*[0-9]{1,3}' "$FILE"; then
  ok "four-dimension ratios present"
else
  fail "no four-dimension ratios found (e.g. 80/20 on Formal<->Casual etc.)"
fi

if has 'word bank|power word'; then ok "word bank present"
else fail "no word bank found (power words + ban list)"; fi

if has 'tone[- ]by[- ]context|context.*tone|onboarding'; then ok "tone-by-context matrix present"
else fail "no tone-by-context matrix found"; fi

if has 'voice[- ]?dna|voice block|paste'; then ok "AI voice-DNA block present"
else fail "no AI voice-DNA block found"; fi

# --- ban list must exist and be non-empty (hard) ------------------------------
# A ban list is a line introducing it ("Ban list:", "Never use:") that also
# carries the actual terms after the colon — comma- and/or backtick-delimited.
# We isolate everything AFTER the colon on those lines; that is the term list.
MARK='ban[ -]?list|never use|words? to avoid|words? to ban'
BAN_TERMS_RAW="$(grep -Ei "($MARK)" "$FILE" 2>/dev/null \
  | sed -E 's/.*(ban[ -]?list|never use|words? to avoid|words? to ban)[^:]*:?//I' \
  | tr ',`' '\n\n' || true)"
# Keep single-word candidate terms (skip multi-word phrases for the word-grep).
BAN_TERMS="$(printf '%s\n' "$BAN_TERMS_RAW" \
  | grep -Eo '[A-Za-z][A-Za-z-]{3,}' \
  | grep -Eiv '^(ban|list|never|use|used|words?|to|avoid|the|incl|including|tell|tells|corporate|filler|drift|killer|say|starter|set)$' \
  | sort -u || true)"
if [ -n "$BAN_TERMS" ] || printf '%s' "$BAN_TERMS_RAW" | grep -q '[A-Za-z]'; then
  ok "ban list present and non-empty"
else
  fail "no non-empty ban list found — the ban list is the drift killer"
fi

# --- 2. trait count 3-5 (warn) ------------------------------------------------
# Heuristic: count "this means" lines, else count bullet/heading lines in the
# first traits block. Only warns; never fails.
TRAIT_N="$(grep -Eic 'this means' "$FILE" 2>/dev/null || true)"
TRAIT_N="${TRAIT_N:-0}"
if [ "$TRAIT_N" -gt 0 ]; then
  if [ "$TRAIT_N" -lt 3 ] || [ "$TRAIT_N" -gt 5 ]; then
    warn "found ~${TRAIT_N} traits (this-means lines) — aim for 3-5"
  else
    ok "trait count ~${TRAIT_N} (within 3-5)"
  fi
else
  warn "could not count traits (no 'this means' lines) — confirm 3-5 traits"
fi

# --- 3. brand-neutral filler used as a trait (warn) ---------------------------
FILLER='innovative|passionate|customer-focused|customer focused|cutting-edge|cutting edge|world-class'
# Look only where a trait would sit: a heading/line that is mostly that word.
F_HITS="$(grep -Eio "($FILLER)" "$FILE" 2>/dev/null | sort -u || true)"
if [ -n "$F_HITS" ]; then
  while IFS= read -r h; do
    [ -n "$h" ] && warn "brand-neutral filler present: \"$h\" — a rival never claims the opposite; pick a trait that excludes someone"
  done <<EOF
$F_HITS
EOF
else
  ok "no brand-neutral filler adjectives detected"
fi

# --- 4. self-consistency: prose uses its own banned words (warn) --------------
# Re-use the single-word ban terms parsed above. Grep the rest of the file
# (everything that is NOT a ban-list line) for each as a whole word.
SELF_HIT=0
if [ -n "$BAN_TERMS" ]; then
  # Prose = the file minus the ban-list lines themselves.
  PROSE="$(grep -Eiv "($MARK)" "$FILE" 2>/dev/null || true)"
  while IFS= read -r term; do
    [ -z "$term" ] && continue
    if printf '%s' "$PROSE" | grep -Eiqw "$term"; then
      warn "guide prose uses its own banned word: \"$term\" — practice what the guide preaches"
      SELF_HIT=$((SELF_HIT + 1))
    fi
  done <<EOF
$BAN_TERMS
EOF
fi
[ "$SELF_HIT" -eq 0 ] && ok "no self-contradiction (prose avoids its own ban list)"

# --- summary ------------------------------------------------------------------
printf '\n'
if [ "$fail_count" -gt 0 ]; then
  printf '%s%d hard failure(s), %d warning(s)%s\n' "$RED" "$fail_count" "$warn_count" "$NC"
  exit 1
fi
if [ "$warn_count" -gt 0 ]; then
  if [ "$STRICT" -eq 1 ]; then
    printf '%s%d warning(s) — failing under --strict%s\n' "$YELLOW" "$warn_count" "$NC"
    exit 1
  fi
  printf '%s%d warning(s), 0 hard failures%s\n' "$YELLOW" "$warn_count" "$NC"
  exit 0
fi
printf '%sall checks passed%s\n' "$GREEN" "$NC"
exit 0
