#!/usr/bin/env bash
# verify.sh — static lint for GitHub Actions workflows.
# Read-only. No network, no install, no run. Heuristic and advisory.
#
# Checks .github/workflows/*.{yml,yaml} in the target dir:
#   ERROR (exit 1): pull_request_target together with a checkout of the PR head
#                   (runs untrusted fork code with full secrets).
#   WARN: third-party uses: (not actions/* or github/*) not pinned to a 40-hex SHA.
#   WARN: a workflow with no permissions: block (default token may be write).
#   WARN: a step using secrets.AWS_/GCP_/AZURE_ creds while the file lacks id-token: write (OIDC nudge).
# Runs `actionlint` if it is on PATH and surfaces its output.
#
# Exits non-zero ONLY on ERROR, so it works as a CI gate.
# Exits 0 on a clean/empty target (no .github/workflows -> nothing to check).
#
# Usage: scripts/verify.sh [dir]   (defaults to current directory)
set -euo pipefail

DIR="${1:-.}"
ERRORS=0
WARN=0

if [ ! -d "$DIR" ]; then
  echo "verify.sh: '$DIR' is not a directory" >&2
  exit 2
fi

err()  { echo "ERROR: $*"; ERRORS=$((ERRORS + 1)); }
warn() { echo "WARN:  $*"; WARN=$((WARN + 1)); }

WF_DIR="$DIR/.github/workflows"
if [ ! -d "$WF_DIR" ]; then
  echo "verify.sh: no .github/workflows under '$DIR' — skill not applied yet, nothing to check."
  exit 0
fi

# bash 3.2 (macOS) friendly: newline-delimited list, no mapfile.
FILES="$(
  find "$WF_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null
)"

if [ -z "$FILES" ]; then
  echo "verify.sh: .github/workflows has no .yml/.yaml files — nothing to check."
  exit 0
fi

# Optional: actionlint if available (advisory; its exit code does not gate us).
if command -v actionlint >/dev/null 2>&1; then
  echo "verify.sh: running actionlint..."
  actionlint "$WF_DIR"/*.yml "$WF_DIR"/*.yaml 2>/dev/null || \
    warn "actionlint reported issues (see above)."
else
  echo "verify.sh: actionlint not on PATH — running built-in checks only."
fi

while IFS= read -r f; do
  [ -z "$f" ] && continue

  # --- ERROR: pull_request_target + checkout of the PR head ---
  if grep -Eq 'pull_request_target' "$f"; then
    if grep -Eq 'github\.event\.pull_request\.head|head\.sha|head\.ref' "$f"; then
      err "$f uses pull_request_target AND checks out the PR head — runs untrusted code with secrets (RCE). Use pull_request, or never check out head.* here."
    fi
  fi

  # --- WARN: no permissions: block at all ---
  if ! grep -Eq '^[[:space:]]*permissions[[:space:]]*:' "$f"; then
    warn "$f has no permissions: block — the default GITHUB_TOKEN may be write. Set 'permissions: contents: read' and widen per job."
  fi

  # --- WARN: third-party uses: not pinned to a 40-hex SHA ---
  # Lines like:  - uses: owner/repo@ref   (ignore ./local and docker:// forms)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ref="${line#*@}"                       # everything after the first @
    owner="${line%%/*}"                    # owner segment of the action path
    owner="${owner##*uses:}"
    owner="$(echo "$owner" | tr -d ' ')"
    # skip first-party actions/* and github/*
    case "$owner" in
      actions|github) continue ;;
    esac
    # accept exactly 40 hex chars (optionally followed by whitespace/comment)
    if ! echo "$ref" | grep -Eq '^[0-9a-fA-F]{40}([[:space:]]|#|$)'; then
      short="$(echo "$line" | sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//' | cut -c1-60)"
      warn "$f: third-party action not SHA-pinned: $short — pin to a full 40-char commit SHA (tags are mutable; cf. tj-actions 2025)."
    fi
  done <<EOF
$(grep -E '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*[^./][^@]+@[^[:space:]]+' "$f" | grep -vE 'uses:[[:space:]]*\./|docker://' || true)
EOF

  # --- WARN: cloud secrets used but no id-token: write (OIDC nudge) ---
  if grep -Eq 'secrets\.(AWS|GCP|GOOGLE|AZURE)[A-Z_]*' "$f"; then
    if ! grep -Eq 'id-token[[:space:]]*:[[:space:]]*write' "$f"; then
      warn "$f references cloud secrets (AWS/GCP/AZURE) but sets no 'id-token: write' — prefer OIDC over long-lived keys."
    fi
  fi
done <<EOF
$FILES
EOF

echo
echo "verify.sh: $ERRORS error(s), $WARN warning(s)."
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
