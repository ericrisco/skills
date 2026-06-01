# Building Go HTTP services

Routing, handler design, middleware, slog, config, the functional-options server, graceful
shutdown, a full minimal service, and production endpoints - the depth behind the SKILL.md
HTTP essentials. Go 1.22+, `net/http` enhanced routing, `log/slog`.

## Routing - Go 1.22 stdlib first

`http.NewServeMux` understands method and path-variable patterns since Go 1.22. Reach for a
framework only when you outgrow it.

```go
mux := http.NewServeMux()
mux.HandleFunc("GET /users/{id}", getUser)   // method-scoped
mux.HandleFunc("POST /users", createUser)
mux.HandleFunc("GET /files/{path...}", serve) // trailing wildcard captures the rest
mux.HandleFunc("GET /healthz", healthz)
```

- `{id}` matches exactly one path segment; read it with `r.PathValue("id")`.
- `{path...}` is a trailing wildcard matching everything to the end; `r.PathValue("path")`.
- Precedence: the **most specific** pattern wins (`/users/me` beats `/users/{id}`), so order
  does not matter.
- The mux returns `405 Method Not Allowed` when the path matches but the method does not, and
  `404 Not Found` when nothing matches - you no longer hand-roll a `switch r.Method`.

chi (`github.com/go-chi/chi/v5`) covers the same surface with a richer ecosystem:

```go
r := chi.NewRouter()
r.Get("/users/{id}", getUser)
// inside the handler:
id := chi.URLParam(r, "id")
```

Decision - stdlib vs chi:

| Need | Pick |
| --- | --- |
| Simple method+path routing, few routes | stdlib `http.ServeMux` |
| Route groups, sub-routers, mounted APIs | chi |
| Large community middleware catalog | chi |
| Zero third-party deps, smallest binary | stdlib |
| URL params + 405/404 handled for you | either (stdlib does this since 1.22) |

## Handler design

Standard handlers cannot return an error, so error handling sprawls. An `error`-returning
adapter centralizes the mapping to status codes and structured logs.

```go
type apiHandler func(http.ResponseWriter, *http.Request) error

func (h apiHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if err := h(w, r); err != nil {
		var verr *ValidationError
		switch {
		case errors.Is(err, ErrNotFound):
			writeError(w, http.StatusNotFound, "not found")
		case errors.As(err, &verr):
			writeError(w, http.StatusBadRequest, verr.Error())
		case errors.Is(err, context.DeadlineExceeded):
			writeError(w, http.StatusGatewayTimeout, "upstream timeout")
		default:
			slog.Error("unhandled handler error", "method", r.Method, "path", r.URL.Path, "err", err)
			writeError(w, http.StatusInternalServerError, "internal error")
		}
	}
}

// Register it: mux.Handle("GET /users/{id}", apiHandler(getUser))
```

JSON helpers - the decoder caps the body and rejects unknown fields:

```go
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("encode response", "err", err)
	}
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) error {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1 MiB cap
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		return &ValidationError{Field: "body", Msg: err.Error()}
	}
	return nil
}
```

Request-scoped values use a **typed, unexported** context key, never a bare string:

```go
type ctxKey int

const requestIDKey ctxKey = iota

func withRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey, id)
}

func requestIDFrom(ctx context.Context) string {
	id, _ := ctx.Value(requestIDKey).(string) // typed key: no cross-package collision
	return id
}
```

## Middleware chains

Middleware is `func(http.Handler) http.Handler`. Compose with a helper that applies the list
outermost-first (the first middleware sees the request first and the response last).

```go
type Middleware func(http.Handler) http.Handler

func Chain(h http.Handler, mws ...Middleware) http.Handler {
	for i := len(mws) - 1; i >= 0; i-- { // wrap in reverse so mws[0] is outermost
		h = mws[i](h)
	}
	return h
}
```

To capture the status code for logging, wrap `http.ResponseWriter`:

```go
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (sr *statusRecorder) WriteHeader(code int) {
	sr.status = code
	sr.ResponseWriter.WriteHeader(code)
}
```

Concrete middlewares:

