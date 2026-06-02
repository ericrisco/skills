#!/usr/bin/env bash
#
# verify.sh — structural guardrail for a drafted cold email / sequence.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free checks over ONE draft file you point it at (a cold
#   email or a multi-step sequence in plain text / markdown):
#     1. First-touch length: the first message block's body is over ~80 words
#        -> warn (soft; brevity is a strong preference, not a law).
#     2. Single binary CTA: more than one question-mark line ("?") in the first
#        touch -> warn (a cold first touch should ask exactly one binary thing).
#     3. Opt-out present: no unsubscribe / opt-out / "reply stop" line anywhere
#        -> FAIL (CAN-SPAM/GDPR hard requirement).
#     4. Postal address present: no street-style postal-address placeholder
#        (a line with a digit + a street/PO token, or an explicit
#        {{address}} / [address] placeholder) -> FAIL (CAN-SPAM requirement).
#     5. Banlist: spam-trigger + AI-tell phrases ("I hope this email finds you
#        well", "just circling back", "just following up", "act now",
#        "100% free", "free guide", "guarantee(d)", "limited time",
#        "to whom it may concern", "I came across your") -> warn each hit.
#     6. Unfilled template slots ({{...}}, [SLOT], ???) outside the address
#        line -> warn (fill before sending).
#
#   Only #3 and #4 are hard failures. Everything else is a warning. A clean OR
#   empty/missing-content file exits 0 — never a false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh draft.md                 # warnings + hard checks
#   ./verify.sh draft.md --ceiling 100   # raise the first-touch word ceiling
#   ./verify.sh draft.md --strict        # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/missing-content file
#   1  a hard failure (no opt-out, or no postal address) — or any warning under --strict
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

usage() { sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
CEILING=80
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --ceiling) CEILING="${2:-80}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

if [ -z "$FILE" ]; then
  printf '%sno draft file given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  ok "empty file — nothing to check"
  exit 0
fi

printf 'cold-outreach verify — %s (ceiling=%s words)\n\n' "$FILE" "$CEILING"

# --- isolate the first-touch block --------------------------------------------
# Heuristic: the first touch ends at the first "STEP 2", "Day +", "Follow-up",
# or a markdown heading after content. We grab everything up to that marker,
# then strip subject/footer-ish lines for the word count.
FIRST_BLOCK="$(awk '
  NR==1 {seen=0}
  /^[[:space:]]*(STEP[[:space:]]*2|Follow[- ]?up[[:space:]]*2|Day[[:space:]]*\+|DM[[:space:]]*2|##[[:space:]])/ && seen {exit}
  /[^[:space:]]/ {seen=1}
  {print}
' "$FILE")"

# Body words: drop subject lines, unsubscribe/footer lines, and address lines.
FIRST_WORDS="$(printf '%s\n' "$FIRST_BLOCK" \
  | grep -iv -e '^[[:space:]]*subject:' -e '^[[:space:]]*asunto:' \
             -e 'unsubscribe' -e 'opt[- ]out' -e 'reply "stop"' -e 'reply stop' \
  | tr -s '[:space:]' '\n' | grep -c '[^[:space:]]' || true)"

if [ "${FIRST_WORDS:-0}" -gt "$CEILING" ]; then
  warn "first touch is ~${FIRST_WORDS} words (over the ${CEILING}-word ceiling) — tighten it"
else
  ok "first-touch length ~${FIRST_WORDS} words (<= ${CEILING})"
fi

# --- single binary CTA in the first touch -------------------------------------
CTA_LINES="$(printf '%s\n' "$FIRST_BLOCK" | grep -c '?' || true)"
if [ "${CTA_LINES:-0}" -gt 1 ]; then
  warn "first touch has ${CTA_LINES} question lines — a cold first touch should ask exactly one binary thing"
elif [ "${CTA_LINES:-0}" -eq 0 ]; then
  warn "first touch has no question-mark CTA — add one binary yes/no ask"
else
  ok "first touch has exactly one CTA line"
fi

# --- opt-out present (hard) ----------------------------------------------------
if grep -Eiq 'unsubscribe|opt[- ]out|reply[[:space:]]+["'\'']?stop|darse de baja|cancelar la suscripci' "$FILE"; then
  ok "opt-out / unsubscribe line present"
else
  fail "no opt-out / unsubscribe line found — CAN-SPAM/GDPR requires a working opt-out"
fi

# --- postal address present (hard) --------------------------------------------
# Accept either an explicit placeholder or a line that looks like a street addr.
if grep -Eiq '\{\{[[:space:]]*(postal[_ ]?)?address|\[[[:space:]]*(postal[_ ]?)?address' "$FILE" \
   || grep -Eiq '[0-9]+[[:space:]].*(street|st\.|ave|avenue|road|rd\.|blvd|suite|ste\.|p\.?o\.? box|calle|carrer|via)' "$FILE"; then
  ok "postal address (or placeholder) present"
else
  fail "no physical postal address found — CAN-SPAM requires one (a {{address}} placeholder counts)"
fi

# --- banlist: spam-trigger + AI-tell phrases ----------------------------------
BAN='i hope this email finds you well|just circling back|just following up|circling back|act now|100% free|free guide|guarantee|limited time|to whom it may concern|i came across your|dear sir or madam'
HITS="$(grep -Eio "$BAN" "$FILE" 2>/dev/null | sort -u || true)"
if [ -n "$HITS" ]; then
  while IFS= read -r h; do
    [ -n "$h" ] && warn "banned phrase present: \"$h\" (spam-trigger / AI-tell — rewrite)"
  done <<EOF
$HITS
EOF
else
  ok "no banned spam/AI-tell phrases"
fi

# --- unfilled template slots (ignore the address-placeholder convenience) -----
SLOTS="$(grep -Eo '\{\{[^}]*\}\}|\?\?\?|\[[A-Z_]{3,}\]' "$FILE" 2>/dev/null \
  | grep -Eiv '\{\{[[:space:]]*(postal[_ ]?)?address|\[[[:space:]]*(POSTAL[_ ]?)?ADDRESS' \
  | sort -u || true)"
if [ -n "$SLOTS" ]; then
  SLOT_N="$(printf '%s\n' "$SLOTS" | grep -c '[^[:space:]]' || true)"
  warn "${SLOT_N} unfilled template slot(s) remain (e.g. $(printf '%s' "$SLOTS" | head -1)) — fill before sending"
else
  ok "no unfilled template slots"
fi

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
