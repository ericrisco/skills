import { readdirSync, readFileSync, writeFileSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv from 'ajv';
import { parseFrontmatter } from './lib/frontmatter.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SKILLS = join(ROOT, 'skills');

function skillDirs() {
  return readdirSync(SKILLS).filter((d) => {
    try { return statSync(join(SKILLS, d)).isDirectory(); } catch { return false; }
  });
}

export function buildManifest() {
  const version = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8')).version;
  const skills = skillDirs().map((id) => {
    const fm = parseFrontmatter(readFileSync(join(SKILLS, id, 'SKILL.md'), 'utf8'));
    return {
      id,
      description: fm.description,
      tags: fm.tags || [],
      recommends: fm.recommends || [],
      profiles: fm.profiles || [],
    };
  }).sort((a, b) => a.id.localeCompare(b.id));
  return { version, counts: { skills: skills.length }, skills };
}

export function validateFrontmatter() {
  const ajv = new Ajv({ allErrors: true });
  const schema = JSON.parse(readFileSync(join(ROOT, 'schema/frontmatter.schema.json'), 'utf8'));
  const validate = ajv.compile(schema);
  const ids = skillDirs();
  const known = new Set(ids);
  const errors = [];
  for (const id of ids) {
    const fm = parseFrontmatter(readFileSync(join(SKILLS, id, 'SKILL.md'), 'utf8'));
    if (!validate(fm)) errors.push(`${id}: ${ajv.errorsText(validate.errors)}`);
    for (const r of fm.recommends || []) if (!known.has(r)) errors.push(`${id}: dangling recommends '${r}'`);
  }
  return errors;
}

function main() {
  const arg = process.argv[2];
  const out = join(ROOT, 'manifest.json');
  if (arg === '--validate') {
    const errs = validateFrontmatter();
    if (errs.length) { console.error(errs.join('\n')); process.exit(1); }
    console.log('frontmatter OK');
    return;
  }
  const manifest = buildManifest();
  const json = JSON.stringify(manifest, null, 2) + '\n';
  if (arg === '--check') {
    let current = '';
    try { current = readFileSync(out, 'utf8'); } catch { /* missing */ }
    if (current !== json) { console.error('manifest.json is stale — run `npm run manifest`'); process.exit(1); }
    console.log(`manifest OK (${manifest.counts.skills} skills)`);
    return;
  }
  writeFileSync(out, json);
  console.log(`wrote manifest.json (${manifest.counts.skills} skills)`);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