```go
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-ID")
		if id == "" {
			id = newID()
		}
		w.Header().Set("X-Request-ID", id)
		next.ServeHTTP(w, r.WithContext(withRequestID(r.Context(), id)))
	})
}

func Logger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sr := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sr, r)
		slog.Info("request",
			"method", r.Method, "path", r.URL.Path,
			"status", sr.status, "dur_ms", time.Since(start).Milliseconds(),
			"request_id", requestIDFrom(r.Context()))
	})
}

func Recover(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				slog.Error("panic recovered", "err", rec, "path", r.URL.Path)
				writeError(w, http.StatusInternalServerError, "internal error")
			}
		}()
		next.ServeHTTP(w, r) // a panic in one request no longer crashes the server
	})
}

func RealIP(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if ip := r.Header.Get("X-Forwarded-For"); ip != "" {
			r.RemoteAddr = ip // trust only behind a known proxy
		}
		next.ServeHTTP(w, r)
	})
}
```

`http.TimeoutHandler(mux, 10*time.Second, "request timeout")` bounds per-request handler time
and writes a 503 if exceeded. Wire them: `Chain(mux, RequestID, RealIP, Logger, Recover)`.

## slog structured logging

Build a JSON logger once in `main`, set the level from the environment, and make it the
default so libraries pick it up.

```go
func newLogger() *slog.Logger {
	lvl := new(slog.LevelVar) // info by default; mutable at runtime if you wish
	switch strings.ToLower(os.Getenv("LOG_LEVEL")) {
	case "debug":
		lvl.Set(slog.LevelDebug)
	case "warn":
		lvl.Set(slog.LevelWarn)
	case "error":
		lvl.Set(slog.LevelError)
	}
	h := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl, ReplaceAttr: redact})
	return slog.New(h)
}

// Redact sensitive keys before they reach the log sink.
func redact(_ []string, a slog.Attr) slog.Attr {
	switch strings.ToLower(a.Key) {
	case "authorization", "password", "token", "set-cookie":
		return slog.String(a.Key, "[REDACTED]")
	}
	return a
}
```

Derive a per-request child logger and carry it in the context:

```go
logger := slog.Default().With("request_id", requestIDFrom(ctx))
ctx = context.WithValue(ctx, loggerKey, logger)
// in a handler: loggerFrom(r.Context()).Info("created user", "id", u.ID)
```

## Config

Parse environment once in `main`, validate it, inject it. No globals, 12-factor.

```go
type Config struct {
	Addr         string
	DatabaseURL  string
	ReadTimeout  time.Duration
	LogLevel     string
}

func LoadConfig() (Config, error) {
	cfg := Config{
		Addr:        envString("ADDR", ":8080"),
		DatabaseURL: envString("DATABASE_URL", ""),
		ReadTimeout: envDuration("READ_TIMEOUT", 15*time.Second),
		LogLevel:    envString("LOG_LEVEL", "info"),
	}
	if cfg.DatabaseURL == "" {
		return Config{}, errors.New("DATABASE_URL is required")
	}
	return cfg, nil
}

func envString(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func envDuration(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}
```

For larger configs, `github.com/caarlos0/env` maps env vars to a tagged struct without the
boilerplate.

## Functional-options server

Build the `*http.Server` with all four timeouts, a `BaseContext`, and an `ErrorLog` derived
from slog so the server's internal errors flow through the same JSON pipeline:

```go
type Option func(*http.Server)

func WithReadTimeout(d time.Duration) Option { return func(s *http.Server) { s.ReadTimeout = d } }
func WithTLS(c *tls.Config) Option           { return func(s *http.Server) { s.TLSConfig = c } }

func NewServer(cfg Config, handler http.Handler, logger *slog.Logger, opts ...Option) *http.Server {
	srv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
		ErrorLog:          slog.NewLogLogger(logger.Handler(), slog.LevelError),
		BaseContext:       func(net.Listener) context.Context { return context.Background() },
	}
	for _, opt := range opts {
		opt(srv)
	}
	return srv
}
```

## Graceful shutdown

