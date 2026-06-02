# Interactive rebase — cleaning history before review

The everyday path is one clean conventional commit per change. Reach for this only when a branch has
accumulated scratch commits you need to collapse, reorder, reword, or drop before a PR. This is a
private-branch operation: only rewrite history nobody else has built on.

## Start the rebase

```bash
git rebase -i HEAD~4        # edit the last 4 commits
git rebase -i main          # replay everything since main; clean the whole branch narrative
```

Git opens a todo list, oldest commit first. Each line starts with a verb you can change:

| Verb         | Effect                                                            |
|--------------|-------------------------------------------------------------------|
| `pick`       | keep the commit as-is                                             |
| `reword` (r) | keep the changes, edit the message (fix a non-conventional subject) |
| `edit` (e)   | pause at this commit to amend its content                        |
| `squash` (s) | fold into the previous commit, **combine** both messages         |
| `fixup` (f)  | fold into the previous commit, **discard** this message          |
| `drop` (d)   | delete the commit entirely (its changes are removed)             |
| reorder      | move a line up/down to reorder commits                           |

Typical cleanup: turn two `wip` commits into `fixup` lines under the real commit they belong to, and
`reword` the survivor into a proper `type(scope): subject`.

```text
pick   a1b2c3d feat(auth): add PKCE flow
fixup  d4e5f6a wip
fixup  7g8h9i0 wip more
```

## Autosquash — the disciplined way

If you mark fixups *as you go*, the rebase organizes itself:

```bash
git commit --fixup a1b2c3d          # creates "fixup! feat(auth): add PKCE flow"
git commit --squash a1b2c3d         # same, but keeps the message for editing
git rebase -i --autosquash main     # auto-orders the fixup!/squash! lines under their targets
```

Set `git config --global rebase.autosquash true` to make `--autosquash` the default.

## The conflict loop

A rebase replays commits one at a time, so a conflict can surface on any of them:

```bash
# rebase stops, reports a conflict
git status                  # see which files conflict
# edit the files, resolve the <<<<<<< markers
git add <resolved-files>
git rebase --continue       # advance to the next commit
# repeat until the rebase finishes
```

Escape hatches:

```bash
git rebase --skip           # drop the current commit and continue (rare; you lose its changes)
git rebase --abort          # bail out entirely — branch returns to its pre-rebase state
```

## Push the rewritten branch

A rebase rewrites hashes, so the remote branch diverges. Push with the lease, never bare force:

```bash
git push --force-with-lease     # refuses if the remote moved since your last fetch
```

If `--force-with-lease` is rejected, someone pushed to your branch — fetch and reconcile before you
overwrite anything. Do not escalate to `--force`.

## Recovery — you have a net

Every commit you "lost" to a rebase is still reachable until git garbage-collects it. `reflog` records
where `HEAD` has been:

```bash
git reflog                          # find the SHA from before the rebase, e.g. HEAD@{5}
git reset --hard a1b2c3d            # restore the branch to that exact state
```

This recovers a botched rebase, a wrong `drop`, or a reset you regret. The reflog makes interactive
rebase safe to experiment with on a *private* branch — never on shared history.
