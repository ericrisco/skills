import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

export function readState(file) {
  if (!existsSync(file)) return { skills: {} };
  try { return JSON.parse(readFileSync(file, 'utf8')); } catch { return { skills: {} }; }
}

export function writeState(file, state) {
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(state, null, 2) + '\n');
}
