# Wiki protocol — `02-DOCS/` layer

This is the protocol for the `02-DOCS/` layer of the workspace. Adapted from
the Karpathy LLM Wiki pattern: "The LLM writes and maintains the wiki; the
human reads and asks questions. The wiki is a persistent, compounding artifact."

This protocol is **embedded inside `risco-project-harness`** — no external
skill required. When the parent skill (`SKILL.md`) reaches Phase 4 step 8
("Build `02-DOCS/`"), follow this document.

---

## Architecture

Three layers, all under `<workspace_root>/02-DOCS/`:

**`raw/`** — Immutable source material. Read, never modify. Organized by
topic subdirectories (e.g., `raw/architecture/`, `raw/operations/`).

**`wiki/`** — Compiled knowledge articles. Full ownership. Organized by topic
subdirectories, one level only: `wiki/<topic>/<article>.md`. Contains these
special files:

- `wiki/index.md` — Global index. One row per article, grouped by topic, with
  link + summary + Updated date + Score.
- `wiki/log.md` — Append-only operation log (every ingest, query, lint,
  maintenance pass, and improve pass).
- `wiki/gaps.md` — Append-only knowledge-gap log. Topics wanted but missing,
  concepts mentioned across multiple articles without their own page, queries
  that couldn't be answered well. Read by the Improve pass.
- `wiki/scores.json` — Per-article composite quality score (regenerated on
  every Maintenance Pass).
- `wiki/dashboard.html` — auto-generated human dashboard (regenerated on every
  Maintenance Pass, gitignored). Self-contained HTML with score histogram,
  top/worst articles, open gaps, recent activity.
- `wiki/reports/YYYY-MM-DD-deep-improve.html` — one HTML report per Deep
  Improve run. Checked into git (small enough, valuable history).
- `wiki/<topic>/<archive>.html` — archived query answers (point-in-time
  reports, never edited, checked in).

### Format split: markdown for state, HTML for surfaces

The wiki uses **markdown for everything the agent reads or iteratively edits**
(`raw/`, articles, `log.md`, `gaps.md`, `scores.json`) and **HTML for surfaces
humans open** (dashboard, archives, deep-improve reports). This follows the
"HTML for artifacts, markdown for state" pattern. Rationale:

- Markdown corpus is grep-friendly for the agent in Query, diff-clean in git,
  and easy for Micro-Improve to rewrite without diff noise.
- HTML surfaces are read-once or regenerated; they get the information
  density (tables, inline SVG, color, interactivity) that Thariq advocates.

When in doubt: if it would be edited again, markdown. If it would be opened
once and looked at, HTML.

Templates live alongside this file in `references/`:

- `wiki-raw-template.md`
- `wiki-article-template.md`
- `wiki-index-template.md`
- `wiki-archive-template.md`

---

## Initialization

Triggers on the first Ingest. Check whether `02-DOCS/raw/` and `02-DOCS/wiki/`
exist. Create only what is missing; never overwrite existing files:

- `02-DOCS/raw/` directory (with `.gitkeep`)
- `02-DOCS/wiki/` directory (with `.gitkeep`)
- `02-DOCS/wiki/index.md` — heading `# Knowledge Base Index`, empty body
- `02-DOCS/wiki/log.md` — heading `# Wiki Log`, empty body
- `02-DOCS/wiki/gaps.md` — heading `# Knowledge Gaps`, empty body
- `02-DOCS/wiki/scores.json` — `{}` (populated by the first Maintenance Pass)
- `02-DOCS/wiki/reports/` directory (with `.gitkeep`) — will hold Deep Improve reports
- `02-DOCS/.gitignore` — at minimum: `wiki/dashboard.html`, plus any
  `audit-*.html` files written at workspace root by the parent skill

If Query or Lint cannot find the wiki structure, tell the user:
"Run an ingest first to initialize the wiki." Do not auto-create.

---

## Ingest

Fetch a source into `raw/`, then compile it into `wiki/`. Always both steps,
no exceptions.

### Fetch (raw/)

1. Get the source content. If it's a local file (a README from a subproject,
   a migrated doc from `02-DOCS/raw/migrated/`), copy/move its content. If
   it's a URL, use the agent's web fetch capability. If nothing can reach
   the source, ask the user to paste it directly.

