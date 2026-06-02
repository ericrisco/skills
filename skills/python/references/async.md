# Async (language level) — deep dive

Read when the SKILL.md async section is not enough: the runtime model, structured concurrency,
timeouts, cancellation discipline, queues, sync<->async bridging, and the IO-bound vs CPU-bound
decision. HTTP servers are out of scope here -> `fastapi`.

## Runtime model

One event loop per thread runs coroutines cooperatively: a coroutine runs until it `await`s,
which yields control back to the loop. `asyncio.run(main())` creates the loop, runs the top
coroutine to completion, and tears the loop down — call it **once**, at the program entry point.
Never create nested loops or call `asyncio.run` from inside a running loop.

A coroutine only makes progress at `await` points. A blocking call (`time.sleep`, a sync DB
driver, heavy CPU) between awaits freezes the *entire* loop, including unrelated tasks.

## Structured concurrency: TaskGroup vs gather

`asyncio.TaskGroup` (3.11+) is the default for running tasks concurrently. Its contract:

- Tasks created via `tg.create_task(...)` are all awaited at the end of the `async with` block.
- If any task raises, the remaining tasks are **cancelled**, and the errors surface as an
  `ExceptionGroup` (handle with `except*`).
- No task outlives the block — there is no leak window.

```python
import asyncio

async def fetch_all(ids: list[int]) -> list[bytes]:
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(fetch(i)) for i in ids]
    return [t.result() for t in tasks]   # reached only if all succeeded

async def fetch_all_handled(ids: list[int]) -> list[bytes]:
    try:
        return await fetch_all(ids)
    except* ConnectionError as eg:
        for exc in eg.exceptions:        # ExceptionGroup members
            log.warning("fetch failed: %s", exc)
        return []
```

`asyncio.gather` has no sibling cancellation: on first failure the other tasks keep running
detached. Reserve `gather(..., return_exceptions=True)` only for the deliberate "run all, collect
every result-or-error" case where partial failure is acceptable and you process the list yourself.

## Timeouts

Bound every wait. `asyncio.timeout` (3.11+) is a context manager; on expiry it cancels the body
and raises `TimeoutError`:

```python
async def with_deadline() -> bytes:
    async with asyncio.timeout(5.0):
        return await slow_fetch()

# Or wrap a single coroutine:
result = await asyncio.wait_for(slow_fetch(), timeout=5.0)
```

`asyncio.timeout_at(loop.time() + 5)` for an absolute deadline you thread through nested calls.

## Cancellation discipline

Cancellation is delivered as `CancelledError` raised at the current `await`. The rule:
**clean up, then re-raise** — never swallow it, or you break cancellation for the whole tree.

```python
async def worker(q: asyncio.Queue[int]) -> None:
    try:
        while True:
            item = await q.get()
            await handle(item)
    except asyncio.CancelledError:
        await flush()        # cleanup is fine
        raise                # MUST re-raise
```

If you must run shielded cleanup that itself awaits, use `asyncio.shield(...)` sparingly — it is
easy to leak with. Prefer making cleanup synchronous or fast.

## Queues

`asyncio.Queue` is the producer/consumer hand-off; `maxsize` applies backpressure.

```python
async def pipeline(items: list[int]) -> None:
    q: asyncio.Queue[int] = asyncio.Queue(maxsize=10)

    async def producer() -> None:
        for it in items:
            await q.put(it)        # blocks when full -> backpressure

    async def consumer() -> None:
        while True:
            it = await q.get()
            try:
                await handle(it)
            finally:
                q.task_done()

    async with asyncio.TaskGroup() as tg:
        tg.create_task(producer())
        c = tg.create_task(consumer())
        await q.join()             # wait until every put is task_done()'d
        c.cancel()                 # then stop the consumer
```

## Bridging sync and async

- **Run a blocking call without freezing the loop**: `await asyncio.to_thread(blocking_fn, arg)`
  offloads it to a thread pool. Use for sync IO (a legacy DB driver, a `requests` call).
- **CPU-bound work**: a thread does not help (the GIL serializes it on a non-free-threaded build).
  Use `loop.run_in_executor(ProcessPoolExecutor(), cpu_fn, arg)` to use real parallelism.
- **Call async from sync** only at a top boundary via `asyncio.run`; do not block on a coroutine
  from inside a running loop.

## IO-bound vs CPU-bound

| Workload | Right tool |
| --- | --- |
| Many network/disk waits | `asyncio` + `TaskGroup` (this skill) |
| One blocking sync call inside async | `asyncio.to_thread` |
| CPU-heavy (parse, compress, math) | `ProcessPoolExecutor` (real parallelism) |
| CPU-heavy, 3.14 free-threaded build | threads (PEP 703 build removes the GIL; ~5–10% single-thread cost) |

Async buys you *concurrency for waiting*, not *parallelism for computing*. If your bottleneck is
CPU, `asyncio` will not speed it up — reach for processes (or the 3.14 free-threaded interpreter).

## Common pitfalls

- A coroutine you never `await` (or never wrap in a task) silently does nothing — "coroutine was
  never awaited" warning.
- `await`ing inside a lock you also need elsewhere can deadlock; keep critical sections short.
- Mixing `time.sleep` into a coroutine (use `asyncio.sleep`).
- Forgetting `task_done()` so `queue.join()` never returns.
