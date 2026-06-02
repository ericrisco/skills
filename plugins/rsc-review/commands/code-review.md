---
description: Adversarial multi-stack code review — route the diff to per-language reviewer agents in parallel, then one consolidated, severity-ranked verdict.
argument-hint: "[pr-number | pr-url | blank for local]"
---

# /rsc-review:code-review

You orchestrate a code review. You do **not** review the code yourself — you select the mode, gather the changed files, dispatch the right reviewer agents in parallel, and aggregate their findings into a single verdict. Every finding still obeys the one rule from the `rsc-sdd:review` discipline: **evidence, not opinion.** This command is the fan-out engine; that skill is the doctrine it runs on.

`$ARGUMENTS` = `{{args}}`

## 1. SELECT MODE

Look at `$ARGUMENTS`:

- **Contains a PR number (`123`, `#123`) or a PR URL** → **PR mode**.
  - `gh pr view <pr> --json title,headRefName,baseRefName,url` to anchor what you're reviewing.
  - `gh pr diff <pr>` for the diff, and `gh pr diff <pr> --name-only` for the changed-file list.
  - Prefer reading the diff over checking out. Only `gh pr checkout <pr>` if a reviewer agent needs surrounding files that the diff alone doesn't show.
- **Blank / no PR reference** → **LOCAL mode**.
  - `git diff --name-only HEAD` for the changed-file list, `git diff HEAD` for the content.
  - If that list is **empty**, STOP and say plainly: `Nothing to review — working tree matches HEAD.` Do not invent a diff, do not review the whole repo.

State which mode you're in and what you're reviewing (PR title + branch, or local HEAD diff) before going further.

## 2. GATHER & GROUP

Take the changed-file list and bucket each path by extension into a **stack group**. One file can only land in one group; route by the table top-to-bottom, first match wins:

| Files | Group → reviewer agent |
| --- | --- |
| `*.py` | `python-reviewer` |
| `*.ts` `*.tsx` `*.jsx` `*.mjs` `*.cjs` | `web-reviewer` |
| `*.go` | `go-reviewer` |
| `*.dart` | `flutter-reviewer` |
| `*.sql`, anything under a `migrations/` path | `sql-reviewer` |
| anything else, OR a diff that spans 3+ of the groups above | `code-reviewer` (generalist) |

`security-reviewer` **always runs**, over the whole changeset, regardless of which language groups fired. Untrusted-input-to-sink doesn't respect file extensions.

Collapse the buckets to the **distinct set of agents** to dispatch. Example: a diff touching `api/users.py`, `web/app.tsx`, and `db/migrations/004.sql` → dispatch `python-reviewer`, `web-reviewer`, `sql-reviewer`, and `security-reviewer` — four agents, in parallel. A diff of only `README.md` and a `Makefile` → `code-reviewer` + `security-reviewer`.

## 3. DISPATCH (parallel)

Launch the selected reviewer agents from this bundle's `agents/` directory **concurrently** — one message, all the agent calls together, never one-at-a-time. Each agent gets:

- the **mode** and the anchor (PR ref or `HEAD`),
- its **own slice** of the changed files (the paths that routed to it),
- the diff for those files,
- the instruction to follow the `rsc-sdd:review` pass order and return **evidence-backed, severity-tagged findings** (`blocker` / `should-fix` / `nit` / `question`) in the finding format — quoted location, why, repro, fix.

`security-reviewer` gets the full changeset, not a slice.

If a spec/plan exists under `02-DOCS/wiki/sdd/`, pass the relevant slug so reviewers can judge **spec fidelity**, not just intrinsic correctness. If there's no spec, tell them so — review against the constitution + the diff's stated intent, don't fake a baseline.

Wait for all agents to return before moving on. A timed-out or failed agent is reported as a **gap** in the final report ("`go-reviewer` did not return — Go files unreviewed"), never silently dropped.

## 4. AGGREGATE → one report

Merge every agent's findings into a single consolidated review. Do **not** paste each agent's output verbatim.

1. **Dedupe.** The same defect found by two agents (e.g. `security-reviewer` and `python-reviewer` both flag the same SQL injection) collapses to one finding, crediting the strongest evidence.
2. **Confidence filter.** Drop anything below ~80% confidence and drop pure style nits that carry no correctness or security weight — those are noise in a consolidated verdict. A genuinely uncertain-but-important item survives as a `[question]`, not a `blocker`.
3. **Rank by severity**, then by blast radius within a severity: `blocker` → `should-fix` → `nit`/`question`. If everything is a blocker, you mis-triaged; if nothing is, you didn't review.
4. **One verdict** at the top, from the triad — mirror the discipline's language:
   - **ship** — no blockers, no unresolved should-fix. Point to `rsc-sdd:ship`.
   - **fix-then-ship** — should-fix items exist but no blockers; list exactly what to fix.
   - **block** — one or more blockers; the merge does not happen until they're resolved.

## 5. VERBOSITY — honor the accompaniment dial

Read the level from `02-DOCS/wiki/harness/user-profile.md`. It changes **narration, never rigor** — every level ran the same agents and the same evidence bar.

- **L0** — verdict + blocker list, terse.
- **L1** — each finding gets its one-line *why*.
- **L2** (default when no profile) — full finding format per item; explain why each blocker blocks.
- **L3** — the above plus the defect-class teaching (IDOR, N+1, TOCTOU…) and plain-language impact.

## Pairs with

This command is the **dispatch + aggregation** layer. The judgment — the pass order, the severity definitions, the verdict semantics, and the *receiving*-a-review half — lives in the `rsc-sdd:review` discipline skill. When a finding gets accepted or declined with consequence, that skill owns logging it to `02-DOCS/wiki/sdd/decisions.md`. Run this command to produce a review; lean on that skill to reason about one.