`signal.NotifyContext` cancels a context on SIGINT/SIGTERM. Run `ListenAndServe` in a
goroutine; on signal, call `Shutdown` with its own bounded context to drain in-flight
requests. Treat `http.ErrServerClosed` as a clean exit.

```go
func run(ctx context.Context) error {
	cfg, err := LoadConfig()
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}
	logger := newLogger()
	slog.SetDefault(logger)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(200) })
	srv := NewServer(cfg, Chain(mux, RequestID, Logger, Recover), logger)

	ctx, stop := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 1)
	go func() {
		logger.Info("listening", "addr", srv.Addr)
		errCh <- srv.ListenAndServe()
	}()

	select {
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("serve: %w", err)
		}
		return nil
	case <-ctx.Done():
		logger.Info("shutdown signal received")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			return fmt.Errorf("shutdown: %w", err)
		}
		return nil
	}
}

func main() {
	if err := run(context.Background()); err != nil {
		slog.Error("fatal", "err", err)
		os.Exit(1)
	}
}
```

## Full minimal service

End-to-end skeleton: routed mux, the `apiHandler` adapter, a `UserStore` interface, slog
wiring, all four timeouts, error->status mapping, and graceful shutdown.

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"log/slog"
)

var ErrNotFound = errors.New("not found")

type User struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// UserStore is declared by the consumer (this handler package).
type UserStore interface {
	GetUser(ctx context.Context, id string) (*User, error)
}

type Handler struct {
	store  UserStore
	logger *slog.Logger
}

func (h *Handler) getUser(w http.ResponseWriter, r *http.Request) error {
	u, err := h.store.GetUser(r.Context(), r.PathValue("id"))
	if err != nil {
		return fmt.Errorf("get user: %w", err) // adapter maps this to a status
	}
	w.Header().Set("Content-Type", "application/json")
	return writeJSON(w, http.StatusOK, u)
}

type apiHandler func(http.ResponseWriter, *http.Request) error

func (a apiHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if err := a(w, r); err != nil {
		switch {
		case errors.Is(err, ErrNotFound):
			http.Error(w, "not found", http.StatusNotFound)
		default:
			slog.Error("handler", "path", r.URL.Path, "err", err)
			http.Error(w, "internal error", http.StatusInternalServerError)
		}
	}
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	h := &Handler{store: newStore(), logger: logger}
	mux := http.NewServeMux()
	mux.Handle("GET /users/{id}", apiHandler(h.getUser))

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
		BaseContext:       func(net.Listener) context.Context { return context.Background() },
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("serve", "err", err)
			stop()
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown", "err", err)
		os.Exit(1)
	}
}
```

## Production endpoints

`/healthz` is liveness (am I running). `/readyz` is readiness (can I serve - check deps).
pprof goes on a **separate internal listener**, never the public one.

```go
func healthz(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) }

func readyz(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := db.PingContext(ctx); err != nil {
			http.Error(w, "not ready", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
	}
}

import (
	"net/http"
	_ "net/http/pprof" // registers /debug/pprof/* handlers on http.DefaultServeMux
	"time"
)

// startPprof serves pprof on 127.0.0.1:6060 only - never the public listener.
// The blank import above is what wires the handlers; the snippet is incomplete without it.
func startPprof() {
	go func() {
		s := &http.Server{
			Addr:              "127.0.0.1:6060",
			Handler:           http.DefaultServeMux, // pprof registered itself here
			ReadHeaderTimeout: 5 * time.Second,
		}
		_ = s.ListenAndServe()
	}()
}
```

If your service already uses `http.DefaultServeMux` for real traffic, do not leak pprof onto
it. Register the profiles on an explicit, private mux instead:

```go
import "net/http/pprof" // NOT blank: call the handlers explicitly on your own mux

func startPprof() {
	mux := http.NewServeMux()
	mux.HandleFunc("/debug/pprof/", pprof.Index)
	mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
	mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	mux.HandleFunc("/debug/pprof/trace", pprof.Trace)
	go func() {
		s := &http.Server{Addr: "127.0.0.1:6060", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
		_ = s.ListenAndServe()
	}()
}
```
