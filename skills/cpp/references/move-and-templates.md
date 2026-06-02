# Move semantics, value categories, and modern generics

## Value categories in one pass

Every expression has a category that decides whether it can be *moved from*:

- **lvalue** — has a name and a stable identity (`x`, `obj.field`, `*p`). Persists past the
  expression. Binds to `T&` and `const T&`.
- **prvalue** — a pure temporary with no name (`42`, `make()`, `a + b`). Binds to `T&&` and `const T&`.
- **xvalue** — an "expiring" lvalue you've cast with `std::move(x)`; its resources may be stolen.

`std::move` is just `static_cast<T&&>` — it *moves nothing*, it only relabels an lvalue as
movable so an overload that steals (the move ctor/assign) is selected. After a move the source is in
a **valid but unspecified** state: assigning to it or destroying it is fine; reading it is a bug.

## Rule of Zero vs Rule of Five

Prefer **Rule of Zero**: hold resources in members that already manage themselves (`std::string`,
`std::vector`, `std::unique_ptr`) and declare *none* of the five special members. The compiler
generates correct copy/move/destroy for free.

Write the five **only** when you manage a raw resource by hand — and treat that as a smell first
(could a `unique_ptr` with a custom deleter do it?). The Rule of Five: if you declare any one of
destructor / copy-ctor / copy-assign / move-ctor / move-assign, declare (or `= default`/`= delete`)
all five, because declaring one suppresses others.

```cpp
// Rule of Five for a hand-managed buffer. Note: every move op is noexcept.
class Buffer {
public:
    explicit Buffer(std::size_t n) : data_(new int[n]), size_(n) {}
    ~Buffer() { delete[] data_; }

    Buffer(const Buffer& o) : data_(new int[o.size_]), size_(o.size_) {
        std::copy(o.data_, o.data_ + size_, data_);
    }
    Buffer& operator=(const Buffer& o) {              // copy-and-swap: strong guarantee, self-safe
        Buffer tmp(o);
        swap(tmp);
        return *this;
    }
    Buffer(Buffer&& o) noexcept                       // steal, leave o empty-but-valid
        : data_(std::exchange(o.data_, nullptr)), size_(std::exchange(o.size_, 0)) {}
    Buffer& operator=(Buffer&& o) noexcept { Buffer tmp(std::move(o)); swap(tmp); return *this; }

    void swap(Buffer& o) noexcept { std::swap(data_, o.data_); std::swap(size_, o.size_); }
private:
    int* data_{};
    std::size_t size_{};
};
```

The equivalent Rule-of-Zero version is shorter and harder to get wrong:

```cpp
class Buffer {
public:
    explicit Buffer(std::size_t n) : data_(n) {}
private:
    std::vector<int> data_;   // vector is the five special members, done correctly
};
```

## noexcept on moves — why it's load-bearing

`std::vector` reallocation uses `move_if_noexcept`: it only *moves* its elements into the new buffer
when the element's move constructor is `noexcept`; otherwise it falls back to *copying* to preserve
the strong exception guarantee. A non-`noexcept` move ctor therefore silently turns every vector
growth into a deep copy. Mark move operations `noexcept` whenever they can't throw (stealing
pointers never throws).

## RVO and copy elision — don't fight it

```cpp
// Good: the local is constructed directly in the caller's slot. No copy, no move.
Widget make() { Widget w; configure(w); return w; }

// Bad: std::move blocks NRVO and forces an actual move that elision would have removed.
Widget make() { Widget w; return std::move(w); }   // pessimization — drop the std::move
```

Return local objects by value, plainly. Only `std::move` a *member* or *parameter* out of a function
(those aren't elision candidates).

## Perfect forwarding

In a function template, `T&&` is a **forwarding reference** (it binds to lvalues *and* rvalues and
preserves which it was). Pass it on with `std::forward<T>` so an rvalue argument stays movable and an
lvalue stays an lvalue:

```cpp
template <class T, class... Args>
std::unique_ptr<T> make(Args&&... args) {
    return std::unique_ptr<T>(new T(std::forward<Args>(args)...));  // category preserved
}
```

Use `std::forward` *only* with a deduced `T&&`. Inside a normal function, a parameter declared `T&&`
where `T` is concrete is an rvalue reference, not forwarding — `std::move` it, don't `std::forward`.

## CTAD and C++20 concepts

Class Template Argument Deduction lets you omit template args when the constructor implies them:

```cpp
std::lock_guard lg(mtx);          // deduces std::lock_guard<std::mutex>
std::vector v{1, 2, 3};           // deduces std::vector<int>
std::pair p{1, "x"};              // std::pair<int, const char*>
```

C++20 **concepts** constrain templates so errors fire at the call site with a readable message
instead of deep inside instantiation, and they document intent:

```cpp
#include <concepts>

template <std::integral T>                          // only integers
T gcd(T a, T b) { return b == 0 ? a : gcd(b, a % b); }

template <class T>
concept Drawable = requires(const T& t) {           // a custom concept
    { t.draw() } -> std::same_as<void>;
};

void render(const Drawable auto& shape) { shape.draw(); }   // constrained abbreviated template
```

Prefer a concept over `enable_if`/SFINAE for new code: same constraint power, vastly better
diagnostics, and it reads like a type. Combine concepts with `&&`/`||`, and use `requires` clauses
for ad-hoc constraints the named concepts don't cover.
