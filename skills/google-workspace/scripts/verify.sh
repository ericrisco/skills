#!/usr/bin/env bash
#
# verify.sh — credential + scope preflight linter for Google Workspace
# integration code. NO network. Scans a target dir for the dangerous/wrong
# patterns this skill bans, and exits non-zero on any hit.
#
# Read-only. Never writes, edits, or sends anything.
#
# Checks:
#   1. Tracked service-account key files: a *.json containing "private_key"
#      and a service-account marker (client_email / .iam.gserviceaccount.com) —
#      a committed SA key.
#   2. Over-broad scope where a narrower variant exists:
#        .../auth/drive    (use drive.file / drive.readonly)
#        .../auth/gmail     [bare] (use gmail.send / gmail.readonly)
#        .../mail.google.com/      (full mailbox incl. delete)
#   3. Hardcoded private key in source: a literal "-----BEGIN PRIVATE KEY-----".
#   4. Workspace API calls (googleapis / googleapiclient) with no backoff/retry
#      helper anywhere in the file (informational WARN, not a hard fail).
#
# Usage:
#   scripts/verify.sh [PATH ...]
#     PATH = a file or directory. With no PATH, scans the current directory.
#
# Exit 0 = no banned pattern found (an empty/clean target is a pass).
# Exit 1 = at least one hard finding (checks 1-3).
# Exit 2 = a usage / environment problem.

set -euo pipefail

# This script intentionally contains the banned patterns as documentation /
# match literals; never let it flag itself. grep -rn emits a "<path>:<line>:..."
# prefix whose <path> is relative or absolute depending on how the target was
# named, so we cannot match the absolute $SELF. Instead, strip any hit whose
# path component (everything before the first ":") basenames to this script.
SELF_BASE="$(basename "${BASH_SOURCE[0]}")"
drop_self() {
  awk -v self="$SELF_BASE" -F: '{
    p = $1
    n = split(p, parts, "/")
    if (parts[n] != self) print
  }'
}

if [ "$#" -eq 0 ]; then
  set -- "."
fi

declare -a TARGETS=()
for t in "$@"; do
  if [ -e "$t" ]; then
    TARGETS+=("$t")
  else
    echo "verify.sh: no such path: $t" >&2
  fi
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "verify.sh: nothing to scan"
  exit 0
fi

# Source extensions we lint, and dirs we skip.
SRC_INCLUDE=(--include='*.js' --include='*.mjs' --include='*.cjs'
  --include='*.ts' --include='*.tsx' --include='*.py' --include='*.json'
  --include='*.env' --include='*.yaml' --include='*.yml' --include='*.sh')
EXCLUDE=(--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist
  --exclude-dir=build --exclude-dir=.venv --exclude-dir=venv
  --exclude-dir=__pycache__ --exclude=verify.sh)

fail=0

emit() { # emit <label> <multiline-hits>
  echo "FAIL  $1"
  while IFS= read -r line; do
    [ -n "$line" ] && echo "        $line"
  done <<< "$2"
  fail=1
}

# --- check 1: committed SA key JSON ---------------------------------------
key_hits=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -qE 'service_account|\.iam\.gserviceaccount\.com|"client_email"' "$f" 2>/dev/null; then
    key_hits+="${f}"$'\n'
  fi
done < <(grep -rlI "${EXCLUDE[@]}" --include='*.json' '"private_key"' "${TARGETS[@]}" 2>/dev/null || true)
if [ -n "${key_hits//[$'\n']/}" ]; then
  emit "committed service-account key JSON (use keyless ADC/WIF or a secret manager)" "$key_hits"
fi

# --- check 2: over-broad OAuth scopes -------------------------------------
broad=""
b="$( { grep -rnI "${EXCLUDE[@]}" "${SRC_INCLUDE[@]}" \
  -E 'googleapis\.com/auth/drive([^.a-zA-Z]|$)' "${TARGETS[@]}" 2>/dev/null || true; } | drop_self)"
[ -n "$b" ] && broad+="$b"$'\n'
b="$( { grep -rnI "${EXCLUDE[@]}" "${SRC_INCLUDE[@]}" \
  -E 'googleapis\.com/auth/gmail([^.a-zA-Z]|$)' "${TARGETS[@]}" 2>/dev/null || true; } | drop_self)"
[ -n "$b" ] && broad+="$b"$'\n'
b="$( { grep -rnI "${EXCLUDE[@]}" "${SRC_INCLUDE[@]}" \
  -F 'mail.google.com/' "${TARGETS[@]}" 2>/dev/null || true; } | drop_self)"
[ -n "$b" ] && broad+="$b"$'\n'
if [ -n "${broad//[$'\n']/}" ]; then
  emit "over-broad scope (prefer drive.file / drive.readonly / gmail.send / gmail.readonly)" "$broad"
fi

# --- check 3: hardcoded private key in source -----------------------------
pk="$( { grep -rnI "${EXCLUDE[@]}" "${SRC_INCLUDE[@]}" \
  -F -- '-----BEGIN PRIVATE KEY-----' "${TARGETS[@]}" 2>/dev/null || true; } | drop_self)"
if [ -n "${pk//[$'\n']/}" ]; then
  emit "hardcoded private key in source (inject from env/secret manager)" "$pk"
fi

# --- check 4: Workspace calls without a backoff helper (WARN only) ---------
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if ! grep -qiE 'backoff|retry|rateLimit|sleep|setTimeout' "$f" 2>/dev/null; then
    echo "WARN  $f: Workspace API call with no backoff/retry helper detected"
  fi
done < <(grep -rlI "${EXCLUDE[@]}" "${SRC_INCLUDE[@]}" \
  -E 'google\.(gmail|drive|calendar|sheets)\(|build\("(gmail|drive|calendar|sheets)"' \
  "${TARGETS[@]}" 2>/dev/null | drop_self)

if [ "$fail" -eq 0 ]; then
  echo "OK    no banned credential/scope patterns found"
fi
exit "$fail"
