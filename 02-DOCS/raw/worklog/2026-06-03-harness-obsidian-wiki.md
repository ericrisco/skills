---
type: worklog
topic: harness
date: 2026-06-03
status: processed
sources: []
---

# Worklog — work-driven, Obsidian-native harness wiki

## What we did

- Investigated whether `02-DOCS/` can be an Obsidian vault → yes, near-native fit.
- Designed and built a **work-driven** path into the harness wiki (the session is
  itself a `raw` source) plus an **Obsidian-native** output skin.
- Edited the `harness` skill: article template (frontmatter + wikilinks), new
  worklog + scaffolding + daily-curation references, `wiki-protocol.md`
  (Obsidian conventions + Worklog Sweep + init), index template, `SKILL.md`.
- Wired a `PreCompact`/`SessionEnd` hook (`targets/worklog-checkpoint.sh` +
  `targets/claude.js`) that reminds the agent to run a Worklog Sweep.
- Dogfooded: scaffolded this very vault and captured this session as worklog #1.

## Why

The harness was ingest-only (`inbox/ → Sweep → wiki/`). The user wants *everything
we do* documented Karpathy-style, living in Obsidian. Chosen approach: graft, not
rebuild — the work session is just another chaos source; the wiki gets an Obsidian
skin (wikilinks, frontmatter, Bases) so the human reads it as a second brain. No
vector DB / RAG — structure over embeddings.

## Files touched

- `skills/harness/SKILL.md` — two on-ramps + Obsidian-native description.
- `skills/harness/references/wiki-protocol.md` — Worklog Sweep + Obsidian conventions + init.
- `skills/harness/references/wiki-article-template.md` — frontmatter + wikilinks.
- `skills/harness/references/{wiki-worklog-template,obsidian-scaffolding,daily-curation-automation}.md` — new.
- `targets/worklog-checkpoint.sh`, `targets/claude.js` — hook wiring.

## Outcome

Shipped & verified on branch `harness-work-driven-obsidian-wiki`: 8 task commits;
all YAML/JSON/`.base` parse; `node --check` + idempotent `wireHook` end-to-end test
green; hook silent without a wiki, emits with one.

## Open questions / next

- Migration pass for the existing brand/content/sdd articles (add frontmatter,
  links → wikilinks) — deferred, opt-in via `knowledge-ops`.
- Wire the daily curation cron via the `schedule` skill when desired.

## Commands

- `node --check targets/claude.js` — js OK
- end-to-end `wireHook` ×2 — `{SessionStart:1, PreCompact:1, SessionEnd:1}` (idempotent)
