#!/usr/bin/env node
import { rmSync, existsSync, cpSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { planInstall } from './install-plan.js';
import { targetPaths, writeSkill, wireHook, baseDir } from '../targets/index.js';
import { readState, writeState } from './lib/state.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// Materialize the real skill files into the project-local base exactly once.
// Re-installs and other assistants reuse it instead of copying again.
function ensureBase(id, cwd) {
  const dest = baseDir(id, cwd);
  if (!existsSync(dest)) {
    mkdirSync(dirname(dest), { recursive: true });
    cpSync(join(ROOT, 'skills', id), dest, { recursive: true });
  }
  return dest;
}

export async function applyInstall({ skillIds, target, home, cwd = process.cwd() }) {
  const paths = targetPaths(target, home, cwd);
  const plan = planInstall({ skillIds, target, home, cwd });
  const state = readState(paths.stateFile);
  for (const step of plan) {
    if (step.kind === 'skill') {
      const base = ensureBase(step.id, cwd);
      const files = await writeSkill(target, step.id, base, step.to);
      state.skills[step.id] = { files, base };
    } else if (step.kind === 'hook') {
      await wireHook(target, paths, join(ensureBase('suggest', cwd), 'SKILL.md'));
    }
  }
  writeState(paths.stateFile, state);
  return state;
}

export function listInstalled({ target, home, cwd = process.cwd() }) {
  const paths = targetPaths(target, home, cwd);
  return Object.keys(readState(paths.stateFile).skills);
}

export async function uninstall({ skillIds, target, home, cwd = process.cwd(), dryRun }) {
  const paths = targetPaths(target, home, cwd);
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
