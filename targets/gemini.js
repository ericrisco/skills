import { cpSync, readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const MARK_START = '<!-- rsc-suggest:start -->';
const MARK_END = '<!-- rsc-suggest:end -->';

export function writeSkill(id, fromDir, toPath) {
  mkdirSync(dirname(toPath), { recursive: true });
  cpSync(fromDir, toPath, { recursive: true });
  return [toPath];
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
