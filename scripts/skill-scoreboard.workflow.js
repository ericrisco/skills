export const meta = {
  name: 'skill-scoreboard',
  description: 'Behaviorally evaluate several rsc skills in parallel (detect only, no fixing) and return each one\'s raw A/B grader signals for local scoring',
  phases: [
    { title: 'Score' },
  ],
}

const ids = Array.isArray(args) ? args : (args && Array.isArray(args.skills) ? args.skills : [])
if (ids.length === 0) throw new Error('skill-scoreboard: pass an array of skill ids as args, e.g. ["debug","grants"]')

phase('Score')
const rows = await parallel(
  ids.map((id) => () =>
    workflow('skill-behavior-eval', id)
      .then((raw) => ({ id, raw }))
      .catch((e) => ({ id, raw: { skillId: id, scenarios: [], error: String(e && e.message || e) } })),
  ),
)

return { rows: rows.filter(Boolean) }
