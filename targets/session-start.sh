#!/usr/bin/env bash
# rsc SessionStart payload (claude). Wired by targets/claude.js.
#   $1 = absolute path to suggest's SKILL.md   $2 = absolute project root
# Always emits suggest's always-on body; appends an onboarding banner when the
# workspace has no harness profile yet, and an auto-ingest nudge when there is
# un-ingested material waiting in the inbox.
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

# Auto-Ingest nudge: when a harness wiki exists and the inbox holds a real file
# (anything other than README.md / dotfiles / the _processed archive), tell the
# agent to run the Auto-Ingest Sweep. The hook only reminds; the agent does the
# scan + ingest. Cheap signal here; the thorough workspace scan lives in the sweep.
inbox="$2/02-DOCS/inbox"
if [ -d "$2/02-DOCS/wiki" ] && [ -d "$inbox" ]; then
  pending=$(find "$inbox" -maxdepth 1 -type f ! -name 'README.md' ! -name '.*' 2>/dev/null | head -1)
  if [ -n "$pending" ]; then
    cat <<'BANNER'

===== rsc auto-ingest =====
Un-ingested material is waiting in 02-DOCS/inbox/.
ACTION: run the Auto-Ingest Sweep now — ingest inbox/, then scan the workspace
(minus .rscignore) for un-ingested documents, recording them in wiki/.ingested.json.
Originals are copied, never moved; deleting an emptied folder needs explicit consent.
===========================
BANNER
  fi
fi
