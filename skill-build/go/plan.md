# IMPLEMENTATION PLAN — skill `go` (Idiomatic Go services)

This is a **writing plan**. Follow it verbatim. No further design decisions are
required. The source of truth is `skill-build/go/spec.md`; this plan operationalizes it.

Target versions to state explicitly everywhere relevant: **Go 1.22+ (assume 1.23/1.24
stable available)**, `net/http` with Go 1.22 enhanced routing, `log/slog`, `errors.Join`
(1.20+), `context.Cause` (1.21), fixed loopvar (1.22 — no `tt := tt`),
`golang.org/x/sync/errgroup`, optional `github.com/go-chi/chi/v5`, PostgreSQL 16 / `pgx v5`.
Tooling: `staticcheck` (honnef.co/go/tools), `golangci-lint` v1.6x, `govulncheck`
(golang.org/x/vuln). Testing: stdlib `testing` first, `testify` only where it pays.

## 0. Global authoring rules (apply to every file)

- One H1 per file. All fenced code blocks MUST have a language tag (`go`, `bash`, `text`,
  `yaml`, `sql`). No bare ``` fences.
- Every Go snippet must compile *in context* (imports implied but consistent; no invented
  APIs). Use real stdlib signatures. When showing a fragment, keep it self-evidently correct.
- Good/Bad contrasts: use `// Good:` and `// Bad:` Go comments (NOT "PASS/FAIL"). Bad block
  comes second or is clearly labeled; never leave a Bad block that could be copy-pasted as if good.
- Imperative, dense, directive tone aimed at an LLM coding agent editing a real repo.
- No placeholders, no `TODO`, no "etc.", no "...". Every example is complete.
- US-ASCII punctuation; no emojis.
- Cross-references use relative links: `references/concurrency.md`, `scripts/verify.sh`.
- "See Also" links to sibling skills by id (no path needed): `error-handling`, `api-design`,
  `secure-coding`, `security-review`, `deployment`, `backend-patterns`.

## 1. File list (exact paths)

Create exactly these files under `/Volumes/EXTERN/DEV/skills/skills/go/`:

```text
/Volumes/EXTERN/DEV/skills/skills/go/SKILL.md
/Volumes/EXTERN/DEV/skills/skills/go/references/concurrency.md
/Volumes/EXTERN/DEV/skills/skills/go/references/http-services.md
/Volumes/EXTERN/DEV/skills/skills/go/references/testing.md
/Volumes/EXTERN/DEV/skills/skills/go/scripts/verify.sh
```

Create parent directories first:

```bash
mkdir -p /Volumes/EXTERN/DEV/skills/skills/go/references
mkdir -p /Volumes/EXTERN/DEV/skills/skills/go/scripts
```

No other files. Do NOT create a README, index, or summary `.md`.

---

## 2. SKILL.md — section-by-section

Budget: **~250–450 lines** (aim ~430). One H1. If a section threatens to overflow, push
detail to the matching `references/*.md` and leave a one-line pointer. Write sections in
this exact order.

### 2.1 Frontmatter (YAML)

```yaml
---
name: go
description: >-
  Use when writing, reviewing, testing, securing, or shipping Go code or HTTP
  services - Go idioms (simplicity, useful zero value, accept-interfaces/return-structs,
  functional options, embedding), error wrapping with %w and errors.Is/As,
  goroutines/channels/context/errgroup concurrency, net/http with Go 1.22 routing,
  log/slog structured logging, graceful shutdown, cmd/-internal/-pkg/ layout,
  table-driven tests with httptest/-race/fuzz, and govulncheck/SQL-parametrization
  security. Triggers - "write a Go service/handler", "review this Go code", "add
  tests", "fix a goroutine leak", "is this idiomatic Go", .go files, go.mod,
  net/http, slog, chi, errgroup.
origin: risco
---
```

Rules: `description` MUST start with "Use when". Keep it trigger-rich (the verbs +
concrete trigger phrases + file/import signals). `origin: risco` exactly. Do NOT add a
`title` field unless other risco skills use one — check a sibling `SKILL.md` in
`/Volumes/EXTERN/DEV/skills/skills/` and match; if they have `title`, add
`title: Idiomatic Go services`, else omit. (Spec mentions `title`; honor only if siblings do.)

### 2.2 `# Idiomatic Go services` (H1) + purpose line

- One-line purpose: "Write, review, test, secure, and ship idiomatic Go HTTP services."
- Version stance line, verbatim intent: "Targets **Go 1.22+**: enhanced `net/http` routing
  (`mux.HandleFunc("GET /users/{id}", h)` + `r.PathValue`), `log/slog` structured logging,
  and fixed loop-variable semantics (no more `tt := tt`)."

