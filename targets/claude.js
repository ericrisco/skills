import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { linkOrCopy } from './index.js';

const HERE = dirname(fileURLToPath(import.meta.url));

export function writeSkill(id, fromDir, toPath) {
  // Migrate away from the legacy nested layout (.claude/skills/rsc/<id>) that
  // Claude Code never discovered — it only reads .claude/skills/<name>/SKILL.md.
  // toPath is now .claude/skills/<id>; drop the stale rsc/ sibling if present.
  const legacy = join(dirname(toPath), 'rsc');
  if (existsSync(legacy)) rmSync(legacy, { recursive: true, force: true });
  return linkOrCopy(fromDir, toPath);
}

// SessionStart runs a project-local session-start.mjs via `node`: it prints
// suggest's always-on body, an onboarding banner when the workspace has no harness
// profile yet, and an auto-ingest nudge when the inbox has un-ingested material. We
// invoke with `node` (not bash) so the hook runs on Windows too. We materialize the
// script next to the shared base and point the hook at it. Any prior rsc SessionStart
// entry (the old `cat …/suggest/SKILL.md` form, or a previous `.sh`/`.mjs` script
// form) is dropped before we add the current one — idempotent, migrating legacy and
// bash-era hooks in place. Other (non-rsc) SessionStart hooks are preserved.
export function wireHook(paths) {
  const scriptDest = join(paths.projectRoot, '.rsc', 'session-start.mjs');
  mkdirSync(dirname(scriptDest), { recursive: true });
  copyFileSync(join(HERE, 'session-start.mjs'), scriptDest);

  const suggestMd = `${paths.skillDir('suggest')}/SKILL.md`;
  const cmd = `node "${scriptDest}" "${suggestMd}" "${paths.projectRoot}"`;

  const file = paths.hookTarget;
  const settings = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : {};
  settings.hooks ||= {};
  settings.hooks.SessionStart ||= [];
  settings.hooks.SessionStart = settings.hooks.SessionStart.filter((e) => {
    const s = JSON.stringify(e);
    // drop legacy cat-form and any prior session-start script (.sh from the bash era, or .mjs)
    return !s.includes('skills/rsc/suggest') && !s.includes('.rsc/session-start.');
  });
  settings.hooks.SessionStart.push({ hooks: [{ type: 'command', command: cmd }] });

  // Worklog checkpoint: PreCompact + SessionEnd run a project-local
  // worklog-checkpoint.mjs via `node` that reminds the agent to capture what we did
  // this session into 02-DOCS/raw/worklog/ (the work-driven on-ramp). Silent when
  // the workspace has no harness wiki. Registered idempotently on both events, with
  // any prior rsc worklog-checkpoint entry (.sh or .mjs) dropped first.
  const wlDest = join(paths.projectRoot, '.rsc', 'worklog-checkpoint.mjs');
  copyFileSync(join(HERE, 'worklog-checkpoint.mjs'), wlDest);
  const wlCmd = `node "${wlDest}" "${paths.projectRoot}"`;
  for (const event of ['PreCompact', 'SessionEnd']) {
    settings.hooks[event] ||= [];
    settings.hooks[event] = settings.hooks[event].filter(
      (e) => !JSON.stringify(e).includes('.rsc/worklog-checkpoint.'),
    );
    settings.hooks[event].push({ hooks: [{ type: 'command', command: wlCmd }] });
  }

  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(settings, null, 2) + '\n');
  return [file, scriptDest, wlDest];
}
