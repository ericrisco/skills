# Testing Go services

Table-driven tests, helpers, httptest, interface fakes, golden files, fuzzing, benchmarks,
coverage, testify-vs-stdlib, and what to test - the depth behind the SKILL.md testing
essentials. Go 1.22+, stdlib `testing` first.

## Table-driven + subtests + parallel

The canonical Go test shape. One slice of cases, one loop, one subtest per case. Check error
identity with `errors.Is` against a sentinel, not just `err != nil`.

```go
func TestParse(t *testing.T) {
	tests := []struct {
		name    string
		in      string
		want    int
		wantErr error
	}{
		{name: "valid", in: "42", want: 42},
		{name: "empty", in: "", wantErr: ErrEmpty},
		{name: "non-numeric", in: "abc", wantErr: ErrInvalid},
	}

	for _, tt := range tests {
		// Go 1.22+: loop var is per-iteration - no tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, err := Parse(tt.in)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("Parse(%q) err = %v, want %v", tt.in, err, tt.wantErr)
			}
			if tt.wantErr == nil && got != tt.want {
				t.Errorf("Parse(%q) = %d, want %d", tt.in, got, tt.want)
			}
		})
	}
}
```

`t.Parallel()` runs the subtests concurrently; the per-iteration loop variable (Go 1.22)
makes this safe without the old `tt := tt` shadow.

## Helpers and fixtures

`t.Helper()` makes failures point at the caller, not the helper. `t.TempDir()`,
`t.Cleanup()`, and `t.Setenv()` manage resources with automatic teardown.

```go
func mustJSON(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	return string(b)
}

func writeTemp(t *testing.T, content string) string {
	t.Helper()
	dir := t.TempDir() // removed automatically when the test ends
	path := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatalf("write temp: %v", err)
	}
	return path
}

func newTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	h := NewHandler(&fakeStore{})
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close) // closed even if the test fails
	return srv
}

func TestWithEnv(t *testing.T) {
	t.Setenv("LOG_LEVEL", "debug") // restored after the test
	// ...
}
```

## httptest

`httptest.NewRecorder` exercises a handler in-process; `httptest.NewServer` spins up a real
HTTP server for full client round-trips. Compare JSON by decoding both sides into structs -
never by string-equality on serialized bytes (field order and whitespace are brittle).

```go
func TestGetUser(t *testing.T) {
	tests := []struct {
		name       string
		method     string
		path       string
		body       string
		wantStatus int
	}{
		{"ok", http.MethodGet, "/users/1", "", http.StatusOK},
		{"missing", http.MethodGet, "/users/999", "", http.StatusNotFound},
		{"wrong method", http.MethodDelete, "/users/1", "", http.StatusMethodNotAllowed},
	}

	h := NewHandler(&fakeStore{
		GetUserFunc: func(_ context.Context, id string) (*User, error) {
			if id == "1" {
				return &User{ID: "1", Name: "Ada"}, nil
			}
			return nil, ErrNotFound
		},
	})

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			var body io.Reader
			if tt.body != "" {
				body = strings.NewReader(tt.body)
			}
			req := httptest.NewRequest(tt.method, tt.path, body)
			w := httptest.NewRecorder()
			h.ServeHTTP(w, req)

			if w.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d", w.Code, tt.wantStatus)
			}
			if tt.wantStatus == http.StatusOK {
				var got User
				if err := json.NewDecoder(w.Body).Decode(&got); err != nil {
					t.Fatalf("decode: %v", err)
				}
				if got.ID != "1" {
					t.Errorf("id = %q, want %q", got.ID, "1")
				}
			}
		})
	}
}
```

Full round-trip against a real client:

```go
func TestRoundTrip(t *testing.T) {
	srv := newTestServer(t)
	resp, err := srv.Client().Get(srv.URL + "/users/1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d", resp.StatusCode)
	}
}
```

## Interface fakes

The idiomatic Go "mock" is a hand-written struct with function fields, injected through the
constructor. No code generation, no framework, full control per test.

```go
type fakeStore struct {
	GetUserFunc  func(ctx context.Context, id string) (*User, error)
	SaveUserFunc func(ctx context.Context, u *User) error
}

func (f *fakeStore) GetUser(ctx context.Context, id string) (*User, error) {
	return f.GetUserFunc(ctx, id)
}

func (f *fakeStore) SaveUser(ctx context.Context, u *User) error {
	return f.SaveUserFunc(ctx, u)
}

func TestServiceGetUser(t *testing.T) {
	store := &fakeStore{
		GetUserFunc: func(_ context.Context, id string) (*User, error) {
			return &User{ID: id, Name: "Ada"}, nil
		},
	}
	svc := NewService(store)
	u, err := svc.GetUser(context.Background(), "1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if u.Name != "Ada" {
		t.Errorf("name = %q, want %q", u.Name, "Ada")
	}
}
```

Reach for `go.uber.org/mock` (mockgen) or `mockery` only for large, volatile interfaces where
generated stubs and call-order assertions pay off. Never mock the standard library - use
`httptest`, `t.TempDir`, in-memory implementations, or a real local Postgres/`testcontainers`.

## Golden files

Compare generated output against a checked-in file in `testdata/`. Regenerate with a flag so
intended changes are a one-command diff in review.

