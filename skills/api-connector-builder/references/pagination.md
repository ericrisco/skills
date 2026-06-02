# Pagination — full code per style

The universal rule: **loop until the API signals no next page.** Never a fixed
page count. Expose results as a generator / async-iterator so callers stream
instead of buffering the whole set in memory.

(graphql.org/learn/pagination + REST pagination pattern guides, accessed
2026-06-02.)

## Offset / page number

Simple, but it **drifts** when rows are inserted or deleted mid-walk (you skip or
double-read) and gets **slow at large offsets** (the server scans and discards).
Prefer cursor/keyset when the API offers it.

```python
def iter_offset(client, path, page_size=100):
    offset = 0
    while True:
        body = client.get(path, params={"offset": offset, "limit": page_size}).json()
        rows = body["data"]
        if not rows:                  # empty page = exhausted
            return
        yield from rows
        offset += len(rows)
```

```typescript
export async function* iterOffset(get: (q: Record<string, number>) => Promise<any>, pageSize = 100) {
  let offset = 0;
  for (;;) {
    const body = await get({ offset, limit: pageSize });
    const rows = body.data as unknown[];
    if (rows.length === 0) return;     // exhausted
    yield* rows;
    offset += rows.length;
  }
}
```

## Cursor / keyset

The server returns an opaque cursor for the next page; you pass it back. **Stable
under concurrent writes and fixed cost regardless of depth** — the strategy to
prefer.

```python
def iter_cursor(client, path, page_size=100):
    cursor = None
    while True:
        body = client.get(path, params={"cursor": cursor, "limit": page_size}).json()
        yield from body["data"]
        cursor = body.get("next_cursor")
        if not cursor:                # cursor exhausted
            return
```

## Link header (REST)

The next page lives in the `Link` response header with `rel="next"`. Follow it
until the header has no `next`.

```python
import re

def iter_link(client, url):
    while url:
        resp = client.get(url)
        yield from resp.json()
        link = resp.headers.get("Link", "")
        m = re.search(r'<([^>]+)>;\s*rel="next"', link)
        url = m.group(1) if m else None   # no rel="next" = exhausted
```

```typescript
function nextLink(header: string | null): string | null {
  if (!header) return null;
  const m = header.match(/<([^>]+)>;\s*rel="next"/);
  return m ? m[1] : null;
}

export async function* iterLink(start: string, get: (u: string) => Promise<Response>) {
  let url: string | null = start;
  while (url) {
    const res = await get(url);
    yield* (await res.json()) as unknown[];
    url = nextLink(res.headers.get("Link"));
  }
}
```

## GraphQL — Relay Cursor Connections

The Relay spec returns `edges` (each with a `node` and `cursor`) and a `pageInfo`
with `endCursor` and `hasNextPage`. Pass `endCursor` as the `after` argument of
the next query and stop when `hasNextPage` is false.

```python
QUERY = """
query($after: String) {
  issues(first: 100, after: $after) {
    edges { node { id title } }
    pageInfo { endCursor hasNextPage }
  }
}
"""

def iter_relay(client, url):
    after = None
    while True:
        body = client.post(url, json={"query": QUERY, "variables": {"after": after}}).json()
        conn = body["data"]["issues"]
        for edge in conn["edges"]:
            yield edge["node"]
        info = conn["pageInfo"]
        if not info["hasNextPage"]:   # exhausted
            return
        after = info["endCursor"]
```

## Dedup on overlap

With offset pagination under concurrent inserts, the same row can appear on two
pages. If exactness matters, track seen ids and skip duplicates:

```python
def dedup(records, key="id"):
    seen = set()
    for r in records:
        k = r[key]
        if k in seen:
            continue
        seen.add(k)
        yield r
```

Cursor/keyset pagination does not have this problem for stable sort keys — another
reason to prefer it.

## Combine with retries + rate limits

Each `client.get(...)` above should go through the retry + rate-limit wrapper from
`SKILL.md` (transient-only retry with jittered backoff, `Retry-After` honored).
Pagination is the loop; the per-request call inside it is where resilience lives.
