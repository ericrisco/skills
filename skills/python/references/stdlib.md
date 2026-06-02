# Stdlib cookbook

Read when reaching for the standard library before a dependency. Recipes for
`pathlib`/`itertools`/`functools`/`collections`/`contextlib`, the `match` statement, the
dataclass field machinery, and Enum patterns.

## pathlib

```python
from pathlib import Path

root = Path(__file__).resolve().parent
cfg = root / "config" / "app.toml"        # join with /
cfg.read_text(encoding="utf-8")
cfg.with_suffix(".bak")                    # app.bak
list(root.glob("**/*.py"))                 # recursive
cfg.parent.mkdir(parents=True, exist_ok=True)
```

`Path` is typed, OS-independent, and composable — use it everywhere instead of `os.path` string
joins. For just-a-string interop, `str(path)` or pass the `Path` directly (most stdlib accepts it).

## collections

```python
from collections import defaultdict, Counter, deque

groups: defaultdict[str, list[int]] = defaultdict(list)
groups[key].append(n)                      # no KeyError, auto-creates the list

counts = Counter(words)
counts.most_common(3)                      # top 3 (word, count)

window: deque[int] = deque(maxlen=100)     # fixed-size ring buffer; old items drop off
window.append(x)
```

`ChainMap` layers several dicts (defaults <- env <- overrides) into one lookup.

## itertools

```python
from itertools import chain, groupby, islice, batched, pairwise

list(chain(a, b, c))                       # flatten iterables
list(islice(gen, 10))                      # first 10 of a (possibly infinite) generator
for size, group in groupby(rows, key=lambda r: r.size):   # input MUST be pre-sorted by key
    ...
list(batched(range(10), 3))                # 3.12+: [(0,1,2),(3,4,5),(6,7,8),(9,)]
list(pairwise([1, 2, 3]))                  # [(1,2),(2,3)]
```

## functools

```python
from functools import cache, cached_property, partial, reduce

@cache                                     # unbounded memo for a pure function
def fib(n: int) -> int:
    return n if n < 2 else fib(n - 1) + fib(n - 2)

class Report:
    @cached_property                       # computed once per instance, then stored
    def total(self) -> int:
        return sum(self.rows)

add5 = partial(add, 5)                     # pre-bind an argument
```

Prefer `@cache` over `@lru_cache(maxsize=None)`; keep `@lru_cache(maxsize=N)` only when you need
a bound.

## contextlib

```python
from contextlib import contextmanager, ExitStack, suppress

@contextmanager
def timer(label: str):
    start = time.perf_counter()
    try:
        yield
    finally:
        log.info("%s took %.3fs", label, time.perf_counter() - start)

with ExitStack() as stack:                 # dynamic, variable number of resources
    files = [stack.enter_context(open(p)) for p in paths]
    # all closed on block exit, in reverse order

with suppress(FileNotFoundError):          # ignore one specific error, cleanly
    Path("cache").unlink()
```

## The match statement

Structural pattern matching — dispatch on shape, not a chain of `isinstance`.

```python
def describe(value: object) -> str:
    match value:
        case []:
            return "empty list"
        case [x]:
            return f"one item: {x}"
        case [first, *rest]:
            return f"{first} and {len(rest)} more"
        case {"type": "point", "x": int(x), "y": int(y)}:
            return f"point {x},{y}"
        case Point(x=0, y=0):              # class pattern, captures by attribute
            return "origin"
        case str() | bytes():
            return "text-ish"
        case _:
            return "other"
```

Capture patterns bind names; `case _` is the wildcard. Guard with `case x if x > 0:`.

## dataclasses, in depth

```python
from dataclasses import dataclass, field

@dataclass(frozen=True, slots=True, kw_only=True)
class Order:
    id: str
    items: list[str] = field(default_factory=list)   # NEVER `= []` (shared mutable default)
    total: float = 0.0
    _cache: dict[str, int] = field(default_factory=dict, compare=False, repr=False)

    def __post_init__(self) -> None:
        if self.total < 0:                 # frozen: validate, don't mutate
            raise ValueError("total < 0")
```

- `frozen=True` -> immutable + hashable. `slots=True` -> no `__dict__`, less memory, faster attrs.
- `kw_only=True` -> all fields keyword-only (avoids positional-order foot-guns).
- `field(default_factory=...)` for any mutable default; `compare=False`/`repr=False` to exclude a field.
- `__post_init__` for validation/derived values (assign via `object.__setattr__` when frozen).

## Enum patterns

```python
from enum import Enum, StrEnum, IntEnum, IntFlag, auto

class Color(Enum):
    RED = auto()
    GREEN = auto()

class Status(StrEnum):                     # 3.11+: members ARE strings
    ACTIVE = "active"
    CLOSED = "closed"
# Status.ACTIVE == "active" -> True; great for JSON/DB string columns.

class Perm(IntFlag):                       # bitwise-combinable flags
    READ = auto()
    WRITE = auto()
    ALL = READ | WRITE
```

Use `StrEnum`/`IntEnum` when the value must interop as a primitive (JSON, DB); plain `Enum` for
opaque tokens. Pair an `Enum` with `Literal` types at boundaries for exhaustiveness checking.