### 2.3 `## When to use / When NOT to use`

Two tight bullet lists.

- When to use (bullets): any `.go` authoring/review/test; designing a Go HTTP API;
  debugging concurrency/leaks/races; structuring a Go module; hardening/shipping a Go binary.
- When NOT to use (each bullet ends with a `-> See Also: <skill>` delegation):
  - Generic cross-language error envelopes / React error boundaries -> `error-handling`
    (this skill keeps only the Go half).
  - HTTP contract design / REST resource naming / status-code taxonomy -> `api-design`.
  - Language-agnostic abuse/authz review -> `secure-coding` / `security-review` (this skill
    keeps Go-specific controls: SQL params, server timeouts, govulncheck, TLS defaults).
  - Containerfile / k8s / CI pipeline authoring -> `deployment` (this skill ships only a
    Docker note + ldflags).
  - Non-service Go (CLI tooling, codegen, ML): patterns apply, but the HTTP/production half
    is irrelevant.

### 2.4 `## Decision rules`

Numbered 1–10, imperative, one line each. Write exactly these (reword tightly, keep meaning):

1. Clear over clever; return early, keep the happy path unindented.
2. Accept interfaces, return concrete structs; define interfaces in the **consumer** package.
3. Make the zero value useful; never ship a type that panics before a constructor runs.
4. `context.Context` is the **first** param, never stored in a struct, never `nil` (use
   `context.TODO()` while wiring).
5. Wrap every crossed boundary with `fmt.Errorf("verb: %w", err)`; classify with
   `errors.Is`/`errors.As`, never string-match messages.
6. No package-level mutable state; inject dependencies through constructors.
7. Every goroutine needs a known exit path (context or a closed channel); a started
   goroutine you cannot stop is a leak.
8. Validate at the boundary; parametrize every SQL query; set all server timeouts; run
   `govulncheck` before shipping.
9. Tests are table-driven with subtests; run `-race` in CI; treat `go vet`/`staticcheck`
   failures as build failures.
10. Pick value-or-pointer receiver per type and stay consistent; mutating/large/contains-`sync`
    -> pointer.

### 2.5 `## Idioms`

Each idiom = 1–4 sentence lead-in + a Good/Bad Go snippet. Write FRESH code (do not copy
ECC). Snippets to include:

1. **Useful zero value** — Good: `type Counter struct { mu sync.Mutex; n int }` with
   `Inc()` using the zero-value mutex; mention `var b bytes.Buffer` works immediately.
   Bad: a struct with a `nil` map field that panics on first write.
2. **Accept interfaces, return structs** — Good: `func NewService(s UserStore) *Service`
   returning the concrete `*Service`; show the consumer-side
   `type UserStore interface { GetUser(ctx context.Context, id string) (*User, error) }`.
   Bad: returning `UserStore` (the interface) from the constructor.
3. **Functional options** — Good: `NewServer(addr string, opts ...Option) *Server` with
   `WithTimeout`/`WithLogger` and sane defaults applied before the loop. One-line decision
   note: "Prefer a plain `Config` struct once options exceed ~5; options are for optional,
   composable tuning."
4. **Embedding for composition** — Good: embed `*slog.Logger` into a service to get
   `.Info/.Error` for free (`type Service struct { *slog.Logger; store UserStore }`).
   Bad: deep type trees faking inheritance.
5. **Early return** — Good: invert the error condition and `return` early, happy path flat.
   Bad: arrow-code nesting (`if ok { if ok2 { ... } }`).
6. **No package-level mutable state** — Good: `func NewServer(db *sql.DB) *Server`.
   Bad: `var db *sql.DB` + `func init()` opening it.
7. **Go 1.22 loopvar note** — short code comment showing the now-obsolete line struck:
   `// tt := tt  // Go 1.22+: DELETE THIS - loop var is per-iteration now`. One sentence:
   "Stop emitting `tt := tt` / `i, v := i, v` in range loops on Go 1.22+."

Keep this section ~80–110 lines. If it runs long, move the embedding example's expansion
to a one-liner and rely on `http-services.md` for slog detail.

### 2.6 `## Errors`

Go-specific (the half ECC `error-handling` delegates here). Include:

- **Sentinel vs typed**: `var ErrNotFound = errors.New("not found")` (sentinel) vs
  `type ValidationError struct { Field, Msg string }` + `func (e *ValidationError) Error() string`.
- **Wrap & classify**: `fmt.Errorf("find user %s: %w", id, err)`; `errors.Is(err, ErrNotFound)`
  for sentinels; `errors.As(err, &verr)` for typed; `errors.Join(err1, err2)` for aggregation
  (1.20+).
