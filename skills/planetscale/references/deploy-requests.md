# Deploy requests — lifecycle, gating, lint, reverts

Offloaded depth from SKILL.md §"The deploy-request workflow". The body has the happy path; this file
covers the states a deploy request moves through, why it stalls, and the revert carve-outs.

## Lifecycle states

A deploy request moves through roughly:

1. **Open** — created from a dev branch against production; PlanetScale has computed a schema diff.
2. **Approved** — a reviewer ran `pscale deploy-request review … --approve` (or approved in the UI).
3. **Queued / deploying** — the deploy is submitted; Vitess starts Online DDL (shadow table build +
   VReplication copy). Large tables spend most of their time here.
4. **Pending cutover / gated** — if auto-apply was disabled (`--disable-auto-apply`), the copy is done
   and the change waits for a manual `pscale deploy-request apply` before cutting over.
5. **Deployed** — cutover complete. The **~30-minute revert window** opens here.
6. **Reverted** or **permanent** — either reverted within the window, or finalized after it closes.

## Online DDL mechanics

A deploy does not run a blocking `ALTER`. Vitess:

- builds a **shadow table** with the target schema,
- uses **VReplication** to copy existing rows and continuously apply in-flight writes from old→new,
- waits for the shadow to catch up (lag → ~0),
- performs an atomic **cutover**, swapping the shadow in as the live table.

That is why a deploy against a big table can sit in "deploying" for a long time: it is copying rows,
not stuck. Watch the deploy's progress before assuming it hung.

## Why a deploy is queued / won't cut over

| Symptom | Likely cause | Action |
| --- | --- | --- |
| "Queued" for a long time on a large table | VReplication is still copying rows | Wait; check copy progress. It is working, not stuck. |
| Deployed-but-not-cut-over | Auto-apply disabled; it is gated | Run `pscale deploy-request apply <db> <number>`. |
| Another deploy already in flight | Deploys serialize per branch | Let the in-flight one finish or revert it first. |
| Blocked at open with lint errors | The diff violates a schema lint rule | Fix the DDL on the branch, re-diff, re-open. |

## Lint errors

PlanetScale lints the schema diff before it will deploy. Common blockers: a table without a primary
key (Vitess wants one for VReplication), or unsupported/foot-gun DDL. Resolve by editing the DDL on the
**branch** (open a `pscale shell`, fix the schema), regenerate the diff, and re-open the deploy request.
Never try to force a lint failure through.

## Revert carve-outs

The ~30-minute window lets you undo a deploy **while preserving writes that happened after the deploy**
— for most additive changes. It does **not** cleanly cover:

- **Dropped tables or columns** — the data is gone; a revert cannot resurrect it.
- **Foreign-key constraint changes** — excluded from clean revert.

After the window closes the deploy is permanent. Treat the window as a safety net for *additive*
changes, and plan destructive rollbacks (re-adding a dropped column, restoring data) as **new forward
deploys**, not as reverts.

## Declarative vs imperative schema

Two ways to express the change on a branch:

- **Imperative** — you run the `ALTER`/`CREATE` statements yourself in `pscale shell`; the deploy
  request diffs branch-vs-production and deploys that diff.
- **Declarative** — you keep the desired schema in version control and let PlanetScale compute the DDL
  needed to converge the branch to that target.

Either way the deploy request is the gate and the diff is the contract. Read the diff before deploying.

## Branch protection / safe migrations

Production branches are protected by default. **Safe migrations** on a branch is the setting that
*requires* the deploy-request flow — it stops raw schema edits from landing directly on the protected
branch. Keep it on for any branch that fronts production. Dev branches are disposable; protect the one
that matters.
