#!/usr/bin/env bash
set -euo pipefail

# verify.sh — analytics skill gate. Run from your PROJECT root (or pass a path).
#
# What it does (read-only, idempotent, NEVER connects to a network/SDK):
#   1. Discovers source files (js/ts/jsx/tsx/html/vue/svelte), skipping vendor dirs.
#   2. PII literals inside capture/track/gtag('event' calls            -> [fail]
#   3. GA4 event names breaking <=40 chars / leading-letter / charset  -> [fail]
#   4. GA present (gtag(/gtag.js) but no gtag('consent','default'      -> [fail] missing consent gate
#   5. posthog.init( with no host option nearby                        -> [warn] reverse-proxy reminder
#
# Exit non-zero ONLY on a hard failure (2,3,4), printing the offending file:line.
# Check 5 is advisory. An empty or clean target exits 0. Stock macOS bash 3.2.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="${1:-$(pwd)}"
if [ ! -e "$ROOT" ]; then skip "path not found: $ROOT — nothing to lint"; ok "verify.sh passed (empty target)"; exit 0; fi

FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.next/*' \
       -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/.venv/*' \) -prune -o \
    -type f \( -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' \
               -o -name '*.mjs' -o -name '*.cjs' -o -name '*.html' -o -name '*.vue' -o -name '*.svelte' \) \
    -print0 2>/dev/null
)

if [ "${#FILES[@]}" -eq 0 ]; then
  skip "no source files found under $ROOT — nothing to lint"
  ok "verify.sh passed (empty target)"
  exit 0
fi

# Lines that look like an analytics capture call.
CAPTURE_RE='(\.capture\(|posthog\.capture\(|\.track\(|gtag\([[:space:]]*['"'"'"]event['"'"'"])'
# PII key names that must never ride inside a capture call.
PII_RE='(email|e_mail|password|passwd|token|secret|api_?key|access_?key|ssn|credit_?card|card_?number|cvv|iban|phone_?number)'

GA_PRESENT=0
GA_CONSENT=0

for f in "${FILES[@]}"; do
  # --- (2) PII literals inside capture/track/gtag event calls (hard fail) ---
  while IFS= read -r hit; do
    [ -n "$hit" ] && err "$f:$hit — PII-looking key inside a capture/track call; scrub before sending"
  done < <(grep -nEi "$CAPTURE_RE" "$f" 2>/dev/null | grep -Ei "$PII_RE" | cut -d: -f1)

  # --- (3) GA4 event names breaking the rule (hard fail) ---
  # extract names from gtag('event', '<name>'...) and validate.
  while IFS= read -r ln; do
    lineno="${ln%%:*}"
    name="$(printf '%s' "$ln" | sed -E "s/.*gtag\([[:space:]]*['\"]event['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]*)['\"].*/\1/")"
    [ -z "$name" ] && continue
    if [ "${#name}" -gt 40 ]; then err "$f:$lineno — GA4 event name '$name' exceeds 40 chars"; fi
    if ! printf '%s' "$name" | grep -Eq '^[A-Za-z][A-Za-z0-9_]*$'; then
      err "$f:$lineno — GA4 event name '$name' must start with a letter and use only [A-Za-z0-9_]"
    fi
  done < <(grep -nE "gtag\([[:space:]]*['\"]event['\"]" "$f" 2>/dev/null)

  # --- track GA presence + consent for check (4) ---
  if grep -Eq "gtag\(|googletagmanager\.com/gtag/js" "$f" 2>/dev/null; then GA_PRESENT=1; fi
  if grep -Eq "gtag\([[:space:]]*['\"]consent['\"][[:space:]]*,[[:space:]]*['\"]default['\"]" "$f" 2>/dev/null; then GA_CONSENT=1; fi

  # --- (5) posthog.init with no host nearby (advisory) ---
  while IFS= read -r ln; do
    lineno="${ln%%:*}"
    # look at the init line and the 8 lines after it for api_host/ui_host/host.
    if ! sed -n "${lineno},$((lineno+8))p" "$f" 2>/dev/null | grep -Eq '(api_host|ui_host|[^a-z_]host)[[:space:]]*:'; then
      note "$f:$lineno — posthog.init( with no api_host/ui_host; consider a reverse proxy to dodge ad-blockers"
    fi
  done < <(grep -nE 'posthog\.init\(' "$f" 2>/dev/null)
done

# --- (4) GA present but no consent default gate (hard fail) ---
if [ "$GA_PRESENT" -eq 1 ] && [ "$GA_CONSENT" -eq 0 ]; then
  err "GA4/gtag detected but no gtag('consent','default', ...) gate found — required for EEA/UK since 21 Jul 2025"
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then
  ok "verify.sh passed — scanned ${#FILES[@]} file(s)"
else
  err "verify.sh found failures"
fi
exit "$EXIT"
