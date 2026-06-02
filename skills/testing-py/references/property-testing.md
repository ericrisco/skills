# Property testing reference

Depth behind the SKILL.md Hypothesis section: the strategy catalog, composite strategies, settings/profiles for CI vs local, regression pinning, the example DB, and stateful testing.

Hypothesis is at 6.155.x (2026-06). The model: declare *strategies* describing the input space, assert a *property* that must hold for every input, and let Hypothesis search for a counterexample. On failure it **shrinks** the input to the minimal failing case and stores it in the `.hypothesis/` example database so the exact failure replays.

## Strategy catalog

```python
from hypothesis import strategies as st

st.integers(min_value=0, max_value=100)
st.floats(allow_nan=False, allow_infinity=False)
st.text()                              # arbitrary unicode
st.text(alphabet="abc", min_size=1)
st.from_regex(r"\d{3}-\d{4}", fullmatch=True)   # strings matching a pattern
st.lists(st.integers(), min_size=1, max_size=10, unique=True)
st.dictionaries(st.text(), st.integers())
st.sampled_from(["GET", "POST", "PUT"])
st.one_of(st.none(), st.integers())
st.datetimes()
st.builds(User, name=st.text(), age=st.integers(0, 120))   # construct a dataclass/object
```

`st.builds(Klass, ...)` is the workhorse for generating valid domain objects — give it the constructor and a strategy per field.

## Composite strategies

When fields are interdependent (a `start` before an `end`), build them together:

```python
@st.composite
def date_ranges(draw):
    start = draw(st.datetimes())
    end = draw(st.datetimes(min_value=start))
    return (start, end)

@given(date_ranges())
def test_range_duration_nonnegative(rng):
    start, end = rng
    assert (end - start).total_seconds() >= 0
```

## Common property shapes

- **Roundtrip:** `decode(encode(x)) == x` — for serializers, codecs, parsers.
- **Idempotence:** `f(f(x)) == f(x)` — for normalizers, dedupers, sorts.
- **Invariant:** `len(sort(xs)) == len(xs)` and output is ordered — structure preserved.
- **Oracle / cross-check:** the fast implementation agrees with a slow obviously-correct one.
- **Metamorphic:** `sum(xs + ys) == sum(xs) + sum(ys)` — a relation between related inputs.

## assume vs filter

Use `assume(predicate)` to discard a generated input that is not a valid case. Prefer it over `st.filter` when the rejection is rare; if you reject most inputs, narrow the strategy instead (Hypothesis raises on too many filtered examples).

```python
from hypothesis import assume

@given(st.integers())
def test_inverse(n):
    assume(n != 0)        # division undefined at 0; skip it
    assert (1 / n) * n == pytest.approx(1)
```

## Pinning regressions with @example

When a property test finds a bug, the example DB replays it locally — but pin it explicitly so it survives a cleared DB and documents the case:

```python
from hypothesis import given, example

@given(st.text())
@example("")            # the empty string broke us once; never regress
@example("‮")      # a right-to-left override broke the parser once
def test_parse(s):
    assert parse(s) is not None
```

## Settings and profiles

Run fewer examples locally for speed, more in CI for thoroughness:

```python
from hypothesis import settings, HealthCheck

settings.register_profile("ci", max_examples=1000, deadline=None)
settings.register_profile("dev", max_examples=50)
# select with: HYPOTHESIS_PROFILE=ci pytest   (or settings.load_profile(...))
```

`deadline` aborts an example that runs too long (default 200ms); set `deadline=None` for legitimately slow code rather than letting it flake, and bound the strategy so examples stay cheap. Suppress `HealthCheck.too_slow` only when you have a concrete reason.

## The example database in CI

The `.hypothesis/examples` directory caches failing inputs so they replay first on the next run. To keep regression pinning across CI runs, persist that directory between builds (cache it) or commit it. Without persistence, CI re-searches from scratch and may not re-hit a rare failure, so combine the DB with explicit `@example` pins for anything important.

## Stateful testing

For systems whose correctness depends on a sequence of operations (a cache, a connection pool, a state machine), use `RuleBasedStateMachine`: declare `@rule` methods Hypothesis sequences randomly, with `@invariant` checks after each step. It finds order-dependent bugs that single-call property tests miss. Reach for it when "the bug only happens after a specific sequence of calls" — see the Hypothesis stateful-testing docs for the full API.
