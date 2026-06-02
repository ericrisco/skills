#!/usr/bin/env bash
set -euo pipefail

# reviewer-guard.sh — assert every rsc-review reviewer agent still carries the
# confidence-filtering doctrine. A reviewer that loses these sections starts
# inventing low-confidence findings and inflating severity, so this guard fails
# the build if any required section goes missing.
#
# bash 3.2-safe: no mapfile, no associative arrays, no process substitution.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
AGENTS_DIR="$REPO_ROOT/plugins/rsc-review/agents"

# One required heading per line (literal substrings, matched with grep -F).
REQUIRED='### Pre-report gate
### High and critical require proof
### Returning zero findings is acceptable
### Common false positives to skip
### No severity inflation
## Prompt defense'

if [ ! -d "$AGENTS_DIR" ]; then
  echo "reviewer-guard: agents dir not found: $AGENTS_DIR" >&2
  exit 1
fi

agent_count=0
fail_count=0

for agent in "$AGENTS_DIR"/*.md; do
  [ -e "$agent" ] || continue
  agent_count=$((agent_count + 1))
  name=$(basename "$agent")
  missing=""

  # Read the required list line by line (set -u / 3.2 safe).
  while IFS= read -r section; do
    [ -n "$section" ] || continue
    if ! grep -qF "$section" "$agent"; then
      missing="$missing
    - missing: $section"
    fi
  done <<EOF
$REQUIRED
EOF

  if [ -n "$missing" ]; then
    echo "FAIL $name$missing"
    fail_count=$((fail_count + 1))
  else
    echo "PASS $name"
  fi
done

echo
if [ "$agent_count" -eq 0 ]; then
  echo "reviewer-guard: no agent files found in $AGENTS_DIR" >&2
  exit 1
fi

if [ "$fail_count" -ne 0 ]; then
  echo "reviewer-guard: $fail_count/$agent_count agent(s) FAILED." >&2
  exit 1
fi

echo "reviewer-guard: all $agent_count reviewer agent(s) PASS."
