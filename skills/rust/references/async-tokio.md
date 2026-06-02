# Async on tokio

Depth behind SKILL.md's async section. tokio 1.x, edition 2024.

## Runtime model

A future is a state machine that does nothing until polled. `.await` yields control back to the
executor at each suspension point. `#[tokio::main]` expands to building a multi-thread runtime and
calling `block_on` on your `main` body:

```rust
#[tokio::main]                  // multi-thread runtime by default
async fn main() -> anyhow::Result<()> {
    // ... build state, serve ...
    Ok(())
}
```

For tests use `#[tokio::test]`; for a single-threaded runtime (e.g. `!Send` work) use
`#[tokio::main(flavor = "current_thread")]`.

## Structured concurrency with JoinSet

`JoinSet` owns its tasks and lets you bound and drain them — the antidote to a loop of bare
`tokio::spawn`:

```rust
use tokio::task::JoinSet;

async fn fetch_all(ids: Vec<i64>) -> anyhow::Result<Vec<Record>> {
    let mut set = JoinSet::new();
    for id in ids {
        set.spawn(async move { fetch_one(id).await });   // spawned task must be Send + 'static
    }
    let mut out = Vec::new();
    while let Some(joined) = set.join_next().await {
        out.push(joined??);          // first ? = JoinError (panic/cancel), second ? = task error
    }
    Ok(out)
}
```

To cap *in-flight* tasks (not just collect them), pair spawning with an `Arc<Semaphore>` and acquire a
permit before each spawn.

## select! and cancellation

`tokio::select!` polls several futures and runs the first to complete, dropping the rest. Wire a
cancellation token into one arm so a shutdown signal aborts the work:

```rust
use tokio_util::sync::CancellationToken;

async fn worker(token: CancellationToken) {
    loop {
        tokio::select! {
            _ = token.cancelled() => break,            // shutdown wins -> exit the loop
            item = next_item() => process(item).await, // otherwise keep working
        }
    }
}
```

Dropping a future cancels it at its current `.await` point — so make sure anything mid-flight is
either idempotent or transactional.

## Channels (tokio::sync)

- `mpsc` — many producers, one consumer. Bounded (`channel(n)`) gives backpressure; prefer it over
  unbounded. The default for a work queue.
- `oneshot` — a single value back from a spawned task.
- `broadcast` — fan a value out to many receivers.
- `watch` — latest-value observation (config reload, shutdown flags).

Prefer a channel over `Arc<Mutex<T>>` when the data flows one direction — it sidesteps the
lock-across-await trap entirely.

## spawn_blocking

The async worker threads are few; a blocking call on one starves every task scheduled there. Move
CPU-bound or synchronous-blocking work off the runtime:

```rust
let hash = tokio::task::spawn_blocking(move || bcrypt_hash(&password)).await?;
```

For long-lived dedicated threads (not request-scoped) use `std::thread` + a channel back into async.

## Send + Sync across await

A future is `Send` only if every value alive across an `.await` is `Send`. The classic failure:

```rust
// Bad: std Mutex guard is not Send; held across .await -> "future cannot be sent between threads safely".
let g = state.lock().unwrap();
remote_call().await;            // g still alive
g.update();

// Good: scope the guard so it is dropped before the await.
{ state.lock().unwrap().update(); }
remote_call().await;

// Or, when the lock must span the await, use tokio's async Mutex.
let mut g = async_state.lock().await;
g.update_after(remote_call().await);
```

`Rc`, `RefCell`, and raw pointers are not `Send` either — none of them survive an `.await` in a
spawned task. Use `Arc`/atomics instead.

## Bounded concurrency + jittered retry helper

Cancellation-aware, never retries a 4xx (client errors are not transient):

```rust
use std::time::Duration;
use rand::Rng;

async fn with_retry<F, Fut, T>(max: u32, mut op: F) -> anyhow::Result<T>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<T, AppError>>,
{
    let mut attempt = 0;
    loop {
        match op().await {
            Ok(v) => return Ok(v),
            Err(e) if e.is_client_error() => return Err(e.into()), // 4xx: do not retry
            Err(_) if attempt + 1 >= max => return Err(anyhow::anyhow!("exhausted {max} retries")),
            Err(_) => {
                let base = 50u64 << attempt;                       // exponential
                let jitter = rand::thread_rng().gen_range(0..base.max(1)); // full jitter
                tokio::time::sleep(Duration::from_millis(base + jitter)).await;
                attempt += 1;
            }
        }
    }
}
```

Wrap the whole thing in `tokio::time::timeout(dur, fut).await` to cap total wall time.
