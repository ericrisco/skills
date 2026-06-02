import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

export function loadManifest() {
  return JSON.parse(readFileSync(join(ROOT, 'manifest.json'), 'utf8'));
}

export function skillById(manifest, id) {
  return manifest.skills.find((s) => s.id === id);
}

export function skillsForProfile(manifest, profile) {
  if (profile === 'full') return manifest.skills.map((s) => s.id);
  return manifest.skills.filter((s) => (s.profiles || []).includes(profile)).map((s) => s.id);
}
