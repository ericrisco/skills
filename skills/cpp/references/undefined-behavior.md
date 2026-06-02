# Undefined behavior — catalog, sanitizers, fixes

UB is not "an error at runtime." The standard says the program has *no defined meaning*, which
licenses the optimizer to assume the situation never happens and rewrite code on that basis. That
is why UB produces distant, nonsensical crashes and "works in Debug, breaks in Release." You do not
debug UB by reasoning about what the CPU *did*; you remove it by construction and prove its absence
with sanitizers.

Static analysis (clang-tidy, cppcheck) and dynamic sanitizers catch **disjoint** bug classes — run
both. Sanitizers only see the paths your tests exercise, so coverage matters.

## The catalog

| Class | What it is | Caught by | Fix |
| --- | --- | --- | --- |
| Lifetime / dangling | reference or pointer to a destroyed object (returned local, dangling iterator after `push_back`, view outliving its owner) | ASan (heap/stack-use-after-scope) | return by value; own with `unique_ptr`; never store a `string_view`/`span` past its backing's lifetime |
| Use-after-move | reading an object after `std::move` (valid but unspecified state) | clang-tidy (`bugprone-use-after-move`) — **not** ASan | reassign before reading, or don't read it |
| Out-of-bounds | index/iterator past the end of a container or array | ASan | `.at()` or a bounds-checked view; range-for / ranges; never trust an external index |
| Signed integer overflow | `INT_MAX + 1`, etc. (UB; unsigned wraps, signed does not) | UBSan | use a wider type, check before, or `<numeric>`/`ckd_add` (C++26) overflow-checked ops |
| Strict aliasing | reading an object through an unrelated pointer type | UBSan (partial); compiler `-Wstrict-aliasing` | `std::bit_cast` (C++20) or `memcpy`, never a reinterpret_cast pun |
| Uninitialized read | reading a variable before assigning it | UBSan (MemorySanitizer for full coverage) | always initialize (`int n{};`); enable `-Wuninitialized` |
| Data race | two threads access the same memory, one writes, no synchronization | TSan | a mutex/`scoped_lock`, `atomic<T>`, or don't share mutable state |
| Null / misaligned deref | dereferencing `nullptr` or a misaligned pointer | UBSan | check before deref; references can't be null — prefer them |
| Invalid downcast / enum | `static_cast` to the wrong dynamic type; out-of-range enum value | UBSan (`vptr`, `enum`) | `dynamic_cast` when polymorphic; validate enum inputs |

## Sanitizer flag combinations & caveats

- **ASan + UBSan together:** `-fsanitize=address,undefined -fno-omit-frame-pointer -g`. This is the
  everyday build for tests and the local gate. Add `-fsanitize=integer` (Clang) to extend UBSan to
  unsigned wraparound you care about.
- **TSan alone:** `-fsanitize=thread -g`. It is **incompatible** with ASan — never combine them. Run
  it as a separate build/CI job over your concurrent tests.
- **MemorySanitizer** (Clang) for uninitialized reads needs *all* code (including libc++)
  instrumented; usually overkill — `-Wuninitialized` + always-initialize covers most cases.
- Sanitizers slow execution ~2–10x and need `-g` and frame pointers for readable stacks. They are a
  test/CI tool, not a production build.
- Tune at runtime via env: `ASAN_OPTIONS=detect_leaks=1:abort_on_error=1`,
  `UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1`.

## Worked fixes

```cpp
// Dangling reference (ASan: stack-use-after-return).
const std::string& bad() { std::string s = make(); return s; }   // s dies at the brace
std::string good() { return make(); }                            // by value; RVO elides the copy

// Iterator invalidation (ASan: heap-use-after-free).
for (auto it = v.begin(); it != v.end(); ++it)
    if (*it == x) v.push_back(*it);            // Bad: push_back may realloc, it now dangles
auto n = std::ranges::count(v, x);             // Good: compute first, then mutate

// Signed overflow (UBSan: signed-integer-overflow).
int total = a + b;                             // Bad if a+b > INT_MAX
auto total = std::int64_t{a} + b;              // Good: widen before the add

// Strict aliasing (type pun).
float f = *reinterpret_cast<float*>(&i);       // Bad: UB
auto f = std::bit_cast<float>(i);              // Good: C++20, defined
```

## Reading an ASan report

A typical use-after-free report has three stacks — read them bottom-up by *event*:

```
==12345==ERROR: AddressSanitizer: heap-use-after-free on address 0x602...
READ of size 4 at 0x602... thread T0
    #0 0x... in Cache::get(int) src/cache.cpp:42      <- where the bad access happened
    ...
0x602... is located 0 bytes inside of 4-byte region [0x602..,0x602..)
freed by thread T0 here:                              <- who freed it (the delete/dtor)
    #0 0x... operator delete(void*)
    #1 0x... in Cache::evict(int) src/cache.cpp:31
previously allocated by thread T0 here:               <- who allocated it
    #0 0x... operator new(unsigned long)
    #1 0x... in Cache::put(int,int) src/cache.cpp:18
```

Procedure: (1) the top READ/WRITE frame is the *symptom* line; (2) "freed by" is the line that ended
the object's life too early; (3) "previously allocated" is its birth. The bug is almost always that
the "freed by" path runs while a pointer/reference/iterator captured between allocation and the
symptom is still in use. The fix is an ownership fix — usually replacing the raw owning pointer with
a `unique_ptr`/`shared_ptr` so the lifetime can't be cut short, or extending the owner's scope.

For data races, TSan prints the two conflicting accesses (read/write) with both stacks and the thread
that created each; the fix is a single mutex/`scoped_lock` or an `atomic<T>` guarding that memory.
