# synctest & concurrency

Deterministic tests for goroutines, timers, and `context` deadlines, plus the race detector and leak detection. Target Go 1.25.

## The bubble model

`synctest.Test(t, func(t *testing.T){ ... })` runs the body inside an isolated **bubble**:

- The bubble has its own **fake clock**, starting at a fixed instant. `time.Now`, `time.Sleep`, `time.After`, `time.NewTimer`, `time.NewTicker`, and `context` deadlines inside the bubble all read this fake clock.
- The fake clock **does not tick on its own**. It only advances when every goroutine in the bubble is **durably blocked** — at which point it jumps forward to the next scheduled timer instantly. A test of a one-hour timeout therefore finishes in microseconds.
- Goroutines started inside the bubble belong to the bubble. The bubble is done when all of them exit.

```go
func TestRetryBackoff(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		start := time.Now()
		err := retry(t.Context(), 3, time.Second, alwaysFail)
		elapsed := time.Since(start) // fake-clock elapsed, computed instantly
		if !errors.Is(err, errExhausted) {
			t.Fatalf("err = %v", err)
		}
		if elapsed != 3*time.Second { // 1s + 2s backoff, deterministic
			t.Errorf("elapsed = %v, want 3s", elapsed)
		}
	})
}
```

## Durably blocked — the exact definition

A goroutine is **durably blocked** when it is blocked and can only be unblocked by another goroutine in the same bubble. That covers: receiving/sending on a bubble channel with no ready counterpart, `select` with no ready case, `sync.WaitGroup.Wait`, `sync.Mutex.Lock` contention, and `time.Sleep`.

It does **not** cover blocking on something outside the bubble: a real network read, a system call, a channel shared with a goroutine started before the bubble. If a bubble goroutine blocks on the outside world, the fake clock will not advance and the test hangs. Keep all I/O inside the bubble fake, or out of the synctest body entirely.

## synctest.Wait()

`synctest.Wait()` blocks the calling goroutine until every **other** goroutine in the bubble is durably blocked. Use it to reach a known quiescent point before asserting:

```go
go worker(ch)
ch <- job
synctest.Wait()        // worker has processed and is now blocked waiting again
if got := metrics.Load(); got != 1 {
	t.Errorf("processed = %d, want 1", got)
}
```

Without `Wait()` you would race the assertion against the worker.

## Race detector

Run anything concurrent with `-race`:

```bash
go test -race ./...
go test -race -run TestRetryBackoff -count=10 ./internal/retry
```

`-count=10` re-runs to flush out order-dependent flakiness. The race detector instruments memory access; it roughly doubles runtime and memory, so it lives in CI and in targeted local runs, not necessarily every `go test`. A clean `-race` run is not a proof of correctness, but a failing one is always a real bug.

## Goroutine-leak detection

A test that starts a goroutine and returns before it exits leaks it. Two approaches:

- Inside a synctest bubble, a leak surfaces naturally: the bubble blocks waiting for the stray goroutine, and the fake clock cannot advance, so the test hangs or the leak is obvious.
- Outside synctest, use `go.uber.org/goleak`:

```go
func TestMain(m *testing.M) {
	goleak.VerifyTestMain(m)
}
```

This fails the run if any unexpected goroutine survives the suite. Prefer `t.Cleanup` to cancel contexts and `synctest.Wait` to drain workers so you never leak in the first place.

## Migration: GOEXPERIMENT → GA

- **Go 1.24**: `testing/synctest` shipped behind `GOEXPERIMENT=synctest`, exposing only `synctest.Run(func(){...})`.
- **Go 1.25**: GA, no build flag. The preferred entry point is `synctest.Test(t, func(t *testing.T){...})`, which takes `*testing.T` and integrates with subtests and cleanup.
- **Go 1.26**: `synctest.Run` is deprecated. Migrate `Run(func(){...})` calls to `Test(t, func(t *testing.T){...})` and use the passed `t` for assertions instead of capturing the outer one.

If you see `GOEXPERIMENT=synctest` in a Makefile or CI config and the module is on 1.25+, delete the flag.