2. Pick a topic directory. Check existing `02-DOCS/raw/` subdirectories
   first; reuse one if the topic is close enough. Create a new subdirectory
   only for genuinely distinct topics.

3. Save as `02-DOCS/raw/<topic>/YYYY-MM-DD-descriptive-slug.md`.
   - Slug from source title, kebab-case, max 60 characters.
   - Published date unknown → omit the date prefix from the file name
     (e.g., `descriptive-slug.md`). The metadata Published field still
     appears; set it to `Unknown`.
   - If a file with the same name already exists, append a numeric suffix
     (e.g., `descriptive-slug-2.md`).
   - Include metadata header: source URL, collected date, published date.
   - Preserve original text. Clean formatting noise. Do not rewrite opinions.

   See `wiki-raw-template.md` for the exact format.

### Compile (wiki/)

Determine where the new content belongs:

- **Same core thesis as existing article** → Merge into that article. Add the
  new source to Sources/Raw. Update affected sections.
- **New concept** → Create a new article in the most relevant topic directory.
  Name the file after the concept, not the raw file.
- **Spans multiple topics** → Place in the most relevant directory. Add
  See Also cross-references to related articles elsewhere.

These are not mutually exclusive. A single source may warrant merging into
one article while also creating a separate article for a distinct concept
it introduces. In all cases, check for factual conflicts: if the new source
contradicts existing content, annotate the disagreement with source
attribution. When merging, note the conflict within the merged article.
When the conflicting content lives in separate articles, note it in both
and cross-link them.

See `wiki-article-template.md` for article format. Key points:

- Sources field: author, organization, or publication name + date,
  semicolon-separated.
- Raw field: markdown links to `raw/` files, semicolon-separated.
- Relative paths from `wiki/<topic>/` use `../../raw/<topic>/<file>.md` (two
  levels up to `02-DOCS/`).

### Cascade Updates

After the primary article, check for ripple effects:

1. Scan articles in the same topic directory for content affected by the
   new source.
2. Scan `02-DOCS/wiki/index.md` entries in other topics for articles covering
   related concepts.
3. Update every article whose content is materially affected. Each updated
   file gets its Updated date refreshed.

Archive pages are never cascade-updated (they are point-in-time snapshots).

### Post-Ingest

Update `02-DOCS/wiki/index.md`: add or update entries for every touched
article. When adding a new topic section, include a one-line description.
The Updated date reflects when the article's knowledge content last changed,
not the file system timestamp. See `wiki-index-template.md` for format.

Append to `02-DOCS/wiki/log.md`:

```
## [YYYY-MM-DD] ingest | <primary article title>
- Updated: <cascade-updated article title>
- Updated: <another cascade-updated article title>
```

Omit `- Updated:` lines when no cascade updates occur.

### Auto-trigger: Maintenance Pass

Every Ingest ends by running the **Maintenance Pass** (see Continuous
Improvement section below). This is not optional — it runs automatically.

---

## Query

Search the wiki and answer questions. Examples of triggers:

- "What do I know about X?"
- "Summarize everything related to Y"
- "Compare A and B based on my wiki"

### Steps

1. Read `02-DOCS/wiki/index.md` to locate relevant articles.
2. Read those articles and synthesize an answer.
3. Prefer wiki content over your own training knowledge. Cite sources with
   markdown links: `[Article Title](02-DOCS/wiki/topic/article.md)`
   (project-root-relative paths for in-conversation citations; within
   wiki/ files, use paths relative to the current file).
4. Output the answer in the conversation. Do not write files unless asked.

### Auto-trigger: Touch Update + Maintenance Pass

After answering, run two automatic passes (non-blocking — the answer comes
first):

1. **Touch Update**:
   - For every article cited, increment its `cited_count` in `wiki/scores.json`.
   - If the query couldn't find a satisfying answer (no relevant article, or
     the agent had to fall back on training data), append a gap to
     `wiki/gaps.md` (format below).
2. **Maintenance Pass** (see Continuous Improvement section below).

### Archiving

When the user explicitly asks to archive or save the answer to the wiki:

