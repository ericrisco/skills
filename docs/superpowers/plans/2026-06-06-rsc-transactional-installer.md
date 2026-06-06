# RSC Transactional Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add project-local backup, restore, sync, safer uninstall, and upgrade command support to `rsc`.

**Architecture:** Add a focused backup/restore module under `scripts/lib/backups.js`, keep install state in the existing per-target `.rsc-state.json`, and extend `install-apply.js` as the operation coordinator. CLI commands in `scripts/rsc.js` call those units; `doctor` reports backup readiness.

**Tech Stack:** Node ESM, built-in `node:test`, filesystem APIs, existing `targets/*` adapters, existing `rsc` CLI.

---

### Task 1: Project-Local Backup And Restore Primitives

**Files:**
- Create: `scripts/lib/backups.js`
- Create: `tests/backups.test.js`

- [ ] **Step 1: Write failing backup/restore tests**

Add `tests/backups.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, writeFileSync, mkdirSync, lstatSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createBackup, listBackups, restoreBackup } from '../scripts/lib/backups.js';

function tmp() {
  return mkdtempSync(join(tmpdir(), 'rsc-backup-'));
}

test('createBackup snapshots existing files and restoreBackup restores them', () => {
  const cwd = tmp();
  const file = join(cwd, 'AGENTS.md');
  writeFileSync(file, 'before\n');

  const snap = createBackup({ cwd, operation: 'install', target: 'codex', paths: [file], cliVersion: '0.0.0-test' });
  writeFileSync(file, 'after\n');

  const restored = restoreBackup({ cwd, id: snap.id });

  assert.equal(readFileSync(file, 'utf8'), 'before\n');
  assert.ok(restored.changed.some((p) => p.endsWith('AGENTS.md')));
});

test('restoreBackup removes managed files that were missing before the snapshot', () => {
  const cwd = tmp();
  const file = join(cwd, '.codex', 'rsc', 'fastapi');

  const snap = createBackup({ cwd, operation: 'install', target: 'codex', paths: [file], cliVersion: '0.0.0-test' });
  mkdirSync(file, { recursive: true });
  writeFileSync(join(file, 'SKILL.md'), 'created\n');

  restoreBackup({ cwd, id: snap.id });

  assert.equal(existsSync(file), false);
});

test('restoreBackup supports dry-run without mutating files', () => {
  const cwd = tmp();
  const file = join(cwd, 'AGENTS.md');
  writeFileSync(file, 'before\n');
  const snap = createBackup({ cwd, operation: 'install', target: 'codex', paths: [file], cliVersion: '0.0.0-test' });
  writeFileSync(file, 'after\n');

  const preview = restoreBackup({ cwd, id: snap.id, dryRun: true });

  assert.equal(readFileSync(file, 'utf8'), 'after\n');
  assert.ok(preview.changed.some((p) => p.endsWith('AGENTS.md')));
});

test('listBackups returns newest snapshots first and latest restores newest', () => {
  const cwd = tmp();
  const first = createBackup({ cwd, operation: 'install', target: 'codex', paths: [], cliVersion: '0.0.0-test', now: new Date('2026-06-06T10:00:00Z') });
  const second = createBackup({ cwd, operation: 'sync', target: 'codex', paths: [], cliVersion: '0.0.0-test', now: new Date('2026-06-06T11:00:00Z') });

  const listed = listBackups({ cwd });
  const latest = restoreBackup({ cwd, id: 'latest', dryRun: true });

  assert.equal(listed[0].id, second.id);
  assert.equal(listed[1].id, first.id);
  assert.equal(latest.snapshot.id, second.id);
});

test('createBackup records symlinks as symlinks', () => {
  const cwd = tmp();
  const real = join(cwd, '.rsc', 'skills', 'fastapi');
  const link = join(cwd, '.claude', 'skills', 'fastapi');
  mkdirSync(real, { recursive: true });
  writeFileSync(join(real, 'SKILL.md'), 'skill\n');
  mkdirSync(join(cwd, '.claude', 'skills'), { recursive: true });
  try {
    symlinkSync('../../.rsc/skills/fastapi', link, 'dir');
  } catch {
    return;
  }

  const snap = createBackup({ cwd, operation: 'install', target: 'claude', paths: [link], cliVersion: '0.0.0-test' });

  assert.equal(snap.entries[0].kind, 'symlink');
  assert.equal(lstatSync(link).isSymbolicLink(), true);
});
```

