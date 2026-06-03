import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync, chmodSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { linkOrCopy } from './index.js';

export function writeSkill(id, fromDir, toPath) {
  return linkOrCopy(fromDir, toPath);
}

// SessionStart runs a project-local session-start.sh: it cats suggest's always-on
// body (preserving prior behavior) and appends an onboarding banner when the
// workspace has no harness profile yet. We materialize the script next to the
// shared base and point the hook at it. Any prior rsc SessionStart entry (the old
// `cat …/suggest/SKILL.md` form or a previous script form) is dropped before we
// add the current one — idempotent, and it migrates legacy hooks in place. Other
// (non-rsc) SessionStart hooks are preserved.
export function wireHook(paths) {
  const scriptDest = join(paths.projectRoot, '.rsc', 'session-start.sh');
  mkdirSync(dirname(scriptDest), { recursive: true });
  copyFileSync(join(dirname(fileURLToPath(import.meta.url)), 'session-start.sh'), scriptDest);
  chmodSync(scriptDest, 0o755);

  const suggestMd = `${paths.skillDir('suggest')}/SKILL.md`;
  const cmd = `bash "${scriptDest}" "${suggestMd}" "${paths.projectRoot}"`;

  const file = paths.hookTarget;
  const settings = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : {};
  settings.hooks ||= {};
  settings.hooks.SessionStart ||= [];
  settings.hooks.SessionStart = settings.hooks.SessionStart.filter((e) => {
    const s = JSON.stringify(e);
    return !s.includes('skills/rsc/suggest') && !s.includes('.rsc/session-start.sh');
  });
  settings.hooks.SessionStart.push({ hooks: [{ type: 'command', command: cmd }] });

  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(settings, null, 2) + '\n');
  return [file, scriptDest];
}
