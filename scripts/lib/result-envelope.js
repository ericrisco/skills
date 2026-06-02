const REQUIRED = [
  'status',
  'executive_summary',
  'artifact',
  'next_recommended',
  'risk',
  'skill_resolution',
  'evidence',
];

export function validateResultEnvelope(envelope) {
  const errors = [];
  for (const key of REQUIRED) {
    if (envelope?.[key] === undefined) errors.push(`missing ${key}`);
  }
  const sr = envelope?.skill_resolution;
  if (sr !== undefined) {
    for (const key of ['used', 'missing', 'fallback', 'compact_rules']) {
      if (!Array.isArray(sr?.[key])) errors.push(`skill_resolution.${key} must be array`);
    }
  }
  if (envelope?.evidence !== undefined && !Array.isArray(envelope.evidence)) {
    errors.push('evidence must be array');
  }
  return errors;
}

export function parseResultEnvelope(text) {
  const match = text.match(/```json\s+result-envelope\s*\n([\s\S]*?)\n```/);
  if (!match) throw new Error('missing result-envelope json block');
  const envelope = JSON.parse(match[1]);
  const errors = validateResultEnvelope(envelope);
  if (errors.length) throw new Error(`invalid result envelope: ${errors.join(', ')}`);
  return envelope;
}