- [ ] **Step 2: Run tests to verify RED**

Run: `node --test tests/backups.test.js`

Expected: fail because `scripts/lib/backups.js` does not exist.

- [ ] **Step 3: Implement backup/restore primitives**

Create `scripts/lib/backups.js` with:

```js
import {
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  readlinkSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, sep } from 'node:path';

const SCHEMA_VERSION = 1;

export function backupsDir(cwd = process.cwd()) {
  return join(cwd, '.rsc', 'backups');
}

export function createBackup({ cwd = process.cwd(), operation, target, paths, cliVersion, now = new Date() }) {
  const uniquePaths = [...new Set((paths || []).filter(Boolean))];
  const id = snapshotId({ now, operation, target });
  const root = join(backupsDir(cwd), id);
  const filesRoot = join(root, 'files');
  mkdirSync(filesRoot, { recursive: true });

  const entries = uniquePaths.map((absPath) => snapshotEntry({ cwd, root, absPath }));
  const manifest = {
    schemaVersion: SCHEMA_VERSION,
    id,
    createdAt: now.toISOString(),
    operation,
    target,
    cwd,
    cliVersion,
    entries,
  };
  writeFileSync(join(root, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  return manifest;
}

export function listBackups({ cwd = process.cwd() } = {}) {
  const dir = backupsDir(cwd);
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .map((id) => readManifest({ cwd, id }))
    .filter(Boolean)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

export function restoreBackup({ cwd = process.cwd(), id, dryRun = false }) {
  const snapshot = resolveSnapshot({ cwd, id });
  const changed = [];
  for (const entry of snapshot.entries) {
    const absPath = safeJoin(cwd, entry.path);
    changed.push(absPath);
    if (dryRun) continue;
    restoreEntry({ cwd, snapshot, entry, absPath });
  }
  return { snapshot, changed };
}

function snapshotEntry({ cwd, root, absPath }) {
  const rel = safeRelative(cwd, absPath);
  if (!existsSync(absPath)) return { path: rel, existed: false, kind: 'missing' };

  const stat = lstatSync(absPath);
  if (stat.isSymbolicLink()) {
    return { path: rel, existed: true, kind: 'symlink', linkTarget: readlinkSync(absPath) };
  }

  const contentPath = join('files', rel);
  const contentAbs = join(root, contentPath);
  mkdirSync(dirname(contentAbs), { recursive: true });
  if (stat.isDirectory()) {
    cpSync(absPath, contentAbs, { recursive: true });
    return { path: rel, existed: true, kind: 'dir', contentPath };
  }
  cpSync(absPath, contentAbs);
  return { path: rel, existed: true, kind: 'file', contentPath };
}

function restoreEntry({ cwd, snapshot, entry, absPath }) {
  if (!entry.existed) {
    rmSync(absPath, { recursive: true, force: true });
    return;
  }

  rmSync(absPath, { recursive: true, force: true });
  mkdirSync(dirname(absPath), { recursive: true });
  if (entry.kind === 'symlink') {
    symlinkSync(entry.linkTarget, absPath, process.platform === 'win32' ? 'junction' : undefined);
    return;
  }
  const contentAbs = join(backupsDir(cwd), snapshot.id, entry.contentPath);
  cpSync(contentAbs, absPath, { recursive: entry.kind === 'dir' });
}

function resolveSnapshot({ cwd, id }) {
  if (!id) throw new Error('restore requires a snapshot id or latest');
  if (id === 'latest') {
    const latest = listBackups({ cwd })[0];
    if (!latest) throw new Error('no backups found');
    return latest;
  }
  const manifest = readManifest({ cwd, id });
  if (!manifest) throw new Error(`backup not found: ${id}`);
  return manifest;
}

function readManifest({ cwd, id }) {
  const path = join(backupsDir(cwd), id, 'manifest.json');
  if (!existsSync(path)) return undefined;
  return JSON.parse(readFileSync(path, 'utf8'));
}

function snapshotId({ now, operation, target }) {
  const stamp = now.toISOString().replace(/[-:]/g, '').replace(/\..*/, '').replace('T', '-');
  return `${stamp}-${safeId(operation)}-${safeId(target || 'all')}`;
}

function safeId(value) {
  return String(value).replace(/[^a-z0-9._-]+/gi, '-').replace(/^-+|-+$/g, '').toLowerCase();
}

function safeRelative(cwd, absPath) {
  const rel = relative(cwd, absPath);
  if (!rel || rel.startsWith('..') || rel.split(sep).includes('..')) {
    throw new Error(`path is outside project root: ${absPath}`);
  }
  return rel.split(sep).join('/');
}

function safeJoin(cwd, relPath) {
  return join(cwd, ...relPath.split('/'));
}
```

