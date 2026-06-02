#!/usr/bin/env bash
# verify.sh — Art. 13/14 completeness + reject-parity + boilerplate-lie check
# for a GDPR artifact (privacy policy / cookie-banner config / DPA / LIA).
# Read-only. Takes the artifact file as $1.
# No argument => prints usage and exits 0 (never blocks when not given an artifact).
# Exits non-zero only when a real artifact violates a rule.
set -euo pipefail

artifact="${1:-}"

if [ -z "$artifact" ]; then
  echo "usage: verify.sh <artifact-file>"
  echo "Checks a GDPR artifact for: missing Art. 13/14 disclosures in a privacy"
  echo "policy, placeholder/boilerplate-lie leftovers, and a cookie banner that"
  echo "has an accept control but no equally-available reject control."
  echo "No file given — nothing to check."
  exit 0
fi

if [ ! -f "$artifact" ]; then
  echo "verify.sh: not a file: $artifact" >&2
  exit 2
fi

fail=0

# --- Detect artifact type loosely by content (case-insensitive). ---
is_policy=0
if grep -niE 'privacy|personal data|pol[ií]tica de privacidad|pol[ií]tica de privacitat' "$artifact" >/dev/null; then
  is_policy=1
fi
is_banner=0
if grep -niE 'cookie' "$artifact" >/dev/null && grep -niE 'accept|aceptar|acceptar' "$artifact" >/dev/null; then
  is_banner=1
fi

# --- Privacy-policy completeness: each load-bearing Art. 13/14 token. ---
if [ "$is_policy" -eq 1 ]; then
  missing=""
  grep -niE 'lawful basis|legal basis|legitimate interest|consent|base (legal|jur[ií]dica)|contract' "$artifact" >/dev/null || missing="$missing lawful-basis"
  grep -niE 'right to|data[- ]subject right|access|erasure|rectification|portability|derechos' "$artifact" >/dev/null || missing="$missing data-subject-rights"
  grep -niE 'retention|retain|conservaci[óo]n|how long|retenci[óo]' "$artifact" >/dev/null || missing="$missing retention"
  grep -niE 'supervisory authorit|lodge a complaint|reclamaci[óo]n|autoridad de control|autoritat de control' "$artifact" >/dev/null || missing="$missing complaint-to-supervisory-authority"
  grep -niE 'contact|email|e-mail|address|contacto|contacte|@' "$artifact" >/dev/null || missing="$missing contact"
  if [ -n "$missing" ]; then
    echo "FAIL: privacy policy is missing required Art. 13/14 element(s):$missing"
    fail=1
  fi
fi

# --- Boilerplate-lie / placeholder leftovers (any artifact). ---
if grep -nE '\[[A-Z0-9 _./-]+\]' "$artifact" >/dev/null; then
  echo "FAIL: unfilled [BRACKET] placeholder(s) — finish the artifact:"
  grep -nE '\[[A-Z0-9 _./-]+\]' "$artifact" | sed 's/^/  /'
  fail=1
fi

if grep -niE 'any and all (data|information)' "$artifact" >/dev/null; then
  echo "FAIL: 'any and all data' catch-all — describe only what is actually processed:"
  grep -niE 'any and all (data|information)' "$artifact" | sed 's/^/  /'
  fail=1
fi

if grep -niE 'industry[- ]standard security' "$artifact" >/dev/null; then
  if ! grep -niE 'article 32|art\.? *32' "$artifact" >/dev/null; then
    echo "FAIL: 'industry-standard security' with no Article 32 reference — cite Art. 32 and the actual measures:"
    grep -niE 'industry[- ]standard security' "$artifact" | sed 's/^/  /'
    fail=1
  fi
fi

# --- Cookie banner: accept present but no reject control. ---
if [ "$is_banner" -eq 1 ]; then
  if ! grep -niE 'reject|decline|rebuig|rebutjar|rechazar|rechazo' "$artifact" >/dev/null; then
    echo "FAIL: cookie banner has an accept control but no reject/decline control —"
    echo "      reject must be as easy as accept (add an equal-weight Reject-all)."
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: $artifact passed Art. 13/14 completeness, placeholder, and reject-parity checks."
fi
exit "$fail"
