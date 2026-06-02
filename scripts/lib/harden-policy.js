// harden-policy.js — pure loop-control for the skill-harden fix loop. No I/O, no randomness.
import { ABS_MIN, LIFT_MIN } from './behavior-score.js';

export const MAX_ROUNDS = 2;

function lastPass(history) {
  return history.length > 0 && history[history.length - 1].pass === true;
}

// { round, history, maxRounds? } -> { action: 'fix'|'stop-pass'|'stop-giveup' }
export function decideAction({ round, history, maxRounds = MAX_ROUNDS }) {
  if (lastPass(history)) return { action: 'stop-pass' };
  if (round >= maxRounds) return { action: 'stop-giveup' };
  return { action: 'fix' };
}

// history -> { kind: 'passed'|'deprecate-or-merge'|'needs-substance'|'mixed', message }
export function recommendationFor(history) {
  if (lastPass(history)) {
    return { kind: 'passed', message: 'Skill passes both gates after hardening.' };
  }
  const last = history[history.length - 1] || { absolute: 0, lift: 0 };
  const absOk = last.absolute >= ABS_MIN;
  const liftOk = last.lift >= LIFT_MIN;
  if (absOk && !liftOk) {
    return {
      kind: 'deprecate-or-merge',
      message: `Output is strong (absolute ${last.absolute}) but the skill barely beats no-skill (lift ${last.lift}). It does not justify itself — consider deprecating or merging it into a sibling.`,
    };
  }
  if (!absOk && liftOk) {
    return {
      kind: 'needs-substance',
      message: `The skill clearly helps (lift ${last.lift}) but the output still falls short (absolute ${last.absolute}). It needs more substance, not more triggering — deepen the body/references.`,
    };
  }
  return {
    kind: 'mixed',
    message: `Still failing after hardening (absolute ${last.absolute}, lift ${last.lift}). Re-examine scope and the capability scenario.`,
  };
}
