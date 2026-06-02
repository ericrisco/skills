import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decideAction, recommendationFor, MAX_ROUNDS } from '../scripts/lib/harden-policy.js';

test('MAX_ROUNDS is 2', () => {
  assert.equal(MAX_ROUNDS, 2);
});

test('decideAction returns stop-pass when the latest round passed', () => {
  const a = decideAction({ round: 1, history: [{ absolute: 8.0, lift: 1.5, pass: false }, { absolute: 8.7, lift: 1.5, pass: true }] });
  assert.equal(a.action, 'stop-pass');
});

test('decideAction returns fix when failing and rounds remain', () => {
  const a = decideAction({ round: 0, history: [] });
  assert.equal(a.action, 'fix');
  const b = decideAction({ round: 1, history: [{ absolute: 8.0, lift: 1.5, pass: false }] });
  assert.equal(b.action, 'fix');
});

test('decideAction returns stop-giveup at the round cap while still failing', () => {
  const a = decideAction({ round: 2, history: [
    { absolute: 8.0, lift: 1.5, pass: false },
    { absolute: 8.2, lift: 1.6, pass: false },
  ] });
  assert.equal(a.action, 'stop-giveup');
});

test('recommendationFor flags deprecate-or-merge on stuck lift with high absolute', () => {
  const r = recommendationFor([{ absolute: 9.8, lift: 0.2, pass: false }, { absolute: 9.7, lift: 0.3, pass: false }]);
  assert.equal(r.kind, 'deprecate-or-merge');
  assert.match(r.message, /justif/i);
});

test('recommendationFor flags needs-substance on stuck low absolute', () => {
  const r = recommendationFor([{ absolute: 8.0, lift: 3.0, pass: false }, { absolute: 8.1, lift: 3.0, pass: false }]);
  assert.equal(r.kind, 'needs-substance');
});

test('recommendationFor returns passed when the last round passed', () => {
  const r = recommendationFor([{ absolute: 8.8, lift: 1.4, pass: true }]);
  assert.equal(r.kind, 'passed');
});
