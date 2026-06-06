import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));

test('rsc registry refresh/status CLI writes project registry', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cli-'));
  const refresh = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'registry', 'refresh', '--target', 'codex'], {
    cwd,
    encoding: 'utf8',
  });
  assert.equal(refresh.status, 0, refresh.stderr);
  assert.ok(refresh.stdout.includes('Registry updated'));
  assert.ok(existsSync(join(cwd, '.rsc', 'skill-registry.json')));
  assert.ok(existsSync(join(cwd, '.rsc', 'skill-registry.md')));

  const status = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'registry', 'status'], {
    cwd,
    encoding: 'utf8',
  });
  assert.equal(status.status, 0, status.stderr);
  assert.ok(status.stdout.includes('"exists": true'));
});

test('rsc consult prioritizes explicit query over repo hints', () => {
  const result = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'consult', 'ejecutar Python en GPU serverless'], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr);
  assert.ok(result.stdout.split('\n')[0].startsWith('modal\t'), result.stdout);
});

test('rsc backups lists project-local snapshots', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cli-backups-'));
  const install = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'add', 'fastapi', '--target', 'claude'], {
    cwd,
    encoding: 'utf8',
  });
  assert.equal(install.status, 0, install.stderr);

  const listed = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'backups'], {
    cwd,
    encoding: 'utf8',
  });

  assert.equal(listed.status, 0, listed.stderr);
  assert.ok(listed.stdout.includes('install'));
  assert.ok(listed.stdout.includes('claude'));
});

test('rsc restore latest --dry-run reports planned restore paths without mutating', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cli-restore-'));
  const install = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'add', 'fastapi', '--target', 'claude'], {
    cwd,
    encoding: 'utf8',
  });
  assert.equal(install.status, 0, install.stderr);

  const preview = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'restore', 'latest', '--dry-run'], {
    cwd,
    encoding: 'utf8',
  });

  assert.equal(preview.status, 0, preview.stderr);
  assert.ok(preview.stdout.includes('Would restore'));
  assert.ok(existsSync(join(cwd, '.claude/skills/fastapi/SKILL.md')));
});

test('rsc sync --dry-run reports installed skills', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cli-sync-'));
  const install = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'add', 'fastapi', '--target', 'claude'], {
    cwd,
    encoding: 'utf8',
  });
  assert.equal(install.status, 0, install.stderr);

  const sync = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'sync', '--target', 'claude', '--dry-run'], {
    cwd,
    encoding: 'utf8',
  });

  assert.equal(sync.status, 0, sync.stderr);
  assert.ok(sync.stdout.includes('Would sync claude'));
  assert.ok(sync.stdout.includes('fastapi'));
});

test('rsc upgrade --dry-run prints npm upgrade command', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cli-upgrade-'));
  const result = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'upgrade', '--target', 'claude', '--dry-run'], {
    cwd,
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr);
  assert.ok(result.stdout.includes('npm install -g @ericrisco/rsc@latest'));
  assert.ok(result.stdout.includes('rsc sync --target claude'));
});
