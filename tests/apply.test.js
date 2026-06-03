import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, existsSync, readFileSync, lstatSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { applyInstall, listInstalled, uninstall } from '../scripts/install-apply.js';
import { doctor } from '../scripts/doctor.js';
import { targetPaths } from '../targets/index.js';

const SESSION_START = join(dirname(fileURLToPath(import.meta.url)), '..', 'targets', 'session-start.sh');

function runSessionStart(root) {
  const suggest = join(root, 'suggest-SKILL.md');
  writeFileSync(suggest, '# rsc-suggest — detect & install\nalways-on body\n');
  return spawnSync('bash', [SESSION_START, suggest, root], { encoding: 'utf8' }).stdout;
}

test('session-start: emits suggest body + banner when no profile and no opt-out', () => {
  const root = mkdtempSync(join(tmpdir(), 'rsc-ss-'));
  const out = runSessionStart(root);
  assert.ok(out.includes('detect & install'), 'always cats suggest body');
  assert.ok(out.includes('rsc onboarding'), 'banner present on fresh install');
});

test('session-start: no banner once user-profile.md exists', () => {
  const root = mkdtempSync(join(tmpdir(), 'rsc-ss-'));
  mkdirSync(join(root, '02-DOCS/wiki/harness'), { recursive: true });
  writeFileSync(join(root, '02-DOCS/wiki/harness/user-profile.md'), 'technical_level: technical\n');
  const out = runSessionStart(root);
  assert.ok(out.includes('detect & install'), 'still cats suggest body');
  assert.ok(!out.includes('rsc onboarding'), 'no banner when profile exists');
});

test('session-start: no banner when .rsc/.no-harness opt-out exists', () => {
  const root = mkdtempSync(join(tmpdir(), 'rsc-ss-'));
  mkdirSync(join(root, '.rsc'), { recursive: true });
  writeFileSync(join(root, '.rsc/.no-harness'), '');
  const out = runSessionStart(root);
  assert.ok(!out.includes('rsc onboarding'), 'opt-out silences the banner');
});

test('targetPaths exposes the project root', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  const paths = targetPaths('claude', undefined, cwd);
  assert.equal(paths.projectRoot, cwd);
});

test('claude: project-local install links to .rsc base, wires hook, list/uninstall work', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest', 'fastapi'], target: 'claude', cwd });

  // Real files live once in the shared base; the assistant folder is a link to it.
  assert.ok(existsSync(join(cwd, '.rsc/skills/fastapi/SKILL.md')), 'base holds the real file');
  assert.ok(existsSync(join(cwd, '.claude/skills/rsc/fastapi/SKILL.md')), 'claude link resolves');
  assert.ok(existsSync(join(cwd, '.claude/skills/rsc/suggest/SKILL.md')));
  assert.equal(lstatSync(join(cwd, '.claude/skills/rsc/fastapi')).isSymbolicLink(), true, 'is a symlink, not a copy');

  const settings = JSON.parse(readFileSync(join(cwd, '.claude/settings.json'), 'utf8'));
  assert.ok(JSON.stringify(settings.hooks.SessionStart).includes('skills/rsc/suggest'));

  assert.ok(listInstalled({ target: 'claude', cwd }).includes('fastapi'));

  const health = doctor({ target: 'claude', cwd });
  assert.equal(health.missing.length, 0);
  assert.ok(health.hookWired);

  const preview = await uninstall({ skillIds: ['fastapi'], target: 'claude', cwd, dryRun: true });
  assert.ok(preview.length > 0);
  assert.ok(existsSync(join(cwd, '.claude/skills/rsc/fastapi/SKILL.md')), 'dry-run keeps files');

  await uninstall({ skillIds: ['fastapi'], target: 'claude', cwd });
  assert.ok(!existsSync(join(cwd, '.claude/skills/rsc/fastapi')), 'link removed');
  assert.ok(existsSync(join(cwd, '.rsc/skills/fastapi/SKILL.md')), 'shared base survives uninstall');
  assert.ok(!listInstalled({ target: 'claude', cwd }).includes('fastapi'));
});

test('claude: SessionStart runs session-start.sh and materializes it executable', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd });

  const settings = JSON.parse(readFileSync(join(cwd, '.claude/settings.json'), 'utf8'));
  const cmd = settings.hooks.SessionStart[0].hooks[0].command;
  assert.ok(cmd.includes('.rsc/session-start.sh'), 'hook runs the script');
  assert.ok(cmd.includes('skills/rsc/suggest'), 'passes suggest SKILL.md as arg');

  const script = join(cwd, '.rsc/session-start.sh');
  assert.ok(existsSync(script), 'script materialized into .rsc/');
  assert.ok(statSync(script).mode & 0o111, 'script is executable');
});

test('claude: wires worklog checkpoint on PreCompact + SessionEnd, materialized + idempotent', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd });
  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd }); // re-install → no dupes

  const settings = JSON.parse(readFileSync(join(cwd, '.claude/settings.json'), 'utf8'));
  for (const event of ['PreCompact', 'SessionEnd']) {
    assert.equal(settings.hooks[event].length, 1, `exactly one ${event} entry`);
    assert.ok(
      settings.hooks[event][0].hooks[0].command.includes('.rsc/worklog-checkpoint.sh'),
      `${event} runs the worklog checkpoint script`,
    );
  }

  const script = join(cwd, '.rsc/worklog-checkpoint.sh');
  assert.ok(existsSync(script), 'worklog-checkpoint.sh materialized into .rsc/');
  assert.ok(statSync(script).mode & 0o111, 'worklog-checkpoint.sh is executable');
});

