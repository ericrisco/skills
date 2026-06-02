# Virtual threads & structured concurrency (deep)

Targets Java 21+ (virtual threads standard), Java 25 LTS for `ScopedValue` (JEP 506, final)
and `StructuredTaskScope` (JEP 505, still **preview** — needs `--enable-preview`).

## Why virtual threads change the model

A virtual thread is an ordinary `java.lang.Thread` scheduled by the JVM onto a small pool of
platform "carrier" threads. When it blocks on I/O, the JVM unmounts it and frees the carrier.
Millions can exist. The consequence: **the thread-per-request model is fast again** — you no
longer need reactive callbacks or hand-tuned pools to scale blocking I/O.

The rules:

- **One task, one virtual thread.** Submit each unit of work; do not pool virtual threads.
- **Never size them to cores.** Cores matter for CPU work, which stays on platform threads.
- **Use them for blocking calls** (JDBC, HTTP, file, RPC) — not for tight CPU loops.

## Executor wiring

```java
try (var exec = Executors.newVirtualThreadPerTaskExecutor()) {
    for (var task : tasks) exec.submit(task);
} // close() blocks until every submitted task completes
```

A single `Thread.ofVirtual().start(r)` is fine for a one-off; the executor is for fan-out.
`Thread.ofVirtual().name("worker-", 0).factory()` gives a named factory for diagnostics.

## Pinning: the JEP 491 change

Before JDK 24, a virtual thread inside a `synchronized` block **pinned** its carrier — it could
not unmount, so heavy `synchronized` I/O code starved the carrier pool. **JEP 491 (JDK 24)
removed this**: virtual threads no longer pin on `synchronized`. Two consequences:

- Legacy `synchronized` code runs correctly on Loom now without rewriting to locks.
- For **long** holds still prefer `ReentrantLock` — it offers `tryLock`, fairness, and
  interruptible acquisition that `synchronized` does not.

Diagnose remaining pinning (native frames, some JNI):

```bash
# JFR event jdk.VirtualThreadPinned fires on every pin; record and inspect.
java -XX:StartFlightRecording=filename=app.jfr,settings=profile -jar app.jar
jfr print --events jdk.VirtualThreadPinned app.jfr
```

## Structured concurrency (preview in 25)

`StructuredTaskScope` binds subtasks to a lexical scope: fork children, join, then the scope
guarantees all children finish or are cancelled before it closes. One failure cancels siblings.

```java
// Requires --enable-preview on Java 25 (JEP 505).
// Joiner.awaitAllSuccessfulOrThrow(): all must succeed, else the first failure cancels the rest.
import java.util.concurrent.StructuredTaskScope;

UserPage load(String id) throws Exception {
    try (var scope = StructuredTaskScope.open()) {           // 25-era API
        var user  = scope.fork(() -> fetchUser(id));
        var orders= scope.fork(() -> fetchOrders(id));
        scope.join();                                        // wait for both
        return new UserPage(user.get(), orders.get());
    }
}
```

The two canonical policies:

- **All-success-or-fail** (fan-out where you need every result): first failure cancels siblings.
- **Any-success** (race / hedged requests): first success cancels the slower siblings.

Note: the exact joiner/factory names have shifted across the five previews. When you write this,
confirm against the JDK you target (`java --enable-preview`) rather than trusting a fixed name.
If you cannot enable preview, `ExecutorService` + `invokeAll`/`Future` on virtual threads gives
most of the value without the lifecycle guarantees.

## ScopedValue (final in 25) replaces ThreadLocal

`ThreadLocal` is mutable, must be cleaned up (`remove()`), and its per-thread copies leak across
millions of virtual threads. `ScopedValue` is **immutable** and bound only for the dynamic extent
of a `run`/`call`, so it auto-unbinds and propagates into forked subtasks.

```java
private static final ScopedValue<RequestCtx> CTX = ScopedValue.newInstance();

ScopedValue.where(CTX, ctx).run(() -> handle(req));   // CTX.get() anywhere in the call tree
// Rebind for a nested extent:
ScopedValue.where(CTX, child).run(() -> deeper());    // outer binding restored on return
```

Migration: a `ThreadLocal<T>` field set at the top of a request becomes a `ScopedValue<T>` bound
once around the request body; every `tl.get()` becomes `sv.get()`; delete every `tl.remove()`.

## CompletableFuture vs structured

`CompletableFuture` composes async stages (`thenApply`, `thenCompose`) but has no scope: a leaked
stage runs on. Prefer structured concurrency (or a virtual-thread executor with try-with-resources)
for request-scoped fan-out so cancellation and lifetime are guaranteed. Keep `CompletableFuture`
for pipeline-style composition where you genuinely want detached, chained stages.

## When platform threads still win

- **CPU-bound** work (parsing, compression, math): a `newFixedThreadPool(cores)` is correct;
  virtual threads add no parallelism for compute.
- **Throttling a scarce resource**: cap concurrency with a `Semaphore` acquired inside each
  virtual task, not by shrinking a pool.
- **FFI / JNI** that pins for long stretches: measure; keep it on a bounded platform pool.
