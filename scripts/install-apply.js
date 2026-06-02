#!/usr/bin/env node
import { rmSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { planInstall } from './install-plan.js';
import { targetPaths, writeSkill, wireHook } from '../targets/index.js';
import { readState, writeState } from './lib/state.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

export async function applyInstall({ skillIds, target, home }) {
  const paths = targetPaths(target, home);
  const plan = planInstall({ skillIds, target, home });
  const state = readState(paths.stateFile);
  for (const step of plan) {
    if (step.kind === 'skill') {
      const files = await writeSkill(target, step.id, join(ROOT, step.from), step.to);
      state.skills[step.id] = { files };
    } else if (step.kind === 'hook') {
      await wireHook(target, paths, join(ROOT, 'skills', 'suggest', 'SKILL.md'));
    }
  }
  writeState(paths.stateFile, state);
  return state;
}

export function listInstalled({ target, home }) {
  const paths = targetPaths(target, home);
  return Object.keys(readState(paths.stateFile).skills);
}

export async function uninstall({ skillIds, target, home, dryRun }) {
  const paths = targetPaths(target, home);
  const state = readState(paths.stateFile);
  const removed = [];
  for (const id of skillIds) {
    const entry = state.skills[id];
    if (!entry) continue;
    for (const f of entry.files) {
      removed.push(f);
      if (!dryRun && existsSync(f)) rmSync(f, { recursive: true, force: true });
    }
    if (!dryRun) delete state.skills[id];
  }
  if (!dryRun) writeState(paths.stateFile, state);
  return removed;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const ids = process.argv.slice(2);
  applyInstall({ skillIds: ids, target: 'claude' }).then(() => console.log('installed', ids.join(', ')));
}
