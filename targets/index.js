import { existsSync, lstatSync, mkdirSync, rmSync, symlinkSync, cpSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { homedir } from 'node:os';
import * as claudeAdapter from './claude.js';
import * as cursorAdapter from './cursor.js';
import * as mdAdapter from './_md-block.js';

// Project-local single source of truth. Real skill files live here exactly once;
// every assistant gets a lightweight pointer (symlink) back to it — no duplication.
export function baseDir(id, cwd = process.cwd()) {
  return join(cwd, '.rsc', 'skills', id);
}

// Point an assistant's skill folder at the shared base. On macOS/Linux a relative
// symlink avoids duplication. On Windows we copy real files: relative `dir`
// symlinks require Developer Mode/admin and are not reliably followed by skill
// discovery, so correctness wins over de-duplication. Idempotent: replaces any
// existing link/dir at toPath.
export function linkOrCopy(fromDir, toPath) {
  mkdirSync(dirname(toPath), { recursive: true });
  try { lstatSync(toPath); rmSync(toPath, { recursive: true, force: true }); } catch { /* nothing there */ }
  if (process.platform === 'win32') {
    cpSync(fromDir, toPath, { recursive: true });
  } else {
    try {
      symlinkSync(relative(dirname(toPath), fromDir), toPath, 'dir');
    } catch {
      cpSync(fromDir, toPath, { recursive: true });
    }
  }
  return [toPath];
}

// One row per assistant. `root` is where its skill folder lives (relative to the
// project), `hook` is the file that gets the always-on suggest block, `adapter`
// picks how skills + hook are written. `skillExt` (cursor only) means each skill
// is a single converted file, not a linked directory.
const SPEC = {
  // JSON-hook + linked skill dirs
  claude: { root: '.claude/skills', hook: '.claude/settings.json', adapter: 'claude' },
  // Converted .mdc rules
  cursor: { root: '.cursor/rules', hook: '.cursor/rules/rsc-suggest.mdc', adapter: 'cursor', skillExt: '.mdc' },
  // AGENTS.md family — all read the same root AGENTS.md
  codex: { root: '.codex/rsc', hook: 'AGENTS.md', adapter: 'md' },
  opencode: { root: '.opencode/rsc', hook: 'AGENTS.md', adapter: 'md' },
  amp: { root: '.amp/rsc', hook: 'AGENTS.md', adapter: 'md' },
  jules: { root: '.jules/rsc', hook: 'AGENTS.md', adapter: 'md' },
  zed: { root: '.zed/rsc', hook: 'AGENTS.md', adapter: 'md' },
  // Own markdown instructions/rules file
  gemini: { root: '.gemini/rsc', hook: 'GEMINI.md', adapter: 'md' },
  antigravity: { root: '.antigravity/rsc', hook: '.antigravity/AGENTS.md', adapter: 'md' },
  copilot: { root: '.github/rsc', hook: '.github/copilot-instructions.md', adapter: 'md' },
  windsurf: { root: '.windsurf/rsc', hook: '.windsurf/rules/rsc-suggest.md', adapter: 'md' },
  cline: { root: '.clinerules/rsc', hook: '.clinerules/rsc-suggest.md', adapter: 'md' },
  roo: { root: '.roo/rsc', hook: '.roo/rules/rsc-suggest.md', adapter: 'md' },
  continue: { root: '.continue/rsc', hook: '.continue/rules/rsc-suggest.md', adapter: 'md' },
  junie: { root: '.junie/rsc', hook: '.junie/guidelines.md', adapter: 'md' },
  kiro: { root: '.kiro/rsc', hook: '.kiro/steering/rsc-suggest.md', adapter: 'md' },
  aider: { root: '.aider/rsc', hook: 'CONVENTIONS.md', adapter: 'md' },
};

const ADAPTER = { claude: claudeAdapter, cursor: cursorAdapter, md: mdAdapter };

// Wizard multi-select list, in "most famous first" order. label/hint are display
// only; detectTarget just pre-marks the one found in the folder.
export const TARGETS = [
  { id: 'claude', label: 'Claude Code', hint: '.claude/skills/' },
  { id: 'codex', label: 'Codex CLI', hint: 'AGENTS.md' },
  { id: 'copilot', label: 'GitHub Copilot', hint: '.github/copilot-instructions.md' },
  { id: 'cursor', label: 'Cursor', hint: '.cursor/rules/' },
  { id: 'gemini', label: 'Gemini CLI', hint: 'GEMINI.md' },
  { id: 'windsurf', label: 'Windsurf', hint: '.windsurf/rules/' },
  { id: 'cline', label: 'Cline', hint: '.clinerules/' },
  { id: 'antigravity', label: 'Antigravity', hint: '.antigravity/' },
  { id: 'zed', label: 'Zed', hint: 'AGENTS.md' },
  { id: 'continue', label: 'Continue', hint: '.continue/rules/' },
  { id: 'roo', label: 'Roo Code', hint: '.roo/rules/' },
  { id: 'amp', label: 'Amp', hint: 'AGENTS.md' },
  { id: 'opencode', label: 'opencode', hint: 'AGENTS.md' },
  { id: 'jules', label: 'Jules', hint: 'AGENTS.md' },
  { id: 'junie', label: 'JetBrains Junie', hint: '.junie/guidelines.md' },
  { id: 'kiro', label: 'Kiro', hint: '.kiro/steering/' },
  { id: 'aider', label: 'Aider', hint: 'CONVENTIONS.md' },
];

// Best-effort default for the wizard's pre-mark. Unique config dirs win; the
// shared AGENTS.md / GEMINI.md fall through to codex / gemini.
export function detectTarget(cwd = process.cwd()) {
  const dir = (d) => existsSync(join(cwd, d));
  if (dir('.cursor')) return 'cursor';
  if (dir('.windsurf')) return 'windsurf';
  if (dir('.clinerules')) return 'cline';
  if (dir('.roo')) return 'roo';
  if (dir('.continue')) return 'continue';
  if (dir('.junie')) return 'junie';
  if (dir('.kiro')) return 'kiro';
  if (dir('.zed')) return 'zed';
  if (dir('.opencode')) return 'opencode';
  if (dir('.amp')) return 'amp';
  if (dir('.jules')) return 'jules';
  if (dir('.antigravity')) return 'antigravity';
  if (existsSync(join(cwd, '.github', 'copilot-instructions.md'))) return 'copilot';
  if (dir('.codex') || dir('AGENTS.md')) return 'codex';
  if (dir('.gemini') || dir('GEMINI.md')) return 'gemini';
  return 'claude';
}

export function targetPaths(target, home = homedir(), cwd = process.cwd()) {
  const s = SPEC[target];
  if (!s) throw new Error(`unknown target ${target}`);
  const rootAbs = join(cwd, ...s.root.split('/'));
  return {
    root: rootAbs,
    projectRoot: cwd,
    skillDir: (id) => (s.skillExt ? join(rootAbs, `${id}${s.skillExt}`) : join(rootAbs, id)),
    stateFile: join(rootAbs, '.rsc-state.json'),
    hookTarget: join(cwd, ...s.hook.split('/')),
  };
}

export function writeSkill(target, id, fromDir, toPath) {
  return ADAPTER[SPEC[target].adapter].writeSkill(id, fromDir, toPath);
}

export function wireHook(target, paths, sourceMd) {
  return ADAPTER[SPEC[target].adapter].wireHook(paths, sourceMd);
}

// Inverse of wireHook — remove rsc's always-on surface for a target (settings.json
// hook entries / AGENTS-block / cursor rule file). Returns the paths it touched.
export function unwireHook(target, paths) {
  const adapter = ADAPTER[SPEC[target].adapter];
  return adapter.unwireHook ? adapter.unwireHook(paths) : [];
}

// Every known target id — used by `purge` to sweep all assistants, installed or not.
export const TARGET_IDS = Object.keys(SPEC);