1. Write the answer as a new **HTML** wiki page. See
   `wiki-archive-template.html`. Archives are point-in-time, read-once
   reports and benefit from HTML's information density (TL;DR box, sources
   sidebar, anchor links, inline SVG when relevant). When converting
   conversation citations to the archive page, rewrite project-root-relative
   paths to file-relative paths.
   - Sources sidebar: links to the wiki articles cited in the answer (use
     `.md` paths — they still link to the live articles).
   - No Raw field (content does not come from raw/).
   - File name reflects the query topic, e.g.,
     `subscription-flow-overview.html`.
   - Place in the most relevant topic directory: `wiki/<topic>/<name>.html`.
   - Self-contained: inline CSS, no CDN, no external scripts.
2. Always create a new page. Never merge into existing articles (archive
   content is a synthesized answer, not raw material).
3. Update `02-DOCS/wiki/index.md`. Add a row pointing to the `.html` file,
   prefix the Summary with `[Archived]`. The link target is the HTML path.
4. Append to `02-DOCS/wiki/log.md`:
   ```
   ## [YYYY-MM-DD] query | Archived: <page title>
   ```

---

## Lint

Quality checks on the wiki. Two categories with different authority levels.

### Deterministic Checks (auto-fix)

Fix these automatically:

**Index consistency** — compare `02-DOCS/wiki/index.md` against actual
`02-DOCS/wiki/` files (excluding index.md and log.md):

- File exists but missing from index → add entry with `(no summary)`
  placeholder. For Updated, use the article's metadata Updated date if
  present; otherwise fall back to file's last modified date.
- Index entry points to nonexistent file → mark as `[MISSING]` in the
  index. Do not delete the entry; let the user decide.

**Internal links** — for every markdown link in `wiki/` article files (body
text and Sources metadata), excluding Raw field links (validated by Raw
references below) and excluding index.md/log.md (handled above):

- Target does not exist → search `wiki/` for a file with the same name
  elsewhere.
  - Exactly one match → fix the path.
  - Zero or multiple matches → report to the user.

**Raw references** — every link in a Raw field must point to an existing
`raw/` file:

- Target does not exist → search `raw/` for a file with the same name
  elsewhere.
  - Exactly one match → fix the path.
  - Zero or multiple matches → report to the user.

**See Also** — within each topic directory:

- Add obviously missing cross-references between related articles.
- Remove links to deleted files.

### Heuristic Checks (report only)

These rely on your judgment. Report findings without auto-fixing:

- Factual contradictions across articles
- Outdated claims superseded by newer sources
- Missing conflict annotations where sources disagree
- Orphan pages with no inbound links from other wiki articles
- Missing cross-topic references
- Concepts frequently mentioned but lacking a dedicated page
- Archive pages whose cited source articles have been substantially updated
  since archival

### Post-Lint

Append to `02-DOCS/wiki/log.md`:

```
## [YYYY-MM-DD] lint | <N> issues found, <M> auto-fixed
```

---

## Continuous Improvement

The wiki improves itself as the user interacts with it. Three layers,
increasing in scope and consent requirements:

### Layer 1 — Maintenance Pass (every Ingest, every Query)

**Runs automatically. No consent prompt. Non-destructive only.**

Operations:

1. **Deterministic Lint with auto-fix** — runs the Lint subset that is safe
   to fix automatically (broken internal links, raw references, See Also
   drift, index consistency).
2. **Recompute quality scores** — for every wiki article, compute:
   ```
   score = (inbound_links * 2)
         + (sources_count)
         + (cited_count * 0.5)
         + freshness_weight
         - (conflict_count * 3)
         - (orphan_penalty)
   ```
   Where:
   - `freshness_weight` = 1.0 if Updated within 30 days, 0.5 within 90, 0.1 beyond 180.
   - `orphan_penalty` = 5 if zero inbound links AND zero citations, else 0.
   - `conflict_count` = number of explicit conflict annotations in the article body.

   Write to `02-DOCS/wiki/scores.json` as `{ "topic/article.md": <score>, ... }`.
3. **Cross-link sweep** — within each affected topic, add obviously missing
   `See Also` links between related articles (the existing Lint heuristic, but
   actually applied, not just reported).
4. **Gap detection** — for concepts mentioned in ≥3 articles but lacking a
   dedicated page, append to `wiki/gaps.md`.
