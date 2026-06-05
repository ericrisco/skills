#!/usr/bin/env node
// rsc Danger guard (claude). Wired by targets/claude.js onto PreToolUse (matcher Bash)
// as `node ...` so it runs on every platform including Windows.
//   argv[2] = absolute project root   stdin = PreToolUse hook JSON
//
// For a NON-TECHNICAL user (per 02-DOCS/wiki/harness/user-profile.md → technical_level),
// it DENIES irreversible, foot-gun Bash commands and tells the agent to find a safer,
// scoped alternative. A fully `technical` user is never guarded. Default-safe: if there
// is no profile yet, the harness convention is "assume non-technical", so the guard is ON.
//
// Disable per project with .rsc/.no-danger-guard — but only when the USER explicitly asks
// for it (the deny message says so). Fail-open on any internal error (never brick a shell).
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.argv[2] || process.cwd();

function allow() { process.exit(0); }
function deny(why) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason:
        `BLOCKED for a non-technical user — this command ${why}. ` +
        `Do NOT run it: explain the risk in plain language and propose a safer, scoped alternative ` +
        `(name exact paths, add a WHERE clause, back up first, etc.). ` +
        `Only if the USER explicitly insists on allowing dangerous commands here, create .rsc/.no-danger-guard to disable this guard.`,
    },
  }));
  process.exit(0);
}

if (existsSync(join(root, '.rsc', '.no-danger-guard'))) allow();

// technical_level === 'technical' → not guarded. non-technical / mixed / missing → guarded.
function technicalLevel() {
  try {
    const txt = readFileSync(join(root, '02-DOCS', 'wiki', 'harness', 'user-profile.md'), 'utf8');
    const m = txt.match(/technical_level:\s*([a-z-]+)/i);
    return m ? m[1].toLowerCase() : null;
  } catch { return null; }
}
if (technicalLevel() === 'technical') allow();

// Only Bash commands can be dangerous here.
let input = {};
try { input = JSON.parse(readFileSync(0, 'utf8') || '{}'); } catch { allow(); }
if ((input.tool_name || input.toolName) !== 'Bash') allow();
const cmd = input.tool_input?.command || input.toolInput?.command || '';
if (typeof cmd !== 'string' || !cmd) allow();

// --- the dangerous-command list ---------------------------------------------
// High-signal, low-false-positive. Each rule: what it catches and the plain why.
const noWhere = (verbRe) => verbRe.test(cmd) && !/\bwhere\b/i.test(cmd);

function isRmRecursiveForce() {
  if (!/\brm\b/.test(cmd)) return false;
  const hasR = /(-[a-z]*r[a-z]*|--recursive)\b/i.test(cmd);
  const hasF = /(-[a-z]*f[a-z]*|--force)\b/i.test(cmd);
  return hasR && hasF; // -rf / -fr / -r -f / --recursive --force
}

const RULES = [
  { id: 'rm-rf', why: 'deletes whole files/folders irreversibly (rm with -r and -f)', match: isRmRecursiveForce },
  { id: 'find-delete', why: 'mass-deletes matched files (find … -delete / -exec rm)', match: () => /\bfind\b[^|;&]*(-delete\b|-exec\s+rm\b)/i.test(cmd) },
  { id: 'dd-disk', why: 'overwrites a raw disk device and can destroy the whole drive (dd of=/dev/…)', match: () => /\bdd\b[^|;&]*\bof=\/dev\//i.test(cmd) },
  { id: 'mkfs', why: 'formats a filesystem, erasing everything on it (mkfs)', match: () => /\bmkfs(\.\w+)?\b/i.test(cmd) },
  { id: 'curl-pipe-shell', why: 'pipes a downloaded script straight into a shell (curl|bash) — runs untrusted code', match: () => /\b(curl|wget)\b[^|]*\|\s*(sudo\s+)?(sh|bash|zsh)\b/i.test(cmd) },

  { id: 'git-push-force', why: 'force-pushes and can overwrite shared history for everyone (git push --force)', match: () => /\bgit\s+push\b[^|;&]*(--force(?!-with-lease)\b|\s-f\b)/i.test(cmd) },
  { id: 'git-reset-hard', why: 'throws away all uncommitted work with no undo (git reset --hard)', match: () => /\bgit\s+reset\b[^|;&]*--hard\b/i.test(cmd) },
  { id: 'git-clean', why: 'permanently deletes untracked files (git clean -f)', match: () => /\bgit\s+clean\b[^|;&]*-[a-z]*f/i.test(cmd) },
  { id: 'git-branch-D', why: 'force-deletes a branch even if its work was never merged (git branch -D)', match: () => /\bgit\s+branch\b[^|;&]*\s-D\b/.test(cmd) },

  { id: 'sql-drop', why: 'drops an entire database/schema/table (DROP …)', match: () => /\bdrop\s+(database|schema|table)\b/i.test(cmd) },
  { id: 'sql-truncate', why: 'empties an entire table (TRUNCATE)', match: () => /\btruncate\s+(table\s+)?\S/i.test(cmd) },
  { id: 'sql-delete-no-where', why: 'deletes EVERY row — a DELETE with no WHERE clause', match: () => noWhere(/\bdelete\s+from\s+\S/i) },
  { id: 'sql-update-no-where', why: 'rewrites EVERY row — an UPDATE with no WHERE clause', match: () => noWhere(/\bupdate\s+\S+\s+set\b/i) },
  { id: 'mongo-wipe', why: 'drops a collection/database or deletes all documents (drop()/dropDatabase/deleteMany({}))', match: () => /\.drop\(\s*\)|dropdatabase\s*\(|deletemany\(\s*\{\s*\}\s*\)|\.remove\(\s*\{\s*\}\s*\)/i.test(cmd) },
];

for (const rule of RULES) {
  try { if (rule.match()) deny(rule.why); } catch { /* a rule erroring must never block */ }
}

allow();
