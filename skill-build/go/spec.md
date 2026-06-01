# DESIGN SPEC — skill `go` (Idiomatic Go services)

Status: design spec. Defines the artifacts to be built; not the skill itself.
Target versions to state explicitly throughout: **Go 1.22+ (assume 1.23/1.24 stable available)**, `net/http`
with **Go 1.22 enhanced routing** (`mux.HandleFunc("GET /users/{id}", …)` + `r.PathValue`), **`log/slog`**
(stdlib structured logging), `errors.Join` (1.20+), loopvar semantics fixed (1.22 — no more `tt := tt`),
`golang.org/x/sync/errgroup`, optional `github.com/go-chi/chi/v5`. Tooling: `staticcheck` (honnef.co/go/tools),
`golangci-lint` v1.6x, `govulncheck` (golang.org/x/vuln). Testing: stdlib `testing` first, `testify` only where it pays.

Audience: an LLM coding agent editing a real polyglot repo (FastAPI/Python, Next.js, Go, Flutter, Postgres). Tone:
directive, dense, copy-pasteable, Good/Bad contrasts. ECC `golang-patterns` + `golang-testing` + `error-handling`(Go part)
+ `backend-patterns` are the floor; this skill must exceed them on currency (1.22 routing, slog, loopvar) and on being
ONE coherent services skill rather than four scattered ones.

---

## 1. Purpose & precise trigger

**Purpose (one line):** Write, review, test, secure, and ship idiomatic Go HTTP services — idioms, errors, concurrency,
`net/http`+slog, layout, testing, security, production — in one skill.

**`description` (frontmatter, trigger-rich, starts with "Use when"):**
> Use when writing, reviewing, testing, securing, or shipping Go code or HTTP services — Go idioms (simplicity, useful
> zero value, accept-interfaces/return-structs, functional options, embedding), error wrapping with `%w` and
> `errors.Is`/`As`, goroutines/channels/context/errgroup concurrency, `net/http` with Go 1.22 routing, `log/slog`
> structured logging, graceful shutdown, `cmd/`–`internal/`–`pkg/` layout, table-driven tests with `httptest`/`-race`/fuzz,
> and `govulncheck`/SQL-parametrization security. Triggers: "write a Go service/handler", "review this Go code",
> "add tests", "fix a goroutine leak", "is this idiomatic Go", `.go` files, `go.mod`, `net/http`, `slog`, `chi`, `errgroup`.

**origin:** `risco`

**When to use:** any `.go` authoring/review/test; designing a Go HTTP API; debugging concurrency/leaks/races;
structuring a Go module; hardening or shipping a Go binary.

**When NOT to use (delegate):**
- Generic cross-language error envelopes / React error boundaries → ECC `error-handling` (this skill keeps only the Go half).
- HTTP contract design / REST resource naming / status-code taxonomy → `See Also: api-design`.
- Language-agnostic abuse/authz review → `See Also: security-review` (`secure-coding`); this skill keeps Go-specific
  controls (sql params, server timeouts, govulncheck, TLS defaults).
- Containerfile / k8s / CI pipeline authoring → `See Also: deployment` (this skill ships only a Docker *note* + ldflags).
- Non-service Go (CLI tooling, codegen, ML) — patterns still apply but the HTTP/production half is irrelevant.

---

## 2. SKILL.md — exact outline (every heading)

Target length **~430 lines**. One H1. Frontmatter: `name: go`, `title`, `description` (above), `origin: risco`.
Long material is pushed to `references/`. Every code block is language-tagged and runnable in context.

### H1 `# Idiomatic Go services`
One-line purpose + the version stance line ("Targets Go 1.22+: enhanced routing, `log/slog`, fixed loopvar.").

### `## When to use / When NOT to use`
Two tight bullet lists mirroring §1. NOT-to-use rows point to the sibling skills above (progressive delegation).

### `## Decision rules` (the spine — ~10 directives the agent applies on every Go edit)
Numbered, imperative, one line each. Delivers:
1. Clear over clever; return early, keep the happy path unindented.
2. Accept interfaces, return concrete structs; define interfaces in the **consumer** package.
3. Make the zero value useful; never ship a type that panics before a constructor runs.
4. `context.Context` is the **first** param, never stored in a struct; never `nil` — use `context.TODO()`.
5. Wrap every crossed boundary with `fmt.Errorf("verb: %w", err)`; classify with `errors.Is`/`As`, never string match.
6. No package-level mutable state; inject dependencies through constructors.
7. Every goroutine must have a known exit path (context or closed channel); a started goroutine you can't stop is a leak.
8. Validate at the boundary; parametrize every SQL query; set server timeouts; run `govulncheck` before shipping.
9. Tests are table-driven + subtests; run `-race` in CI; treat `go vet`/`staticcheck` failures as build failures.
10. Pointer vs value receiver: pick one per type and be consistent; mutating/large/contains-`sync` → pointer.