- [ ] **Step 4: Run backup tests to verify GREEN**

Run: `node --test tests/backups.test.js`

Expected: pass.

- [ ] **Step 5: Commit Task 1**

Run:

```bash
git add scripts/lib/backups.js tests/backups.test.js
git commit -m "feat: add rsc backup restore primitives"
```

### Task 2: Wire Backups Into Install, Uninstall, And Sync

**Files:**
- Modify: `scripts/install-apply.js`
- Modify: `tests/apply.test.js`

- [ ] **Step 1: Write failing install/uninstall/sync tests**

Append tests to `tests/apply.test.js`:

```js
test('install creates a backup before overwriting managed hook files', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-install-backup-'));
  mkdirSync(join(cwd, '.claude'), { recursive: true });
  writeFileSync(join(cwd, '.claude/settings.json'), JSON.stringify({ hooks: { SessionStart: [{ hooks: [{ type: 'command', command: 'echo mine' }] }] } }, null, 2));

  await applyInstall({ skillIds: ['suggest'], target: 'claude', cwd });

  const backups = listBackups({ cwd });
  assert.equal(backups[0].operation, 'install');
  assert.equal(backups[0].target, 'claude');
  assert.ok(backups[0].entries.some((e) => e.path === '.claude/settings.json' && e.existed));
});

test('uninstall creates a backup that restoreBackup can use to recover target wiring', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-uninstall-backup-'));
  await applyInstall({ skillIds: ['fastapi'], target: 'claude', cwd });

  await uninstall({ skillIds: ['fastapi'], target: 'claude', cwd });
  assert.equal(existsSync(join(cwd, '.claude/skills/fastapi')), false);

  restoreBackup({ cwd, id: 'latest' });

  assert.ok(existsSync(join(cwd, '.claude/skills/fastapi/SKILL.md')));
});

test('syncInstalled dry-run reports managed paths without mutating stale base files', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-sync-dry-'));
  await applyInstall({ skillIds: ['fastapi'], target: 'claude', cwd });
  writeFileSync(join(cwd, '.rsc/.version'), '0.0.1\n');
  writeFileSync(join(cwd, '.rsc/skills/fastapi/STALE.txt'), 'old');

  const preview = await syncInstalled({ target: 'claude', cwd, dryRun: true });

  assert.ok(preview.paths.some((p) => p.includes('.claude/skills/fastapi')));
  assert.ok(existsSync(join(cwd, '.rsc/skills/fastapi/STALE.txt')));
});

test('syncInstalled refreshes installed skills and creates a sync backup', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-sync-'));
  await applyInstall({ skillIds: ['fastapi'], target: 'claude', cwd });
  writeFileSync(join(cwd, '.rsc/.version'), '0.0.1\n');
  writeFileSync(join(cwd, '.rsc/skills/fastapi/STALE.txt'), 'old');

  const result = await syncInstalled({ target: 'claude', cwd });

  assert.deepEqual(result.synced, ['fastapi']);
  assert.ok(!existsSync(join(cwd, '.rsc/skills/fastapi/STALE.txt')));
  assert.equal(listBackups({ cwd })[0].operation, 'sync');
});
```

