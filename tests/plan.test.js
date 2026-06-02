import { test } from 'node:test';
import assert from 'node:assert/strict';
import { planInstall } from '../scripts/install-plan.js';

test('plan copies each skill dir for claude target', () => {
  const plan = planInstall({ skillIds: ['fastapi'], target: 'claude', home: '/home/u' });
  const skillStep = plan.find((p) => p.kind === 'skill' && p.id === 'fastapi');
  assert.ok(skillStep.to.includes('.claude/skills/rsc/fastapi'));
});

test('plan wires hook when suggest is included', () => {
  const plan = planInstall({ skillIds: ['suggest'], target: 'claude', home: '/home/u' });
  assert.ok(plan.some((p) => p.kind === 'hook'));
});

test('plan has no hook when suggest absent', () => {
  const plan = planInstall({ skillIds: ['go'], target: 'cursor', home: '/home/u' });
  assert.ok(!plan.some((p) => p.kind === 'hook'));
});
