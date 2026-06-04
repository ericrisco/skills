#!/usr/bin/env node
// rsc Worklog checkpoint (claude). Wired by targets/claude.js onto PreCompact and
// SessionEnd as `node ...` so it runs on every platform including Windows.
//   argv[2] = absolute project root
// Reminds the agent to run a Worklog Sweep (capture what we did this session into
// 02-DOCS/raw/worklog/). The hook only reminds; the agent writes the worklog.
// Silent when this workspace has no harness wiki yet.
import { existsSync } from 'node:fs';
import { join } from 'node:path';

const root = process.argv[2] || process.cwd();

// No harness wiki here → nothing to document into. Stay silent.
if (!existsSync(join(root, '02-DOCS', 'wiki'))) process.exit(0);

process.stdout.write(`
===== rsc worklog checkpoint =====
If this session did meaningful work (files changed, a decision made, a commit),
run a WORKLOG SWEEP before context is lost:
  1. Write 02-DOCS/raw/worklog/<YYYY-MM-DD>-<slug>.md using the harness
     wiki-worklog-template.md (what we did · why · files touched · outcome · next).
  2. Compile it into wiki/ (update existing articles first; wikilinks + Related);
     append significant decisions to 02-DOCS/wiki/harness/decisions.md.
Skip entirely if this was a pure read/answer turn with no changes.
==================================
`);
