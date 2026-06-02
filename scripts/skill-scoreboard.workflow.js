export const meta = {
  name: 'skill-scoreboard',
  description: 'Behaviorally evaluate several rsc skills in parallel (detect only, no fixing) and return each one\'s raw A/B grader signals for local scoring',
  phases: [
    { title: 'Score' },
  ],
}

function parseIds(a) {
  if (Array.isArray(a)) return a
  if (a && Array.isArray(a.skills)) return a.skills
  if (typeof a === 'string') {
    const s = a.trim()
    if (s.startsWith('[')) {
      try { const p = JSON.parse(s); if (Array.isArray(p)) return p } catch (_) { /* fall through */ }
    }
    return s.split(/[\s,]+/).filter(Boolean)
  }
  return []
}
const ids = parseIds(args)
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
