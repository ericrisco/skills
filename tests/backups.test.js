import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createBackup, listBackups, restoreBackup } from '../scripts/lib/backups.js';

function tmp() {
  return mkdtempSync(join(tmpdir(), 'rsc-backup-'));
}

test('createBackup snapshots existing files and restoreBackup restores them', () => {
  const cwd = tmp();
  const file = join(cwd, 'AGENTS.md');
  writeFileSync(file, 'before\n');

  const snap = createBackup({ cwd, operation: 'install', target: 'codex', paths: [file], cliVersion: '0.0.0-test' });
  writeFileSync(file, 'after\n');

  const restored = restoreBackup({ cwd, id: snap.id });

  assert.equal(readFileSync(file, 'utf8'), 'before\n');
  assert.ok(restored.changed.some((p) => p.endsWith('AGENTS.md')));
});

test('restoreBackup removes managed files that were missing before the snapshot', () => {
  const cwd = tmp();
  const file = join(cwd, '.codex', 'rsc', 'fastapi');

  const snap = createBackup({ cwd, operation: 'install', target: 'codex', paths: [file], cliVersion: '0.0.0-test' });
  mkdirSync(file, { recursive: true });
  writeFileSync(join(file, 'SKILL.md'), 'created\n');

  restoreBackup({ cwd, id: snap.id });

  assert.equal(existsSync(file), false);
});

test('restoreBackup supports dry-run without mutating files', () => {
  const cwd = tmp();
  const file = join(cwd, 'AGENTS.md');
  writeFileSync(file, 'before\n');
  const snap = createBackup({ cwd, operation: 'install', target: 'codex', paths: [file], cliVersion: '0.0.0-test' });
  writeFileSync(file, 'after\n');

  const preview = restoreBackup({ cwd, id: snap.id, dryRun: true });

  assert.equal(readFileSync(file, 'utf8'), 'after\n');
  assert.ok(preview.changed.some((p) => p.endsWith('AGENTS.md')));
});

test('listBackups returns newest snapshots first and latest restores newest', () => {
  const cwd = tmp();
  const first = createBackup({
    cwd,
    operation: 'install',
    target: 'codex',
    paths: [],
    cliVersion: '0.0.0-test',
    now: new Date('2026-06-06T10:00:00Z'),
  });
  const second = createBackup({
    cwd,
    operation: 'sync',
    target: 'codex',
    paths: [],
    cliVersion: '0.0.0-test',
    now: new Date('2026-06-06T11:00:00Z'),
  });

  const listed = listBackups({ cwd });
  const latest = restoreBackup({ cwd, id: 'latest', dryRun: true });

  assert.equal(listed[0].id, second.id);
  assert.equal(listed[1].id, first.id);
  assert.equal(latest.snapshot.id, second.id);
});

test('createBackup records symlinks as symlinks', () => {
  const cwd = tmp();
  const real = join(cwd, '.rsc', 'skills', 'fastapi');
  const link = join(cwd, '.claude', 'skills', 'fastapi');
  mkdirSync(real, { recursive: true });
  writeFileSync(join(real, 'SKILL.md'), 'skill\n');
  mkdirSync(join(cwd, '.claude', 'skills'), { recursive: true });
  try {
    symlinkSync('../../.rsc/skills/fastapi', link, 'dir');
  } catch {
    return;
  }

  const snap = createBackup({ cwd, operation: 'install', target: 'claude', paths: [link], cliVersion: '0.0.0-test' });

  assert.equal(snap.entries[0].kind, 'symlink');
  assert.equal(lstatSync(link).isSymbolicLink(), true);
});
