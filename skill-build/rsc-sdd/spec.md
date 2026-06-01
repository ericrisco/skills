# rsc-sdd — Spec-Driven Development for the rsc ecosystem (design spec)

## Purpose & identity

`rsc-sdd` is the **engineering counterpart of the `harness`**. Where the harness runs the
*chaos → knowledge* loop (inbox → 02-DOCS wiki), `rsc-sdd` runs *intent → shipped, verified
software*, recording the spec / plan / decisions into `02-DOCS` so the project's living
knowledge model grows with every feature.

It uses the **standard Spec-Driven Development nomenclature** (GitHub Spec Kit lineage:
constitution → specify → clarify → plan → tasks → analyze → implement). This gives it its own
established identity as an *SDD* ecosystem — it is **not** a re-skin of obra/superpowers.

### Originality constraints (hard)

- 100% original prose in the rsc voice. **Never** reproduce superpowers' signature artifacts or
  phrasing: no "EXTREMELY-IMPORTANT / 1% chance" blocks, no copied rationalization-table wording,
  no `*-reviewer-prompt.md` file convention, no verbatim flowchart text.
- The organizing axis is rsc-native (harness, 02-DOCS, accompaniment dial, stack handoff), not
  superpowers' silhouette.
- Mine the *ideas*; the expression is Eric's. See memory: original-not-copies, git-authorship-is-eric.

## Packaging

- New 7th bundle **`rsc-sdd`** → `plugins/rsc-sdd/` (real copies via `scripts/sync-bundles.sh`),
  entry in `.claude-plugin/marketplace.json`, namespace `/rsc-sdd:*`,
  install `/plugin install rsc-sdd@rsc-skills`.
- One new skill in **`rsc-core`**: `author-skill` (meta — authoring/editing skills). Added to the
  rsc-core bundle (alongside init, harness) → `/rsc-core:author-skill`.
- Knowledge-map rows added to the harness `claude-md-template.md` for the new topics.

## The dispatcher & flow

`/rsc-sdd:sdd` is the entry/dispatcher: states the SDD method, the **invoke-the-right-phase rule**
(in rsc voice, tied to the harness accompaniment dial — verbosity L0..L3), and the **chained phase
map**. Each phase skill ends by pointing at the next.

Canonical chain:
`constitution` (once per project) → `specify` → `clarify` → `plan` → `tasks` → `analyze` →
`implement` → `verify` → `review` → `ship`.
On-demand, callable from any phase: `debug`, `worktrees`, `parallel`.

## The 14 rsc-sdd skills

Each: hybrid (`SKILL.md` focused + `references/` where genuinely needed + `evals/cases.yaml`).
No `verify.sh` (process skills — judged on safety rails). Description is third-person, trigger-rich
"Use when…", ≤1024 chars, valid quoted YAML, `origin: risco`. Honors the accompaniment dial.

1. **sdd** — dispatcher. The method, the phase map, the invoke rule, how to read the
   accompaniment level from `02-DOCS/wiki/harness/user-profile.md` and adapt. Points to `constitution`/`specify`.
