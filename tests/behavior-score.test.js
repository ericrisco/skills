import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  round1, composeOutputScore, deriveScenario, aggregate, behavioralGate,
  scoreFromRaw, formatScorecard, ABS_MIN, LIFT_MIN,
} from '../scripts/lib/behavior-score.js';

const HERE = dirname(fileURLToPath(import.meta.url));
const fixture = (name) => JSON.parse(readFileSync(join(HERE, 'fixtures', name), 'utf8'));

test('round1 rounds to one decimal', () => {
  assert.equal(round1(8.449), 8.4);
  assert.equal(round1(8.45), 8.5);
});

test('composeOutputScore blends coverage 60% and quality 40%', () => {
  // 4/5 satisfied => coverage 8.0; quality mean 9 => 0.6*8 + 0.4*9 = 8.4
  const s = composeOutputScore({
    mustInclude: [{ satisfied: true }, { satisfied: true }, { satisfied: true }, { satisfied: true }, { satisfied: false }],
    quality: { completeness: 9, actionability: 9, correctness: 9, grounding: 9 },
  });
  assert.equal(s, 8.4);
});

test('composeOutputScore with empty output scores 0', () => {
  const s = composeOutputScore({
    mustInclude: [{ satisfied: false }, { satisfied: false }],
    quality: { completeness: 0, actionability: 0, correctness: 0, grounding: 0 },
  });
  assert.equal(s, 0);
});

test('composeOutputScore with no checklist falls back to quality only', () => {
  const s = composeOutputScore({ mustInclude: [], quality: { completeness: 8, actionability: 8, correctness: 8, grounding: 8 } });
  assert.equal(s, 8);
});

test('deriveScenario computes absolute and delta', () => {
  assert.deepEqual(deriveScenario(9.0, 7.0), { absolute: 9, delta: 2 });
});

test('aggregate means absolute and lift, ignoring nulls', () => {
  const agg = aggregate([{ absolute: 9, delta: 2 }, null, { absolute: 8, delta: 1 }]);
  assert.deepEqual(agg, { absoluteScore: 8.5, lift: 1.5, n: 2, dropped: 1 });
});

test('aggregate with all nulls reports n=0', () => {
  assert.deepEqual(aggregate([null, null]), { absoluteScore: null, lift: null, n: 0, dropped: 2 });
});

test('behavioralGate passes when absolute>=8.5 and lift>=1.0', () => {
  const g = behavioralGate({ absoluteScore: 8.6, lift: 1.2, n: 2, dropped: 0 });
  assert.equal(g.pass, true);
  assert.equal(g.mustFix.length, 0);
});

test('behavioralGate fails on low absolute', () => {
  const g = behavioralGate({ absoluteScore: 8.0, lift: 2.0, n: 1, dropped: 0 });
  assert.equal(g.pass, false);
  assert.ok(g.reasons.some((r) => r.includes('absolute')));
});

test('behavioralGate fails on non-positive lift even with high absolute', () => {
  const g = behavioralGate({ absoluteScore: 9.5, lift: 0.2, n: 1, dropped: 0 });
  assert.equal(g.pass, false);
  assert.ok(g.reasons.some((r) => r.includes('lift')));
});

test('behavioralGate fails closed with no scenarios', () => {
  const g = behavioralGate({ absoluteScore: null, lift: null, n: 0, dropped: 0 });
  assert.equal(g.pass, false);
  assert.ok(g.mustFix[0].includes('capability scenario'));
});

test('thresholds are 8.5 and 1.0', () => {
  assert.equal(ABS_MIN, 8.5);
  assert.equal(LIFT_MIN, 1.0);
});

test('scoreFromRaw maps X/Y to treatment/baseline via xIsTreatment', () => {
  const r = scoreFromRaw(fixture('behavior-raw-pass.json'));
  // scenario 0: treatment=X (2/2 cov=10, q=9 -> 9.6), baseline=Y (1/2 cov=5, q=6.5 -> 5.6) delta 4.0
  assert.equal(r.scenarios[0].absolute, 9.6);
  assert.equal(r.scenarios[0].delta, 4.0);
  // scenario 1: treatment=Y (1/1 cov=10, q=9 -> 9.6), baseline=X (0/1 cov=0, q=5.5 -> 2.2) delta 7.4
  assert.equal(r.scenarios[1].absolute, 9.6);
  assert.equal(r.aggregate.absoluteScore, 9.6);
  assert.equal(r.gate.pass, true);
});

test('scoreFromRaw drops scenarios flagged with error to null', () => {
  const r = scoreFromRaw({ skillId: 'x', scenarios: [{ index: 0, error: 'grade-failed' }] });
  assert.equal(r.gate.pass, false);
  assert.equal(r.aggregate.n, 0);
});

test('formatScorecard renders verdict and the two aggregates', () => {
  const md = formatScorecard(scoreFromRaw(fixture('behavior-raw-pass.json')));
  assert.ok(md.includes('PASS'));
  assert.ok(md.includes('absolute'));
  assert.ok(md.includes('lift'));
});