- **Worked 3-layer boundary snippet** (the differentiator): repo returns
  `fmt.Errorf("user %s: %w", id, ErrNotFound)` (wrapping `sql.ErrNoRows`); service passes
  through (optionally wraps); handler `switch { case errors.Is(err, ErrNotFound): ... }`
  maps to HTTP status with `slog.Error` on the default branch. End with: "Full handler
  adapter -> `references/http-services.md`."
- **`defer` + named return** to capture `Close()` errors:
  `func read() (err error) { f, e := os.Open(...); if e != nil { return e };
  defer func() { err = errors.Join(err, f.Close()) }(); ... }`.
- **Anti-patterns** (one line each): `if err.Error() == "not found"` string matching;
  `panic` for control flow; swallowing with `_ = err`.

Keep ~70 lines.

### 2.7 `## Concurrency (essentials)`

Overview only (~40 lines). Push depth to `references/concurrency.md`. Include:

- Context cancel/timeout snippet:
  `ctx, cancel := context.WithTimeout(ctx, 5*time.Second); defer cancel()`.
- One bounded worker pool via errgroup:
  `g, ctx := errgroup.WithContext(ctx); g.SetLimit(8); for ... { g.Go(func() error { ... }) };
  err := g.Wait()`.
- Goroutine-leak Good/Bad: Bad = unbuffered `ch <- v` with no receiver after cancel;
  Good = buffered `make(chan T, 1)` + `select { case ch <- v: case <-ctx.Done(): }`.
- One line each: `sync.Once` (lazy init), `sync.RWMutex` (read-heavy), `sync/atomic`
  (`atomic.Int64`).
- Bold directive: "**Run `-race` in CI.**"
- Pointer line: "Full pipelines, fan-in/out, semaphores, `singleflight`, leak detection ->
  `references/concurrency.md`."

### 2.8 `## HTTP services (essentials)`

Overview only (~45 lines). Push depth to `references/http-services.md`. Include:

- Go 1.22 routed mux: `mux := http.NewServeMux(); mux.HandleFunc("GET /users/{id}", h)` and
  `id := r.PathValue("id")`.
- The `error`-returning handler adapter (just the type + ServeHTTP signature, full body in ref):
  `type apiHandler func(http.ResponseWriter, *http.Request) error`.
- One middleware showing the `func(http.Handler) http.Handler` chain (request-id + slog),
  abbreviated.
- `http.Server` with **all four timeouts set**: `ReadHeaderTimeout`, `ReadTimeout`,
  `WriteTimeout`, `IdleTimeout` (show concrete durations, e.g. 5s/15s/30s/120s).
- Graceful shutdown one-liner: `ctx, stop := signal.NotifyContext(ctx, os.Interrupt,
  syscall.SIGTERM); ... srv.Shutdown(shutdownCtx)`.
- Pointer line: "Routing patterns, chi vs stdlib, full middleware stack, config,
  functional-options server, JSON helpers -> `references/http-services.md`."

### 2.9 `## Project layout`

Include:

- Annotated tree in a `text` block:
  ```text
  cmd/api/main.go        # entrypoint: wiring only
  internal/handler/      # HTTP adapters
  internal/service/      # business logic; defines the interfaces it needs
  internal/repository/   # data access (pgx); implements service interfaces
  internal/config/       # env parsing, validation
  pkg/                   # ONLY genuinely reusable, stable public API
  testdata/              # fixtures, golden files
  go.mod go.sum
  ```
- Repository <-> service <-> handler split with **constructor injection** (one short snippet:
  `repo := repository.New(db); svc := service.New(repo); h := handler.New(svc)`).
- Package naming rules: short, lowercase, no underscores, no `util`/`common`, avoid stutter
  (`user.User` not `user.UserStruct`).
- Where interfaces live: **consumer side** (the service package declares `UserStore`, not
  the repository package).

### 2.10 `## Testing (essentials)`

Embedded (~35 lines) + pointer. Include:

- One table-driven test with subtests + `t.Parallel()`; include the comment
  `// Go 1.22+: no tt := tt needed`.
- `wantErr bool` field checked via `errors.Is(err, ErrX)` (not just `!= nil`).
- `httptest` one-liner: `req := httptest.NewRequest("GET", "/users/1", nil);
  w := httptest.NewRecorder(); h.ServeHTTP(w, req)`.
- `t.Helper()`, `t.TempDir()`, `t.Cleanup()`, `t.Setenv()` in one sentence.
- Command: `go test -race -cover ./...`.
- testify-vs-stdlib rule: stdlib default; `testify/require` only for deep-equality or large
  suites.
