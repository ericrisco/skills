# skills

Eric Risco's personal collection of agent skills for [skills.sh](https://skills.sh).

[![skills.sh](https://skills.sh/b/ericrisco/skills)](https://skills.sh/ericrisco/skills)

## Install

Install everything to your active agent (Claude Code, Codex, Cursor, etc.):

```bash
npx skills add ericrisco/skills --all
```

Install a single skill:

```bash
npx skills add ericrisco/skills --skill risco-project-harness
```

List what's in this catalog without installing:

```bash
npx skills add ericrisco/skills --list
```

## Skills in this catalog

### [risco-project-harness](skills/risco-project-harness/)

Workspace bootstrapper / brownfield auditor. Scans any project, detects
external provider integrations from 100+ catalog entries (Stripe, OpenAI,
Anthropic, Supabase, Sentry, Twilio, …), and — only with explicit
consent — scaffolds a canonical `01-TOOLS/` layer (one folder per
provider, each with a working `probar_conexion` smoke-test) plus a
`02-DOCS/` **chaos→knowledge engine** (Karpathy-style, fully embedded —
no external skill dependency).

The `02-DOCS/` layer is the second-brain pattern, domain-agnostic and
multiformat: drop **any raw file** (PDF, image, CSV, JSON, notes, html)
into `inbox/` and an **Inbox Sweep** — the agent "going for a walk" —
extracts it, classifies it by content into topics (`finanzas/`, `legal/`,
`crm/`…), cross-links it, and compiles it into a living wiki that
**self-improves** with every file (Maintenance Pass → Micro-Improve →
Deep Improve, schedulable via cron). The app on top consumes the
knowledge model, not the loose documents.

Also generates the root `CLAUDE.md` and `AGENTS.md`, and migrates legacy
`XX-*` numbered folders into the canonical structure.

Triggers: `"audit my project"`, `"bootstrap workspace"`, `"set up
01-TOOLS and 02-DOCS"`, `"risco harness"`, `"project harness"`,
`"procesa el inbox"`, `"sal a pasear"`.

## Skill format

Each skill is a directory under `skills/<name>/` with at minimum a
`SKILL.md` that has YAML frontmatter:

```yaml
---
name: my-skill
description: Use when [specific triggering conditions]
---
```

The full spec lives at [agentskills.io/specification](https://agentskills.io/specification).

## Contributing

This is a personal catalog. Bug reports welcome via GitHub issues. PRs
fixing detector patterns, provider endpoints, or English typos are
appreciated.

## License

MIT. See [LICENSE](LICENSE).
