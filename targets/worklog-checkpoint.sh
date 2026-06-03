#!/usr/bin/env bash
# rsc Worklog checkpoint payload (claude). Wired by targets/claude.js onto the
# PreCompact and SessionEnd hooks.
#   $1 = absolute project root
# Reminds the agent to run a Worklog Sweep (capture what we did this session into
# 02-DOCS/raw/worklog/ so the harness can compile it into the wiki). The hook only
# REMINDS — the agent writes the worklog (Karpathy: the LLM writes the wiki).
# Silent when this workspace has no harness wiki yet (nothing to document into).
set -u

root="${1:-$PWD}"

# No harness wiki here → nothing to do. Stay silent.
[ -d "$root/02-DOCS/wiki" ] || exit 0

cat <<'BANNER'

===== rsc worklog checkpoint =====
If this session did meaningful work (files changed, a decision made, a commit),
run a WORKLOG SWEEP before context is lost:
  1. Write 02-DOCS/raw/worklog/<YYYY-MM-DD>-<slug>.md using the harness
     wiki-worklog-template.md (what we did · why · files touched · outcome · next).
  2. Compile it into wiki/ (update existing articles first; wikilinks + Related);
     append significant decisions to 02-DOCS/wiki/harness/decisions.md.
Skip entirely if this was a pure read/answer turn with no changes.
==================================
BANNER
