#!/usr/bin/env bash
set -euo pipefail

# verify.sh — whatsapp-telegram integration gate. Read-only, never writes.
#
# Statically greps the integration code in the TARGET dir (arg 1, default: cwd) for the known
# WhatsApp/Telegram footguns this skill warns about:
#   1. Every WhatsApp Graph send URL pins a version — fail on a versionless graph.facebook.com call.
#   2. No hardcoded WhatsApp bearer tokens (EAA...) or Telegram bot tokens (\d{8,10}:[A-Za-z0-9_-]{35}).
#   3. A file that polls getUpdates must not also call setWebhook (mutually exclusive).
#   4. Advisory: if a free-form WhatsApp send exists, a template-send path should exist too.
#
# Artifact-conditional: if no integration files are found, exit 0 with a [skip] (safe to run
# anywhere — an empty/clean target NEVER fails). Exit non-zero ONLY on a real footgun, with paths.
#
# Portability: stock macOS bash 3.2 — no mapfile, no associative arrays, arrays initialised.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

TARGET="${1:-$(pwd)}"
if [ ! -d "$TARGET" ]; then
  skip "target '$TARGET' is not a directory — nothing to check"
  exit 0
fi

# Collect candidate integration source files (skip deps / vcs / build output). Initialised array.
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(find "$TARGET" \
  \( -path '*/node_modules' -o -path '*/.git' -o -path '*/dist' -o -path '*/build' -o -path '*/.next' -o -path '*/vendor' \) -prune -o \
  -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.mjs' -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.sh' -o -name '*.json' \) -print0 2>/dev/null)

# Keep only files that actually touch one of the two platforms.
RELEVANT=()
for f in "${FILES[@]:-}"; do
  [ -n "$f" ] || continue
  if grep -Eql 'graph\.facebook\.com|api\.telegram\.org|messaging_product' "$f" 2>/dev/null; then
    RELEVANT+=("$f")
  fi
done

if [ "${#RELEVANT[@]:-0}" -eq 0 ]; then
  skip "no WhatsApp/Telegram integration files found under $TARGET — nothing to check"
  exit 0
fi
ok "scanning ${#RELEVANT[@]} integration file(s)"

# ---- 1. WhatsApp Graph URL must pin a version ----
HITS="$(grep -EnH 'graph\.facebook\.com/[^v"'"'"'\`/[:space:]]' "${RELEVANT[@]}" 2>/dev/null \
  | grep -Ev 'graph\.facebook\.com/v[0-9]+' || true)"
if [ -n "$HITS" ]; then
  err "versionless graph.facebook.com URL (pin v25.0):"
  printf '%s\n' "$HITS"
else
  ok "WhatsApp Graph URLs are version-pinned"
fi

# ---- 2. no hardcoded tokens ----
# WhatsApp access tokens start EAA...; Telegram bot tokens look like 123456789:AA....(35 chars).
TOK="$(grep -EnH "EAA[A-Za-z0-9_-]{20,}|[0-9]{8,10}:[A-Za-z0-9_-]{35}" "${RELEVANT[@]}" 2>/dev/null || true)"
if [ -n "$TOK" ]; then
  err "hardcoded token literal (move to an env var):"
  printf '%s\n' "$TOK"
else
  ok "no hardcoded WhatsApp/Telegram token literals"
fi

# ---- 3. setWebhook and getUpdates not in the same file ----
for f in "${RELEVANT[@]}"; do
  if grep -Eql 'getUpdates' "$f" 2>/dev/null && grep -Eql 'setWebhook' "$f" 2>/dev/null; then
    err "both getUpdates and setWebhook in one file (pick one): $f"
  fi
done
if [ "$EXIT" -eq 0 ]; then ok "no getUpdates+setWebhook conflict"; fi

# ---- 4. advisory: free-form send should pair with a template path ----
if grep -Eql '"type"[[:space:]]*:[[:space:]]*"text"|type:[[:space:]]*"text"' "${RELEVANT[@]}" 2>/dev/null; then
  if ! grep -Eql '"type"[[:space:]]*:[[:space:]]*"template"|type:[[:space:]]*"template"' "${RELEVANT[@]}" 2>/dev/null; then
    skip "advisory: free-form WhatsApp send found but no template path — out-of-window sends will hit #131047"
  fi
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found footguns"; fi
exit "$EXIT"
