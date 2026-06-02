# Queries and performance (Prisma 7)

Depth offloaded from `SKILL.md`. Everything here assumes the v7 client: `provider =
"prisma-client"`, a driver adapter on the constructor, connection in `prisma.config.ts`.

## Shaping rows: `select` vs `include`

| You want | Use | Returns |
| --- | --- | --- |
| Only specific scalar fields | `select` | Exactly the named fields, nothing else |
| Specific fields + nested relation fields | nested `select` | Named scalars + named relation fields |
| A relation alongside the full record | `include` | **All** scalar fields + the named relation |

Rules:

- Default to `select`. `include` is convenient but over-fetches every column on the row,
  which costs bandwidth and leaks fields you did not mean to expose.
- Never put `select` and `include` at the same level — Prisma throws a validation error. Nest
  `select` inside a relation key to get both shaping and the relation.

```ts
// Shape the parent AND the relation with nested select
const users = await prisma.user.findMany({
  take: 20,
  select: {
    id: true,
    email: true,
    posts: { select: { id: true, title: true } }, // nested select, not include
  },
});
```

## Pagination: offset vs cursor

| Pattern | API | When | Cost |
| --- | --- | --- | --- |
| Offset | `skip` + `take` | Jump to an arbitrary page, small/medium tables | `skip` re-scans skipped rows; degrades on large offsets |
| Cursor | `cursor` + `take` (+ `skip: 1` to drop the anchor) | Infinite scroll, large tables, stable ordering | Seeks by an indexed unique column; constant cost |

```ts
// Cursor pagination — seek from the last id you saw
const page = await prisma.post.findMany({
  take: 20,
  ...(lastId ? { cursor: { id: lastId }, skip: 1 } : {}),
  orderBy: { id: "asc" }, // cursor needs a stable, indexed order
  select: { id: true, title: true },
});
const nextCursor = page.at(-1)?.id;
```

The cursor column must be unique and indexed (here `id`). Cursor pagination cannot jump to
"page 7" — it only moves forward/backward from a known row.

## Writes

```ts
// upsert: create-or-update keyed on a unique field
await prisma.user.upsert({
  where: { email },
  create: { email, role: "MEMBER" },
  update: { role: "MEMBER" },
});

// createMany: bulk insert, skip rows that collide on a unique constraint
await prisma.user.createMany({
  data: rows,
  skipDuplicates: true,
});
```

`createMany` does not return created rows and does not support nested writes. Use
`createManyAndReturn` when you need the inserted records back.

## Transactions

| Situation | Form | Why |
| --- | --- | --- |
| Several independent writes that must all commit or all roll back | `prisma.$transaction([opA, opB, opC])` (array) | One round trip, no app-side logic between ops |
| Read, branch on the result, then write conditionally | `prisma.$transaction(async (tx) => { … })` (interactive) | You need values from one op to decide the next |

```ts
// Interactive: read-then-write with a guard inside one transaction
const order = await prisma.$transaction(async (tx) => {
  const stock = await tx.product.findUniqueOrThrow({ where: { id }, select: { qty: true } });
  if (stock.qty < want) throw new Error("out of stock"); // throwing rolls the tx back
  await tx.product.update({ where: { id }, data: { qty: { decrement: want } } });
  return tx.order.create({ data: { productId: id, qty: want } });
});
```

Keep interactive transactions short. Every statement holds a connection and a DB lock; long
transactions starve the pool. Set a `timeout` / `maxWait` option for slow paths.

## Generated types and `Prisma.validator`

Do not hand-write the shape of a query result. Derive it from the query args so the two never
drift.

```ts
// Reuse one args object as both the query input and its result type
const userWithPosts = Prisma.validator<Prisma.UserDefaultArgs>()({
  select: { id: true, email: true, posts: { select: { title: true } } },
});

type UserWithPosts = Prisma.UserGetPayload<typeof userWithPosts>;

const users: UserWithPosts[] = await prisma.user.findMany(userWithPosts);
```

`Prisma.validator` type-checks the args at definition time; `Prisma.<Model>GetPayload`
extracts the exact return type for that selection.

## Performance checklist: kill N+1 and over-fetch

1. **Use `relationLoadStrategy: "join"` for parent-with-children reads.** Default in v7. On
   Postgres it emits a single LATERAL JOIN with JSON aggregation; on MySQL, correlated
   subqueries. The top-level choice cascades to nested relations. This collapses N+1 into one
   query.
2. **Switch to `"query"` only when a join fans out badly** (one parent → thousands of children
   multiplies rows). `"query"` runs one query per relation and stitches in the app.
3. **`select` only the columns you render.** A list view that shows a title should not pull a
   `body @db.Text`.
4. **`@@index` every column you filter or order on**, and every FK you join on — Prisma does
   not create FK indexes for you.
5. **See the SQL.** Set `log: ["query"]` on the client (or `["query", "warn", "error"]`). Read
   the emitted statements; a burst of identical `SELECT … WHERE id = $1` is N+1 — fix it with
   `"join"` or a batched `where: { id: { in: ids } }`.
6. **For `EXPLAIN ANALYZE`, the query planner, index theory, and pool sizing**, that is the
   database engine — see `../postgresdb/SKILL.md`. This skill stops at "here is the SQL Prisma
   emitted and how to make Prisma emit a better one".

```ts
// N+1 in disguise: looks like one call, but each iteration is a round trip
for (const u of users) {
  u.posts = await prisma.post.findMany({ where: { authorId: u.id } }); // N queries
}

// Fixed: load children with the parents in one query
const withPosts = await prisma.user.findMany({
  relationLoadStrategy: "join",
  select: { id: true, posts: { select: { id: true, title: true } } },
});
```

## Raw SQL safety matrix

| API | Parameterized? | Use |
| --- | --- | --- |
| `` $queryRaw`… ${x} …` `` (tagged template) | Yes | Default for ad-hoc reads with dynamic values |
| `` $executeRaw`… ${x} …` `` (tagged template) | Yes | Writes / DDL with dynamic values |
| `$queryRawTyped(...)` + `.sql` files | Yes + typed result | Reusable queries you want fully type-checked |
| `Prisma.sql` / `Prisma.join` | Yes (composed) | Building a parameterized fragment / `IN` list |
| `$queryRawUnsafe(string)` / `$executeRawUnsafe(string)` | **No** | Only with a fixed, non-user string (e.g. a known identifier you whitelisted) |

```ts
// Safe: values are bound as parameters, never concatenated
const rows = await prisma.$queryRaw`SELECT id FROM "User" WHERE email = ${email}`;

// Safe IN-list via Prisma.join
const ids = [1, 2, 3];
await prisma.$queryRaw`SELECT * FROM "Post" WHERE id IN (${Prisma.join(ids)})`;

// UNSAFE: interpolating user input into the *Unsafe API is SQL injection
const rows = await prisma.$queryRawUnsafe(`SELECT id FROM "User" WHERE email = '${email}'`);
```

Identifiers (table/column names) cannot be parameterized. If you must vary an identifier,
validate it against an allowlist before building the string — never pass user input straight
through.
