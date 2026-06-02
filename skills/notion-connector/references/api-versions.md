# API versions — 2022-06-28 → 2025-09-03 → 2026-03-11 migration map

Pin `Notion-Version` per request. The SDK `@notionhq/client` v5.12.0+ (latest
5.22.0 as of 2026-05-19) defaults to `2025-09-03` and supports `2026-03-11` when
you pass `notionVersion`. Behavior is version-gated server-side: the *header you
send* decides the shapes, not the SDK version alone.

## 2022-06-28 → 2025-09-03 (breaking)

The big one. Databases became **containers of data sources**. A `2022-06-28`
integration cannot see or query a database once it has more than one data
source — this is the classic "it worked yesterday, now 404" report.

| Concern | 2022-06-28 | 2025-09-03 |
|---|---|---|
| Query rows | `POST /v1/databases/:id/query` | `POST /v1/data_sources/:data_source_id/query` |
| Read schema | `GET /v1/databases/:id` (props inline) | `GET /v1/data_sources/:data_source_id` |
| Update schema/title | `PATCH /v1/databases/:id` | `PATCH /v1/data_sources/:data_source_id` |
| Resolve container | n/a | `GET /v1/databases/:id` → `data_sources[]` ({id,name}) |
| Page parent | `{ "type": "database_id", "database_id": "…" }` | `{ "type": "data_source_id", "data_source_id": "…" }` |
| Search object filter | `filter.value = "database"` | `filter.value = "data_source"` (also `"page"`) |

Migration steps:

1. Bump the pinned version to `2025-09-03`.
2. For every `database_id` you query, first `GET /v1/databases/:id`, read
   `data_sources[]`, and select the right `id` (by `name` if more than one).
3. Replace `databases/:id/query` calls with `data_sources/:id/query`.
4. Change every page-create parent to `data_source_id`.
5. Update any `POST /v1/search` object filter value to `"data_source"`.

```diff
- POST /v1/databases/abc123/query
+ GET  /v1/databases/abc123            → data_sources:[{ id:"ds_…", name:"Tasks" }]
+ POST /v1/data_sources/ds_…/query
```

## 2025-09-03 → 2026-03-11 (breaking)

Smaller, but it changes field names you write.

| Concern | 2025-09-03 | 2026-03-11 |
|---|---|---|
| Insert block at position | `after` block param | `position` object: `{ after_block }` / `{ start }` / `{ end }` |
| Soft delete flag | `archived` (pages/dbs/blocks/data sources) | `in_trash` (same surfaces) |
| Audio-transcription block | block type `transcription` | block type `meeting_notes` |

```diff
- { "archived": true }
+ { "in_trash": true }

- await notion.blocks.children.append({ block_id, after, children })
+ await notion.blocks.children.append({ block_id, position: { after_block }, children })
```

## Picking a version

- Default to **`2025-09-03`** — it is the SDK default and the current major.
- Opt into **`2026-03-11`** only if you need `meeting_notes` blocks or the new
  block-`position` insertion semantics, and then use `in_trash` consistently.
- Whatever you choose, send it as an explicit header on every request and write
  code against *that* version's field names — never mix `archived` and
  `in_trash` in one codebase.