5. **Dashboard regeneration** — render `wiki/dashboard.html` from
   `wiki-dashboard-template.html`, populating it with current scores, top/worst
   5 articles, open gaps, and the last 20 lines from `wiki/log.md`. The HTML is
   self-contained (inline CSS + SVG, no CDN). Gitignored.
6. **Log** — append a one-line entry to `wiki/log.md`:
   ```
   ## [YYYY-MM-DD] maintenance | autofixes: <N>, new See Also: <M>, gaps detected: <K>
   ```

This pass MUST complete in under ~30 seconds for typical-sized wikis (< 200
articles). If it can't, skip the heaviest step (cross-link sweep) and log a
warning. The dashboard regeneration is cheap (< 1s) and never skipped.

### Layer 2 — Micro-Improve (every N interactions, default N=5)

**Runs automatically. No consent required for additive changes. Old versions
preserved.** Counts Ingests + Queries together. The counter lives at the top
of `wiki/log.md` (or in `wiki/scores.json` under `_meta.interactions_since_improve`).

When the counter hits N, run:

1. **Pick 1 lowest-scoring article** from `wiki/scores.json`. If its score is
   below threshold (default: 2.0), rewrite it:
   - Re-read all its `Raw:` sources.
   - Distill again with better structure (improved overview, clearer body
     sections, accurate See Also).
   - **Preserve the old version** at `wiki/<topic>/_archive/<article>__YYYY-MM-DD.md`
     so the user can revert.
   - Bump the Updated date.
2. **Pick 1 top gap** from `wiki/gaps.md`. If there's enough raw material for
   it (≥2 raw sources mention the concept), create a new article. Mark the
   gap as `[FILLED YYYY-MM-DD]` in `wiki/gaps.md` instead of deleting (audit trail).
3. **Refresh 1 stale archive** — if any archived query answer cites articles
   whose Updated dates are newer than the archive's, append a `> ⚠ Stale:
   underlying sources updated YYYY-MM-DD` note to the archive (read-only flag,
   don't rewrite).
4. **Reset counter** to 0.
5. **Log**:
   ```
   ## [YYYY-MM-DD] micro-improve | rewrote: <title>, filled gap: <title>, flagged stale: <title>
   ```

If a rewrite affects an article the user touched in the last 24 hours, SKIP
that article and pick the next lowest-scoring one — never overwrite recent
human work.

### Layer 3 — Deep Improve (explicit or scheduled)

**Runs on explicit user request, or via cron.** Heavier than Micro-Improve;
processes multiple articles per run.

Triggers:
- User says: `"improve the wiki"`, `"deep improve"`, `"polish wiki"`.
- Scheduled via the `schedule` skill (recommended cadence: weekly).

Operations:

1. Run a full Lint (both deterministic and heuristic categories).
2. Rewrite the bottom-K articles by score (default K=5).
3. Fill the top-K gaps (default K=3).
4. Generate cross-topic See Also recommendations from the heuristic Lint
   report and apply them.
5. Refresh all archive freshness flags.
6. Compact `wiki/gaps.md` — remove `[FILLED]` entries older than 90 days.
7. **Write the Deep Improve report** to
   `wiki/reports/YYYY-MM-DD-deep-improve.html` using
   `wiki-deep-improve-report-template.html`. Includes: summary stats,
   per-rewrite cards with old/new title and reason, gaps filled, conflicts
   flagged, archives marked stale. Self-contained HTML (inline CSS/SVG, no
   CDN). **Checked into git** (one report per run, dated, history is
   valuable).
8. Append a comprehensive log entry to `wiki/log.md` referencing the report
   file path.

Before Deep Improve runs from a user command, the agent MUST list what it
plans to rewrite/create and ask for `"yes, proceed"`. Scheduled runs use the
configuration captured at schedule creation time.

### Suggested cron setup

```bash
# Weekly Deep Improve, Sundays 04:00 local
schedule create wiki-improve --cron "0 4 * * 0" --command "deep improve wiki"

# Daily Lint with auto-fix at 03:00
schedule create wiki-lint --cron "0 3 * * *" --command "lint wiki --autofix"
```

### Knowledge Gaps log — format

`wiki/gaps.md` accumulates wanted-but-missing topics. Append-only; gaps get
flagged `[FILLED YYYY-MM-DD]` when addressed, never deleted.

```
# Knowledge Gaps

