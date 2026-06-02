import { test } from 'node:test';
import assert from 'node:assert/strict';
import { expandRecommends, toOutcomes } from '../scripts/lib/recommend.js';
import { loadManifest } from '../scripts/lib/manifest.js';

test('expandRecommends adds siblings of chosen skills', () => {
  const m = loadManifest();
  const out = expandRecommends(m, ['nextjs']);
  assert.ok(out.includes('design'));
});

test('toOutcomes renders human labels not skill names', () => {
  const labels = toOutcomes(['nextjs', 'deployment']);
  assert.ok(labels.every((l) => typeof l.label === 'string' && l.label.length));
});