Also update the import line:

```js
import { applyInstall, listInstalled, uninstall, syncInstalled } from '../scripts/install-apply.js';
import { listBackups, restoreBackup } from '../scripts/lib/backups.js';
```

- [ ] **Step 2: Run targeted tests to verify RED**

Run: `node --test tests/apply.test.js`

Expected: fail because `syncInstalled` and backup wiring do not exist.

- [ ] **Step 3: Implement managed path collection and sync**

Update `scripts/install-apply.js`:

```js
import { createBackup } from './lib/backups.js';
```

Add:

```js
function managedPathsForInstall({ skillIds, target, home, cwd }) {
  const paths = targetPaths(target, home, cwd);
  const plan = planInstall({ skillIds, target, home, cwd });
  const out = [paths.stateFile, versionFile(cwd)];
  for (const step of plan) {
    if (step.kind === 'skill') {
      out.push(step.to, baseDir(step.id, cwd));
    } else if (step.kind === 'hook') {
      out.push(step.to, ...generatedHookFiles({ target, cwd }));
    }
  }
  return [...new Set(out)];
}

function generatedHookFiles({ target, cwd }) {
  if (target !== 'claude') return [];
  return [
    join(cwd, '.rsc', 'session-start.mjs'),
    join(cwd, '.rsc', 'worklog-checkpoint.mjs'),
    join(cwd, '.rsc', 'ship-guard.mjs'),
    join(cwd, '.rsc', 'danger-guard.mjs'),
  ];
}
```

Change `applyInstall` signature:

```js
export async function applyInstall({ skillIds, target, home, cwd = process.cwd(), operation = 'install', dryRun = false }) {
  const managedPaths = managedPathsForInstall({ skillIds, target, home, cwd });
  if (dryRun) return { dryRun: true, paths: managedPaths, skills: skillIds };
  const backup = createBackup({ cwd, operation, target, paths: managedPaths, cliVersion: CLI_VERSION });
  ...
  return { ...state, backup };
}
```

Change `uninstall` so it creates a backup before removals:

```js
const managedPaths = [];
for (const id of skillIds) {
  const entry = state.skills[id];
  if (!entry) continue;
  managedPaths.push(...entry.files);
}
managedPaths.push(paths.stateFile);
if (dryRun) return managedPaths;
const backup = createBackup({ cwd, operation: 'uninstall', target, paths: managedPaths, cliVersion: CLI_VERSION });
...
return removed;
```

Add:

```js
export async function syncInstalled({ target, home, cwd = process.cwd(), dryRun = false }) {
  const paths = targetPaths(target, home, cwd);
  const state = readState(paths.stateFile);
  const ids = Object.keys(state.skills || {});
  if (!ids.length) return dryRun ? { dryRun: true, synced: [], paths: [] } : { synced: [], backup: null };
  if (dryRun) {
    return {
      dryRun: true,
      synced: ids,
      paths: managedPathsForInstall({ skillIds: ids, target, home, cwd }),
    };
  }
  const nextState = await applyInstall({ skillIds: ids, target, home, cwd, operation: 'sync' });
  return { synced: ids, backup: nextState.backup };
}
```

- [ ] **Step 4: Run targeted tests to verify GREEN**

Run: `node --test tests/backups.test.js tests/apply.test.js`

Expected: pass.

- [ ] **Step 5: Commit Task 2**

Run:

```bash
git add scripts/install-apply.js tests/apply.test.js
git commit -m "feat: make rsc install operations recoverable"
```

### Task 3: Add CLI Commands For Backups, Restore, Sync, And Upgrade

