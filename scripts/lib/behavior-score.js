// behavior-score.js — pure scoring math for the behavioral skill gate.
// No I/O, no LLM, no randomness: every function is deterministic and unit-tested.
// The Workflow engine returns raw grader signals; this lib turns them into the /10.

export const ABS_MIN = 8.5;
export const LIFT_MIN = 1.0;
export const COVERAGE_WEIGHT = 0.6;
export const QUALITY_WEIGHT = 0.4;

export function round1(x) {
  return Math.round(x * 10) / 10;
}

// Compose one output's 0-10 from grader signals.
// signals: { mustInclude: [{satisfied:boolean}], quality: {completeness,actionability,correctness,grounding} }
export function composeOutputScore(signals) {
  const mi = Array.isArray(signals && signals.mustInclude) ? signals.mustInclude : [];
  const total = mi.length;
  const satisfied = mi.filter((m) => m && m.satisfied).length;
  const q = (signals && signals.quality) || {};
  const qVals = [q.completeness, q.actionability, q.correctness, q.grounding]
    .map((v) => (typeof v === 'number' ? v : 0));
  const quality = qVals.reduce((a, b) => a + b, 0) / qVals.length; // 0-10
  if (total === 0) return round1(quality); // no checklist -> quality only
  const coverage = (satisfied / total) * 10; // 0-10
  return round1(COVERAGE_WEIGHT * coverage + QUALITY_WEIGHT * quality);
}

// treatmentScore/baselineScore are composed 0-10 numbers.
export function deriveScenario(treatmentScore, baselineScore) {
  return { absolute: round1(treatmentScore), delta: round1(treatmentScore - baselineScore) };
}

// scenarios: array of {absolute, delta} | null
export function aggregate(scenarios) {
  const valid = scenarios.filter((s) => s && typeof s.absolute === 'number');
  const dropped = scenarios.length - valid.length;
  if (valid.length === 0) return { absoluteScore: null, lift: null, n: 0, dropped };
  const absoluteScore = round1(valid.reduce((a, s) => a + s.absolute, 0) / valid.length);
  const lift = round1(valid.reduce((a, s) => a + s.delta, 0) / valid.length);
  return { absoluteScore, lift, n: valid.length, dropped };
}

export function behavioralGate(agg) {
  const reasons = [];
  const mustFix = [];
  if (!agg || agg.n === 0) {
    reasons.push('No gradeable capability scenarios (none present or all dropped).');
    mustFix.push('Add at least one capability scenario with a must_include rubric, then re-run.');
    return { pass: false, reasons, mustFix };
  }
  let pass = true;
  if (agg.absoluteScore < ABS_MIN) {
    pass = false;
    reasons.push(`absolute_score ${agg.absoluteScore} < ${ABS_MIN}`);
    mustFix.push(`Raise produced-output quality: absolute ${agg.absoluteScore}, needs >= ${ABS_MIN}.`);
  }
  if (agg.lift < LIFT_MIN) {
    pass = false;
    reasons.push(`lift ${agg.lift} < ${LIFT_MIN}`);
    mustFix.push(`Skill barely beats no-skill (lift ${agg.lift}). Make the body add value a bare agent lacks.`);
  }
  return { pass, reasons, mustFix };
}

// raw: { skillId, scenarios: [{index, xIsTreatment, gradeX, gradeY, error?}] }
export function scoreFromRaw(raw) {
  const scenarios = (raw && Array.isArray(raw.scenarios) ? raw.scenarios : []).map((s) => {
    if (!s || s.error || !s.gradeX || !s.gradeY) {
      return { index: s ? s.index : null, error: (s && s.error) || 'missing-grade', absolute: null, delta: null };
    }
    const treatment = s.xIsTreatment ? s.gradeX : s.gradeY;
    const baseline = s.xIsTreatment ? s.gradeY : s.gradeX;
    const t = composeOutputScore(treatment);
    const b = composeOutputScore(baseline);
    const d = deriveScenario(t, b);
    return { index: s.index, treatment: t, baseline: b, absolute: d.absolute, delta: d.delta };
  });
  const agg = aggregate(scenarios);
  const gate = behavioralGate(agg);
  return { skillId: (raw && raw.skillId) || null, scenarios, aggregate: agg, gate };
}

export function formatScorecard(scored) {
  const { skillId, scenarios, aggregate: agg, gate } = scored;
  const lines = [];
  lines.push(`# Behavioral scorecard — ${skillId || '(unknown skill)'}`);
  lines.push('');
  lines.push(`**Verdict:** ${gate.pass ? 'PASS ✅' : 'FAIL ❌'}  ·  absolute ${agg.absoluteScore == null ? 'n/a' : agg.absoluteScore}/10 (gate >= ${ABS_MIN})  ·  lift ${agg.lift == null ? 'n/a' : agg.lift} (gate >= ${LIFT_MIN})  ·  n=${agg.n}${agg.dropped ? ` (${agg.dropped} dropped)` : ''}`);
  lines.push('');
  lines.push('| Scenario | Treatment | Baseline | Delta |');
  lines.push('|---|---|---|---|');
  for (const s of scenarios) {
    if (s.error) { lines.push(`| ${s.index} | — | — | dropped (${s.error}) |`); continue; }
    lines.push(`| ${s.index} | ${s.treatment} | ${s.baseline} | ${s.delta >= 0 ? '+' : ''}${s.delta} |`);
  }
  if (!gate.pass) {
    lines.push('');
    lines.push('**Must fix:**');
    for (const f of gate.mustFix) lines.push(`- ${f}`);
  }
  return lines.join('\n');
}
