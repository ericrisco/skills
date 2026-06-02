import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { detectRepo } from '../scripts/detect-repo.js';

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