**Files:**
- Create: `scripts/lib/upgrade.js`
- Modify: `scripts/rsc.js`
- Modify: `tests/rsc-cli.test.js`

- [ ] **Step 1: Write failing CLI tests**

Append to `tests/rsc-cli.test.js`:

```js
test('rsc backups lists project-local snapshots', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cli-backups-'));
  const install = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'add', 'fastapi', '--target', 'claude'], { cwd, encoding: 'utf8' });
  assert.equal(install.status, 0, install.stderr);

  const listed = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'backups'], { cwd, encoding: 'utf8' });

  assert.equal(listed.status, 0, listed.stderr);
  assert.ok(listed.stdout.includes('install'));
  assert.ok(listed.stdout.includes('claude'));
});

test('rsc restore latest --dry-run reports planned restore paths without mutating', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cli-restore-'));
  const install = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'add', 'fastapi', '--target', 'claude'], { cwd, encoding: 'utf8' });
  assert.equal(install.status, 0, install.stderr);

  const preview = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'restore', 'latest', '--dry-run'], { cwd, encoding: 'utf8' });

  assert.equal(preview.status, 0, preview.stderr);
  assert.ok(preview.stdout.includes('Would restore'));
  assert.ok(existsSync(join(cwd, '.claude/skills/fastapi/SKILL.md')));
});

test('rsc sync --dry-run reports installed skills', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cli-sync-'));
  const install = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'add', 'fastapi', '--target', 'claude'], { cwd, encoding: 'utf8' });
  assert.equal(install.status, 0, install.stderr);

  const sync = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'sync', '--target', 'claude', '--dry-run'], { cwd, encoding: 'utf8' });

  assert.equal(sync.status, 0, sync.stderr);
  assert.ok(sync.stdout.includes('Would sync claude'));
  assert.ok(sync.stdout.includes('fastapi'));
});

test('rsc upgrade --dry-run prints npm upgrade command', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-cli-upgrade-'));
  const result = spawnSync(process.execPath, [join(ROOT, 'scripts/rsc.js'), 'upgrade', '--target', 'claude', '--dry-run'], { cwd, encoding: 'utf8' });

  assert.equal(result.status, 0, result.stderr);
  assert.ok(result.stdout.includes('npm install -g @ericrisco/rsc@latest'));
  assert.ok(result.stdout.includes('rsc sync --target claude'));
});
```

- [ ] **Step 2: Run CLI tests to verify RED**

Run: `node --test tests/rsc-cli.test.js`

Expected: fail on unknown commands.

- [ ] **Step 3: Implement upgrade planning**

Create `scripts/lib/upgrade.js`:

```js
import { spawnSync } from 'node:child_process';

export function upgradePlan({ targets = [] } = {}) {
  const targetArg = targets.length ? targets.join(',') : '<target>';
  return {
    installCommand: 'npm install -g @ericrisco/rsc@latest',
    syncCommand: `rsc sync --target ${targetArg}`,
  };
}

export function runUpgrade({ targets = [], dryRun = false, global = false } = {}) {
  const plan = upgradePlan({ targets });
  if (dryRun || !global) {
    return { ran: false, plan };
  }
  const result = spawnSync('npm', ['install', '-g', '@ericrisco/rsc@latest'], { stdio: 'inherit' });
  if (result.status !== 0) throw new Error('npm global upgrade failed');
  return { ran: true, plan };
}
```

- [ ] **Step 4: Wire CLI commands**

Update `scripts/rsc.js` imports:

```js
import { applyInstall, listInstalled, uninstall, syncInstalled } from './install-apply.js';
import { listBackups, restoreBackup } from './lib/backups.js';
import { runUpgrade } from './lib/upgrade.js';
```

Add switch cases before `uninstall`:

