# Mocks, fakes & HTTP test doubles

The default is a hand-written fake. This file covers the decision, minimal templates for the three approaches, and `net/http/httptest` recipes.

## Which double?

| You have | Use |
|---|---|
| An interface you own, small surface, you care about values not call order | Hand-rolled func-field fake |
| A large interface where the **sequence and arguments** of calls is the contract under test | `go.uber.org/mock` (gomock) |
| An existing codebase already standardized on testify | `testify/mock` (consistency over preference) |
| An HTTP client or handler | `net/http/httptest` (below) — not a mock |

`go.uber.org/mock` is the maintained successor to the archived `github.com/golang/mock`. Use it, not the original.

## Hand-rolled fake (default)

Declare the interface at the consumer, keep it minimal, give the fake a func field per method so each test sets exactly the behavior it needs.

```go
type Store interface {
	Get(ctx context.Context, id string) (Item, error)
	Put(ctx context.Context, it Item) error
}

type fakeStore struct {
	get func(ctx context.Context, id string) (Item, error)
	put func(ctx context.Context, it Item) error
}

func (f fakeStore) Get(ctx context.Context, id string) (Item, error) { return f.get(ctx, id) }
func (f fakeStore) Put(ctx context.Context, it Item) error          { return f.put(ctx, it) }

func TestService_NotFound(t *testing.T) {
	s := Service{store: fakeStore{
		get: func(context.Context, string) (Item, error) { return Item{}, ErrNotFound },
	}}
	if _, err := s.Lookup(t.Context(), "x"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}
```

For a stateful fake (e.g. an in-memory store), back it with a `map` and a `sync.Mutex` instead of func fields. That doubles as a usable test fixture for many tests at once.

## gomock template

Generate from the interface, then set expectations:

```bash
go install go.uber.org/mock/mockgen@latest
mockgen -source=store.go -destination=mock_store_test.go -package=mypkg
```

```go
func TestService_callsPutOnce(t *testing.T) {
	ctrl := gomock.NewController(t)
	m := NewMockStore(ctrl)
	m.EXPECT().Put(gomock.Any(), gomock.Any()).Return(nil).Times(1)
	// ... exercise; ctrl asserts expectations at test cleanup
}
```

The payoff is automatic call-count and argument verification; the cost is generated files, regen on every interface change, and tests coupled to call order. Worth it only when that order is the contract.

## testify/mock template

```go
type MockStore struct{ mock.Mock }

func (m *MockStore) Get(ctx context.Context, id string) (Item, error) {
	args := m.Called(ctx, id)
	return args.Get(0).(Item), args.Error(1)
}

// in the test:
m := new(MockStore)
m.On("Get", mock.Anything, "x").Return(Item{}, ErrNotFound)
m.AssertExpectations(t)
```

Use only where the repo already uses testify for mocks; otherwise prefer the func-field fake.

## httptest recipes

**Test an HTTP client** against a fake server:

```go
func TestClient_Fetch(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/items/42" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"id":"42"}`)
	}))
	defer srv.Close()

	c := NewClient(srv.URL)
	it, err := c.Fetch(t.Context(), "42")
	if err != nil {
		t.Fatalf("Fetch: %v", err)
	}
	if it.ID != "42" {
		t.Errorf("ID = %q, want 42", it.ID)
	}
}
```

**Test an `http.Handler`** with a recorder — no server, no socket:

```go
func TestHandler_OK(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want 200", rec.Code)
	}
}
```

**Fake transport** when you cannot change the base URL — swap the `RoundTripper`:

```go
type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

client := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader(`{"ok":true}`)),
		Header:     make(http.Header),
	}, nil
})}
```

Prefer `httptest.NewServer` when the code under test takes a URL; reach for the `RoundTripper` only when it constructs the client internally.
