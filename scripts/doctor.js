import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { targetPaths } from '../targets/index.js';
import { readState } from './lib/state.js';
import { loadManifest } from './lib/manifest.js';
import { listBackups } from './lib/backups.js';

export function doctor({ target, home, cwd }) {
  const root = cwd || process.cwd();
  const paths = targetPaths(target, home, cwd);
  const state = readState(paths.stateFile);
  const manifest = loadManifest();
  const backups = listBackups({ cwd: root });
  const report = {
    target,
    installed: Object.keys(state.skills),
    missing: [],
    hookWired: existsSync(paths.hookTarget),
    manifestSkills: manifest.counts.skills,
    backups: {
      exists: existsSync(join(root, '.rsc', 'backups')),
      count: backups.length,
      latest: backups[0]?.id || null,
    },
  };
  for (const [id, e] of Object.entries(state.skills)) {
    for (const f of e.files) if (!existsSync(f)) report.missing.push(`${id}:${f}`);
  }
  return report;
}
