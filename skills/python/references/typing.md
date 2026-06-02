# Typing — deep dive

Read when the SKILL.md typing section is not enough: generic bounds/variance, structural vs
nominal typing, `TypedDict` precision, callable-shape generics, narrowing, and the common
`mypy --strict` errors and their fixes.

## PEP 695 generics in full (Python 3.12+)

Inline type parameters replace explicit `TypeVar` objects for new code.

```python
# Bound: T must be (a subtype of) Comparable.
from typing import Protocol

class Comparable(Protocol):
    def __lt__(self, other: object) -> bool: ...

def smallest[T: Comparable](xs: list[T]) -> T:
    return min(xs)

# Constraints: T is exactly one of these types (not "any subtype").
def join[T: (str, bytes)](sep: T, parts: list[T]) -> T:
    return sep.join(parts)

# Generic class and a generic method on it.
class Stack[T]:
    def __init__(self) -> None:
        self._items: list[T] = []
    def push(self, item: T) -> None:
        self._items.append(item)
    def pop(self) -> T:
        return self._items.pop()

# The `type` statement: a true alias, lazily evaluated, can be generic.
type Pair[T] = tuple[T, T]
type Json = dict[str, "Json"] | list["Json"] | str | int | float | bool | None
```

**Variance** is inferred by the checker from how a type parameter is used — you no longer
declare `covariant=`/`contravariant=`. A `list[T]` is invariant; a read-only `Sequence[T]`
behaves covariantly. When you need an explicit infer-variance marker, PEP 695 exposes it, but
in practice let the checker decide and fix the reported error.

Legacy `TypeVar`/`Generic` syntax is **not deprecated** and may be mixed with the new syntax
in the same file — but write PEP 695 for anything new.

## Protocol (structural) vs ABC (nominal)

- **`Protocol`**: duck typing the checker enforces. A class satisfies it by *shape*, with no
  inheritance. Use for "anything with these methods". Add `@runtime_checkable` only if you need
  `isinstance` against it (it checks method presence, not signatures).
- **ABC** (`abc.ABC` + `@abstractmethod`): nominal — subclasses must explicitly inherit. Use
  when you own the hierarchy and want to *share implementation* or force registration.

```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class Closeable(Protocol):
    def close(self) -> None: ...

def shut(x: Closeable) -> None:
    x.close()        # any object with close()->None type-checks; no base class needed
```

Prefer `Protocol` for boundaries you consume from elsewhere; reserve ABCs for frameworks you author.

## TypedDict — Required / NotRequired

Types a plain dict (e.g. a JSON payload) without a runtime class.

```python
from typing import TypedDict, Required, NotRequired

class Config(TypedDict):
    name: Required[str]
    retries: NotRequired[int]     # key may be absent

# total=False flips the default: every key NotRequired unless marked Required.
class Patch(TypedDict, total=False):
    name: str
    retries: int
```

For closed value sets inside a dict field, combine with `Literal`. When you need *runtime
validation* of the dict (untrusted input), that is a Pydantic/service concern -> `fastapi`.

## Callable shapes: ParamSpec and TypeVarTuple

```python
from collections.abc import Callable
from functools import wraps

# ParamSpec: preserve the wrapped function's full signature through a decorator.
def timed[**P, R](fn: Callable[P, R]) -> Callable[P, R]:
    @wraps(fn)
    def inner(*args: P.args, **kwargs: P.kwargs) -> R:
        return fn(*args, **kwargs)
    return inner

# TypeVarTuple: variadic generics over an arbitrary number of types.
def first_and_rest[T, *Ts](x: T, *rest: *Ts) -> tuple[T, tuple[*Ts]]:
    return x, rest
```

## @overload — signature families

When one function has distinct return types per argument shape, declare overloads then a single
untyped-to-the-caller implementation:

```python
from typing import overload

@overload
def get(key: str) -> str: ...
@overload
def get(key: str, default: int) -> str | int: ...
def get(key: str, default: int | None = None) -> str | int:
    ...
```

## Narrowing: guards, TypeGuard, TypeIs

Mypy follows control flow, so `isinstance`, `is None`, and `assert` narrow automatically.
For custom predicates use `TypeIs` (3.13+, narrows in both branches) or `TypeGuard`:

```python
from typing import TypeIs

def is_str_list(xs: list[object]) -> TypeIs[list[str]]:
    return all(isinstance(x, str) for x in xs)

def handle(xs: list[object]) -> None:
    if is_str_list(xs):
        xs[0].upper()        # narrowed to list[str] here
```

Use `typing.cast(T, value)` only as a last resort when you know more than the checker; it is an
unchecked assertion. `reveal_type(x)` (no import needed under mypy) prints the inferred type at
check time — delete it before committing.

## Common `mypy --strict` errors and fixes

| Error | Fix |
| --- | --- |
| `Function is missing a return type annotation` | Add `-> T` (use `-> None` for procedures). |
| `Need type annotation for "x"` | Annotate the empty container: `x: list[int] = []`. |
| `Returning Any from function declared to return "T"` | Type the source, or `cast` if truly unknowable. |
| `Incompatible default for argument` | A `None` default needs `X | None` in the type. |
| `Item "None" of "X | None" has no attribute ...` | Narrow with `if v is None: return` first. |
| `Untyped decorator makes function "f" untyped` | Type the decorator with `ParamSpec` (see above). |
| `Call to untyped function in typed context` | Add hints to the callee, or stub it. |

## 3.14: deferred annotations

Annotations are evaluated **lazily by default** (PEP 649/749): forward references resolve
without `from __future__ import annotations`, recursive type aliases just work, and the new
`annotationlib` module inspects annotations as live objects (`get_annotations`). `types.UnionType`
is now an alias for `typing.Union`. Drop the `__future__` import in 3.14-only code; keep it for
3.12/3.13 compatibility.
