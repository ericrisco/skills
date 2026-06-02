# Ownership, borrowing, lifetimes

Deep dive on the model SKILL.md front-loads. Read this when the borrow checker is in your way.

## Move vs borrow vs clone

Every value has exactly one owner. Three things can happen when you pass it:

- **Move** — ownership transfers; the source binding is dead afterward. Default for non-`Copy` types
  (`String`, `Vec<T>`, structs holding them).
- **Borrow** — `&T` (shared, many at once, read-only) or `&mut T` (exclusive, exactly one, read-write).
  No transfer; the owner keeps the value.
- **Clone** — `.clone()` makes an independent copy. Real cost (allocation for heap types). Legitimate
  when you genuinely need two independent owners; a smell when used only to dodge a borrow error.

`Copy` types (`i32`, `bool`, `f64`, `char`, small tuples of `Copy`) are bitwise-copied on assignment, so
they are never "moved away" — no E0382 for them.

Rule of thumb for APIs: **borrow on the way in, own on the way out.** Take `&str`/`&[T]`, return
`String`/`Vec<T>`. Take `impl AsRef<str>` when you want to accept both `&str` and `String` ergonomically.

## The borrow-checker error catalog

| Error | Meaning | Typical fix |
| --- | --- | --- |
| E0382 "value moved here" / "borrow of moved value" | Used a value after moving it | Borrow instead of move; clone only if two owners are truly needed |
| E0499 "cannot borrow as mutable more than once" | Two `&mut` overlap | Scope the first borrow so it ends before the second |
| E0502 "already borrowed as immutable" | `&mut` while a `&` is live | Don't mutate through one path while reading through another; collect first, mutate after |
| E0505 "cannot move out … borrowed" | Moved a value that is still borrowed | End the borrow (drop/scope) before moving |
| E0597 "does not live long enough" | A reference outlives its referent | Return an owned value, or make the owner outlive the borrow |
| E0515 "returns a reference to data owned by the current function" | Returning a borrow of a local | Return the owned value, or take the buffer as a `&mut` param |

Non-lexical lifetimes mean a borrow ends at its last *use*, not at the end of the block — so often just
reordering statements (move the read before the write) resolves E0502 with no restructuring.

## Lifetimes & `'static`

A lifetime annotation (`'a`) names how long a reference is valid; the compiler infers most of them
(elision). You only annotate when a function returns a reference whose lifetime ties to an input:

```rust
// The returned &str lives as long as the input slice.
fn first_word<'a>(s: &'a str) -> &'a str {
    s.split_whitespace().next().unwrap_or("")
}
```

`'static` means "valid for the whole program" — string literals are `&'static str`. `T: 'static` as a
bound (common in `tokio::spawn`) means "contains no non-`'static` references", i.e. it owns its data; it
does **not** mean the value lives forever. Prefer owned data over lifetime-threaded structs when the
lifetimes get noisy — a `String` field is simpler than a `&'a str` field that infects every caller.

## `Cow` — clone on write

`Cow<'_, str>` lets a function return a borrow when it can and an owned value only when it must:

```rust
use std::borrow::Cow;
fn normalize(input: &str) -> Cow<'_, str> {
    if input.contains(' ') { Cow::Owned(input.replace(' ', "_")) } // allocate only when changed
    else { Cow::Borrowed(input) }                                  // zero-copy fast path
}
```

## Smart pointers — the full tree

```text
Need a value on the heap / a trait object / recursion?  -> Box<T>
Shared ownership, single-threaded?                       -> Rc<T>
Shared ownership, across threads or .await?              -> Arc<T>
Mutate through a shared ref, single-threaded?            -> RefCell<T>   (runtime borrow check)
Mutate through a shared ref, single-threaded + Rc?       -> Rc<RefCell<T>>
Mutate shared state across threads (sync)?               -> Arc<Mutex<T>> / Arc<RwLock<T>>
Mutate shared state across .await?                       -> Arc<tokio::sync::Mutex<T>> (or a channel)
```

`Rc`/`RefCell` are **not** thread-safe and will not compile across threads — the compiler enforces it via
`Send`/`Sync`. Reach for `Arc` the moment a value crosses a thread or an `.await` point.

## Interior mutability

`RefCell<T>` moves the borrow check to runtime: `.borrow()` / `.borrow_mut()` panic on a violation
(two mutable borrows). Use it only when the compile-time check is genuinely too strict (e.g. a graph,
an observer registry). For atomics and counters prefer `std::sync::atomic` types or `Mutex`; for
shared async state prefer a channel (message passing) over `Arc<Mutex<T>>` (shared memory) whenever the
data really flows in one direction.
