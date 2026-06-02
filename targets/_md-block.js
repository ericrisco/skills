import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { linkOrCopy } from './index.js';

// Shared adapter for every assistant whose "always-on" surface is a plain
// markdown instructions/rules file (AGENTS.md, copilot-instructions.md, a
// .windsurf/.roo/.continue rule, …). Skills are symlinked to the shared base;
// the suggest block is injected between idempotent markers so re-installs and
// multiple assistants sharing one file never duplicate it.
const MARK_START = '<!-- rsc-suggest:start -->';
const MARK_END = '<!-- rsc-suggest:end -->';

export function writeSkill(id, fromDir, toPath) {
  return linkOrCopy(fromDir, toPath);
}

export function wireHook(paths, sourceMd) {
  const body = stripFrontmatter(readFileSync(sourceMd, 'utf8'));
  const block = `${MARK_START}\n${body}\n${MARK_END}`;
  let doc = existsSync(paths.hookTarget) ? readFileSync(paths.hookTarget, 'utf8') : '';
  if (doc.includes(MARK_START)) {
    doc = doc.replace(new RegExp(`${MARK_START}[\\s\\S]*?${MARK_END}`), block);
  } else {
    doc += `\n\n${block}\n`;
  }
  mkdirSync(dirname(paths.hookTarget), { recursive: true });
  writeFileSync(paths.hookTarget, doc);
  return [paths.hookTarget];
}

function stripFrontmatter(md) {
  return md.replace(/^---\n[\s\S]*?\n---\n?/, '');
}
