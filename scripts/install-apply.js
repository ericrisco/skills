#!/usr/bin/env node
import { rmSync, existsSync, cpSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { planInstall } from './install-plan.js';
import { targetPaths, writeSkill, wireHook, baseDir } from '../targets/index.js';
import { readState, writeState } from './lib/state.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const CLI_VERSION = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8')).version;

// `.rsc/.version` records the CLI version the shared bases (.rsc/skills/) were
// materialized at — the single, target-agnostic source of truth for "installed
// skills version" (read by the SessionStart update check too).
const versionFile = (cwd) => join(cwd, '.rsc', '.version');
function readBaseVersion(cwd) {
  try { return readFileSync(versionFile(cwd), 'utf8').trim(); } catch { return undefined; }
}

// Materialize the real skill files into the project-local base. Normally copied
// once and reused; when `refresh` is set (a different CLI version than the base was
// materialized at) the base is re-copied so a reinstall actually updates content.
// Skills are read-only catalog (user customization lives in 02-DOCS/CLAUDE.md), so
// overwriting on a version change is safe.
function ensureBase(id, cwd, refresh) {
  const dest = baseDir(id, cwd);
  if (refresh && existsSync(dest)) rmSync(dest, { recursive: true, force: true });
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
  // Refresh bases when installing a different version than they were materialized at
  // (or a pre-versioning install where the marker is absent). Same version → no-op.
  const refresh = readBaseVersion(cwd) !== CLI_VERSION;
  for (const step of plan) {
    if (step.kind === 'skill') {
      const base = ensureBase(step.id, cwd, refresh);
      const files = await writeSkill(target, step.id, base, step.to);
      state.skills[step.id] = { files, base };
    } else if (step.kind === 'hook') {
      await wireHook(target, paths, join(ensureBase('suggest', cwd, refresh), 'SKILL.md'));
    }
  }
  state.version = CLI_VERSION;
  writeState(paths.stateFile, state);
  mkdirSync(dirname(versionFile(cwd)), { recursive: true });
  writeFileSync(versionFile(cwd), CLI_VERSION + '\n');
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
