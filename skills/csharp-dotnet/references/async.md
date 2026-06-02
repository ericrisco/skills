# async/await in .NET — full catalog

The body has the rules; this is the depth. Read before any non-trivial async review.

## Task vs ValueTask

- Default to `Task`/`Task<T>`. It composes everywhere and is hard to misuse.
- `ValueTask<T>` avoids an allocation when the method usually completes synchronously
  (a cache hit, a buffered read). Constraints: **await it exactly once**, never block on
  it, never store it. Convert with `.AsTask()` if you need to await twice or `WhenAll` it.

```csharp
// Good: hot path that is usually a cache hit
public ValueTask<User> GetAsync(int id, CancellationToken ct) =>
    _cache.TryGetValue(id, out var u) ? new ValueTask<User>(u) : new ValueTask<User>(LoadAsync(id, ct));
```

## ConfigureAwait

- **Libraries**: `ConfigureAwait(false)` on every await. Why: do not capture and force a
  resumption context onto callers; avoids deadlocks if a caller blocks.
- **ASP.NET Core app code**: there is no `SynchronizationContext`, so `ConfigureAwait`
  is a no-op — do not litter app code with it. The deadlock risk comes from *blocking*,
  not from omitting `ConfigureAwait`.

## CancellationToken propagation

Flow one token from the entry point through every async call. Pass it last by convention.

```csharp
public async Task<Report> BuildAsync(int id, CancellationToken ct)
{
    var data = await _repo.LoadAsync(id, ct);          // DB
    var enriched = await _http.GetAsync(data.Url, ct); // outbound HTTP
    ct.ThrowIfCancellationRequested();                 // explicit check before expensive CPU work
    return Render(enriched);
}
```

`CancellationToken.None` is the explicit "this genuinely cannot be cancelled" signal —
use it deliberately, never as a shortcut to avoid plumbing.

## Deadlock catalog

| Trigger | Mechanism | Fix |
|---|---|---|
| `.Result` / `.Wait()` blocking on async | Thread blocks waiting for a continuation that needs that thread (classic context deadlock) or starves the thread pool under load | `await` |
| `Task.Run` to "make sync code async" then await | Burns a thread pool thread for I/O-bound work | Use a truly async API |
| Sync-over-async deep in a call chain | One blocking call poisons the whole request | Make the whole chain async |

The symptom users report: "my web request hangs / the app freezes under load." It is
almost always a blocking call on an async method. Search for `.Result`, `.Wait(`,
`.GetAwaiter().GetResult()`.

## IAsyncEnumerable

Stream rows instead of materializing a giant `List<T>`:

```csharp
public async IAsyncEnumerable<OrderRow> StreamAsync([EnumeratorCancellation] CancellationToken ct)
{
    await foreach (var o in _db.Orders.AsAsyncEnumerable().WithCancellation(ct))
        yield return new OrderRow(o.Id, o.Total);
}
```

`[EnumeratorCancellation]` lets `await foreach (... .WithCancellation(ct))` flow the token in.

## Parallelism

- **Independent awaits**: `await Task.WhenAll(a, b, c)` — runs concurrently, surfaces the
  first exception (inspect `Task.Exception` for all).
- **Bounded concurrency over a collection**: `Parallel.ForEachAsync` with
  `MaxDegreeOfParallelism`. Do not fire 10k tasks at once.
- **Producer/consumer pipelines**: `System.Threading.Channels` (`Channel<T>`).
- **Synchronization** (C# 13+): use the `System.Threading.Lock` type instead of locking
  on an arbitrary `object`; it has a clearer `EnterScope()` API and better diagnostics.

```csharp
private readonly System.Threading.Lock _gate = new();   // C# 13+
public void Touch() { lock (_gate) { _count++; } }
```
