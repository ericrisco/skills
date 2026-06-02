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
  assert.ok(refresh.stdout.includes('Registry actualizado'));
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
