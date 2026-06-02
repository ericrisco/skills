import { skillById } from './manifest.js';

const OUTCOMES = {
  suggest: 'Un asistente que te va proponiendo lo que necesitas',
  harness: 'Un espacio de trabajo ordenado: conecta y documenta tu empresa',
  init: 'Arranque guiado de tu proyecto',
  nextjs: 'Tu web (rápida y lista para Google)',
  flutter: 'Tu app de móvil',
  fastapi: 'Tu API / backend en Python',
  go: 'Tu servicio backend en Go',
  postgresdb: 'Guardar tus datos de forma fiable',
  design: 'Que se vea bien y convierta',
  marketing: 'Textos que venden',
  presentations: 'Presentaciones con tu marca',
  'course-storytelling': 'Enseñar de forma que se entienda',
  'building-agents': 'Un agente de IA propio',
  'secure-coding': 'Que sea seguro',
  deployment: 'Publicarlo online',
};

export function expandRecommends(manifest, chosen) {
  const set = new Set(chosen);
  for (const id of chosen) {
    const s = skillById(manifest, id);
    for (const r of s?.recommends || []) set.add(r);
  }
  return [...set];
}

export function toOutcomes(ids) {
  return ids.map((id) => ({ id, label: OUTCOMES[id] || id }));
}
