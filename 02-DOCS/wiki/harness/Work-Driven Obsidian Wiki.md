---
title: Work-Driven Obsidian Wiki
aliases: [work-driven-obsidian-wiki, worklog-sweep]
tags: [karpathy, obsidian, knowledge-engine]
type: article
topic: harness
status: stable
sources:
  - "[[2026-06-03-harness-obsidian-wiki]]"
updated: 2026-06-03
score: 0.0
---

# Work-Driven Obsidian Wiki

> Sources: Eric, 2026-06-03
> Raw: [[2026-06-03-harness-obsidian-wiki]]

## Overview

The harness `02-DOCS/` engine documents **what we do**, not only what we drop in
`inbox/`, and the wiki it produces lives natively in Obsidian. Two grafts on the
existing `inbox → Sweep → raw → Compile → wiki` machine — no parallel system.

## The two on-ramps

- **Inbox Sweep** (existing) — the user drops files; the agent compiles them.
- **Worklog Sweep** (new) — a session of work is itself a `raw` source. It lands
  in `raw/worklog/` and is Compiled into `wiki/` through the same pipeline.
  Triggers: a `PreCompact`/`SessionEnd` hook, an explicit milestone (a commit),
  and the daily curation automation. The hook only reminds; the agent writes the
  wiki (Karpathy: the LLM writes, the human reads).

## The Obsidian skin

The `wiki/` layer uses wikilinks, YAML frontmatter (Properties), `status`
lifecycle, readable filenames, `attachments/`, and `.base` views. Navigation is
**structure** (links + frontmatter + Bases), not semantic similarity — **no vector
DB, no embeddings, no RAG**. The `.base` views are the human navigation; `index.md`
+ `scores.json` stay as the machine layer.

## Related

- [[Decisions]] — the design choice and its alternatives.