```js
case 'sync': {
  const dry = argv.includes('--dry-run');
  for (const t of targets) {
    const result = await syncInstalled({ target: t, dryRun: dry });
    if (!result.synced.length) say(`${dry ? 'Would sync' : 'Synced'} ${t}: (nothing to sync)`);
    else say(`${dry ? 'Would sync' : 'Synced'} ${t}: ${result.synced.join(', ')}`);
    if (dry && result.paths?.length) for (const p of result.paths) say(`  ${p}`);
  }
  return;
}
case 'backups': {
  const backups = listBackups();
  if (!backups.length) return void say('(no backups)');
  for (const b of backups) say(`${b.id}\t${b.operation}\t${b.target}\t${b.entries.length} files\t${b.createdAt}`);
  return;
}
case 'restore': {
  const dry = argv.includes('--dry-run');
  const id = argv.slice(1).find((a) => !a.startsWith('--'));
  const result = restoreBackup({ id, dryRun: dry });
  say(`${dry ? 'Would restore' : 'Restored'} ${result.snapshot.id}`);
  for (const p of result.changed) say(`  ${p}`);
  return;
}
case 'upgrade': {
  const dry = argv.includes('--dry-run');
  const global = argv.includes('--global');
  const result = runUpgrade({ targets, dryRun: dry, global });
  if (result.ran) say('Upgraded global @ericrisco/rsc. Restart your shell if needed.');
  else say(`${dry ? 'Would run' : 'Upgrade guide'}: ${result.plan.installCommand}`);
  say(`After upgrade: ${result.plan.syncCommand}`);
  return;
}
```

Update default help to mention `sync | backups | restore <id|latest> | upgrade`.

- [ ] **Step 5: Run CLI tests to verify GREEN**

Run: `node --test tests/rsc-cli.test.js`

Expected: pass.

- [ ] **Step 6: Commit Task 3**

Run:

```bash
git add scripts/lib/upgrade.js scripts/rsc.js tests/rsc-cli.test.js
git commit -m "feat: add rsc lifecycle cli commands"
```

### Task 4: Improve Doctor Backup Readiness

**Files:**
- Modify: `scripts/doctor.js`
- Modify: `tests/apply.test.js`

- [ ] **Step 1: Write failing doctor test**

Append to `tests/apply.test.js`:

```js
test('doctor reports backup readiness and latest snapshot', async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'rsc-doctor-backups-'));
  await applyInstall({ skillIds: ['fastapi'], target: 'claude', cwd });

  const health = doctor({ target: 'claude', cwd });

  assert.equal(health.backups.exists, true);
  assert.equal(health.backups.count, 1);
  assert.ok(health.backups.latest.includes('install-claude'));
});
```

- [ ] **Step 2: Run targeted tests to verify RED**

Run: `node --test tests/apply.test.js`

Expected: fail because `health.backups` is missing.

- [ ] **Step 3: Add backup readiness to doctor**

Update `scripts/doctor.js`:

```js
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { listBackups } from './lib/backups.js';
```

Inside `doctor`:

```js
const backups = listBackups({ cwd });
...
backups: {
  exists: existsSync(join(cwd || process.cwd(), '.rsc', 'backups')),
  count: backups.length,
  latest: backups[0]?.id || null,
},
```

- [ ] **Step 4: Run targeted tests to verify GREEN**

Run: `node --test tests/apply.test.js`

Expected: pass.

- [ ] **Step 5: Commit Task 4**

Run:

```bash
git add scripts/doctor.js tests/apply.test.js
git commit -m "feat: report rsc backup readiness"
```

### Task 5: Documentation And Full Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README command list**

Edit `README.md` CLI section to include:

```md
rsc sync --target claude,codex        # refresh managed skills/hooks from current package version
rsc backups                           # list project-local snapshots
rsc restore latest --dry-run          # preview restoring the newest snapshot
rsc restore <snapshot-id>             # restore a project-local snapshot
rsc upgrade --dry-run                 # show npm upgrade + sync commands
```

- [ ] **Step 2: Run manifest and tests**

Run:

```bash
npm run manifest:check
npm test
```

Expected: both pass.

- [ ] **Step 3: Commit Task 5**

Run:

```bash
git add README.md
git commit -m "docs: document rsc lifecycle commands"
```
