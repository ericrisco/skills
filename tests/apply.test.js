import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, existsSync, readFileSync, lstatSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { applyInstall, listInstalled, uninstall } from '../scripts/install-apply.js';
import { doctor } from '../scripts/doctor.js';
import { targetPaths } from '../targets/index.js';

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

test('unknown target throws', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  await assert.rejects(() => applyInstall({ skillIds: ['suggest'], target: 'nope', cwd }), /unknown target/);
});
