import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { detectRepo, detectRepoProfile } from '../scripts/detect-repo.js';

function tmp() { return mkdtempSync(join(tmpdir(), 'rsc-')); }

test('detects nextjs from package.json', () => {
  const d = tmp();
  writeFileSync(join(d, 'package.json'), JSON.stringify({ dependencies: { next: '15' } }));
  assert.ok(detectRepo(d).includes('nextjs'));
});

test('detects go from go.mod', () => {
  const d = tmp();
  writeFileSync(join(d, 'go.mod'), 'module x');
  assert.ok(detectRepo(d).includes('go'));
});

test('empty repo returns []', () => {
  assert.deepEqual(detectRepo(tmp()), []);
});

test('detectRepoProfile reports node package manager, scripts, runners and verify commands', () => {
  const d = tmp();
  writeFileSync(join(d, 'package.json'), JSON.stringify({
    scripts: {
      test: 'vitest run',
      lint: 'eslint .',
      typecheck: 'tsc --noEmit',
      build: 'next build'
    },
    dependencies: { next: '15', react: '19' },
    devDependencies: { vitest: '^2.0.0', '@playwright/test': '^1.0.0' }
  }, null, 2));
  writeFileSync(join(d, 'pnpm-lock.yaml'), '');

  const profile = detectRepoProfile(d);

  assert.deepEqual(profile.packageManagers, ['pnpm']);
  assert.ok(profile.stacks.includes('nextjs'));
  assert.ok(profile.testRunners.includes('vitest'));
  assert.ok(profile.testRunners.includes('playwright'));
  assert.equal(profile.scripts.test, 'vitest run');
  assert.deepEqual(profile.commands.verify, ['pnpm run lint', 'pnpm run typecheck', 'pnpm run test', 'pnpm run build']);
  assert.equal(profile.strictTdd, true);
});

test('detectRepoProfile reports python and go test capabilities', () => {
  const d = tmp();
  writeFileSync(join(d, 'pyproject.toml'), '[tool.pytest.ini_options]\nasyncio_mode = "auto"\n');
  writeFileSync(join(d, 'go.mod'), 'module x\n');

  const profile = detectRepoProfile(d);

  assert.ok(profile.stacks.includes('fastapi'));
  assert.ok(profile.stacks.includes('go'));
  assert.ok(profile.testRunners.includes('pytest'));
  assert.ok(profile.testRunners.includes('go test'));
  assert.ok(profile.commands.apply.includes('pytest'));
  assert.ok(profile.commands.verify.includes('go test ./...'));
});

test('detectRepoProfile detects monorepo workspaces', () => {
  const d = tmp();
  mkdirSync(join(d, 'packages'), { recursive: true });
  writeFileSync(join(d, 'package.json'), JSON.stringify({ workspaces: ['packages/*'] }));

  const profile = detectRepoProfile(d);

  assert.equal(profile.monorepo, true);
  assert.ok(profile.signals.includes('package.json#workspaces'));
});
