#!/usr/bin/env bash
# verify.sh — lint an email-connector integration for the four non-negotiables.
# Read-only. Scans .ts/.tsx/.js/.mjs files under TARGET (default: cwd).
# Exits 0 on a clean OR empty target (no email code = nothing to fail).
# Exits 1 with a one-line reason per violation found.
set -euo pipefail

TARGET="${1:-.}"
if [[ ! -e "$TARGET" ]]; then
  echo "verify: target not found: $TARGET" >&2
  exit 2
fi

# Collect candidate source files (portable, no mapfile dependency).
FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(
  find "$TARGET" -type f \
    \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.mjs' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' 2>/dev/null
)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "verify: no source files under '$TARGET' — nothing to check."
  exit 0
fi

# Is this even an email integration? If no provider is referenced, pass quietly.
PROVIDER_HITS=$(grep -rliE "from 'resend'|@sendgrid/mail|postmarkapp\.com|X-Postmark-Server-Token|resend\.emails\.|sgMail\.send|resend\.batch\." "${FILES[@]}" 2>/dev/null || true)
if [[ -z "$PROVIDER_HITS" ]]; then
  echo "verify: no email-provider code detected under '$TARGET' — nothing to check."
  exit 0
fi

fail=0
report() { echo "verify: FAIL — $1" >&2; fail=1; }

# 1) No hard-coded API keys / server tokens. Catch literal key prefixes in quotes.
if grep -rnE "['\"](re_[A-Za-z0-9_]{8,}|SG\.[A-Za-z0-9._-]{8,})['\"]" "${FILES[@]}" 2>/dev/null \
   | grep -vE "process\.env" >/dev/null; then
  report "hard-coded API key literal (re_… or SG.…) — read from process.env instead"
fi
# Postmark server token assigned to a literal rather than env.
if grep -rniE "X-Postmark-Server-Token['\"]?\s*[:,]\s*['\"][0-9a-f-]{16,}['\"]" "${FILES[@]}" 2>/dev/null >/dev/null; then
  report "hard-coded Postmark server token — read from process.env instead"
fi

# 2) Idempotency on transactional sends: either a Resend idempotencyKey,
#    or a self-dedupe table for SendGrid/Postmark.
HAS_IDEMP=$(grep -rliE "idempotencyKey|insertIfAbsent|sent_emails|sentEmails|dedupe|suppress" "${FILES[@]}" 2>/dev/null || true)
if [[ -z "$HAS_IDEMP" ]]; then
  report "no idempotency key or self-dedupe found on sends — retries will double-send"
fi

# 3) A sendEmail() seam exists (provider SDK behind one function).
HAS_SEAM=$(grep -rliE "function sendEmail|sendEmail\s*=|export .*sendEmail" "${FILES[@]}" 2>/dev/null || true)
if [[ -z "$HAS_SEAM" ]]; then
  report "no sendEmail() seam found — provider SDK should sit behind one function"
fi

# 4) If a webhook handler is present, it must verify a signature on the raw body.
WEBHOOK_FILES=$(grep -rliE "email\.bounced|email\.complained|SpamComplaint|RecordType|spamreport|webhook" "${FILES[@]}" 2>/dev/null || true)
if [[ -n "$WEBHOOK_FILES" ]]; then
  if ! grep -rliE "verif|signature|\.text\(\)|rawBody|svix" "${FILES[@]}" 2>/dev/null >/dev/null; then
    report "webhook handler present but no signature verification on the raw body"
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "verify: OK — env key, idempotency, sendEmail() seam, webhook signature all present."
exit 0
