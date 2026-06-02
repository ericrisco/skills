#!/usr/bin/env bash
# verify.sh — static, offline checks for the fal skill's worked code.
# Read-only. No network, no real FAL_KEY. Exit 0 on a clean/empty target.
#
# Usage: scripts/verify.sh [TARGET_DIR]
#   TARGET_DIR defaults to the skill root (parent of this script's dir).
# Checks the SKILL.md + references code fences for:
#   1. no deprecated @fal-ai/serverless-client (must use @fal-ai/client)
#   2. webhook section names all four X-Fal-Webhook-* headers + the JWKS URL
#   3. long-job guidance uses submit/webhook_url and flags run as not-for-long-jobs
#   4. FAL_KEY is referenced and no hardcoded key literal is present

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${1:-$(cd "$here/.." && pwd)}"

fail=0
note() { printf '  - %s\n' "$1"; }
err()  { printf 'FAIL: %s\n' "$1"; fail=1; }

# Gather the skill's markdown files. Empty target => nothing to check => pass.
# Portable to bash 3.2 (default macOS) — no mapfile.
files="$(find "$target" -type f -name '*.md' 2>/dev/null | sort)"
if [ -z "$files" ]; then
  echo "verify(fal): no markdown files under $target — nothing to check."
  exit 0
fi
file_count="$(printf '%s\n' "$files" | wc -l | tr -d ' ')"

# Concatenated corpus for grep (read-only).
corpus="$(printf '%s\n' "$files" | while IFS= read -r f; do cat "$f"; done 2>/dev/null || true)"

# 1. deprecated client must not appear.
if grep -q '@fal-ai/serverless-client' <<<"$corpus"; then
  # Allowed only when explicitly flagged as deprecated/NOT/migrate on the same line.
  if grep '@fal-ai/serverless-client' <<<"$corpus" \
       | grep -qviE 'deprecat|NOT |migrate|anti-pattern'; then
    err "deprecated @fal-ai/serverless-client referenced without a deprecation flag"
  fi
fi
grep -q '@fal-ai/client' <<<"$corpus" || err "current @fal-ai/client never referenced"

# 2. webhook headers + JWKS URL (only enforce if a webhook section exists).
if grep -qi 'webhook' <<<"$corpus"; then
  for h in X-Fal-Webhook-Request-Id X-Fal-Webhook-User-Id \
           X-Fal-Webhook-Timestamp X-Fal-Webhook-Signature; do
    grep -qi "$h" <<<"$corpus" || err "webhook header $h not documented"
  done
  grep -q 'rest.fal.ai/.well-known/jwks.json' <<<"$corpus" \
    || err "JWKS URL rest.fal.ai/.well-known/jwks.json not referenced"
fi

# 3. long-job guidance: submit/webhook present, run flagged as not-for-long-jobs.
grep -qiE 'webhook_url|webhookUrl' <<<"$corpus" || err "webhook_url not in guidance"
grep -qi 'submit' <<<"$corpus" || err "submit call mode not documented"
grep -qiE 'run.*(drop|long|no queue|few second)' <<<"$corpus" \
  || err "'run' not flagged as unsuitable for long jobs"

# 4. FAL_KEY referenced; no hardcoded key literal.
grep -q 'FAL_KEY' <<<"$corpus" || err "FAL_KEY auth not referenced"
# A real key looks like key_id:key_secret with long hex-ish parts; placeholders are fine.
if grep -oE 'key_[0-9a-f]{16,}:[0-9a-f]{16,}' <<<"$corpus" >/dev/null; then
  err "a hardcoded FAL_KEY literal appears in the docs"
fi

if [ "$fail" -ne 0 ]; then
  echo "verify(fal): checks failed."
  exit 1
fi
echo "verify(fal): all static checks passed ($file_count files)."
exit 0
