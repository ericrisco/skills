---
name: sdd-init
description: "Use when calibrating an existing repo before running the rsc SDD flow: detecting stack, package manager, test runners, lint/type/build commands, monorepo signals, artifact store, execution mode, review budget, strict TDD capability, and project skill registry. Triggers: 'calibrate this repo for SDD', 'run sdd init', 'detect my test runner before implementing', 'set up SDD config', 'prepare this repo for spec-driven development'. NOT first-contact user/workspace bootstrap (init), NOT 01-TOOLS/02-DOCS scaffolding (harness), NOT writing a feature spec (specify)."
tags: [sdd, init, config, testing, registry]
recommends: [sdd, specify, implement, verify]
profiles: [core, full]
origin: risco
---

# sdd-init — calibrate the repo before the SDD chain

`sdd-init` is step zero for technical SDD work. It does not profile the user and it does not scaffold the harness. `init` owns first contact; `harness` owns `01-TOOLS/` and `02-DOCS/`. This skill reads the repo, detects how it should be built and tested, refreshes the cheap skill registry, and writes one durable config:

```text
02-DOCS/wiki/sdd/config.yaml
```

That config is the runtime contract later phases read before choosing commands, TDD strictness, artifact paths, review budget or skill briefs.

## Inputs

Read-only first:

- `package.json`, lockfiles, `pnpm-workspace.yaml`, `pyproject.toml`, `requirements.txt`, `go.mod`, `pubspec.yaml`, `Dockerfile`, `.github/`.
- Existing `02-DOCS/wiki/sdd/config.yaml`, if present.
- `02-DOCS/wiki/harness/user-profile.md`, if present, for accompaniment level only.
- `.rsc/skill-registry.json`, if present, to decide whether it is stale or missing.

If `02-DOCS/` does not exist, create only the `02-DOCS/wiki/sdd/` path needed for the config. Do not run full harness scaffolding unless the user asked for `harness`.

## Preflight Choices

Ask only when the answer changes behavior. At L0/L1 infer defaults and show them; at L2/L3 explain the trade-off.

| Setting | Default | Options |
| --- | --- | --- |
| `execution_mode` | `interactive` | `interactive` pauses at review-risk gates; `automatic` chains phases until a blocker/risk appears. |
| `artifact_store` | `02-DOCS/wiki/sdd` | Keep RSC artifacts in `02-DOCS`; do not create an `openspec/` parallel tree. |
| `review_budget.line_budget` | `400` | Lower for solo tight review; higher only with explicit approval. |
| `delivery_strategy.default` | `ask-on-risk` | `ask-on-risk`, `single-pr`, `autochain`, `exception`. |

## Detection

Use the repo detector exposed by the CLI code (`detectRepoProfile`) or reproduce the same facts manually if running inside an agent without code access:

- stacks: Next.js/React, FastAPI/Python, Go, Flutter, Postgres, deployment signals;
- package managers: pnpm, npm, yarn, bun;
- scripts: `test`, `lint`, `typecheck`, `build`;
- runners: Vitest, Jest, Playwright, pytest, `go test`, `flutter test`;
- monorepo signals;
- recommended apply and verify commands.

If any runner is detected, set `testing.strict_tdd: true`. Strict TDD means implement phases must do red -> green -> triangulate edge cases -> refactor, with command evidence. If no runner is detected, set it false and record the gap rather than pretending.

## Skill Registry

Refresh the project registry:

```bash
npx rsc registry refresh
```

This writes:

```text
.rsc/skill-registry.json
.rsc/skill-registry.md
```

Later phases use this as a cheap index: id, trigger, tags, path, installed/available, hash. Do not load every skill into context. Select the few matching the phase and stack, then digest them into compact rules for subagents.

## Config Shape

Write `02-DOCS/wiki/sdd/config.yaml` in this shape:

```yaml
version: 1
project:
  root: .
  stacks: []
  package_managers: []
  monorepo: false
  signals: []
sdd:
  artifact_store: 02-DOCS/wiki/sdd
  execution_mode: interactive
  registry_path: .rsc/skill-registry.json
  review_budget:
    line_budget: 400
    file_budget: 12
  delivery_strategy:
    default: ask-on-risk
testing:
  strict_tdd: false
  runners: []
  commands:
    apply: []
    verify: []
phase_rules:
  proposal: optional-on-ambiguity
  specify: requires intent or proposal
  plan: requires spec
  tasks: requires plan and spec
  analyze: requires spec plan tasks
  implement: requires analyze pass, strict_tdd when testing.strict_tdd is true
  verify: requires spec tasks evidence
  archive: requires verify record and review/ship outcome
```

Preserve user edits if the file exists: update detected facts and leave comments/custom policy fields intact when possible. If preservation is risky, write a proposed replacement next to it as `config.proposed.yaml` and ask.

## Result Envelope

End with the standard SDD result envelope:

```json result-envelope
{
  "status": "complete",
  "executive_summary": "SDD config calibrated and registry refreshed.",
  "artifact": "02-DOCS/wiki/sdd/config.yaml",
  "next_recommended": "sdd",
  "risk": "low",
  "skill_resolution": {
    "used": ["sdd-init"],
    "missing": [],
    "fallback": [],
    "compact_rules": [
      "Read config.yaml before choosing commands.",
      "Use .rsc/skill-registry.json as the cheap skill index."
    ]
  },
  "evidence": ["npx rsc registry refresh", "detected test commands recorded"]
}
```

## Anti-patterns

| Temptation | Reality |
| --- | --- |
| "I'll skip config and remember the commands in chat." | Chat is not source of truth. Write `config.yaml`. |
| "No test command detected, but I'll still say strict TDD is active." | Strict TDD needs a runner. Record the gap. |
| "Load all skills so the agent has context." | That pollutes context. Use registry -> selected skills -> compact rules. |
| "This is the same as init." | No. `init` profiles user/workspace; `sdd-init` calibrates technical SDD runtime. |
| "Create openspec/ because Gentle does." | RSC uses `02-DOCS/wiki/sdd/` as source of truth. |

## Next

After `sdd-init`, return to `sdd`. If no spec exists, route to `specify`. If the work is ambiguous or architectural, write a proposal first under `02-DOCS/wiki/sdd/proposals/`.