test('claude: re-install migrates a legacy cat-style SessionStart in place (no dupes)', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  mkdirSync(join(cwd, '.claude'), { recursive: true });
  writeFileSync(join(cwd, '.claude/settings.json'), JSON.stringify({
    hooks: { SessionStart: [{ hooks: [{ type: 'command', command: 'cat "/x/.claude/skills/rsc/suggest/SKILL.md"' }] }] },
  }, null, 2));

  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd });

  const settings = JSON.parse(readFileSync(join(cwd, '.claude/settings.json'), 'utf8'));
  assert.equal(settings.hooks.SessionStart.length, 1, 'exactly one SessionStart entry');
  assert.ok(settings.hooks.SessionStart[0].hooks[0].command.includes('.rsc/session-start.sh'), 'migrated to script form');
});

test('claude: a user SessionStart hook is preserved through wiring', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  mkdirSync(join(cwd, '.claude'), { recursive: true });
  writeFileSync(join(cwd, '.claude/settings.json'), JSON.stringify({
    hooks: { SessionStart: [{ hooks: [{ type: 'command', command: 'echo mine' }] }] },
  }, null, 2));

  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd });

  const settings = JSON.parse(readFileSync(join(cwd, '.claude/settings.json'), 'utf8'));
  const cmds = settings.hooks.SessionStart.map((e) => e.hooks[0].command);
  assert.ok(cmds.some((c) => c === 'echo mine'), 'user hook untouched');
  assert.ok(cmds.some((c) => c.includes('.rsc/session-start.sh')), 'rsc hook added');
});

test('codex: appends always-on block to AGENTS.md and links the base', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest', 'go'], target: 'codex', cwd });
  const agents = readFileSync(join(cwd, 'AGENTS.md'), 'utf8');
  assert.ok(agents.includes('rsc-suggest:start'));
  assert.ok(existsSync(join(cwd, '.codex/rsc/go/SKILL.md')));
  assert.ok(existsSync(join(cwd, '.rsc/skills/go/SKILL.md')));
});

test('antigravity: links base and wires suggest into .antigravity/AGENTS.md', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest', 'go'], target: 'antigravity', cwd });
  assert.ok(existsSync(join(cwd, '.antigravity/rsc/go/SKILL.md')));
  assert.ok(readFileSync(join(cwd, '.antigravity/AGENTS.md'), 'utf8').includes('rsc-suggest:start'));
});

test('two assistants share a single base copy (no duplication)', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest', 'go'], target: 'claude', cwd });
  const before = statSync(join(cwd, '.rsc/skills/go/SKILL.md')).ino;
  await applyInstall({ skillIds: ['suggest', 'go'], target: 'codex', cwd });
  const after = statSync(join(cwd, '.rsc/skills/go/SKILL.md')).ino;
  assert.equal(before, after, 'base file reused, not recreated, across assistants');
  assert.ok(existsSync(join(cwd, '.claude/skills/rsc/go/SKILL.md')));
  assert.ok(existsSync(join(cwd, '.codex/rsc/go/SKILL.md')));
});

test('copilot: links base under .github/rsc and wires copilot-instructions.md', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest', 'go'], target: 'copilot', cwd });
  assert.ok(existsSync(join(cwd, '.github/rsc/go/SKILL.md')));
  assert.ok(readFileSync(join(cwd, '.github/copilot-instructions.md'), 'utf8').includes('rsc-suggest:start'));
});

test('windsurf: links base and wires an always-on rule file', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest', 'go'], target: 'windsurf', cwd });
  assert.ok(existsSync(join(cwd, '.windsurf/rsc/go/SKILL.md')));
  assert.ok(readFileSync(join(cwd, '.windsurf/rules/rsc-suggest.md'), 'utf8').includes('rsc-suggest:start'));
});

// Every AGENTS.md-family assistant injects the same idempotent block into the
// one shared AGENTS.md — selecting several must not duplicate it.
test('AGENTS.md family (codex/zed/opencode/amp/jules) shares one idempotent block', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  for (const target of ['codex', 'zed', 'opencode', 'amp', 'jules']) {
    await applyInstall({ skillIds: ['suggest', 'go'], target, cwd });
    assert.ok(existsSync(join(cwd, `.${target}/rsc/go/SKILL.md`)));
  }
  const agents = readFileSync(join(cwd, 'AGENTS.md'), 'utf8');
  assert.equal(agents.match(/rsc-suggest:start/g).length, 1, 'block appears exactly once');
});

test('cross-target: onboarding gate text rides suggest into a non-claude target', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest'], target: 'codex', cwd });
  const agents = readFileSync(join(cwd, 'AGENTS.md'), 'utf8');
  assert.ok(agents.includes('Onboarding gate'), 'gate section injected cross-target');
  assert.ok(agents.includes('.no-harness'), 'opt-out marker documented in the injected block');
});

test('unknown target throws', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await assert.rejects(() => applyInstall({ skillIds: ['suggest'], target: 'nope', cwd }), /unknown target/);
});
