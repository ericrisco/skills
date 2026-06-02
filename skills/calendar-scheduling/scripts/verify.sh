#!/usr/bin/env bash
# verify.sh — calendar-scheduling lint. Run inside YOUR project against the
# generated scheduling integration. Read-only: it greps, it never edits.
#
# Usage:
#   bash scripts/verify.sh [path]      # default path: .
#
# Lints three definite booking hazards (a lint, not a build):
#   1. Over-broad Google scope — restricted auth/calendar or auth/calendar.events
#      requested where a narrower scope (calendar.freebusy, calendar.app.created,
#      calendar.events.owned) would do.
#   2. Timezone hazard — a Google event payload with a dateTime but no timeZone.
#   3. Webhook unsafety — a booking webhook handler with neither a signature
#      verification nor an idempotency key.
#
# Exit non-zero ONLY on a definite hazard. Empty/clean target -> exit 0.
# Prose-only configs (docs, READMEs) pass the scope/timezone checks.
#
# Env: NO_COLOR=1 disables color.
# Portability: stock macOS bash 3.2 and CI bash 5. No mapfile, no bash-4 features.
set -euo pipefail

ROOT="${1:-.}"

if [[ -n "${NO_COLOR:-}" ]]; then YEL=""; GRN=""; RED=""; RST=""
else YEL=$'\033[33m'; GRN=$'\033[32m'; RED=$'\033[31m'; RST=$'\033[0m'; fi
warn() { printf '%s[skip]%s %s\n' "$YEL" "$RST" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$GRN" "$RST" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED" "$RST" "$*"; }

if [[ ! -e "$ROOT" ]]; then warn "path not found: $ROOT (nothing to lint)"; exit 0; fi

# Collect candidate source files (NUL-delimited; bash-3.2-safe, no mapfile).
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(find "$ROOT" \
  \( -path '*/node_modules/*' -o -path '*/vendor/*' -o -path '*/.git/*' \
     -o -path '*/dist/*' -o -path '*/build/*' \) -prune \
  -o -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
     -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.json' \
     -o -name '*.yaml' -o -name '*.yml' -o -name '*.env*' \) -print0 2>/dev/null)

if [[ ${#FILES[@]} -eq 0 ]]; then
  ok "no scheduling source files under $ROOT — nothing to lint"
  exit 0
fi

FAILED=0

# 1. Over-broad Google scope. The restricted scopes are the full-string forms;
#    do not flag the granular .freebusy/.app.created/.events.owned/.readonly ones.
SCOPE_HITS=""
for f in ${FILES[@]+"${FILES[@]}"}; do
  if grep -Eq 'auth/calendar(\.events)?["'\'' ,)]' "$f" 2>/dev/null \
     || grep -Eq 'auth/calendar(\.events)?$' "$f" 2>/dev/null; then
    # exclude lines that are actually a narrower scope
    if grep -E 'auth/calendar(\.events)?["'\'' ,)$]' "$f" 2>/dev/null \
        | grep -Ev 'freebusy|app\.created|events\.owned|readonly|events\.freebusy' >/dev/null 2>&1; then
      SCOPE_HITS="$SCOPE_HITS $f"
    fi
  fi
done
if [[ -n "$SCOPE_HITS" ]]; then
  fail "restricted Google scope (auth/calendar or auth/calendar.events) found in:$SCOPE_HITS"
  fail "  -> use calendar.freebusy / calendar.app.created / calendar.events.owned to avoid the security assessment"
  FAILED=1
else
  ok "no over-broad Google calendar scopes"
fi

# 2. Timezone hazard — a Google event payload with dateTime but no timeZone in
#    the same file. Heuristic: files mentioning dateTime must also mention timeZone.
TZ_HITS=""
for f in ${FILES[@]+"${FILES[@]}"}; do
  if grep -q 'dateTime' "$f" 2>/dev/null; then
    if ! grep -q 'timeZone' "$f" 2>/dev/null; then
      TZ_HITS="$TZ_HITS $f"
    fi
  fi
done
if [[ -n "$TZ_HITS" ]]; then
  fail "event payload uses dateTime without timeZone (drifts after DST) in:$TZ_HITS"
  fail "  -> set timeZone (IANA id) on start/end; store the instant in UTC"
  FAILED=1
else
  ok "no naive datetime payloads (timeZone present where dateTime is)"
fi

# 3. Webhook unsafety — a booking webhook handler with neither signature
#    verification nor an idempotency key.
WH_HITS=""
for f in ${FILES[@]+"${FILES[@]}"}; do
  if grep -Eiq 'invitee\.(created|canceled)|BOOKING_(CREATED|CANCELLED|RESCHEDULED)|webhook' "$f" 2>/dev/null; then
    has_sig=0; has_idem=0
    grep -Eiq 'signature|verifySignature|constructEvent|x-cal-signature|x-hook-signature|hmac' "$f" 2>/dev/null && has_sig=1
    grep -Eiq 'idempoten|dedupe|event[_.]?id|already[_ ]?processed' "$f" 2>/dev/null && has_idem=1
    if [[ $has_sig -eq 0 && $has_idem -eq 0 ]]; then
      WH_HITS="$WH_HITS $f"
    fi
  fi
done
if [[ -n "$WH_HITS" ]]; then
  fail "booking webhook handler with no signature verification AND no idempotency key in:$WH_HITS"
  fail "  -> verify the provider signature and dedupe on the provider event id"
  FAILED=1
else
  ok "booking webhook handlers verify a signature or dedupe (or none present)"
fi

echo
if [[ $FAILED -ne 0 ]]; then
  fail "calendar-scheduling lint found definite hazards above"
  exit 1
fi
ok "calendar-scheduling lint clean"
exit 0
