#!/usr/bin/env bash
# verify.sh — read-only static lint for AWS IAM/policy/config artifacts.
#
# Mirrors the SKILL.md anti-patterns table so the advice is enforceable. It scans
# JSON / .tf / .yaml / .yml / .sh / .env-ish files under TARGET (default ".") for
# dangerous patterns. It is a LINT — no AWS API calls, no credentials, deterministic,
# CI-safe. Read-only: it never writes or mutates anything.
#
# Rules:
#   1. Full-admin policy:     "Action":"*"  together with  "Resource":"*"
#   2. AdministratorAccess attached/referenced (god-mode managed policy)
#   3. Public S3 bucket policy: Effect Allow with "Principal":"*" (or {"AWS":"*"})
#   4. Legacy OAI:            origin-access-identity / OriginAccessIdentity (non-empty)
#   5. Long-lived keys:       AKIA... access-key id, or aws_secret_access_key literal
#   6. Open DB ingress:       0.0.0.0/0 on or near port 5432 / 3306
#
# Exits 1 with file:line + rule on any hit. Exits 0 on a clean OR empty target.
# Usage: verify.sh [TARGET_DIR_OR_FILE]

set -uo pipefail

TARGET="${1:-.}"
fail=0

hit() { printf 'FAIL [%s] %s:%s — %s\n' "$1" "$2" "$3" "$4" >&2; fail=1; }
note() { printf '%s\n' "$1"; }

if [ ! -e "$TARGET" ]; then
  note "verify: target does not exist: $TARGET — nothing to check."
  exit 0
fi

# Collect candidate files. No matches => clean/empty => exit 0.
files=()
if [ -f "$TARGET" ]; then
  files=("$TARGET")
else
  while IFS= read -r f; do
    files+=("$f")
  done < <(find "$TARGET" -type f \
    \( -name '*.json' -o -name '*.tf' -o -name '*.yaml' -o -name '*.yml' \
       -o -name '*.sh' -o -name '*.env' -o -name '*.tfvars' \) \
    -not -path '*/.git/*' 2>/dev/null)
fi

if [ "${#files[@]}" -eq 0 ]; then
  note "verify: no AWS policy/config files found under $TARGET — nothing to check."
  exit 0
fi

for f in "${files[@]}"; do
  # Strip CR so Windows-edited files match cleanly.
  content=$(tr -d '\r' < "$f")

  # --- Rule 1: full-admin "*"/"*" (file-level: both appear in the same file) ---
  if printf '%s' "$content" | grep -Eq '"Action"[[:space:]]*:[[:space:]]*"\*"' \
     && printf '%s' "$content" | grep -Eq '"Resource"[[:space:]]*:[[:space:]]*"\*"'; then
    ln=$(grep -nE '"Action"[[:space:]]*:[[:space:]]*"\*"' "$f" | head -n1 | cut -d: -f1)
    hit "full-admin" "$f" "${ln:-?}" 'policy grants Action "*" on Resource "*" — scope to specific actions+ARNs'
  fi

  # --- Rule 2: AdministratorAccess ---
  while IFS=: read -r ln _; do
    [ -n "$ln" ] && hit "admin-access" "$f" "$ln" 'AdministratorAccess referenced — scope an app/task role to least privilege'
  done < <(grep -nE 'AdministratorAccess' "$f" 2>/dev/null)

  # --- Rule 3: public S3 / resource policy (Principal "*") ---
  while IFS=: read -r ln _; do
    [ -n "$ln" ] && hit "public-principal" "$f" "$ln" 'resource policy with Principal "*" — bucket/resource is public; scope to a specific ARN'
  done < <(grep -nE '"Principal"[[:space:]]*:[[:space:]]*("\*"|\{[[:space:]]*"AWS"[[:space:]]*:[[:space:]]*"\*")' "$f" 2>/dev/null)

  # --- Rule 4: legacy OAI (ignore the empty-string OAC form "OriginAccessIdentity":"") ---
  while IFS=: read -r ln rest; do
    [ -z "$ln" ] && continue
    # Skip the legitimate empty OAC form.
    printf '%s' "$rest" | grep -Eq 'OriginAccessIdentity"[[:space:]]*:[[:space:]]*""' && continue
    hit "legacy-oai" "$f" "$ln" 'origin-access-identity (OAI) is legacy — use Origin Access Control (OAC)'
  done < <(grep -nE 'origin-access-identity|OriginAccessIdentity"[[:space:]]*:[[:space:]]*"[^"]+|create-cloud-front-origin-access-identity' "$f" 2>/dev/null)

  # --- Rule 5: long-lived access keys ---
  while IFS=: read -r ln _; do
    [ -n "$ln" ] && hit "long-lived-key" "$f" "$ln" 'looks like an AWS access key id (AKIA…) — use a role / temporary credentials'
  done < <(grep -nE '\bAKIA[0-9A-Z]{16}\b' "$f" 2>/dev/null)
  while IFS=: read -r ln _; do
    [ -n "$ln" ] && hit "long-lived-key" "$f" "$ln" 'aws_secret_access_key literal — secrets belong in Secrets Manager / OIDC, not code'
  done < <(grep -niE 'aws_secret_access_key[[:space:]]*[:=]' "$f" 2>/dev/null)

  # --- Rule 6: open DB ingress (0.0.0.0/0 near a DB port) ---
  while IFS=: read -r ln _; do
    [ -n "$ln" ] && hit "open-db-sg" "$f" "$ln" 'DB port (5432/3306) ingress from 0.0.0.0/0 — reference the app security group, never the internet'
  done < <(grep -nE '(5432|3306).*0\.0\.0\.0/0|0\.0\.0\.0/0.*(5432|3306)' "$f" 2>/dev/null)
done

if [ "$fail" -ne 0 ]; then
  note "verify: AWS artifact lint FAILED — fix the issues above."
  exit 1
fi
note "verify: all scanned AWS policy/config files pass the lint."
exit 0