- Pointer: "Golden files, fuzzing, benchmarks, httptest matrices, interface fakes ->
  `references/testing.md`."

### 2.11 `## Security (embedded)`

Go-specific, terse. Include:

- **SQL**: Good `db.QueryContext(ctx, "SELECT ... WHERE id = $1", id)`; Bad
  `fmt.Sprintf("... WHERE id = '%s'", id)`. Note: PostgreSQL 16, prefer `pgx v5`
  (`pgxpool.Pool`).
- **Input**: `r.Body = http.MaxBytesReader(w, r.Body, 1<<20)` and
  `dec := json.NewDecoder(r.Body); dec.DisallowUnknownFields()`.
- **Server timeouts** as a DoS control (cross-ref §2.8).
- **TLS**: `tls.Config{MinVersion: tls.VersionTLS12}`; rely on `crypto/tls` defaults,
  do not hand-pick cipher suites.
- **`govulncheck ./...`** in CI; `go mod tidy` + `go mod verify`.
- Secrets from env / secret manager, never logged; slog `ReplaceAttr` to redact tokens.
- Pointer: "Deeper authz/abuse review -> `secure-coding`."

### 2.12 `## Production`

Include:

- Graceful shutdown (cross-ref §2.8 / ref).
- `log/slog` JSON handler wired in `main`, level from env:
  `slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl}))` +
  `slog.SetDefault(logger)`.
- Build info: `-ldflags "-X main.version=$(git describe --tags --always)"` +
  `runtime/debug.ReadBuildInfo()` for module versions.
- `net/http/pprof` mounted on a **separate internal mux/port** (security note: never on the
  public listener).
- `/healthz` (liveness, static 200) + `/readyz` (checks deps, e.g. `db.PingContext`).
- Docker **note only**: distroless/static base, `CGO_ENABLED=0`, multi-stage build ->
  "full Containerfile -> `deployment`."

### 2.13 `## Anti-patterns / rationalizations -> STOP`

Two-column markdown table `| Rationalization | Reality / Do instead |`. Exactly these ~12 rows:

| Rationalization | Reality / Do instead |
| --- | --- |
| "I'll store ctx in the struct to avoid threading it" | No. `ctx` is the first arg of every call. |
| "`_ = err` here, it can't fail" | Handle, log, or document why; `errcheck` catches it. |
| "string-compare the error message" | `errors.Is`/`errors.As`; messages are not API. |
| "global `db`/`logger` is simpler" | Inject via constructor; globals kill testability. |
| "fire the goroutine, it'll finish" | Unbounded/unstoppable goroutine = leak; give it ctx + buffer. |
| "I'll add `tt := tt` to be safe" | Go 1.22 fixed loopvar; it's noise now. |
| "interface in the provider package, return the interface" | Return structs; interface lives with the consumer. |
| "no timeouts, the LB handles it" | Set all four `http.Server` timeouts; Slowloris is real. |
| "`panic` for this bad input" | Return an error; panic only for programmer bugs / `main` wiring. |
| "skip `-race`, tests pass" | Race bugs are silent; `-race` in CI is mandatory. |
| "`fmt.Sprintf` into SQL, the input's trusted" | Parametrize ($1...); trust nothing at the boundary. |
| "testify everywhere" | Stdlib first; reach for testify only when it earns its weight. |

### 2.14 `## Quick reference`

Table `| Task | Idiom / command |`. Rows:

| Task | Idiom / command |
| --- | --- |
| Format | `gofmt -w .` / `goimports -w .` |
| Vet | `go vet ./...` |
| Lint | `staticcheck ./...` / `golangci-lint run` |
| Test (race+cover) | `go test -race -cover ./...` |
| Fuzz | `go test -fuzz=Fuzz -fuzztime=30s` |
| Vulns | `govulncheck ./...` |
| Wrap error | `fmt.Errorf("verb: %w", err)` |
| Classify error | `errors.Is` / `errors.As` |
| Route | `mux.HandleFunc("GET /p/{id}", h)` + `r.PathValue("id")` |
| Log | `slog.Info("msg", "key", val)` |
| Shutdown | `signal.NotifyContext` + `srv.Shutdown(ctx)` |
| Leak guard | buffered chan + `select { case ch<-v: case <-ctx.Done(): }` |
| Local gate | `./scripts/verify.sh` (run in your module root) |

### 2.15 `## See Also`

Two parts:

- Sibling skills, one line each: `error-handling` (cross-language envelopes/boundaries),
  `api-design` (HTTP contract & status taxonomy), `secure-coding` / `security-review`
  (authz/abuse review), `deployment` (Docker/CI/k8s), `backend-patterns`
  (caching/queues/repository concepts, language-agnostic).
