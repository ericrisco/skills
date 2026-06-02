# EF Core 10 — full catalog

The body has the rules; this is the depth. Raw DB schema/index tuning is `postgresdb`.

## DbContext lifetime

- Register with `AddDbContext<T>` — **scoped** (one per request). It is not thread-safe.
- Never share a `DbContext` across concurrent awaits or background threads. For parallel
  work, create a context per unit via `IDbContextFactory<T>` (`AddDbContextFactory`).
- For short-lived background jobs, resolve a fresh scope and a fresh context per job.

```csharp
builder.Services.AddDbContext<ShopDb>(o => o.UseNpgsql(cs));
// parallel/background work:
builder.Services.AddDbContextFactory<ShopDb>(o => o.UseNpgsql(cs));
```

## Query patterns

```csharp
// Read path: no tracking, project straight to a DTO (selects only needed columns).
var rows = await db.Orders.AsNoTracking()
    .Where(o => o.Status == OrderStatus.Open)
    .Select(o => new OrderRow(o.Id, o.Customer.Name, o.Lines.Count))
    .ToListAsync(ct);

// Write path: tracked entity, mutate, SaveChangesAsync with the token.
var order = await db.Orders.FindAsync([id], ct);
order!.Status = OrderStatus.Closed;
await db.SaveChangesAsync(ct);
```

- `AsNoTracking()` on every read-only query — drops change-tracking memory/CPU.
- Use the async query operators (`ToListAsync`, `FirstOrDefaultAsync`, `AnyAsync`,
  `SaveChangesAsync`) and flow the token into all of them.
- Projection (`Select` to a DTO) is usually better than loading whole entities: less data
  over the wire, no accidental over-fetch.

## Tracking and N+1

The N+1 trap: load a list, then touch a navigation property inside a loop — EF issues one
extra query per row. Symptom: "my page does hundreds of tiny queries."

```csharp
// Bad: N+1
var orders = await db.Orders.ToListAsync(ct);
foreach (var o in orders) { var c = o.Customer.Name; } // one query per order

// Good: projection (single JOIN) or Include
var orders = await db.Orders.Include(o => o.Customer).ToListAsync(ct);
```

Use `AsSplitQuery()` when a single query with multiple collection `Include`s causes a
cartesian-product explosion (rows multiply across joins). Trade-off: more round-trips,
smaller result sets.

## Migrations workflow

```bash
dotnet ef migrations add AddProductPrice -p Shop.Api
# review the generated Up()/Down() — they are real code you ship
dotnet ef database update -p Shop.Api
dotnet ef migrations script --idempotent -o migrate.sql   # for controlled prod deploys
```

- Always review the generated migration before applying. EF guesses; you confirm.
- Never hand-edit a migration that has already been applied to any shared environment —
  add a new one.
- For production, prefer an idempotent SQL script run by your deploy pipeline over
  `database update` at app startup. Deploy mechanics are `deployment`.

## EF Core 10 highlights

- **Native `json` column type** — map a property to a real JSON column with first-class
  querying, instead of serializing to a string manually.
- **`vector` type + `VECTOR_DISTANCE()`** — store embeddings and run similarity search in
  the database for RAG/semantic features (provider support required).
- **`LeftJoin` / `RightJoin` LINQ operators** — express outer joins directly instead of
  the old `GroupJoin` + `SelectMany` + `DefaultIfEmpty` dance.
- **Named query filters** — multiple global query filters per entity, each named so you
  can selectively disable one (e.g. ignore soft-delete but keep tenant filter) via
  `IgnoreQueryFilters([...])`.

## Raw SQL safety

Use only parameterized interpolation — EF turns the holes into parameters:

```csharp
// Good: parameterized, injection-safe
var products = await db.Products
    .FromSql($"SELECT * FROM products WHERE name = {name}")   // {name} becomes a parameter
    .ToListAsync(ct);
```

Never `FromSqlRaw($"... WHERE name = '{name}'")` with string interpolation/concatenation —
that is SQL injection. Reserve raw SQL for cases LINQ cannot express; otherwise stay in LINQ.
