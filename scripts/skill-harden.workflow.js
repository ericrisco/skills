export const meta = {
  name: 'skill-harden',
  description: 'Detect AND fix one rsc skill: behaviorally score it, diagnose the failure, edit the right artifact with anti-gaming guards, re-verify, and commit on pass (max 2 rounds)',
  phases: [
    { title: 'Evaluate' },
    { title: 'Diagnose & Fix' },
    { title: 'Commit' },
  ],
}

const skillId = (typeof args === 'string' ? args : (args && args.skillId)) || ''
if (!skillId) throw new Error('skill-harden: pass the skill id as args, e.g. "debug"')

const MAX_ROUNDS = 2

const SCORE_SCHEMA = {
  type: 'object',
  properties: {
    pass: { type: 'boolean' },
    absolute: { type: 'number' },
    lift: { type: 'number' },
    mustFix: { type: 'array', items: { type: 'string' } },
  },
  required: ['pass', 'absolute', 'lift', 'mustFix'],
}

const FAULT_SCHEMA = {
  type: 'object',
  properties: {
    fault: { type: 'string', enum: ['skill', 'eval'] },
    rationale: { type: 'string' },
  },
  required: ['fault', 'rationale'],
}

const GUARD_SCHEMA = {
  type: 'object',
  properties: {
    genuine: { type: 'boolean' },
    rationale: { type: 'string' },
  },
  required: ['genuine', 'rationale'],
}

const HOLDOUT_SCHEMA = {
  type: 'object',
  properties: {
    scenario: { type: 'string' },
    mustInclude: { type: 'array', items: { type: 'string' } },
  },
  required: ['scenario', 'mustInclude'],
}

// Score a raw eval result via the authoritative CLI (keeps math in behavior-score.js).
async function scoreRaw(raw, round) {
  return agent(
    `Write this JSON to /tmp/harden-${skillId}-r${round}.json exactly, then run ` +
    `\`node scripts/skill-behavior-eval.js --score /tmp/harden-${skillId}-r${round}.json\`. ` +
    `Read its markdown output and return {pass, absolute, lift, mustFix}: pass = the CLI exit code was 0 ` +
    `(scorecard says PASS), absolute and lift from the Verdict line, mustFix = the bullet list under "Must fix" ` +
    `(empty array if none).\n\nJSON:\n${JSON.stringify(raw)}`,
    { label: `score:r${round}`, phase: 'Evaluate', schema: SCORE_SCHEMA },
  )
}

const history = []
let round = 0
let committed = null

while (true) {
  phase('Evaluate')
  const raw = await workflow('skill-behavior-eval', skillId)
  if (raw && raw.error === 'no-capability-scenarios') {
    return { skillId, error: 'no-capability-scenarios', history, committed: null }
  }
  const score = await scoreRaw(raw, round)
  history.push({ absolute: score.absolute, lift: score.lift, pass: score.pass })

  if (score.pass) break
  if (round >= MAX_ROUNDS) break

  phase('Diagnose & Fix')
  const evidence = JSON.stringify(raw.scenarios || [])
  const fault = await agent(
    `Follow scripts/skill-harden-rubric.md (Diagnosis). The skill "${skillId}" FAILED its behavioral gate. ` +
    `mustFix:\n- ${score.mustFix.join('\n- ')}\n\nGrader signals (both A/B outputs, per-item evidence):\n${evidence}\n\n` +
    `Decide fault = 'skill' or 'eval' and give a rationale. Default to 'skill' when unsure.`,
    { label: `diagnose:r${round}`, phase: 'Diagnose & Fix', schema: FAULT_SCHEMA },
  )

  if (fault.fault === 'eval') {
    const judged = await agent(
      `Follow scripts/skill-harden-rubric.md (Eval-fix guard). Proposed: edit skills/${skillId}/evals/cases.yaml to ` +
      `correct an eval bias (self-describing scenario, or a phantom-context must_include item). ` +
      `Rationale from diagnosis: ${fault.rationale}\n\n` +
      `Decide genuine=true ONLY if the change corrects a real bias WITHOUT lowering the bar. If genuine, APPLY the ` +
      `edit to cases.yaml now (Edit tool); if not, change nothing. Return {genuine, rationale}.`,
      { label: `eval-judge:r${round}`, phase: 'Diagnose & Fix', schema: GUARD_SCHEMA },
    )
    if (!judged.genuine) {
      // Eval blamed but not justified -> fall through to a skill fix this round.
      fault.fault = 'skill'
    }
  }

  if (fault.fault === 'skill') {
    await agent(
      `Follow the author-skill discipline. The skill "${skillId}" must genuinely cover this mustFix without ` +
      `keyword-stuffing:\n- ${score.mustFix.join('\n- ')}\n\nEdit skills/${skillId}/SKILL.md (body) and/or files under ` +
      `skills/${skillId}/references/ to add the REAL missing capability (method, decision rules, concrete guidance). ` +
      `Do not touch evals/. Apply the edits now.`,
      { label: `fix:r${round}`, phase: 'Diagnose & Fix' },
    )
    const diffJudge = await agent(
      `Follow scripts/skill-harden-rubric.md (Skill-fix guard 1). Run \`git diff -- skills/${skillId}/SKILL.md skills/${skillId}/references\` ` +
      `and judge: does the diff add genuine capability, or just echo the mustFix wording to satisfy the grader? ` +
      `If it is keyword-stuffing, run \`git checkout -- skills/${skillId}/SKILL.md skills/${skillId}/references\` to revert it. ` +
      `Return {genuine, rationale}.`,
      { label: `diff-judge:r${round}`, phase: 'Diagnose & Fix', schema: GUARD_SCHEMA },
    )

    if (diffJudge.genuine) {
      // Guard 2: hold-out. Generate a fresh scenario and re-score the A/B on it only.
      const holdout = await agent(
        `Invent ONE fresh capability scenario for the "${skillId}" skill's domain that is NOT in its cases.yaml and ` +
        `does NOT enumerate its own requirements. Return {scenario, mustInclude:[3-6 outcome-level checks]}.`,
        { label: `holdout-gen:r${round}`, phase: 'Diagnose & Fix', schema: HOLDOUT_SCHEMA },
      )
      const holdoutRaw = await workflow('skill-behavior-eval', { skillId, scenarios: [holdout] })
      await scoreRaw(holdoutRaw, `${round}-holdout`) // recorded in transcript; informs the next loop's eval
    }
  }

  round++
}

const passed = history.length > 0 && history[history.length - 1].pass === true
if (passed) {
  phase('Commit')
  const commit = await agent(
    `The skill "${skillId}" now passes its behavioral gate. Commit ONLY its files: ` +
    `run \`git add skills/${skillId}\` then commit with a message describing the hardening. ` +
    `Author is Eric — do NOT add any Claude co-author or generated footer. Return the commit hash as plain text.`,
    { label: `commit:${skillId}`, phase: 'Commit' },
  )
  committed = (commit || '').trim()
}

return { skillId, rounds: round + 1, history, committed, passed }