- Local references with "read when…": `references/concurrency.md` (goroutines, channels,
  errgroup, leaks, race detector), `references/http-services.md` (routing, middleware, slog,
  graceful shutdown, full service skeleton), `references/testing.md` (table tests, httptest,
  fakes, golden, fuzz, benchmarks).

---

## 3. references/concurrency.md (~320 lines)

H1: `# Go concurrency for services`. One-line intro. Sections in this order, each with the
listed runnable code.

1. `## Mental model` — "share memory by communicating"; goroutines are cheap (~few KB
   stacks) but not free; when NOT to go concurrent (premature parallelism, serial I/O that's
   already fast). No code or one tiny snippet.
2. `## Context` — `context.WithTimeout`/`WithCancel`/`WithDeadline` (always `defer cancel()`);
   propagating ctx down the call chain; `ctx.Err()` vs `context.Cause(ctx)` (1.21, returns
   the cause passed to `WithCancelCause`); a `fetchWithTimeout(ctx, url)` example using
   `http.NewRequestWithContext`.
3. `## Channels & select` — directional channels (`<-chan T` / `chan<- T`), `select` with
   `default` (non-blocking), closing semantics ("the **sender** closes, never the receiver"),
   `for v := range ch`. Show a Good closing pattern and the Bad double-close panic.
4. `## Goroutine leaks` — canonical Bad (unbuffered send, no receiver after ctx cancel) vs
   Good (buffered `make(chan T, 1)` + `select` on `ctx.Done()`). State the rule: "every
   goroutine needs a guaranteed exit." Detection: `runtime.NumGoroutine()` deltas in tests,
   and the `go.uber.org/goleak` note (`defer goleak.VerifyNone(t)`).
5. `## Worker pool` — TWO variants:
   - Modern: `errgroup` + `g.SetLimit(n)` to bound concurrency, writing results into a
     **preallocated** `results[i]` slice (index-per-goroutine, no shared-map race).
   - Raw: `sync.WaitGroup` + `jobs <-chan Job` + `results chan<- Result`, N workers ranging
     over `jobs`, `close(results)` after `wg.Wait()`.
