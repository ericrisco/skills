import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { targetPaths } from '../../targets/index.js';
import { loadManifest } from './manifest.js';
import { readState } from './state.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

export function refreshRegistry({
  cwd = process.cwd(),
  target = 'codex',
  home = homedir(),
  manifest = loadManifest(),
  catalogRoot = ROOT,
} = {}) {
  const dir = join(cwd, '.rsc');
  mkdirSync(dir, { recursive: true });
  const registry = buildRegistry({ cwd, target, home, manifest, catalogRoot });
  writeFileSync(join(dir, 'skill-registry.json'), JSON.stringify(registry, null, 2) + '\n');
  writeFileSync(join(dir, 'skill-registry.md'), renderRegistryMarkdown(registry));
  return registry;
}

export function registryStatus({ cwd = process.cwd() } = {}) {
  const path = join(cwd, '.rsc', 'skill-registry.json');
  if (!existsSync(path)) return { exists: false, path };
  const data = JSON.parse(readFileSync(path, 'utf8'));
  return {
    exists: true,
    path,
    version: data.version,
    counts: data.counts || { skills: data.skills?.length || 0 },
  };
}

export function buildRegistry({
  cwd = process.cwd(),
  target = 'codex',
  home = homedir(),
  manifest = loadManifest(),
  catalogRoot = ROOT,
} = {}) {
  const installed = installedIds({ target, home, cwd });
  const skills = manifest.skills.map((skill) => {
    const skillPath = resolve(catalogRoot, 'skills', skill.id, 'SKILL.md');
    const available = existsSync(skillPath);
    return {
      id: skill.id,
      trigger: skill.description,
      tags: skill.tags || [],
      source: 'catalog',
      path: skillPath,
      installed: installed.has(skill.id),
      available,
      hash: hashSkill({ ...skill, path: skillPath, available }),
    };
  }).sort((a, b) => a.id.localeCompare(b.id));
  return {
    version: 1,
    target,
    root: resolve(cwd),
    counts: {
      skills: skills.length,
      installed: skills.filter((s) => s.installed).length,
      available: skills.filter((s) => s.available).length,
    },
    skills,
  };
}

export function renderRegistryMarkdown(registry) {
  const rows = [
    '# RSC Skill Registry',
    '',
    `Target: ${registry.target}`,
    `Skills: ${registry.counts.skills} (${registry.counts.installed} installed, ${registry.counts.available} available)`,
    '',
    '| id | installed | available | tags | path |',
    '| --- | --- | --- | --- | --- |',
  ];
  for (const skill of registry.skills) {
    rows.push(`| ${skill.id} | ${yesNo(skill.installed)} | ${yesNo(skill.available)} | ${(skill.tags || []).join(', ')} | ${skill.path} |`);
  }
  return rows.join('\n') + '\n';
}

function installedIds({ target, home, cwd }) {
  const paths = targetPaths(target, home, cwd);
  return new Set(Object.keys(readState(paths.stateFile).skills || {}));
}

function hashSkill(skill) {
  return createHash('sha256')
    .update(JSON.stringify({
      id: skill.id,
      trigger: skill.description,
      tags: skill.tags || [],
      path: skill.path,
      available: skill.available,
    }))
    .digest('hex')
    .slice(0, 12);
}

function yesNo(value) {
  return value ? 'yes' : 'no';
}
