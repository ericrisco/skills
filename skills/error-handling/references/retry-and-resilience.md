# Retry & resilience — code per language

Companion to Steps 1–3 of `../SKILL.md`. Full-jitter math, `withRetry` in four
stacks, the idempotency-key recipe, error-class skeletons, and the circuit-breaker
config matrix. Versions verified 2026-06-02.

## Full jitter

```text
delay = random_between(0, min(cap, base * 2 ** attempt))
```

Full jitter (random over the whole `[0, ceiling]` window) spreads retrying clients
across time better than fixed backoff or equal jitter (`half + random(half)`),
which still clusters. Source: AWS Builders' Library, "Timeouts, retries and
backoff with jitter".

Budget targets: 3–5 attempts, base 100–200ms ×2 per attempt, per-delay cap
10–30s, total budget 10–60s.

## Error-class skeletons

```python
# Python — stable code + preserved cause via `raise ... from`.
class AppError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        super().__init__(message)

class ProviderDown(AppError):
    def __init__(self, cause: Exception):
        super().__init__("provider_down", "upstream unavailable")
        # `from cause` keeps __cause__ for the traceback
try:
    charge()
except TimeoutError as e:
    raise ProviderDown(e) from e
```

```java
// Java — typed cause via the Throwable(message, cause) constructor.
public final class ProviderDownException extends RuntimeException {
    public ProviderDownException(Throwable cause) {
        super("provider_down", cause); // cause survives in the stack trace
    }
}
```

```go
// Go — sentinel + %w wrapping; classify with errors.Is / errors.As.
var ErrProviderDown = errors.New("provider_down")
if err != nil {
    return fmt.Errorf("charging customer: %w", errors.Join(ErrProviderDown, err))
}
// caller: if errors.Is(err, ErrProviderDown) { ... }
```

## withRetry per language

```python
# Python — tenacity. Retry only transient; cap; full jitter; per-attempt timeout.
from tenacity import (retry, stop_after_attempt, wait_random,
                      retry_if_exception_type)
import httpx

@retry(
    retry=retry_if_exception_type((httpx.TimeoutException, httpx.ConnectError)),
    wait=wait_random(0, 10),          # full jitter, 10s ceiling
    stop=stop_after_attempt(4),
    reraise=True,
)
def fetch(client: httpx.Client, url: str):
    return client.get(url, timeout=2.0)  # per-attempt timeout FIRST
```

```java
// Java — Resilience4j 2.2.0: Retry + TimeLimiter + CircuitBreaker composed.
RetryConfig retry = RetryConfig.custom()
    .maxAttempts(4)
    .intervalFunction(IntervalFunction.ofExponentialRandomBackoff(
        Duration.ofMillis(150), 2.0, 0.5)) // base, multiplier, jitter factor
    .retryOnException(e -> e instanceof IOException) // transient only
    .build();
```

```csharp
// .NET — Polly 8.6.5 resilience pipeline: timeout → retry → circuit breaker.
var pipeline = new ResiliencePipelineBuilder()
    .AddRetry(new RetryStrategyOptions {
        MaxRetryAttempts = 4,
        BackoffType = DelayBackoffType.Exponential,
        UseJitter = true,                         // full jitter
        Delay = TimeSpan.FromMilliseconds(150),
        ShouldHandle = new PredicateBuilder().Handle<HttpRequestException>(),
    })
    .AddTimeout(TimeSpan.FromSeconds(2))          // per-attempt timeout
    .Build();
```

## Idempotency-key recipe

Required before retrying any mutation. The key design itself is `../../api-design/SKILL.md`;
this is the minimal client+server contract.

```ts
// Client — generate ONE key per logical operation, reuse it across retries.
const key = crypto.randomUUID();
await withRetry(() =>
  fetch("/charges", {
    method: "POST",
    headers: { "Idempotency-Key": key, "content-type": "application/json" },
    body: JSON.stringify({ cents: 500 }),
  }),
);
```

```sql
-- Server — dedupe with a UNIQUE constraint; second arrival returns the first result.
CREATE TABLE idempotency (
  key        text PRIMARY KEY,
  response   jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
-- on insert conflict, return the stored response instead of charging again.
```

## Circuit-breaker config matrix

| Profile | Trip threshold | Window | Open duration | Use for |
|---|---|---|---|---|
| Critical | ~30% failures | ~20 reqs | 30s | payments, auth — fail fast |
| Default | ~50% failures | ~20 reqs | 30–60s | most downstream calls |
| Tolerant | ~70% failures | ~20 reqs | 60s | best-effort enrichment, analytics |

```ts
// Node — Opossum (promise-based). Defaults: timeout 3000ms,
// errorThresholdPercentage 50, resetTimeout 30000ms.
import CircuitBreaker from "opossum";

const breaker = new CircuitBreaker(callProvider, {
  timeout: 2000,                 // per-call timeout
  errorThresholdPercentage: 50,  // trip at 50% over the rolling window
  resetTimeout: 30000,           // Open → Half-Open after 30s
});
breaker.fallback(() => ({ status: "degraded" })); // graceful degradation
```

## Bulkhead sizing

Give each downstream its own bounded pool (connections, or a semaphore /
worker queue). Size = expected concurrency + small headroom, never unbounded.
The point: a downstream that saturates its own pool cannot starve the others.
Resilience4j ships `Bulkhead`; in Node, a bounded `p-limit` queue per dependency
is the equivalent.