6. `## errgroup` — `errgroup.WithContext(ctx)`; first non-nil error cancels siblings via the
   derived ctx; `SetLimit` as a semaphore; collecting indexed results without a shared map.
   Show the full `fetchAll(ctx, urls) ([][]byte, error)` (note: in Go 1.22+ the
   `i, url := i, url` capture is unnecessary — call this out explicitly as the modern fix to
   ECC's stale code).
7. `## Pipelines` — generator -> stage -> stage with fan-out/fan-in; each stage closes its
   own output channel; stages select on `ctx.Done()`. Runnable 3-stage example:
   `gen(ctx, nums...) -> square(ctx, in) -> sum(in)`.
8. `## sync primitives` — `Mutex`/`RWMutex` (note useful zero value, never copy after use);
   `sync.Once` for lazy singletons; `sync.WaitGroup`; `sync/atomic` (`atomic.Int64.Add`);
   `sync.Pool` (with the **reset-on-Put** caveat); `golang.org/x/sync/singleflight` to
   collapse duplicate concurrent calls (`g.Do(key, fn)`).
9. `## Race detector` — `go test -race ./...`; it catches data races at runtime on exercised
   paths, misses unexercised code; CI gate. Show a deliberately racy counter (`go func(){ n++ }()`)
   and the fix (`atomic.Int64` or mutex).
10. `## Checklist` — bullet list: bounded? ctx-cancellable? who closes the channel? buffered
    to avoid a leak? `-race` green in CI?

Include a `### Tables` where useful, e.g. a small "channel operation behavior" table
(send/recv on nil vs closed vs open channel: block / panic / proceed).

---

## 4. references/http-services.md (~420 lines)

H1: `# Building Go HTTP services`. One-line intro. Sections in order:

1. `## Routing - Go 1.22 stdlib first` — `http.NewServeMux`; method+path patterns
   (`"GET /users/{id}"`, `"POST /users"`); `{id}` single segment and `{path...}` trailing
   wildcard; `r.PathValue("id")`; precedence (most-specific wins); built-in `405 Method Not
   Allowed` and `404`. Then a short **chi** equivalent (`r := chi.NewRouter();
   r.Get("/users/{id}", h); chi.URLParam(r, "id")`) and a decision note: stdlib for simple
   routing; chi for route groups, sub-routers, and its middleware ecosystem.
2. `## Handler design` — the `error`-returning adapter:
   ```go
   type apiHandler func(http.ResponseWriter, *http.Request) error
   func (h apiHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
       if err := h(w, r); err != nil { /* map via errors.Is/As to status + slog */ }
   }
   ```
   `writeJSON(w, status, v)` and `decodeJSON(w, r, &dst)` helpers (the decoder sets
   `MaxBytesReader` + `DisallowUnknownFields`). Typed context key for request-scoped values
   (`type ctxKey int; const requestIDKey ctxKey = iota`) — never a bare string key.
3. `## Middleware chains` — the `func(http.Handler) http.Handler` signature; a
   `Chain(h, mw...)` helper applying middleware **in order** (outermost first); concrete
   middlewares: request-id (generate + stash in ctx + response header), slog request logger
   (method/path/status/latency via a `statusRecorder` wrapping `http.ResponseWriter` to
   capture the code), panic-recovery (`defer recover()` -> log + 500, server stays up),
   real-IP, and timeout (`http.TimeoutHandler`).
4. `## slog structured logging` —
   `slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl}))`;
   `slog.SetDefault`; per-request child logger `logger.With("request_id", id)` stashed in
   ctx and retrieved in handlers; level from env (`LOG_LEVEL` -> `slog.Level`); redacting
   sensitive attrs with `HandlerOptions.ReplaceAttr` (drop/replace `authorization`,
   `password`, `token`).
5. `## Config` — env-based `Config` struct parsed once in `main`, validated, injected (no
   globals); 12-factor; defaults + required-var failure. Provide tiny helpers
   `envString(key, def)`, `envInt(key, def)`, `envDuration(key, def)` (no heavy dep) and a
   one-line mention of `caarlos0/env` as an option.
6. `## Functional-options server` — `NewServer(cfg Config, opts ...Option) *http.Server`
   wiring the mux, all four timeouts, `BaseContext`, and `ErrorLog` derived from slog
   (`slog.NewLogLogger(handler, slog.LevelError)`); options `WithReadTimeout`,
   `WithTLS(*tls.Config)`. Production defaults for the four timeouts.
7. `## Graceful shutdown` —
   `ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)`;
   run `srv.ListenAndServe()` in a goroutine pushing to an error channel; on `<-ctx.Done()`
   create a fresh `shutdownCtx` with its own timeout and call `srv.Shutdown(shutdownCtx)`;
   treat `http.ErrServerClosed` as a clean exit. Full `run(ctx) error` + thin `main()` that
   calls `run` and `os.Exit(1)` on error.
8. `## Full minimal service` — one ~70-line end-to-end example tying together: routed mux,
   one handler using the `apiHandler` adapter, a `UserStore` interface, slog wiring, all four
   timeouts, graceful shutdown, and error->status mapping. This is the copy-paste skeleton.
   Must compile conceptually (consistent imports, real signatures).
9. `## Production endpoints` — `/healthz` (static 200), `/readyz` (calls `db.PingContext(ctx)`
   with a short timeout, returns 503 on failure), and `net/http/pprof` mounted on a
   **separate** `http.Server` bound to `127.0.0.1:6060` (internal-only) — with the security
   note that pprof must never be on the public listener.

Include at least one decision table (e.g. "stdlib mux vs chi: when to pick each").

---

## 5. references/testing.md (~360 lines)

H1: `# Testing Go services`. One-line intro. Sections in order:

1. `## Table-driven + subtests + parallel` — canonical pattern: `tests := []struct{ name ...;
   wantErr bool }{...}`; `for _, tt := range tests { t.Run(tt.name, func(t *testing.T){
   t.Parallel(); ... }) }`. Explicit comment: `// Go 1.22+: loop var is per-iteration - no
   tt := tt`. Check errors with `errors.Is(err, ErrX)` plus a `wantErr` flag, not just `!= nil`.
2. `## Helpers & fixtures` — `t.Helper()`, `t.TempDir()`, `t.Cleanup()`, `t.Setenv()`; a
   `newTestServer(t)` helper returning a wired handler/server and registering cleanup.
3. `## httptest` — `httptest.NewRecorder()` for handler unit tests;
   `httptest.NewServer(handler)` for full round-trips with a real client; a request-matrix
   table (`method/path/body/wantStatus/wantBody`); assert JSON by decoding both sides and
   comparing structs (avoid brittle string equality on JSON).
4. `## Interface fakes` — hand-written struct fake with func fields
   (`type fakeStore struct { GetUserFunc func(ctx, id) (*User, error) }` + method delegating
   to the field), injected via the service constructor — the idiomatic Go "mock". Note when
   to reach for `go.uber.org/mock` (mockgen) or `mockery`: large/volatile interfaces,
   generated stubs. Do not mock the stdlib.
5. `## Golden files` — `var update = flag.Bool("update", false, "update golden files")`;
   `testdata/<name>.golden`; write on `-update`, else read + `bytes.Equal`; run
   `go test -run TestRender -update` to regenerate.
6. `## Fuzzing (1.18+)` — `func FuzzParse(f *testing.F)` with `f.Add(seed...)` corpus +
   `f.Fuzz(func(t *testing.T, in string){...})`; property example: round-trip
   `Unmarshal -> Marshal` must not error after a successful parse; corpus lives in
   `testdata/fuzz/`; run `go test -fuzz=Fuzz -fuzztime=30s`.
7. `## Benchmarks` — `func BenchmarkX(b *testing.B)`, `b.ResetTimer()`, `b.ReportAllocs()`,
   sub-benchmarks by input size (`b.Run(fmt.Sprintf("size=%d", n), ...)`); run with
   `-benchmem`; read `ns/op B/op allocs/op`; `benchstat` note for comparing runs.
8. `## Coverage` — `go test -race -coverprofile=cover.out ./...`;
   `go tool cover -html=cover.out` / `-func=cover.out`. Pragmatic targets table (critical
   logic high, glue lower) framed as guidance, NOT a gate to game.
9. `## testify vs stdlib` — decision table: stdlib default; `require` (aborts) for
   preconditions, `assert` (continues) for independent checks; deep-equality-heavy suites
   justify testify; never use `assert` where a failed precondition should stop the test.
10. `## What to test` — behavior via the public API; error paths; boundary/validation. Don't:
    test private funcs directly, `time.Sleep` to "wait" (use channels / the `testing/synctest`
    note), or paper over flakes with `-count`. Fix the flake.

Include the coverage-targets table and the testify-vs-stdlib table.

---

## 6. scripts/verify.sh — exact contract

Write this file EXACTLY as below (this is the authoritative content — implementer may keep
it verbatim). Then `chmod +x`. Do NOT execute it in this repo.

```bash
#!/usr/bin/env bash
#
# verify.sh - local quality gate for a Go module (superset of CI).
#
# Usage:
#   cd <your-go-module-root>   # the directory containing go.mod
#   ./verify.sh
#
# Runs: gofmt, go vet, staticcheck, golangci-lint, go test -race -cover, govulncheck.
# Tools that are not installed are skipped with a yellow warning (not a failure).
# Real problems (unformatted code, vet/test/vuln failures) exit non-zero.
# Read-only: never mutates your source.

set -euo pipefail

readonly YELLOW=$'\033[33m'
readonly RED=$'\033[31m'
readonly GREEN=$'\033[32m'
readonly RESET=$'\033[0m'

failed=0

have()  { command -v "$1" >/dev/null 2>&1; }
warn()  { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail()  { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; failed=1; }
ok()    { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
info()  { printf '----- %s\n' "$*"; }

# Must run from a module root.
if [[ ! -f go.mod ]]; then
  printf '%serror:%s no go.mod in %s - cd into your module root first.\n' \
    "$RED" "$RESET" "$(pwd)" >&2
  exit 2
fi

# 1. gofmt - always available with the Go toolchain; formatting is non-negotiable.
info "gofmt"
if have gofmt; then
  fmt_out="$(gofmt -l .)"
  if [[ -n "$fmt_out" ]]; then
    fail "unformatted files (run: gofmt -w .):"
    printf '%s\n' "$fmt_out"
  else
    ok "gofmt clean"
  fi
else
  warn "gofmt not found (is Go installed?)"
fi

# 2. go vet - always available with the Go toolchain.
info "go vet"
if have go; then
  if go vet ./...; then ok "go vet clean"; else fail "go vet reported issues"; fi
else
  warn "go not found - cannot run go vet/test"
fi

# 3. staticcheck - optional.
info "staticcheck"
if have staticcheck; then
  if staticcheck ./...; then ok "staticcheck clean"; else fail "staticcheck reported issues"; fi
else
  warn "staticcheck not found (go install honnef.co/go/tools/cmd/staticcheck@latest)"
fi

# 4. golangci-lint - optional.
info "golangci-lint"
if have golangci-lint; then
  if golangci-lint run; then ok "golangci-lint clean"; else fail "golangci-lint reported issues"; fi
else
  warn "golangci-lint not found (https://golangci-lint.run/usage/install/)"
fi

# 5. go test -race -cover. -race needs a C toolchain; detect and degrade gracefully.
info "go test -race -cover"
if have go; then
  if CGO_ENABLED=1 go env >/dev/null 2>&1 && have cc; then
    if go test -race -cover ./...; then ok "tests pass (race+cover)"; else fail "tests failed"; fi
  else
    warn "no C compiler for -race; running plain go test -cover"
    if go test -cover ./...; then ok "tests pass (no race)"; else fail "tests failed"; fi
  fi
else
  warn "go not found - skipping tests"
fi

# 6. govulncheck - optional; findings are a real failure.
info "govulncheck"
if have govulncheck; then
  if govulncheck ./...; then ok "no known vulnerabilities"; else fail "govulncheck found vulnerabilities"; fi
else
  warn "govulncheck not found (go install golang.org/x/vuln/cmd/govulncheck@latest)"
fi

echo
if [[ "$failed" -ne 0 ]]; then
  printf '%sFAIL:%s one or more checks failed.\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s all checks passed.\n' "$GREEN" "$RESET"
```

Then run:

```bash
chmod +x /Volumes/EXTERN/DEV/skills/skills/go/scripts/verify.sh
```

Do NOT execute `verify.sh` — this skills repo is not a Go module.

Notes for the implementer: the `cc`/CGO detection above is the "detect-or-skip" for `-race`.
Keep the soft-skip semantics: every check runs (no early `exit` mid-script except the
`go.mod` guard); `failed` is set and the single `exit 1` happens at the end.

---

## 7. Acceptance checks (implementer must self-verify before finishing)

Run/inspect each; all must pass:

1. **Files exist** at the five exact paths in §1; no extra `.md` files created.
2. **Frontmatter**: `name: go`, `origin: risco`, `description` starts with "Use when" and is
   trigger-rich. (`title` present only if sibling skills use it.)
3. **One H1 per file**; all headings consistent (`##` for sections, `###` for sub-sections);
   no skipped levels.
4. **Every fenced code block has a language tag** (`go`/`bash`/`text`/`yaml`/`sql`). Grep for
   bare fences:
   ```bash
   grep -rnE '^```$' /Volumes/EXTERN/DEV/skills/skills/go/ && echo "BARE FENCE FOUND" || echo "ok"
   ```
   (A closing fence on its own line is fine; this check flags an *opening* bare fence only if
   it's the first of a pair — manually confirm any hits are closers.)
5. **No placeholders**: grep returns nothing for `TODO`, `FIXME`, `XXX`, `\.\.\.` (literal
   ellipsis used as hand-waving), `PLACEHOLDER`:
   ```bash
   grep -rnE 'TODO|FIXME|XXXX|PLACEHOLDER' /Volumes/EXTERN/DEV/skills/skills/go/ && echo "REVIEW" || echo "clean"
   ```
6. **Go correctness**: every Go snippet uses real stdlib APIs — `r.PathValue`,
   `http.NewServeMux`, `slog.NewJSONHandler`, `signal.NotifyContext`, `errors.Is/As/Join`,
   `errgroup.WithContext`/`SetLimit`, `httptest.NewRecorder`. No invented functions. No
   `tt := tt` anywhere except the explicitly-struck "delete this" example.
7. **Currency**: no `log.Println` as the recommended logger (use `slog`); no hand-rolled
   `switch r.Method` routing where Go 1.22 patterns apply; loopvar workaround shown only as
   the obsolete-pattern callout.
8. **SKILL.md length** is within ~250–450 lines:
   ```bash
   wc -l /Volumes/EXTERN/DEV/skills/skills/go/SKILL.md
   ```
   Each reference within ~200–500 lines.
9. **verify.sh is executable**:
   ```bash
   test -x /Volumes/EXTERN/DEV/skills/skills/go/scripts/verify.sh && echo "executable" || echo "NOT EXECUTABLE"
   ```
   And starts with `#!/usr/bin/env bash` + `set -euo pipefail`.
10. **See Also** links present in SKILL.md to sibling skills (`error-handling`, `api-design`,
    `secure-coding`/`security-review`, `deployment`, `backend-patterns`) and to all three
    local references.
11. **Cross-refs resolve**: each `references/*.md` pointer in SKILL.md points to a file that
    exists; the 3-layer error example references `references/http-services.md` which contains
    the handler adapter.
12. **Anti-patterns table** has the 12 rows from §2.13; **Quick reference** table present;
    **Decision rules** are numbered 1–10.
13. **shellcheck** (if available) is clean on `verify.sh`:
    ```bash
    command -v shellcheck >/dev/null && shellcheck /Volumes/EXTERN/DEV/skills/skills/go/scripts/verify.sh || echo "shellcheck not installed - skip"
    ```
    Do NOT run `verify.sh` itself here.
