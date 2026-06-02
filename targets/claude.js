import { cpSync, readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

export function writeSkill(id, fromDir, toPath) {
  mkdirSync(dirname(toPath), { recursive: true });
  cpSync(fromDir, toPath, { recursive: true });
  return [toPath];
}

export function wireHook(paths) {
  const file = paths.hookTarget;
  const settings = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : {};
  settings.hooks ||= {};
  settings.hooks.SessionStart ||= [];
  const cmd = `cat "${paths.skillDir('suggest')}/SKILL.md"`;
  const already = JSON.stringify(settings.hooks.SessionStart).includes('skills/rsc/suggest');
  if (!already) {
    settings.hooks.SessionStart.push({ hooks: [{ type: 'command', command: cmd }] });
  }
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(settings, null, 2) + '\n');
  return [file];
}
