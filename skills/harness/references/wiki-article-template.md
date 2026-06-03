---
title: {Title}
aliases: [{old-slug}]
tags: []
type: article
topic: {topic}
status: draft
sources: []
updated: {YYYY-MM-DD}
score: 0.0
---

# {Title}

> Sources: {Author1, YYYY-MM-DD; Author2, YYYY-MM-DD}
> Raw: [[{raw-source-1}]]; [[{raw-source-2}]]

## Overview

{One paragraph summarizing the key points of this article.}

## {Body Sections}

{Synthesize a coherent structure from the source material. Do not copy source text verbatim; distill and reorganize. Use blockquotes sparingly for particularly important original phrasing.}

## Related

{OPTIONAL — include only when cross-references exist. Maintained during lint. Use wikilinks so the link survives renames and shows in the Obsidian graph + backlinks:
- Same or different topic: `- [[Other Article]] — why it connects.`
- With display text: `- [[Other Article|how we say it here]] — why it connects.`}

<!--
FRONTMATTER CONTRACT (this is what powers Obsidian Properties + Bases + graph):
- title    human-readable; the H1 matches it.
- aliases  keep the old kebab slug here so pre-migration links/wikilinks still resolve.
- tags     cross-cutting qualities ONLY — never the main category (that is `topic`).
- type     article | decision | worklog | brief | spec | profile
- topic    the wiki/<topic>/ folder, one level. Inferred from content, never hardcoded.
- status   draft | stable | stale  (lifecycle; filterable in a Base).
- sources  wikilinks to raw/ pages this was distilled from (cite your evidence).
- updated  YYYY-MM-DD of the last meaningful edit.
- score    mirror of scores.json, written by the Maintenance Pass (single writer → no drift).
-->