2. **constitution** — capture the project's non-negotiable principles (stack canon, quality bars,
   conventions). Writes/updates `02-DOCS/wiki/sdd/constitution.md`, links from the root CLAUDE.md
   Knowledge map. Read by every later phase as guardrails. Integrates with harness (it may already
   hold conventions in 02-DOCS/wiki/stack/*).
3. **specify** — turn a fuzzy intent into a spec (what & why, no implementation). Writes
   `02-DOCS/wiki/sdd/specs/<slug>.md`. Asks one focused question at a time only where it can't infer.
4. **clarify** — read the spec, surface ambiguities / edge cases / underspecified areas, ask the
   user, bake answers back into the spec. The de-risking gate before planning.
5. **plan** — technical implementation plan from the spec (architecture, interfaces, data flow,
   testing strategy, risks). Writes `02-DOCS/wiki/sdd/plans/<slug>.md`. Defers stack specifics to
   the relevant stack skill.
6. **tasks** — break the plan into an ordered, independently-verifiable task list (each task has a
   done-check). Writes the task list into the plan artifact.
7. **analyze** — pre-implementation consistency gate: cross-check constitution ↔ spec ↔ plan ↔
   tasks for gaps/contradictions/scope drift. Report only; the user resolves. No code yet.
8. **implement** — execute tasks with checkpoints. **TDD discipline embedded** (red → green →
   refactor), delegating the concrete test tooling to the relevant stack skill (fastapi/go/nextjs/
   flutter testing references). Logs decisions to `02-DOCS/wiki/sdd/decisions.md`. Uses `parallel`
   when tasks are independent. Stays consistent with the constitution.
9. **verify** — post-implementation gate: run the relevant stack skill's `scripts/verify.sh`
   (lint/type/test/audit) + check the task done-checks + the spec's acceptance criteria. Evidence
   before claiming done. Points to `review`.
10. **review** — adversarial code review (both giving a rigorous review and receiving one with
    technical rigor, no performative agreement). Verifies findings before acting.
11. **ship** — close the branch: PR / merge / cleanup options. **Git authorship = Eric, never
    Claude** (no Co-Authored-By Claude, no generated-with footer). Mirrors how we actually ship.
12. **debug** — disciplined root-cause diagnosis: reproduce → isolate → hypothesize → fix →
    verify, before proposing fixes. Callable mid-implement.
13. **worktrees** — isolate feature work in a branch/worktree before executing a plan.
14. **parallel** — when and how to fan out independent work across subagents (the pattern we use):
    disjoint scope, no shared state, gather results.

## author-skill (rsc-core)

`/rsc-core:author-skill` — author or edit a skill to the rsc catalog's bar: trigger-rich third-
person description (≤1024, valid YAML), hybrid structure (SKILL.md + references/ + evals/ +
verify.sh where applicable), progressive disclosure, the best-practice rubric we audited against,
and an `evals/cases.yaml` for the new skill. Knows the rsc conventions (bundles, namespacing,
sync-bundles, Knowledge map). Original voice; does not copy superpowers' writing-skills.

## rsc integrations (what makes it ours)

- **Artifacts in 02-DOCS:** `02-DOCS/wiki/sdd/` holds constitution, specs/, plans/, decisions.md;
  indexed from the root CLAUDE.md `## Knowledge map`. The harness manages/improves them.
- **Stack handoff:** `implement`/`verify` delegate concrete tooling to the stack skills; `tdd`
  discipline lives in `implement`.
- **Accompaniment dial:** every skill reads the harness user-profile and adapts verbosity/question
  count (L0 terse … L3 explain-everything).
- **Ties:** `init` recommends installing `rsc-sdd`; `ship` enforces Eric-only git authorship.

## Format & acceptance criteria

- Each SKILL.md ~120–400 lines, focused; deep material in `references/`; use a copy-able checklist /
  decision table where a flow branches (only where non-obvious), an anti-patterns table in rsc voice.
- Each skill ships `evals/cases.yaml` (≥5 should_trigger incl. non-obvious, ≥4 near-miss
  should_not_trigger routed to the correct sibling, ≥1 capability scenario with a rubric) + `evals/README.md`.
- `scripts/eval-lint.sh` passes for the new skills; `sync-bundles.sh` updated with the rsc-sdd
  bundle map and re-run so `plugins/rsc-sdd/skills/*` are real copies (0 symlinks).
- `marketplace.json` gains the `rsc-sdd` plugin entry; `plugins/rsc-sdd/.claude-plugin/plugin.json`
  created (version in plugin.json only, `mcpServers: {}`, no agents/hooks fields).
- README catalog + Knowledge-map template updated.
- No broken `../sibling/SKILL.md` links; all descriptions valid YAML ≤1024 chars.
- Git authorship: Eric only.
