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

const SESSION_START = join(dirname(fileURLToPath(import.meta.url)), '..', 'targets', 'session-start.mjs');

function runSessionStart(root) {
  const suggest = join(root, 'suggest-SKILL.md');
  writeFileSync(suggest, '# rsc-suggest — detect & install\nalways-on body\n');
  return spawnSync('node', [SESSION_START, suggest, root], { encoding: 'utf8' }).stdout;
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

test('session-start: auto-ingest nudge when wiki exists and inbox has a real file', () => {
  const root = mkdtempSync(join(tmpdir(), 'rsc-ss-'));
  mkdirSync(join(root, '02-DOCS/wiki'), { recursive: true });
  mkdirSync(join(root, '02-DOCS/inbox'), { recursive: true });
  writeFileSync(join(root, '02-DOCS/inbox/invoice.pdf'), '%PDF-1.4');
  const out = runSessionStart(root);
  assert.ok(out.includes('rsc auto-ingest'), 'nudges the Auto-Ingest Sweep');
});

test('session-start: no auto-ingest nudge when inbox holds only README', () => {
  const root = mkdtempSync(join(tmpdir(), 'rsc-ss-'));
  mkdirSync(join(root, '02-DOCS/wiki'), { recursive: true });
  mkdirSync(join(root, '02-DOCS/inbox'), { recursive: true });
  writeFileSync(join(root, '02-DOCS/inbox/README.md'), 'drop zone');
  const out = runSessionStart(root);
  assert.ok(!out.includes('rsc auto-ingest'), 'README alone is not un-ingested material');
});

test('session-start: no auto-ingest nudge without a harness wiki', () => {
  const root = mkdtempSync(join(tmpdir(), 'rsc-ss-'));
  mkdirSync(join(root, '02-DOCS/inbox'), { recursive: true });
  writeFileSync(join(root, '02-DOCS/inbox/invoice.pdf'), '%PDF-1.4');
  const out = runSessionStart(root);
  assert.ok(!out.includes('rsc auto-ingest'), 'no wiki → nothing to ingest into yet');
});

test('targetPaths exposes the project root', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  const paths = targetPaths('claude', undefined, cwd);
  assert.equal(paths.projectRoot, cwd);
});

test('claude: skills install at the discoverable flat path .claude/skills/<id>/ (not nested under rsc/)', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-flat-'));
  await applyInstall({ skillIds: ['fastapi'], target: 'claude', cwd });
  // Claude Code discovers project skills at .claude/skills/<name>/SKILL.md — one level.
  // A skill nested at .claude/skills/rsc/<id>/ is NOT discovered (that was the Windows bug).
  assert.ok(existsSync(join(cwd, '.claude/skills/fastapi/SKILL.md')),
    'skill must sit one level under .claude/skills/ so Claude Code discovers it');
  assert.ok(!existsSync(join(cwd, '.claude/skills/rsc/fastapi/SKILL.md')),
    'must NOT be nested under an rsc/ subfolder');
});

test('claude: install migrates away the legacy nested .claude/skills/rsc/ layout', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-mig-'));
  // Simulate an old (broken) install that wrote skills under the nested rsc/ folder.
  mkdirSync(join(cwd, '.claude/skills/rsc/oldskill'), { recursive: true });
  writeFileSync(join(cwd, '.claude/skills/rsc/oldskill/SKILL.md'), 'stale');
  await applyInstall({ skillIds: ['fastapi'], target: 'claude', cwd });
  assert.ok(!existsSync(join(cwd, '.claude/skills/rsc')), 'legacy rsc/ folder removed on install');
  assert.ok(existsSync(join(cwd, '.claude/skills/fastapi/SKILL.md')), 'new flat skill present');
});

