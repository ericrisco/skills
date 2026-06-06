# RSC Transactional Installer Design

## Goal

Make `rsc` feel like a mature installer without changing its core product shape: a project-local, granular skill catalog. The V1 adds project-local backups, restore, sync, safer uninstall, and an upgrade command surface.

## Chosen Approach

Use a project-local transactional layer under `.rsc/`:

- `.rsc/backups/<snapshot-id>/manifest.json`
- `.rsc/backups/<snapshot-id>/files/...`
- existing per-target `.rsc-state.json` files stay the source of truth for installed skills
- `.rsc/.version` remains the materialized catalog version marker

This keeps the product aligned with the current README promise that everything stays in the project. A global `~/.rsc` state is explicitly out of scope for this V1 because it would change the product from project manager to machine manager.

## Alternatives Considered

1. Project-local V1.
   Best fit for current architecture. Easy to test with temporary directories, minimal blast radius, and works for all current targets.

2. Global state V1.
   Closer to `gentle-ai`, but it would require redefining ownership across projects, global target roots, and machine-level sync. Too large for this step.

3. Full pipeline/rollback engine.
   Strongest long-term model, but premature. V1 can expose the right user behavior with smaller primitives: snapshot, apply, restore.

## Commands

### `rsc sync`

Refresh managed skills for one or more targets using the current installed state.

Behavior:

- Reads the target state file.
- Reinstalls every skill recorded in that state.
- Includes `suggest` if installed, so hooks are refreshed.
- Creates a backup before modifying managed files.
- Updates `.rsc/.version`.
- Supports `--target a,b`.
- Supports `--dry-run`, printing the files that would be refreshed.

If no installed skills exist for the selected target, it prints `(nothing to sync)`.

### `rsc backups`

List project-local backup snapshots newest first.

Output includes:

- snapshot id
- operation
- target
- number of files captured
- timestamp

### `rsc restore <snapshot-id|latest>`

Restore files captured in a project-local snapshot.

Behavior:

- Restores regular files from the snapshot.
- Restores missing files that existed at snapshot time.
- Removes files that were created by the operation after the snapshot, when they are tracked in the snapshot manifest as managed files that did not exist before.
- Does not touch anything outside the current project root.
- Requires an argument. `latest` resolves to the newest snapshot.
- Supports `--dry-run`.

### `rsc uninstall`

Keep current skill-level uninstall behavior but make it safer.

Behavior:

- Creates a backup before removing managed files.
- Supports existing `--dry-run`.
- Removes only files recorded in the target state.
- Leaves shared `.rsc/skills/<id>` bases intact in V1, preserving the existing expectation that uninstall removes target wiring, not the catalog cache.

### `rsc upgrade`

Provide an npm-native upgrade surface.

Behavior:

- Default mode is guided: print exact commands to upgrade and sync:
  - `npm install -g @ericrisco/rsc@latest`
  - `npx @ericrisco/rsc sync --target <targets>`
- `--global` executes `npm install -g @ericrisco/rsc@latest`.
- `--dry-run` prints the planned command.
- Never runs `sync` automatically after upgrading, because the current process is still the old binary. It tells the user to run `rsc sync` after the new version is installed.

## Backup Model

Every mutating operation creates a snapshot before it writes or removes files:

- `install`
- `sync`
- `uninstall`

Snapshot ids use UTC-ish sortable timestamps plus operation, for example:

`20260606-143012-install-claude`

Each snapshot manifest records:

- schema version
- id
- createdAt ISO timestamp
- operation
- target
- cwd
- CLI version
- entries

Each entry records:

- relative path from project root
- existed before the operation
- kind: `file`, `dir`, `symlink`, or `missing`
- content path in the snapshot for files and symlinks

For V1, directories are recorded so restore can remove newly-created managed directories when they were absent before, but directory permissions are not preserved.

## Managed Path Collection

Before a mutation, `rsc` computes the paths it may touch:

- paths from the install plan
- existing tracked files for skills being uninstalled
- target state file
- `.rsc/.version`
- generated hook scripts returned by target adapters when known

For install and sync, the install plan already knows the target skill paths and hook target. For Claude, hook materialization writes `.rsc/session-start.mjs`, `.rsc/worklog-checkpoint.mjs`, `.rsc/ship-guard.mjs`, and `.rsc/danger-guard.mjs`; these are included in the backup path set.

## Restore Semantics

Restore is conservative:

- If an entry existed and was a file, restore the exact file content.
- If an entry existed and was a symlink, restore the symlink target when the platform supports symlinks; otherwise restore as a copied directory only when the snapshot contains the copied files.
- If an entry was missing before the operation and exists now, remove it.
- If a path is outside the current project root, restore refuses to act.

The restore command reports every path it would change in dry-run mode.

## Doctor Improvements

`rsc doctor` should include backup readiness:

- whether `.rsc/backups` exists
- snapshot count
- latest snapshot id
- installed skill count
- missing managed files
- hook presence

No network checks in V1.

## Testing Strategy

Use Node's built-in test runner with temporary project directories.

Required tests:

- backup snapshots capture existing hook files before install overwrites them
- uninstall creates a snapshot and can be restored
- restore `latest` restores modified files and removes newly-created managed files
- sync dry-run reports installed skills without mutating files
- sync refreshes stale `.rsc/skills/<id>` content when `.rsc/.version` is old
- `rsc backups` lists snapshots
- `rsc restore latest --dry-run` prints planned paths and does not mutate
- `rsc upgrade --dry-run` prints the npm command
- doctor reports snapshot count and latest snapshot

## Non-Goals

- No global `~/.rsc` ownership layer.
- No automatic post-upgrade sync from the old process.
- No compressed archives in V1.
- No pruning policy in V1.
- No cross-project restore.
- No attempt to restore arbitrary user files not in the managed path set.

## Success Criteria

- Existing tests still pass.
- New backup/restore/sync/upgrade tests pass.
- Mutating commands create a recoverable project-local snapshot.
- `restore latest` can undo a simple install or uninstall in tests.
- The CLI help/error text clearly names the new commands.
