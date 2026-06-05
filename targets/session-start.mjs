#!/usr/bin/env node
// rsc SessionStart payload (claude). Wired by targets/claude.js as `node ...` so
// it runs on every platform including Windows (no bash dependency).
//   argv[2] = absolute path to suggest's SKILL.md   argv[3] = absolute project root
// Always emits suggest's always-on body; appends an onboarding banner when the
// workspace has no harness profile yet, and an auto-ingest nudge when there is
// un-ingested material waiting in the inbox.
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const suggestMd = process.argv[2];
const root = process.argv[3] || process.cwd();

try { process.stdout.write(readFileSync(suggestMd, 'utf8')); } catch { /* missing → emit nothing */ }

const profile = join(root, '02-DOCS', 'wiki', 'harness', 'user-profile.md');
const optout = join(root, '.rsc', '.no-harness');
if (!existsSync(profile) && !existsSync(optout)) {
  process.stdout.write(`
===== rsc onboarding =====
Fresh setup: 02-DOCS/wiki/harness/user-profile.md is missing.
ACTION: invoke \`init\` now (first contact: technical level + accompaniment dial) before the task.
If the user does not want a harness here: create .rsc/.no-harness
==========================
`);
}

// Auto-Ingest nudge: when a harness wiki exists and the inbox holds a real file
// (anything other than README.md / dotfiles / the _processed archive), tell the
// agent to run the Auto-Ingest Sweep. The hook only reminds; the agent does the
// scan + ingest. Cheap signal here; the thorough workspace scan lives in the sweep.
const inbox = join(root, '02-DOCS', 'inbox');
if (existsSync(join(root, '02-DOCS', 'wiki')) && existsSync(inbox)) {
  let pending = false;
  try {
    pending = readdirSync(inbox, { withFileTypes: true })
      .some((e) => e.isFile() && e.name !== 'README.md' && !e.name.startsWith('.'));
  } catch { /* unreadable → no nudge */ }
  if (pending) {
    process.stdout.write(`
===== rsc auto-ingest =====
Un-ingested material is waiting in 02-DOCS/inbox/.
ACTION: run the Auto-Ingest Sweep now — ingest inbox/, then scan the workspace
(minus .rscignore) for un-ingested documents, recording them in wiki/.ingested.json.
Originals are copied, never moved; deleting an emptied folder needs explicit consent.
===========================
`);
  }
}

// Update check: compare the installed version (.rsc/.version, written at install)
// against the latest published on npm, and nudge the agent to offer an update.
// Fail-silent (offline / missing baseline / parse error → nothing). Disable with
// RSC_NO_UPDATE_CHECK=1. RSC_LATEST overrides the npm lookup (tests / mirrors).
function isNewer(a, b) {
  const pa = String(a).split('.').map(Number);
  const pb = String(b).split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if ((pa[i] || 0) > (pb[i] || 0)) return true;
    if ((pa[i] || 0) < (pb[i] || 0)) return false;
  }
  return false;
}

if (!process.env.RSC_NO_UPDATE_CHECK) {
  try {
    const installed = readFileSync(join(root, '.rsc', '.version'), 'utf8').trim();
    let latest = process.env.RSC_LATEST;
    if (!latest) {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 1500);
      const res = await fetch('https://registry.npmjs.org/@ericrisco%2frsc/latest', { signal: ctrl.signal });
      clearTimeout(timer);
      latest = (await res.json()).version;
    }
    if (installed && latest && isNewer(latest, installed)) {
      process.stdout.write(`
===== rsc update available =====
rsc ${latest} is out — you have ${installed}.
ACTION: tell the user a new version is available and, if they say yes, run:
  npx @ericrisco/rsc@latest
(That reinstalls and refreshes the skill content to the latest.)
================================
`);
    }
  } catch { /* offline / no baseline / parse error → stay silent */ }
}
