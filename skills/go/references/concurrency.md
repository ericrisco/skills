# Go concurrency for services

Goroutines, channels, context, errgroup, sync primitives, pipelines, and leak/race
prevention - the depth behind the SKILL.md essentials. Go 1.22+.

## Contents

- [Mental model](#mental-model)
- [Context](#context)
- [Channels and select](#channels-and-select)
- [Goroutine leaks](#goroutine-leaks)
- [Worker pool](#worker-pool)
- [errgroup](#errgroup)
- [Retry with backoff](#retry-with-backoff)
- [Pipelines](#pipelines)
- [sync primitives](#sync-primitives)
- [Race detector](#race-detector)
- [Checklist](#checklist)

## Mental model

"Don't communicate by sharing memory; share memory by communicating." Prefer passing values
over channels (or returning them) to coordinating goroutines through shared mutable state.

Goroutines are cheap (a few KB of growable stack) but not free: each one is a scheduling
unit, a potential leak, and a source of races if it touches shared state. Start one only
when you have a reason and a guaranteed exit path.

Do NOT go concurrent when:

- The work is already fast and serial (premature parallelism adds bugs, not speed).
- I/O is naturally sequential (paginated APIs, ordered writes).
- The shared state is large and contended - the lock will erase the gains.

Reach for concurrency when work is independent, I/O-bound, and fans out (N HTTP calls, N
files, N rows to enrich). Measure before and after.

## Context

`context.Context` carries cancellation, deadlines, and request-scoped values down a call
chain. It is the first parameter of every blocking call. Always `defer cancel()` to release
the timer/goroutine the context spawns.

```go
ctx, cancel := context.WithTimeout(parent, 5*time.Second)
defer cancel()

ctx, cancel := context.WithCancel(parent)   // cancel when you decide
defer cancel()

ctx, cancel := context.WithDeadline(parent, t) // cancel at an absolute time
defer cancel()
```

Propagate `ctx` - never create `context.Background()` deep in a call chain; thread the
caller's context through so cancellation reaches the leaves.

`ctx.Err()` returns `context.Canceled` or `context.DeadlineExceeded`. Since Go 1.21,
`context.Cause(ctx)` returns the specific error passed to `WithCancelCause`, preserving why:

```go
ctx, cancel := context.WithCancelCause(parent)
cancel(fmt.Errorf("upstream 503: %w", ErrUnavailable))
// later, anywhere downstream:
if err := context.Cause(ctx); err != nil {
	slog.Error("cancelled", "cause", err) // the rich cause, not just "context canceled"
}
```

A context-aware fetch - the deadline propagates into the transport and aborts the dial/read:

```go
func fetchWithTimeout(ctx context.Context, url string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch %s: %w", url, err)
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}
```

## Channels and select

Use directional channel types in signatures to document intent and let the compiler enforce
it: `<-chan T` (receive-only), `chan<- T` (send-only).

```go
func produce(out chan<- int)  { /* only sends */ }
func consume(in <-chan int)   { /* only receives */ }
```

`select` multiplexes channel operations; a `default` case makes it non-blocking:

```go
select {
case v := <-in:
	handle(v)
case <-ctx.Done():
	return ctx.Err()
default:
	// nothing ready right now - do not block
}
```

**The sender closes a channel, never the receiver.** Closing signals "no more values".
Receiving from a closed channel yields the zero value with `ok == false`; `for range` over
a channel stops when it is closed.

```go
// Good: producer owns the channel and closes it; consumer ranges to completion.
func gen(nums ...int) <-chan int {
	out := make(chan int)
	go func() {
		defer close(out) // close exactly once, on the sender side
		for _, n := range nums {
			out <- n
		}
	}()
	return out
}

// Bad: closing from the receiver, or closing twice, panics.
func bad(out chan int) {
	close(out)
	close(out) // panic: close of closed channel
}
```

Channel operation behavior:

| Operation | nil channel | closed channel | open channel |
| --- | --- | --- | --- |
| Send `ch <- v` | blocks forever | panic | proceeds (or blocks until room) |
| Receive `<-ch` | blocks forever | returns zero, `ok=false` | proceeds (or blocks until value) |
| Close `close(ch)` | panic | panic | succeeds |

## Goroutine leaks

A goroutine that can never make progress and never returns is leaked: it holds its stack and
any captured references for the life of the process. **Every goroutine needs a guaranteed
exit.**

```go
// Bad: if the caller stops receiving after a cancel, this send blocks forever.
func leakyFetch(url string) <-chan []byte {
	ch := make(chan []byte) // unbuffered
	go func() {
		data, _ := fetch(url)
		ch <- data // no receiver -> goroutine parked forever
	}()
	return ch
}

// Good: buffer of 1 absorbs the send even if nobody reads; select honors cancel.
func safeFetch(ctx context.Context, url string) <-chan []byte {
	ch := make(chan []byte, 1)
	go func() {
		data, err := fetch(url)
		if err != nil {
			return
		}
		select {
		case ch <- data:
		case <-ctx.Done():
		}
	}()
	return ch
}
```

Detection in tests - assert the goroutine count is stable, or use `goleak`:

```go
func TestNoLeak(t *testing.T) {
	before := runtime.NumGoroutine()
	doWork()
	time.Sleep(10 * time.Millisecond) // let stragglers exit
	if after := runtime.NumGoroutine(); after > before {
		t.Errorf("leaked %d goroutines", after-before)
	}
}

// Preferred: go.uber.org/goleak, fails the test on any unexpected goroutine.
func TestMain(m *testing.M) { goleak.VerifyTestMain(m) }
// or per test: defer goleak.VerifyNone(t)
```

## Worker pool

Two idioms. Use the `errgroup` variant unless you need fine control.

**Modern - errgroup with a bounded limit and a preallocated result slice (no shared map):**

```go
func enrichAll(ctx context.Context, ids []string) ([]Record, error) {
	g, ctx := errgroup.WithContext(ctx)
	g.SetLimit(8) // at most 8 in flight
	results := make([]Record, len(ids))
	for i, id := range ids { // Go 1.22+: i, id are per-iteration; no capture dance
		g.Go(func() error {
			rec, err := enrich(ctx, id)
			if err != nil {
				return fmt.Errorf("enrich %s: %w", id, err)
			}
			results[i] = rec // each goroutine writes its own index - race-free
			return nil
		})
	}
	if err := g.Wait(); err != nil {
		return nil, err
	}
	return results, nil
}
```

**Raw - WaitGroup with jobs/results channels and a fixed worker count:**

```go
func runPool(jobs <-chan Job, results chan<- Result, workers int) {
	var wg sync.WaitGroup
	for range workers { // Go 1.22+: range over an int
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := range jobs { // exits when jobs is closed
				results <- process(j)
			}
		}()
	}
	wg.Wait()
	close(results) // close results only after all workers are done
}
```

The producer closes `jobs`; the pool closes `results` after `wg.Wait()`.

## errgroup

`errgroup.WithContext` returns a group and a derived context. The first goroutine to return
a non-nil error cancels that context, so siblings observing `ctx.Done()` stop early. `Wait`
returns that first error.

```go
func fetchAll(ctx context.Context, urls []string) ([][]byte, error) {
	g, ctx := errgroup.WithContext(ctx)
	g.SetLimit(16) // SetLimit doubles as a semaphore bounding concurrency
	out := make([][]byte, len(urls))
	for i, url := range urls {
		// Go 1.22+: the stale `i, url := i, url` capture is no longer needed - delete it.
		g.Go(func() error {
			b, err := fetchWithTimeout(ctx, url)
			if err != nil {
				return fmt.Errorf("url %d: %w", i, err)
			}
			out[i] = b
			return nil
		})
	}
	if err := g.Wait(); err != nil {
		return nil, err // out is partially filled; discard it
	}
	return out, nil
}
```

Collect indexed results into a preallocated slice (`out[i]`), never a shared `map` written
from multiple goroutines - that is a data race the `-race` detector will flag.

## Retry with backoff

Resilient upstream calls retry transient failures with exponential backoff plus jitter, honor
the context deadline, and stop early on errors that will never succeed (4xx, validation,
auth). A `retryIf` guard keeps the policy explicit: retry only what is genuinely transient.

```go
type RetryOptions struct {
	MaxAttempts int                    // total tries, including the first; <=0 means 1
	BaseDelay   time.Duration          // first backoff step (e.g. 100ms)
	MaxDelay    time.Duration          // cap per-attempt sleep (e.g. 5s)
	RetryIf     func(error) bool       // return false to stop retrying immediately
}

func DefaultRetryOptions() RetryOptions {
	return RetryOptions{
		MaxAttempts: 4,
		BaseDelay:   100 * time.Millisecond,
		MaxDelay:    5 * time.Second,
		RetryIf:     func(error) bool { return true },
	}
}

// withRetry calls fn until it succeeds, RetryIf rejects the error, attempts run out, or ctx
// is done. Backoff is exponential (BaseDelay * 2^n) capped at MaxDelay, with full jitter to
// avoid thundering-herd synchronization across callers.
func withRetry(ctx context.Context, fn func(ctx context.Context) error, opts RetryOptions) error {
	if opts.MaxAttempts <= 0 {
		opts.MaxAttempts = 1
	}
	if opts.RetryIf == nil {
		opts.RetryIf = func(error) bool { return true }
	}

	var err error
	for attempt := 0; attempt < opts.MaxAttempts; attempt++ {
		if err = fn(ctx); err == nil {
			return nil
		}
		// Stop immediately on non-retryable errors and on context cancellation.
		if !opts.RetryIf(err) || ctx.Err() != nil {
			return err
		}
		if attempt == opts.MaxAttempts-1 {
			break // last attempt: do not sleep, just return the error
		}

		// Exponential backoff capped at MaxDelay, then full jitter in [0, backoff].
		backoff := opts.BaseDelay << attempt // BaseDelay * 2^attempt
		if backoff <= 0 || backoff > opts.MaxDelay {
			backoff = opts.MaxDelay
		}
		delay := time.Duration(rand.Int63n(int64(backoff) + 1))

		timer := time.NewTimer(delay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return fmt.Errorf("retry aborted: %w", ctx.Err())
		case <-timer.C:
		}
	}
	return fmt.Errorf("after %d attempts: %w", opts.MaxAttempts, err)
}
```

The `retryIf` guard is the important half: **never retry a 4xx**. Retrying a `400`/`401`/`403`
wastes the budget and can amplify load during an incident. Retry only timeouts, `5xx`, and
connection failures:

```go
// HTTPStatusError carries the status so retryIf can classify without string-matching.
type HTTPStatusError struct{ Code int }

func (e *HTTPStatusError) Error() string { return fmt.Sprintf("http status %d", e.Code) }

func isTransient(err error) bool {
	if errors.Is(err, context.Canceled) {
		return false // caller gave up; do not retry
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return true // a per-attempt timeout is worth another shot within the outer budget
	}
	var se *HTTPStatusError
	if errors.As(err, &se) {
		return se.Code == http.StatusTooManyRequests || se.Code >= 500 // 429 + 5xx only
	}
	return true // unknown (e.g. dial/reset) errors are treated as transient
}

func fetchUser(ctx context.Context, id string) (*User, error) {
	var u *User
	err := withRetry(ctx, func(ctx context.Context) error {
		got, err := callUpstream(ctx, id) // wraps non-2xx as *HTTPStatusError
		if err != nil {
			return err
		}
		u = got
		return nil
	}, RetryOptions{MaxAttempts: 4, BaseDelay: 100 * time.Millisecond, MaxDelay: 2 * time.Second, RetryIf: isTransient})
	return u, err
}
```

Pair retries with a per-attempt timeout (set inside `fn` via `context.WithTimeout`) and an
overall budget on the outer `ctx`, so a slow upstream cannot stretch one call indefinitely.
`math/rand` jitter is fine here; it is timing, not a security boundary.

## Pipelines

Compose stages where each stage reads from an input channel, processes, and writes to an
output channel it owns and closes. Stages select on `ctx.Done()` so a cancel drains the
whole pipeline. Fan-out runs N copies of a stage; fan-in merges their outputs.

```go
func gen(ctx context.Context, nums ...int) <-chan int {
	out := make(chan int)
	go func() {
		defer close(out)
		for _, n := range nums {
			select {
			case out <- n:
			case <-ctx.Done():
				return
			}
		}
	}()
	return out
}

func square(ctx context.Context, in <-chan int) <-chan int {
	out := make(chan int)
	go func() {
		defer close(out)
		for n := range in {
			select {
			case out <- n * n:
			case <-ctx.Done():
				return
			}
		}
	}()
	return out
}

func sum(in <-chan int) int {
	total := 0
	for n := range in { // drains until the upstream stage closes
		total += n
	}
	return total
}

// Wire: gen -> square -> sum.
func pipeline(ctx context.Context) int {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	return sum(square(ctx, gen(ctx, 1, 2, 3, 4)))
}
```

## sync primitives

`sync.Mutex` / `sync.RWMutex` - the zero value is an unlocked mutex (useful zero value).
**Never copy a mutex after first use** (copies a partial lock state); `go vet` catches this.
`RWMutex` lets many readers or one writer - use it only when reads dominate.

```go
type Cache struct {
	mu sync.RWMutex
	m  map[string]string
}

func (c *Cache) Get(k string) (string, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	v, ok := c.m[k]
	return v, ok
}
```

`sync.Once` - run an initializer exactly once, even under concurrent access:

```go
var (
	once   sync.Once
	client *http.Client
)

func getClient() *http.Client {
	once.Do(func() { client = &http.Client{Timeout: 10 * time.Second} })
	return client
}
```

`sync.WaitGroup` - wait for a known set of goroutines (`Add` before the `go`, `Done` in a
`defer`, `Wait` after).

`sync/atomic` - lock-free counters and flags; the typed wrappers are the modern API:

```go
var hits atomic.Int64
hits.Add(1)
n := hits.Load()
```

`sync.Pool` - reuse short-lived allocations under load. **Reset on Put**, or you leak stale
data into the next user:

```go
var bufPool = sync.Pool{New: func() any { return new(bytes.Buffer) }}

func use() {
	b := bufPool.Get().(*bytes.Buffer)
	defer func() { b.Reset(); bufPool.Put(b) }() // reset before returning to the pool
	b.WriteString("work")
}
```

`golang.org/x/sync/singleflight` - collapse duplicate concurrent calls for the same key into
one execution (cache stampede protection):

```go
var g singleflight.Group

func getConfig(ctx context.Context, key string) (*Config, error) {
	v, err, _ := g.Do(key, func() (any, error) {
		return loadConfig(ctx, key) // runs once; concurrent callers share the result
	})
	if err != nil {
		return nil, err
	}
	return v.(*Config), nil
}
```

## Race detector

A data race is concurrent access to the same memory where at least one access is a write and
there is no synchronization. The behavior is undefined - the program may crash, corrupt data,
or pass tests by luck.

```go
// Bad: N goroutines write n with no synchronization.
func racy() int {
	n := 0
	var wg sync.WaitGroup
	for range 100 {
		wg.Add(1)
		go func() { defer wg.Done(); n++ }() // data race
	}
	wg.Wait()
	return n // not reliably 100
}

// Good: atomic makes the increment indivisible.
func safe() int64 {
	var n atomic.Int64
	var wg sync.WaitGroup
	for range 100 {
		wg.Add(1)
		go func() { defer wg.Done(); n.Add(1) }()
	}
	wg.Wait()
	return n.Load() // 100
}
```

Run `go test -race ./...`. The detector instruments memory accesses and reports races on the
code paths your tests actually exercise - it cannot find races in unexercised code, so cover
your concurrent paths. **Make `-race` a mandatory CI gate.** It needs a C toolchain (cgo).

## Checklist

Before merging anything concurrent, confirm:

- Bounded? Concurrency is capped (`errgroup.SetLimit`, a worker count, or a semaphore).
- Cancellable? Every goroutine selects on `ctx.Done()` or reads a channel that gets closed.
- Who closes? Exactly one owner closes each channel, on the sender side, exactly once.
- Buffered to avoid a leak? Sends that may outlive their receiver use a buffer + select.
- `-race` green? CI runs `go test -race ./...` and it passes.