## [YYYY-MM-DD] gap | <concept>
Source: <where it was detected — query that couldn't answer, articles mentioning it, etc.>
Mentioned in: [Article A](topic/a.md), [Article B](topic/b.md)
Suggested topic: <topic where the new article would go>
Status: open
```

When filled:

```
## [YYYY-MM-DD] gap | <concept>
...
Status: [FILLED 2026-06-02] → wrote [New Article](topic/new-article.md)
```

### Safety rails for autonomous improvement

These apply to all Layers:

1. **Never overwrite without preservation.** Rewrites always archive the old
   version to `wiki/<topic>/_archive/`. The archive folder is gitignored
   from compaction (lives forever unless the user prunes).
2. **Never touch articles the human just touched.** If `Updated` < 24h ago,
   skip in Micro-Improve. (Deep Improve respects this via the consent prompt.)
3. **Never auto-resolve conflicts.** Heuristic Lint flags contradictions;
   the user resolves.
4. **Always log every change** to `wiki/log.md`. The log is the audit trail
   for everything autonomous.
5. **`wiki/gaps.md` and `wiki/log.md` are append-only.** No edits to past
   entries. Compaction (in Deep Improve) only removes `[FILLED]` gaps older
   than 90 days, and only adds a single compaction marker entry to the log.

---

## Conventions

- Standard markdown with relative links throughout.
- `wiki/` supports one level of topic subdirectories only. No deeper
  nesting.
- Today's date for log entries, Collected dates, and Archived dates.
  Updated dates reflect when the article's knowledge content last changed.
  Published dates come from the source (use `Unknown` when unavailable).
- Inside `wiki/` files, all markdown links use paths relative to the
  current file. In conversation output, use project-root-relative paths
  (e.g., `02-DOCS/wiki/topic/article.md`).
- Ingest updates both `02-DOCS/wiki/index.md` and `02-DOCS/wiki/log.md`.
  Archive (from Query) updates both. Lint updates `02-DOCS/wiki/log.md`
  (and `02-DOCS/wiki/index.md` only when auto-fixing index entries). Plain
  queries do not write any files.

---

## How autonomous improvement interacts with this protocol

- **Bootstrap Ingest** (Phase 4 step 8 of the parent SKILL.md) ends with the
  Maintenance Pass automatically — the wiki starts with scores already
  computed.
- **Subsequent Ingests and Queries** triggered by the user from any session
  carry the same auto-Maintenance behavior.
- **Counter persistence**: the interaction counter for Micro-Improve lives in
  `wiki/scores.json` under `_meta.interactions_since_improve`. Don't lose it
  across sessions.
- **Configuration**: defaults can be overridden by a `wiki/.config.json` if
  present: `{ "micro_improve_every": 5, "rewrite_threshold": 2.0, "skip_recent_hours": 24 }`.

---

## How `risco-project-harness` uses this protocol

When the parent skill reaches Phase 4 step 8 ("Build `02-DOCS/`"), it
performs a **bootstrap ingest** by treating each of these as a separate
Fetch+Compile pass:

1. Each subproject `README.md` → topic = `subprojects` (or split per
   subproject: `backend`, `frontend`, etc., if the workspace already has
   strong per-subproject identity).
2. `01-TOOLS/README.md` → topic = `operations`.
3. Each `01-TOOLS/<TOOL>/README.md` and `CREDENTIALS.md` → topic = `operations`,
   one article per tool, citing both files as Raw.
4. Each file under `02-DOCS/raw/migrated/` (from legacy `XX-*` folder
   migration) → topic chosen by content. **These files stay where they are
   in `raw/migrated/` — they're already raw.** Skip the Fetch step entirely
   and run only Compile: write `02-DOCS/wiki/<topic>/<article>.md` citing
   `../../raw/migrated/<original-folder>/<file>.md` in the Raw field. Do NOT
   duplicate the content into `raw/<topic>/`.
5. Root `CLAUDE.md` and `AGENTS.md` → topic = `meta`.

After the bootstrap ingest, the index.md should have at least these topics
populated. The user can re-trigger ingest later for new sources, and
the same protocol applies.