test('claude: project-local install links to .rsc base, wires hook, list/uninstall work', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest', 'fastapi'], target: 'claude', cwd });

  // Real files live once in the shared base; the assistant folder is a link to it.
  assert.ok(existsSync(join(cwd, '.rsc/skills/fastapi/SKILL.md')), 'base holds the real file');
  assert.ok(existsSync(join(cwd, '.claude/skills/fastapi/SKILL.md')), 'claude link resolves');
  assert.ok(existsSync(join(cwd, '.claude/skills/suggest/SKILL.md')));
  assert.equal(lstatSync(join(cwd, '.claude/skills/fastapi')).isSymbolicLink(), true, 'is a symlink, not a copy');

  const settings = JSON.parse(readFileSync(join(cwd, '.claude/settings.json'), 'utf8'));
  assert.ok(JSON.stringify(settings.hooks.SessionStart).includes('skills/suggest'));

  assert.ok(listInstalled({ target: 'claude', cwd }).includes('fastapi'));

  const health = doctor({ target: 'claude', cwd });
  assert.equal(health.missing.length, 0);
  assert.ok(health.hookWired);

  const preview = await uninstall({ skillIds: ['fastapi'], target: 'claude', cwd, dryRun: true });
  assert.ok(preview.length > 0);
  assert.ok(existsSync(join(cwd, '.claude/skills/fastapi/SKILL.md')), 'dry-run keeps files');

  await uninstall({ skillIds: ['fastapi'], target: 'claude', cwd });
  assert.ok(!existsSync(join(cwd, '.claude/skills/fastapi')), 'link removed');
  assert.ok(existsSync(join(cwd, '.rsc/skills/fastapi/SKILL.md')), 'shared base survives uninstall');
  assert.ok(!listInstalled({ target: 'claude', cwd }).includes('fastapi'));
});

test('claude: SessionStart runs session-start.mjs via node (Windows-safe), materialized', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd });

  const settings = JSON.parse(readFileSync(join(cwd, '.claude/settings.json'), 'utf8'));
  const cmd = settings.hooks.SessionStart[0].hooks[0].command;
  assert.ok(cmd.startsWith('node '), 'invoked via node, not bash, so it runs on Windows');
  assert.ok(cmd.includes('.rsc/session-start.mjs'), 'hook runs the node script');
  assert.ok(cmd.includes('skills/suggest'), 'passes suggest SKILL.md as arg');

  const script = join(cwd, '.rsc/session-start.mjs');
  assert.ok(existsSync(script), 'script materialized into .rsc/');
});

test('claude: wires worklog checkpoint on PreCompact + SessionEnd, materialized + idempotent', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd });
  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd }); // re-install → no dupes

  const settings = JSON.parse(readFileSync(join(cwd, '.claude/settings.json'), 'utf8'));
  for (const event of ['PreCompact', 'SessionEnd']) {
    assert.equal(settings.hooks[event].length, 1, `exactly one ${event} entry`);
    const cmd = settings.hooks[event][0].hooks[0].command;
    assert.ok(cmd.startsWith('node '), `${event} invoked via node (Windows-safe)`);
    assert.ok(cmd.includes('.rsc/worklog-checkpoint.mjs'), `${event} runs the worklog checkpoint script`);
  }

  const script = join(cwd, '.rsc/worklog-checkpoint.mjs');
  assert.ok(existsSync(script), 'worklog-checkpoint.mjs materialized into .rsc/');
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
  assert.ok(settings.hooks.SessionStart[0].hooks[0].command.includes('.rsc/session-start.mjs'), 'migrated to node script form');
});

test('claude: re-install migrates bash-era .sh hooks to node .mjs (no dupes)', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  mkdirSync(join(cwd, '.claude'), { recursive: true });
  writeFileSync(join(cwd, '.claude/settings.json'), JSON.stringify({
    hooks: {
      SessionStart: [{ hooks: [{ type: 'command', command: 'bash "/x/.rsc/session-start.sh" "/x/s" "/x"' }] }],
      PreCompact: [{ hooks: [{ type: 'command', command: 'bash "/x/.rsc/worklog-checkpoint.sh" "/x"' }] }],
      SessionEnd: [{ hooks: [{ type: 'command', command: 'bash "/x/.rsc/worklog-checkpoint.sh" "/x"' }] }],
    },
  }, null, 2));

  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd });

  const settings = JSON.parse(readFileSync(join(cwd, '.claude/settings.json'), 'utf8'));
  assert.equal(settings.hooks.SessionStart.length, 1, 'no dupe SessionStart');
  assert.ok(settings.hooks.SessionStart[0].hooks[0].command.includes('session-start.mjs'), 'SessionStart migrated to node');
  assert.ok(!JSON.stringify(settings.hooks).includes('session-start.sh'), 'old bash session-start entry gone');
  assert.equal(settings.hooks.PreCompact.length, 1, 'no dupe PreCompact');
  assert.ok(settings.hooks.PreCompact[0].hooks[0].command.includes('worklog-checkpoint.mjs'), 'worklog migrated to node');
  assert.ok(!JSON.stringify(settings.hooks).includes('worklog-checkpoint.sh'), 'old bash worklog entries gone');
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
  assert.ok(cmds.some((c) => c.includes('.rsc/session-start.mjs')), 'rsc hook added');
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
  assert.ok(existsSync(join(cwd, '.claude/skills/go/SKILL.md')));
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
