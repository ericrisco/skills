#!/usr/bin/env bash
# verify.sh — read-only static check of an e-signature integration artifact.
# Greps the produced code for the must-haves of a safe signing flow.
# It does NOT call any live API and never modifies files.
#
# Usage: scripts/verify.sh [path]   (default: current directory)
# Exit:  0 = clean / nothing to flag, 1 = at least one FAIL.

set -euo pipefail

TARGET="${1:-.}"

if [ ! -e "$TARGET" ]; then
  echo "verify.sh: target '$TARGET' does not exist" >&2
  exit 1
fi

# Collect candidate source files (signing-integration code). Empty list => clean pass.
FILES=()
while IFS= read -r f; do
  [ -n "$f" ] && FILES+=("$f")
done < <(
  grep -rIl -E 'docusign|dropbox/sign|signature_request|EnvelopesApi|SignatureRequestApi|event_hash|X-DocuSign-Signature' \
    --include='*.js' --include='*.ts' --include='*.mjs' --include='*.cjs' \
    --include='*.py' --include='*.go' --include='*.rb' \
    "$TARGET" 2>/dev/null || true
)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "PASS: no e-signature integration code found in '$TARGET' (nothing to check)"
  exit 0
fi

echo "Checking ${#FILES[@]} file(s) under '$TARGET'..."
FAIL=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

# Search helper: matches pattern, excluding comment/TODO-only lines.
has_real() {
  # $1 = ERE pattern
  grep -rIhE "$1" "${FILES[@]}" 2>/dev/null \
    | grep -vE '^\s*(//|#|\*)' \
    | grep -viE 'TODO|FIXME|XXX' \
    | grep -q .
}

# 1. Webhook signature verification present (and not only a TODO).
if has_real 'createHmac|hmac\.new|X-DocuSign-Signature|event_hash|timingSafeEqual|compare_digest'; then
  pass "webhook signature verification present"
else
  fail "no webhook signature verification (expected HMAC / event_hash / X-DocuSign-Signature check)"
fi

# 2. No hardcoded API key or private key in source.
if grep -rIhE 'hs_live_|BEGIN (RSA )?PRIVATE KEY|api[_-]?key\s*[:=]\s*["'"'"'][A-Za-z0-9]{16,}' "${FILES[@]}" 2>/dev/null | grep -q .; then
  fail "hardcoded secret detected (API key or PRIVATE KEY literal in source)"
else
  pass "no hardcoded API key / private key literal"
fi

# 3. Sandbox / test_mode guard present.
if has_real 'demo\.docusign\.net|account-d\.docusign\.com|test_?[mM]ode'; then
  pass "sandbox / test_mode guard present"
else
  fail "no sandbox guard (expected demo.docusign.net or test_mode)"
fi

# 4. Completion path retrieves signed PDF + audit trail / certificate.
if has_real 'certificate|audit'; then
  pass "completion retrieves audit trail / certificate"
else
  fail "completion path does not retrieve the audit trail / Certificate of Completion"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "verify.sh: one or more checks FAILED"
  exit 1
fi
echo "verify.sh: all checks passed"
exit 0
