#!/usr/bin/env bash
#
# verify.sh — structural + banlist linter for a candidate chatbot SYSTEM PROMPT.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free checks over ONE system-prompt file you point it at
#   (markdown / plain text — e.g. system-prompt.md). It approximates the
#   output filter you'd run in production:
#     HARD FAILS:
#       1. A secret/credential pattern is present (API key, password, token,
#          bearer, "sk-..." style key)  -> never ship a secret in a prompt.
#       2. No refusal / forbidden-topic section (refuse|never|do not|not
#          authorized|forbidden)        -> the bot has no "no".
#       3. No handoff instruction (handoff|human|escalat|connect|agent|
#          representative)              -> no escape hatch.
#       4. No grounding/citation instruction (cite|source|knowledge|grounded|
#          retriev|only from|don.t know)-> nothing stops hallucination.
#       5. An unbounded-commitment phrase as an instruction the bot would say
#          ("we guarantee", "any price", "always refund", "unlimited",
#          "100% money back", "we promise", "best price guaranteed").
#     WARN (heuristic; not a hard fail):
#       - No explicit length cap mentioned (word|character|sentence limit).
#       - No injection-defense language (ignore previous|instruction
#         hierarchy|data not instructions|reveal ... prompt).
#
#   A clean OR empty/whitespace-only file exits 0 — never a false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh system-prompt.md
#   ./verify.sh prompt.txt --strict     # treat warnings as failures (CI gate)
#   ./verify.sh                         # defaults to ./system-prompt.md if present
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/missing-content file
#   1  a hard failure (secret / missing required section / commitment phrase)
#      — or any warning under --strict
#   2  bad usage (file given but does not exist)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

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

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

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

# Default target: only if it actually exists. Empty/clean target must not fail.
if [ -z "$FILE" ]; then
  if [ -f "system-prompt.md" ]; then FILE="system-prompt.md"
  elif [ -f "system-prompt.txt" ]; then FILE="system-prompt.txt"
  else
    ok "no system-prompt file given and no default found — nothing to check"
    exit 0
  fi
fi

if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  ok "empty file — nothing to check"
  exit 0
fi

printf 'chatbot verify — %s\n\n' "$FILE"

has() { grep -Eiq "$1" "$FILE" 2>/dev/null; }

# --- 1. secrets / credentials (HARD) ------------------------------------------
SECRET='(sk-[a-z0-9]{8,})|(api[_ -]?key)|(secret[_ -]?key)|(password\s*[:=])|(bearer\s+[a-z0-9._-]{8,})|(access[_ -]?token)|(client[_ -]?secret)|(-----BEGIN [A-Z ]*PRIVATE KEY-----)'
if grep -Eiq "$SECRET" "$FILE" 2>/dev/null; then
  fail "possible secret/credential in the prompt — a system prompt is semi-public; remove all keys/passwords/tokens"
else
  ok "no obvious secret/credential pattern"
fi

# --- 2. refusal / forbidden-topic section (HARD) ------------------------------
if has 'refus|(^|[^a-z])never([^a-z]|$)|do not|don.t|not authorized|forbidden|must not|out of scope'; then
  ok "refusal / forbidden-topic language present"
else
  fail "no refusal / forbidden-topic section — the bot needs an explicit 'no' (refuse/never/not authorized)"
fi

# --- 3. handoff instruction (HARD) --------------------------------------------
if has 'hand[ -]?off|handoff|human|escalat|connect you|connect to|representative|(^|[^a-z])agent([^a-z]|$)|live (person|team)'; then
  ok "handoff / human-escalation instruction present"
else
  fail "no handoff instruction — every bot needs an escape hatch to a human (handoff/human/escalate/connect)"
fi

# --- 4. grounding / citation instruction (HARD) -------------------------------
if has 'cite|source|knowledge|grounded|retriev|only (from|using)|don.t (have|know)|do not have|excerpt'; then
  ok "grounding / citation instruction present"
else
  fail "no grounding/citation instruction — answers must be grounded in the KB (cite/source/knowledge/only-from)"
fi

# --- 5. unbounded-commitment phrases (HARD) -----------------------------------
COMMIT='we guarantee|guaranteed|any price|always refund|unlimited|100% money[ -]?back|money[ -]?back guarantee|we promise|best price guarantee|we will always|whatever (it takes|you want)|name your price'
C_HITS="$(grep -Eio "$COMMIT" "$FILE" 2>/dev/null | sort -u || true)"
if [ -n "$C_HITS" ]; then
  while IFS= read -r h; do
    [ -n "$h" ] && fail "unbounded-commitment phrase present: \"$h\" — the bot must not promise terms a human hasn't approved (Air Canada / Chevy)"
  done <<EOF
$C_HITS
EOF
else
  ok "no unbounded-commitment phrases"
fi

# --- 6. length cap (WARN) -----------------------------------------------------
if has '(word|character|char|sentence)s?[^.]{0,20}(limit|cap|max|under|fewer|less than)|under ~?[0-9]+ words|keep.*(short|brief|concise)'; then
  ok "length cap mentioned"
else
  warn "no explicit length cap found — a hard reply cap stops a coaxed long answer from smuggling a promise"
fi

# --- 7. injection-defense language (WARN) -------------------------------------
if has 'ignore (previous|prior|the above)|instruction hierarchy|data,? not (commands|instructions)|reveal.*(prompt|instruction)|outrank|treat .* as data'; then
  ok "prompt-injection defense language present"
else
  warn "no prompt-injection defense language — state the instruction hierarchy and refuse 'ignore previous / reveal prompt' patterns"
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
