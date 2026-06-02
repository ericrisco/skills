import { existsSync } from 'node:fs';
import { targetPaths } from '../targets/index.js';
import { readState } from './lib/state.js';
import { loadManifest } from './lib/manifest.js';

export function doctor({ target, home }) {
  const paths = targetPaths(target, home);
  const state = readState(paths.stateFile);
  const manifest = loadManifest();
  const report = {
    target,
    installed: Object.keys(state.skills),
    missing: [],
    hookWired: existsSync(paths.hookTarget),
    manifestSkills: manifest.counts.skills,
  };
  for (const [id, e] of Object.entries(state.skills)) {
    for (const f of e.files) if (!existsSync(f)) report.missing.push(`${id}:${f}`);
  }
  return report;
}
