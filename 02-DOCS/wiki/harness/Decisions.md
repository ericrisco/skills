---
title: Decisions
aliases: [decisions]
tags: []
type: decision
topic: harness
status: stable
sources: []
updated: 2026-06-03
score: 0.0
---

# Decisions

Append-only. One entry per significant decision: requirements, the 3 options, the
choice, and the why.

## [2026-06-03] Documenting our work as an Obsidian-native Karpathy wiki

**Requirements gathered:** capture *everything we do* automatically; faithful to
Karpathy (the LLM writes the wiki, the human reads); must live natively in
Obsidian; reusable inside the `harness` skill; no vector DB / RAG.

**Options:**

1. **Graft + hook** — keep the harness engine; add an Obsidian skin (wikilinks,
   frontmatter, Bases) + a work-driven Worklog Sweep, made reliable by a
   `PreCompact`/`SessionEnd` hook. **← chosen.**
2. **Protocol-only** — same, but no hooks; capture is best-effort.
3. **Full reference-template restructure** — adopt an external `schema/` + PARA
   folders; large rewrite, risks cloning the source, discards scores/dashboard.

**Choice:** Option 1.

**Why:** respects the minimal floor, keeps rsc original (the reference repo
`ek0212/second-brain-template` informed the Obsidian mapping, not the structure),
grafts the smallest change that makes the wiki a real vault, and the hook is what
makes "document everything" actually fire instead of relying on memory.

## Related

- [[Work-Driven Obsidian Wiki]] — the capability this decision shaped.
