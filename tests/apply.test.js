import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, existsSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { applyInstall, listInstalled, uninstall } from '../scripts/install-apply.js';
import { doctor } from '../scripts/doctor.js';

test('claude: apply installs suggest+fastapi, wires hook, list shows, uninstall removes', async () => {
  const home = mkdtempSync(join(tmpdir(), 'rsc-home-'));
  await applyInstall({ skillIds: ['suggest', 'fastapi'], target: 'claude', home });

  assert.ok(existsSync(join(home, '.claude/skills/rsc/fastapi/SKILL.md')));
  assert.ok(existsSync(join(home, '.claude/skills/rsc/suggest/SKILL.md')));

  const settings = JSON.parse(readFileSync(join(home, '.claude/settings.json'), 'utf8'));
  assert.ok(JSON.stringify(settings.hooks.SessionStart).includes('skills/rsc/suggest'));

  assert.ok(listInstalled({ target: 'claude', home }).includes('fastapi'));

  const health = doctor({ target: 'claude', home });
  assert.equal(health.missing.length, 0);
  assert.ok(health.hookWired);

  const preview = await uninstall({ skillIds: ['fastapi'], target: 'claude', home, dryRun: true });
  assert.ok(preview.length > 0);
  assert.ok(existsSync(join(home, '.claude/skills/rsc/fastapi/SKILL.md')), 'dry-run keeps files');

  await uninstall({ skillIds: ['fastapi'], target: 'claude', home });
  assert.ok(!existsSync(join(home, '.claude/skills/rsc/fastapi/SKILL.md')));
  assert.ok(!listInstalled({ target: 'claude', home }).includes('fastapi'));
});

test('codex: apply appends always-on block to AGENTS.md', async () => {
  const home = mkdtempSync(join(tmpdir(), 'rsc-cwd-'));
  // codex writes relative to cwd; run from the temp dir
  const prev = process.cwd();
  process.chdir(home);
  try {
    await applyInstall({ skillIds: ['suggest', 'go'], target: 'codex' });
    const agents = readFileSync(join(home, 'AGENTS.md'), 'utf8');
    assert.ok(agents.includes('rsc-suggest:start'));
    assert.ok(existsSync(join(home, '.codex/rsc/go/SKILL.md')));
  } finally {
    process.chdir(prev);
  }
});
