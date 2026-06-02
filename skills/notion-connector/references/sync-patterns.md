# Sync patterns — idempotent upsert, dedupe, two-way reconcile, checkpointing

The Notion API has no native "upsert by my key" call. You build idempotency
yourself by keying every row on an **external id you control** and looking it up
before deciding create vs update.

## 1. Upsert by external key (one-way: app → Notion)

Store your external id in a dedicated `rich_text` property (e.g. `ExternalId`).
Look up by exact match, then branch.

```ts
async function upsert(dataSourceId: string, extId: string, props: object) {
  const found = await notion.dataSources.query({
    data_source_id: dataSourceId,
    filter: { property: "ExternalId", rich_text: { equals: extId } },
    page_size: 1,
  });
  if (found.results.length > 0) {
    await notion.pages.update({ page_id: found.results[0].id, properties: props });
    return found.results[0].id;
  }
  const created = await notion.pages.create({
    parent: { type: "data_source_id", data_source_id: dataSourceId },
    properties: { ...props, ExternalId: { rich_text: [{ text: { content: extId } }] } },
  });
  return created.id;
}
```

Better still: persist the returned Notion `page_id` next to the external id in
your own DB. Then most syncs skip the lookup query entirely (saves you against
the 3 req/s ceiling) and only fall back to query-by-key when the mapping is
missing.

## 2. Dedupe an already-duplicated table

If a prior blind-create run left duplicates: pull every row, group by
`ExternalId`, keep the newest by `last_edited_time`, archive the rest.

```ts
const rows = await queryAll(dataSourceId); // the has_more loop from SKILL.md
const byKey = new Map<string, any[]>();
for (const r of rows) {
  const k = r.properties.ExternalId?.rich_text?.[0]?.plain_text ?? "";
  if (!k) continue;
  (byKey.get(k) ?? byKey.set(k, []).get(k)!).push(r);
}
for (const [, group] of byKey) {
  if (group.length < 2) continue;
  group.sort((a, b) => b.last_edited_time.localeCompare(a.last_edited_time));
  for (const dup of group.slice(1)) {
    await notion.pages.update({ page_id: dup.id, archived: true }); // in_trash on 2026-03-11
  }
}
```

## 3. Two-way reconcile

Keep a `last_edited_time` watermark per row on each side.

- Pull rows from Notion changed since the last watermark (filter on
  `last_edited_time` `on_or_after`).
- Pull rows from your DB changed since the same checkpoint.
- For a row changed on **both** sides since the last sync → conflict. Default to
  last-writer-wins by comparing timestamps; for anything money/state-critical,
  do not auto-resolve — write both versions to a review queue and stop.
- Advance the watermark only after a clean pass commits.

A pure mirror (Notion → app, read-only) skips all of this: just pull and
overwrite your local copy.

## 4. Cursor checkpointing for large pulls

A pull of thousands of rows spans many cursor pages and may hit a 429 partway.
Persist the `next_cursor` after each page so a crashed job resumes instead of
restarting from row 0.

```ts
let cursor = await loadCheckpoint();      // undefined on first run
do {
  const res = await withRetry(() =>      // withRetry from SKILL.md
    notion.dataSources.query({ data_source_id: dataSourceId, start_cursor: cursor, page_size: 100 }));
  await handle(res.results);
  cursor = res.has_more ? res.next_cursor ?? undefined : undefined;
  await saveCheckpoint(cursor);          // durable between pages
} while (cursor);
```

## Rules of thumb

- One external id ⇒ exactly one Notion page. Enforce it in your own store.
- Never trust row order or array index to identify a row; key on `ExternalId`.
- Batch reads, serialize writes; respect the per-integration ~3 req/s average.
- Treat `archived`/`in_trash` as soft delete, then reconcile, before hard delete.
