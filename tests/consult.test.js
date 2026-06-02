import { test } from 'node:test';
import assert from 'node:assert/strict';
import { rank } from '../scripts/consult.js';
import { loadManifest } from '../scripts/lib/manifest.js';

test('ranks postgres skill for a database query', async () => {
  const m = loadManifest();
  const ranked = await rank(m, 'guardar datos en una base de datos sql postgres');
  assert.ok(ranked.slice(0, 3).some((r) => r.id === 'postgresdb'));
});

test('ranks web skill for a website query', async () => {
  const m = loadManifest();
  const ranked = await rank(m, 'quiero una web nextjs react');
  assert.ok(ranked.slice(0, 3).some((r) => r.id === 'nextjs'));
});

test('empty query returns []', async () => {
  const m = loadManifest();
  assert.deepEqual(await rank(m, '   '), []);
});
