#!/usr/bin/env node
import { rmSync, existsSync, cpSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { planInstall } from './install-plan.js';
import { targetPaths, writeSkill, wireHook, baseDir } from '../targets/index.js';
import { readState, writeState } from './lib/state.js';
import { createBackup } from './lib/backups.js';

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

function generatedHookFiles({ target, cwd }) {
  if (target !== 'claude') return [];
  return [
    join(cwd, '.rsc', 'session-start.mjs'),
    join(cwd, '.rsc', 'worklog-checkpoint.mjs'),
    join(cwd, '.rsc', 'ship-guard.mjs'),
    join(cwd, '.rsc', 'danger-guard.mjs'),
  ];
}

function managedPathsForInstall({ skillIds, target, home, cwd }) {
  const paths = targetPaths(target, home, cwd);
  const plan = planInstall({ skillIds, target, home, cwd });
  const out = [paths.stateFile, versionFile(cwd)];
  for (const step of plan) {
    if (step.kind === 'skill') {
      out.push(step.to, baseDir(step.id, cwd));
    } else if (step.kind === 'hook') {
      out.push(step.to, ...generatedHookFiles({ target, cwd }));
    }
  }
  return [...new Set(out)];
}

export async function applyInstall({ skillIds, target, home, cwd = process.cwd(), operation = 'install', dryRun = false }) {
  const paths = targetPaths(target, home, cwd);
  const plan = planInstall({ skillIds, target, home, cwd });
  const managedPaths = managedPathsForInstall({ skillIds, target, home, cwd });
  if (dryRun) return { dryRun: true, skills: skillIds, paths: managedPaths };
  const state = readState(paths.stateFile);
  const backup = createBackup({ cwd, operation, target, paths: managedPaths, cliVersion: CLI_VERSION });
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
  return { ...state, backup };
}

export function listInstalled({ target, home, cwd = process.cwd() }) {
  const paths = targetPaths(target, home, cwd);
  return Object.keys(readState(paths.stateFile).skills);
}

export async function uninstall({ skillIds, target, home, cwd = process.cwd(), dryRun }) {
  const paths = targetPaths(target, home, cwd);
  const state = readState(paths.stateFile);
  const removed = [];
  const managedPaths = [paths.stateFile];
  for (const id of skillIds) {
    const entry = state.skills[id];
    if (!entry) continue;
    for (const f of entry.files) {
      managedPaths.push(f);
      removed.push(f);
    }
  }
  if (!removed.length) return removed;
  if (dryRun) return removed;
  createBackup({ cwd, operation: 'uninstall', target, paths: managedPaths, cliVersion: CLI_VERSION });
  for (const id of skillIds) {
    const entry = state.skills[id];
    if (!entry) continue;
    for (const f of entry.files) {
      if (existsSync(f)) rmSync(f, { recursive: true, force: true });
    }
    delete state.skills[id];
  }
  writeState(paths.stateFile, state);
  return removed;
}

export async function syncInstalled({ target, home, cwd = process.cwd(), dryRun = false }) {
  const paths = targetPaths(target, home, cwd);
  const state = readState(paths.stateFile);
  const ids = Object.keys(state.skills || {});
  if (!ids.length) return dryRun ? { dryRun: true, synced: [], paths: [] } : { synced: [], backup: null };
  if (dryRun) {
    return {
      dryRun: true,
      synced: ids,
      paths: managedPathsForInstall({ skillIds: ids, target, home, cwd }),
    };
  }
  const nextState = await applyInstall({ skillIds: ids, target, home, cwd, operation: 'sync' });
  return { synced: ids, backup: nextState.backup };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const ids = process.argv.slice(2);
  applyInstall({ skillIds: ids, target: 'claude' }).then(() => console.log('installed', ids.join(', ')));
}
