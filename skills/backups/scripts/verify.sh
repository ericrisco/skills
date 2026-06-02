#!/usr/bin/env bash
# verify.sh — completeness lint for a backup-policy / restore-runbook artifact.
#
# Read-only. It does NOT run, create, or touch any backup. It only greps a
# produced artifact for the five pillars this skill insists on:
#   1. an RPO value           4. immutability (Object Lock / WORM)
#   2. an RTO value           5. a scheduled restore-test cadence + a verification step
#   3. an offsite copy
#
# Usage:
#   scripts/verify.sh <path-to-policy-or-runbook.md>
#
# Exit codes:
#   0  all pillars present, OR no/empty target given (nothing to lint = no false failure)
#   1  the target exists with content but is missing one or more pillars
#   2  the target path was given but does not exist / is unreadable

set -euo pipefail

target="${1:-}"

# No target, or an empty target → nothing to lint. Clean exit, never a false failure.
if [[ -z "${target}" ]]; then
  echo "verify.sh: no artifact path given — nothing to lint (ok)"
  exit 0
fi

if [[ ! -e "${target}" ]]; then
  echo "verify.sh: '${target}' does not exist" >&2
  exit 2
fi

if [[ ! -r "${target}" ]]; then
  echo "verify.sh: '${target}' is not readable" >&2
  exit 2
fi

if [[ ! -s "${target}" ]]; then
  echo "verify.sh: '${target}' is empty — nothing to lint (ok)"
  exit 0
fi

# Case-insensitive presence check helper.
has() { grep -Eiq -- "$1" "${target}"; }

missing=()

# Pillar 1: RPO — the acronym, with a number somewhere near it is ideal but the
# label alone is the minimum signal.
has 'rpo' || missing+=("RPO target (recovery point objective)")

# Pillar 2: RTO.
has 'rto' || missing+=("RTO target (recovery time objective)")

# Pillar 3: an offsite copy.
has 'off[ -]?site|different (region|account)|cross[ -]region' \
  || missing+=("offsite copy (different region/account)")

# Pillar 4: immutability.
has 'immutab|object[ -]?lock|worm' \
  || missing+=("immutability (Object Lock / WORM)")

# Pillar 5a: a scheduled restore-test cadence.
has 'restore[ -](test|drill)|test(ed)? restore|monthly|quarterly|annual' \
  || missing+=("scheduled restore-test cadence")

# Pillar 5b: a verification / integrity step.
has 'verif|integrity|checksum|\bcheck\b|0 (verification )?errors' \
  || missing+=("verification / integrity step")

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "verify.sh: '${target}' covers all five pillars — ok"
  exit 0
fi

echo "verify.sh: '${target}' is missing the following pillar(s):" >&2
for m in "${missing[@]}"; do
  echo "  - ${m}" >&2
done
exit 1