```go
var update = flag.Bool("update", false, "update golden files")

func TestRender(t *testing.T) {
	got := Render(Template{Name: "report", Items: []string{"a", "b"}})

	golden := filepath.Join("testdata", "report.golden")
	if *update {
		if err := os.WriteFile(golden, got, 0o600); err != nil {
			t.Fatalf("update golden: %v", err)
		}
	}
	want, err := os.ReadFile(golden)
	if err != nil {
		t.Fatalf("read golden: %v", err)
	}
	if !bytes.Equal(got, want) {
		t.Errorf("output mismatch (run: go test -run TestRender -update)\n got: %s\nwant: %s", got, want)
	}
}
```

Run `go test -run TestRender -update` to refresh after an intended change, then review the
golden file diff like any other.

## Fuzzing (1.18+)

Fuzz tests assert properties over machine-generated inputs. A common property is a round-trip
invariant: a value that parses must re-serialize without error.

```go
func FuzzParse(f *testing.F) {
	f.Add("42")   // seed corpus
	f.Add("-7")
	f.Add("")

	f.Fuzz(func(t *testing.T, in string) {
		n, err := Parse(in)
		if err != nil {
			return // rejecting bad input is fine; we only assert on success
		}
		// Property: a parsed value must round-trip through its string form.
		got, err := Parse(strconv.Itoa(n))
		if err != nil || got != n {
			t.Fatalf("round-trip failed for %q: got %d, err %v", in, got, err)
		}
	})
}
```

Run `go test -fuzz=FuzzParse -fuzztime=30s`. Failing inputs are written to `testdata/fuzz/`
and become permanent regression cases on the next plain `go test`.

## Benchmarks

Prefer `for b.Loop() { ... }` (Go 1.24+) as the benchmark idiom: it runs the loop exactly once
per benchmark, auto-resets the timer after setup and stops it before teardown (so setup/teardown
never count toward the measurement), and keeps the call's parameters and results alive so the
compiler can't optimize the benchmarked work away — no manual `b.ResetTimer()` and no sink variable
needed. Report allocations; vary input size with sub-benchmarks.

```go
func BenchmarkRender(b *testing.B) {
	for _, n := range []int{10, 100, 1000} {
		b.Run(fmt.Sprintf("size=%d", n), func(b *testing.B) {
			tmpl := makeTemplate(n) // setup — excluded from timing by b.Loop
			b.ReportAllocs()
			for b.Loop() {
				_ = Render(tmpl)
			}
		})
	}
}
```

Legacy pattern (pre-1.24, still valid): `for range b.N` with an explicit `b.ResetTimer()` after
setup — `b.N` is chosen by the framework, which calls the function repeatedly while ramping up. Use
`b.Loop` for new benchmarks; reach for the `b.N` form only when targeting an older toolchain.

Run `go test -bench=Render -benchmem`. Output columns are `ns/op` (time), `B/op` (bytes
allocated), `allocs/op` (allocation count) - watch allocations, they drive GC pressure. Use
`benchstat` to compare two runs and confirm a change is a real, statistically significant
improvement, not noise.

## Coverage

```bash
go test -race -coverprofile=cover.out ./...
go tool cover -func=cover.out   # per-function summary + total
go tool cover -html=cover.out   # annotated source in the browser
```

Coverage targets are guidance, not a number to game - 100% line coverage of trivial getters
proves nothing, while one untested error branch in a payment path is a real risk.

| Code type | Pragmatic target |
| --- | --- |
| Critical business logic | High - cover every branch and error path |
| Public API / exported funcs | High |
| Glue / wiring / `main` | Lower - integration tests cover the seams |
| Generated code | Exclude |

## testify vs stdlib

Stdlib `testing` is the default. Add `github.com/stretchr/testify` only when deep-equality
assertions or large suites make the boilerplate worth a dependency.

| Situation | Use |
| --- | --- |
| Most tests | stdlib `if got != want { t.Errorf(...) }` |
| Deep struct/slice/map equality | `assert.Equal` / `require.Equal` (or stdlib `reflect.DeepEqual` / `go-cmp`) |
| A precondition that must stop the test | `require.*` (aborts the test) |
| Independent checks that should all run | `assert.*` (continues) |
| Large suites with repetitive assertions | testify to cut boilerplate |

Never use `assert.*` where a failed check makes the rest of the test meaningless (e.g. a nil
result you then dereference) - that is what `require.*` is for. `github.com/google/go-cmp`
(`cmp.Diff`) is a great stdlib-adjacent choice for readable struct diffs without the full
testify surface.

## What to test

DO:

- Test behavior through the **public API**, the way callers use it.
- Cover error paths and boundary/validation cases, not just the happy path.
- Use `errors.Is`/`errors.As` to assert error identity, not message strings.
- Make tests deterministic and parallel-safe.

DON'T:

- Test private functions directly - if a private function needs its own test, it probably
  wants to be its own exported package.
- `time.Sleep` to "wait" for concurrency - synchronize on a channel, a `sync.WaitGroup`, or
  the stable `testing/synctest` package (GA since Go 1.25; controls a fake clock for
  concurrent code) instead.
- Paper over a flaky test with `-count` or retries - a flake is a real bug (a race, a leaked
  goroutine, a timing assumption); find and fix it.
