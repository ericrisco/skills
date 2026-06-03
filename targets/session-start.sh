#!/usr/bin/env bash
# rsc SessionStart payload (claude). Wired by targets/claude.js.
#   $1 = absolute path to suggest's SKILL.md   $2 = absolute project root
# Always emits suggest's always-on body; appends an onboarding banner only when
# the workspace has no harness profile yet and the user has not opted out.
set -u

cat "$1" 2>/dev/null

profile="$2/02-DOCS/wiki/harness/user-profile.md"
optout="$2/.rsc/.no-harness"

if [ ! -f "$profile" ] && [ ! -f "$optout" ]; then
  cat <<'BANNER'

===== rsc onboarding =====
Fresh setup: 02-DOCS/wiki/harness/user-profile.md is missing.
ACTION: invoke `init` now (first contact: technical level + accompaniment dial) before the task.
If the user does not want a harness here: create .rsc/.no-harness
==========================
BANNER
fi