### `## Idioms` (core, copy-pasteable, Good/Bad)
Delivers, each with a Good/Bad pair (fresh code, not ECC's):
- **Useful zero value** — `Counter{ mu sync.Mutex; n int }`; Bad = nil map field that panics.
- **Accept interfaces, return structs** — `func New(...) *Service`; consumer-side `type UserStore interface {…}`.
- **Functional options** — `New(addr, WithTimeout(…), WithLogger(…))` with sane defaults; note: use a plain Config
  struct when options exceed ~5 (decision note, not dogma).
- **Embedding for composition** — embed `*slog.Logger`/a base; Bad = faking inheritance with deep type trees.
- **Early return** — invert conditions; Bad = arrow-code nesting.
- **No package-level mutable state** — Bad = `var db *sql.DB; init()`; Good = `NewServer(db *sql.DB)`.
- **Go 1.22 loopvar note** — `tt := tt` is now unnecessary; show the *removed* line struck in a comment so agents
  stop emitting it.

### `## Errors` (Go-specific; the half ECC `error-handling` delegates here)
Delivers:
- Sentinel errors (`var ErrNotFound = errors.New(...)`) vs typed errors (`type ValidationError struct{…}` with `Error()`).
- Wrap with `%w`; `errors.Is` for sentinels, `errors.As` for typed; `errors.Join` for multi-error aggregation (1.20+).
- One worked **boundary mapping** snippet: repo returns `%w ErrNotFound` → service passes through → handler `switch`es
  `errors.Is` → HTTP status (the canonical 3-layer flow, cross-ref `http-services.md`).
- Anti-pattern: `if err.Error() == "not found"` string matching; `panic` for control flow; swallowing with `_`.
- Note: `defer` + named return error to capture `Close()` failures (`defer func(){ err = errors.Join(err, f.Close()) }()`).

### `## Concurrency (essentials)` (overview only → `references/concurrency.md`)
~40 lines: context cancellation/timeout snippet; one bounded worker pool via `errgroup.SetLimit`; the goroutine-leak
Good/Bad (buffered chan + `select{case ch<-v: case <-ctx.Done():}`); one line each on `sync.Once`/`sync.RWMutex`/
`atomic`; "**run `-race` in CI**". Then: "Full pipelines, fan-in/out, semaphores, `singleflight` → `references/concurrency.md`."

### `## HTTP services (essentials)` (overview only → `references/http-services.md`)
~45 lines: Go 1.22 routed mux (`mux.HandleFunc("GET /users/{id}", h)` + `r.PathValue("id")`); a `Handler` returning
`error` adapter (`type apiHandler func(...) error`); one middleware (request-id + slog) showing the
`func(http.Handler) http.Handler` chain; `http.Server` with **all four timeouts set** (`ReadHeaderTimeout`,
`ReadTimeout`, `WriteTimeout`, `IdleTimeout`); graceful shutdown via `signal.NotifyContext` + `srv.Shutdown(ctx)`.
Then: "Routing patterns, chi vs stdlib, full middleware stack, config, functional-options server, JSON helpers →
`references/http-services.md`."

### `## Project layout`
Delivers the `cmd/ internal/ pkg/` tree (annotated), the repository↔service↔handler split with **constructor
injection**, package-naming rules (short, lowercase, no `util`/`common`/stutter), and where interfaces live (consumer side).

### `## Testing (essentials)` (embedded + → `references/testing.md`)
~35 lines: one table-driven test with subtests + `t.Parallel()` (note "Go 1.22: no `tt := tt` needed"); `httptest`
recorder one-liner; `t.Helper()`/`t.TempDir()`/`t.Cleanup()`; "`go test -race -cover ./...`"; testify-vs-stdlib rule
(stdlib default; `testify/require` only for deep equality/large suites). Then: "Golden files, fuzzing, benchmarks,
table httptest matrix, interface fakes → `references/testing.md`."

### `## Security (embedded)`
Delivers, Go-specific, terse:
- **SQL**: `db.QueryContext(ctx, "… WHERE id=$1", id)` — never `fmt.Sprintf` into SQL (Bad shown). Postgres 16 / pgx note.
- **Input validation** at the boundary; `http.MaxBytesReader` + `json.Decoder.DisallowUnknownFields()`.
- **Server timeouts** as DoS control (cross-ref above).
- **TLS**: `tls.Config{MinVersion: tls.VersionTLS12}`; rely on `crypto/tls` defaults, don't hand-pick ciphers.
- **`govulncheck ./...`** in CI; `go mod tidy` + `go mod verify`.
- Secrets from env/secret-manager, never logged (slog: redact tokens).
- "Deeper authz/abuse review → `See Also: secure-coding`."

### `## Production`
Delivers: graceful shutdown (already shown — cross-ref), `log/slog` JSON handler wiring at `main` with level from env,
build info via `-ldflags "-X main.version=$(git describe)"` + `runtime/debug.ReadBuildInfo()`, `net/http/pprof`
mounted on a **separate internal** mux/port (not the public one — security note), `/healthz` + `/readyz`. Docker
*note only*: distroless/static base, `CGO_ENABLED=0`, multi-stage — "full Containerfile → `See Also: deployment`."

### `## Anti-patterns / rationalizations → STOP` (table)
Two-column `| Rationalization | Reality / Do instead |`. ~12 rows, e.g.:
- "I'll store ctx in the struct to avoid threading it" → No. ctx is the first arg, every call.
- "`_ = err` here, it can't fail" → Handle, log, or document why; `errcheck` will catch it.
- "string-compare the error message" → `errors.Is`/`As`; messages are not API.
- "global `db`/`logger` is simpler" → inject via constructor; globals kill testability.
- "fire goroutine, it'll finish" → unbounded/unstoppable goroutine = leak; give it ctx + buffer.
- "I'll add `tt := tt` to be safe" → Go 1.22 fixed loopvar; it's noise now.
- "interface in the provider package, return the interface" → return structs; interface lives with the consumer.
- "no timeouts, the LB handles it" → set all four `http.Server` timeouts; Slowloris is real.
- "`panic` for this bad input" → return an error; panic only for programmer bugs/`main` wiring.
- "skip `-race`, tests pass" → race bugs are silent; `-race` in CI is mandatory.
- "`fmt.Sprintf` into SQL, the input's trusted" → parametrize; trust nothing at the boundary.
- "testify everywhere" → stdlib first; reach for testify only when it earns its weight.

### `## Quick reference` (table)
`| Task | Idiom / command |` — gofmt, `go vet ./...`, `staticcheck ./...`, `golangci-lint run`,
`go test -race -cover ./...`, `go test -fuzz=Fuzz -fuzztime=30s`, `govulncheck ./...`, wrap=`%w`, classify=`errors.Is/As`,
route=`"GET /p/{id}"`+`PathValue`, log=`slog`, shutdown=`signal.NotifyContext`+`Shutdown`, leak-guard=buffered chan + ctx select.
Final row points to `scripts/verify.sh` as the one-shot local gate.

### `## See Also`
`error-handling` (cross-language envelopes), `api-design` (HTTP contract), `secure-coding`/`security-review`,
`deployment` (Docker/CI/k8s), `backend-patterns` (caching/queues/repository concepts language-agnostic).
And the three local references with a one-line "read when…" each.

---

## 3. references/ files — outlines & key code

### `references/concurrency.md` (~320 lines)
Focused on Go concurrency for services. Sections + key code:
1. **Mental model** — "share memory by communicating"; goroutine cost; when NOT to go concurrent (premature).
2. **Context** — `WithTimeout`/`WithCancel`/`WithDeadline`; propagating ctx through call chains; `ctx.Err()` vs
   `context.Cause(ctx)` (1.21); the `http.NewRequestWithContext` fetch-with-timeout example.
3. **Channels & select** — directional channels (`<-chan`/`chan<-`), `select` with `default`, closing semantics
   (sender closes, never receiver), `for range` over channel.
4. **Goroutine leaks** — the canonical Bad (unbuffered send, no receiver after cancel) vs Good (buffered + `select`
   on `ctx.Done()`); the "every goroutine needs an exit" rule; `go test -run x -count=1` + leak detection via
   `runtime.NumGoroutine`/`go.uber.org/goleak` note.
5. **Worker pool** — bounded pool with `errgroup` + `g.SetLimit(n)` (modern), and a raw `sync.WaitGroup`+jobs/results
   variant; results aggregation without data races.
6. **errgroup** — `errgroup.WithContext`; first error cancels siblings; `SetLimit` as semaphore; collecting indexed
   results into a preallocated slice (no shared-map race).
7. **Pipelines** — generator → stage → stage fan-in/fan-out; each stage closes its output; ctx-aware stages; a runnable
   3-stage example (gen ints → square → sum).
8. **sync primitives** — `Mutex`/`RWMutex` (and "useful zero value"), `sync.Once` for lazy init, `sync.WaitGroup`,
   `sync/atomic` (`atomic.Int64`), `sync.Pool` (with the reset-on-put caveat), `golang.org/x/sync/singleflight`
   to collapse duplicate in-flight calls.
9. **Race detector** — `go test -race ./...`; what it catches/misses; CI gate; a deliberately racy example + the fix.
10. **Checklist** — bounded?, ctx-cancellable?, who closes?, buffered to avoid leak?, `-race` green?

### `references/http-services.md` (~420 lines)
Focused on building an HTTP service. Sections + key code:
1. **Routing — Go 1.22 stdlib first** — `http.NewServeMux`; method+path patterns (`"GET /users/{id}"`,
   `"POST /users"`), `{id}` and `{path...}` wildcards, `r.PathValue`, precedence rules, `405`/`404` behavior. Then a
   short **chi** equivalent and a decision note: stdlib for simple routing; chi when you need route groups,
   sub-routers, rich middleware ecosystem.
2. **Handler design** — the `error`-returning handler adapter (`type Handler func(http.ResponseWriter,*http.Request) error`
   + `func (h Handler) ServeHTTP` mapping errors→status via `errors.Is`/`As`, cross-ref errors). `writeJSON`/`decodeJSON`
   helpers with `MaxBytesReader` + `DisallowUnknownFields`. Request context values via a typed key (not bare string).
3. **Middleware chains** — the `func(http.Handler) http.Handler` signature; a `Chain(...)`/`compose` helper applying
   in order; concrete middlewares: request-id, slog request logger (method/path/status/latency via a status-capturing
   `responseWriter`), panic-recovery (logs + 500, never crashes the server), real-IP, timeout (`http.TimeoutHandler`).
4. **slog structured logging** — `slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl}))`;
   `slog.SetDefault`; per-request child logger with `logger.With("request_id", id)` stashed in ctx; levels from env;
   redacting sensitive attrs via `ReplaceAttr`.
5. **Config** — env-based config struct, parsed once in `main`, validated, injected (no globals); 12-factor; defaults +
   required-var failure; a tiny `envString/envInt/envDuration` helper (no heavy dep, mention `caarlos0/env` as option).
6. **Functional-options server** — `NewServer(cfg, opts...) *http.Server` wiring mux+timeouts+`BaseContext`+
   `ErrorLog` from slog; `WithTLS`, `WithReadTimeout` options; sane production defaults for all four timeouts.
7. **Graceful shutdown** — `ctx, stop := signal.NotifyContext(ctx, SIGINT, SIGTERM)`; run `srv.ListenAndServe` in a
   goroutine; on `<-ctx.Done()` call `srv.Shutdown(shutdownCtx)` with its own timeout; drain in-flight; return
   non-`ErrServerClosed`. Full runnable `run(ctx) error` + thin `main`.
8. **Full minimal service** — one ~70-line end-to-end `main.go`+handler+repo-interface tying routing+slog+timeouts+
   shutdown+error mapping together (the copy-paste skeleton).
9. **Production endpoints** — `/healthz`, `/readyz` (checks deps), pprof on a separate internal mux.

### `references/testing.md` (~360 lines)
Focused on testing Go services. Sections + key code:
1. **Table-driven + subtests + parallel** — canonical pattern; `t.Run(tt.name, …)`; `t.Parallel()`; explicit
   "Go 1.22 fixed loopvar — drop `tt := tt`". `wantErr bool` + `errors.Is` on a sentinel rather than just `!= nil`.
2. **Helpers & fixtures** — `t.Helper()`, `t.TempDir()`, `t.Cleanup()`, `t.Setenv`; a `newTestServer(t)` helper.
3. **httptest** — `httptest.NewRecorder()` for handlers; `httptest.NewServer` for full round-trips/clients; a table of
   request matrices (method/path/body/wantStatus/wantBody); asserting JSON via `encoding/json` decode + compare.
4. **Interface fakes** — hand-written struct fake with func fields (`GetUserFunc`) injected via constructor — the
   idiomatic Go mock; note when to use `gomock`/`mockery` (large interfaces, generated). No mocking the stdlib.
5. **Golden files** — `var update = flag.Bool("update", …)`; `testdata/<name>.golden`; `go test -update`; `bytes.Equal`.
6. **Fuzzing (1.18+)** — `FuzzParse(f)` with `f.Add` seed corpus + `f.Fuzz`; property assertions (round-trip
   marshal/unmarshal); `go test -fuzz=Fuzz -fuzztime=30s`; corpus lives in `testdata/fuzz/`.
7. **Benchmarks** — `b.N`, `b.ResetTimer()`, `b.ReportAllocs()`, sub-benchmarks by size, `-benchmem`;
   reading `ns/op B/op allocs/op`; `benchstat` note.
8. **Coverage** — `-coverprofile`, `go tool cover -html/-func`, `-race` together; pragmatic targets table
   (critical logic high, glue lower) — framed as guidance, not a gate to game.
9. **testify vs stdlib** — decision table: stdlib default; `require`/`assert` for deep-equality-heavy suites; never
   mix `assert` (continues) where `require` (aborts) is meant.
10. **What to test** — behavior via public API, error paths, boundary/validation; **don't** test private fns directly,
    don't `time.Sleep` (use channels/`synctest` note), fix flakes don't `-count` around them.

---

## 4. scripts/verify.sh — contract

Executable gate the **end user** runs inside **their** Go module. Idempotent, read-only (never mutates code).
NOT executed in this skills repo (not a Go project).

- Shebang `#!/usr/bin/env bash`; `set -euo pipefail`.
- Top usage comment: purpose, `cd` into module root, `./verify.sh`; note it's a superset of CI.
- A `have()` helper (`command -v`) + yellow `warn()` (skip) and red `fail()` printers; track a `failed` flag so all
  checks run and the script exits non-zero **once** at the end if any real check failed (don't bail on first soft skip).
- Guard: if no `go.mod` in cwd → print error, exit 2 (wrong directory).
- Checks, in this exact order (each: detect tool → skip-with-warning if missing → run → record failure on non-zero):
  1. **gofmt** — `fmt_out="$(gofmt -l .)"`; if non-empty → print the unformatted files and **fail** (formatting is
     non-negotiable; `gofmt` always present with Go). Suggest `gofmt -w .`.
  2. **go vet** — `go vet ./...`; fail on non-zero. (Always present.)
  3. **staticcheck** — `staticcheck ./...`; if binary missing → warn+skip with install hint
     (`go install honnef.co/go/tools/cmd/staticcheck@latest`).
  4. **golangci-lint** — `golangci-lint run`; missing → warn+skip with install hint.
  5. **go test -race -cover** — `go test -race -cover ./...`; fail on non-zero. (`-race` needs cgo/gcc; if the toolchain
     can't race, detect and warn+skip rather than hard-fail.)
  6. **govulncheck** — `govulncheck ./...`; missing → warn+skip with hint
     (`go install golang.org/x/vuln/cmd/govulncheck@latest`); present + findings → fail.
- Final summary line (green "all checks passed" / red "N check(s) failed"); `exit 0` only when no hard failures.
- After writing: `chmod +x scripts/verify.sh`. Do **not** run it here.

---

## 5. Quality differentiators (why this beats the ECC equivalents)

1. **Current to Go 1.22+ where ECC is stale** — enhanced `net/http` routing (`"GET /{id}"` + `PathValue`) and
   `log/slog` as the default logger; explicitly tells the agent to **stop** emitting `tt := tt` (ECC still teaches the
   obsolete loopvar workaround). ECC uses `log`/`println` and hand-rolled mux.
2. **One coherent services skill** — idioms+errors+concurrency+http+testing+security+production in a single triggerable
   unit with progressive disclosure, instead of four disjoint ECC skills the agent must guess between.
3. **A real local gate (`verify.sh`)** — ECC only lists commands prose; this ships an idempotent, tool-detecting,
   skip-vs-fail script the user runs in their repo, matching the exact CI order requested.
4. **The 3-layer error boundary worked end-to-end** — repo `%w ErrNotFound` → service → handler `errors.Is` switch →
   HTTP status, wired across the errors + http references; ECC shows the pieces but never the full path with slog.
5. **Production-grade HTTP defaults baked in** — all four `http.Server` timeouts, panic-recovery middleware,
   `signal.NotifyContext` graceful shutdown, pprof on a *separate* port, healthz/readyz — ECC's HTTP coverage is a bare
   handler test.
6. **Embedded, Go-specific security** — `MaxBytesReader`+`DisallowUnknownFields`, parametrized SQL with a Bad
   `fmt.Sprintf` contrast, `govulncheck` in the gate, TLS `MinVersion` — none of which the ECC Go content covers.
7. **Concurrency that prevents leaks, not just demos pools** — "every goroutine needs an exit", buffered-chan+ctx
   `select` leak fix, `errgroup.SetLimit` bounded pools, `singleflight`, and a mandatory `-race` CI stance.
8. **Decision rules + rationalizations→STOP table** tuned for an LLM editing real code (house style from
   `risco-project-harness`), turning idioms into enforceable directives rather than a reference dump.
