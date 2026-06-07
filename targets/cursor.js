import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';

export function writeSkill(id, fromDir, toPath) {
  const body = readFileSync(join(fromDir, 'SKILL.md'), 'utf8');
  mkdirSync(dirname(toPath), { recursive: true });
  writeFileSync(toPath, `---\ndescription: rsc skill ${id}\nalwaysApply: false\n---\n${stripFrontmatter(body)}`);
  return [toPath];
}

export function wireHook(paths, sourceMd) {
  const body = stripFrontmatter(readFileSync(sourceMd, 'utf8'));
  mkdirSync(dirname(paths.hookTarget), { recursive: true });
  writeFileSync(paths.hookTarget, `---\ndescription: rsc auto-suggest\nalwaysApply: true\n---\n${body}`);
  return [paths.hookTarget];
}

// Inverse of wireHook: the cursor detector is its own file, so just remove it.
export function unwireHook(paths) {
  if (!existsSync(paths.hookTarget)) return [];
  rmSync(paths.hookTarget, { force: true });
  return [paths.hookTarget];
}

function stripFrontmatter(md) {
  return md.replace(/^---\n[\s\S]*?\n---\n?/, '');
}
