import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

export function detectTarget(cwd = process.cwd()) {
  if (existsSync(join(cwd, '.cursor'))) return 'cursor';
  if (existsSync(join(cwd, '.codex')) || existsSync(join(cwd, 'AGENTS.md'))) return 'codex';
  if (existsSync(join(cwd, '.gemini')) || existsSync(join(cwd, 'GEMINI.md'))) return 'gemini';
  return 'claude';
}

export function targetPaths(target, home = homedir(), cwd = process.cwd()) {
  switch (target) {
    case 'claude':
      return {
        root: join(home, '.claude', 'skills', 'rsc'),
        skillDir: (id) => join(home, '.claude', 'skills', 'rsc', id),
        stateFile: join(home, '.claude', 'skills', 'rsc', '.rsc-state.json'),
        hookTarget: join(home, '.claude', 'settings.json'),
      };
    case 'cursor':
      return {
        root: join(cwd, '.cursor', 'rules'),
        skillDir: (id) => join(cwd, '.cursor', 'rules', `${id}.mdc`),
        stateFile: join(cwd, '.cursor', 'rules', '.rsc-state.json'),
        hookTarget: join(cwd, '.cursor', 'rules', 'rsc-suggest.mdc'),
      };
    case 'codex':
      return {
        root: join(cwd, '.codex', 'rsc'),
        skillDir: (id) => join(cwd, '.codex', 'rsc', id),
        stateFile: join(cwd, '.codex', 'rsc', '.rsc-state.json'),
        hookTarget: join(cwd, 'AGENTS.md'),
      };
    case 'gemini':
      return {
        root: join(cwd, '.gemini', 'rsc'),
        skillDir: (id) => join(cwd, '.gemini', 'rsc', id),
        stateFile: join(cwd, '.gemini', 'rsc', '.rsc-state.json'),
        hookTarget: join(cwd, 'GEMINI.md'),
      };
    default:
      throw new Error(`unknown target ${target}`);
  }
}

export async function writeSkill(target, id, fromDir, toPath) {
  const { writeSkill: w } = await import(`./${target}.js`);
  return w(id, fromDir, toPath);
}

export async function wireHook(target, paths, sourceMd) {
  const { wireHook: w } = await import(`./${target}.js`);
  return w(paths, sourceMd);
}
