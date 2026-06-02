# Mocking reference

Depth behind the SKILL.md mocking section: the where-to-patch worked example, the autospec/spec/spec_set ladder, side effects and call assertions, and faking time/HTTP/DB/filesystem/async.

## Where to patch — a full worked example

The rule: **patch the name the module under test looks up at call time**, not the name in the library where it was defined.

```python
# mymod.py
from httpx import Client          # `Client` is now bound as mymod.Client

def fetch(url: str) -> dict:
    with Client(timeout=5) as c:
        return c.get(url).raise_for_status().json()
```

```python
# test_mymod.py
from unittest.mock import patch, create_autospec
import httpx
import mymod

# Bad: patches httpx.Client. mymod already bound its own `Client` at import time,
# so this changes a name mymod never reads again. The real client runs. Test hits the network.
def test_fetch_bad():
    with patch("httpx.Client") as m:        # NO EFFECT on mymod.Client
        mymod.fetch("https://x")            # makes a real request

# Good: patch the name in mymod, autospec'd so the fake matches httpx.Client's real API.
def test_fetch_good():
    fake_client = create_autospec(httpx.Client, instance=True)
    resp = create_autospec(httpx.Response, instance=True)
    resp.raise_for_status.return_value = resp
    resp.json.return_value = {"ok": True}
    fake_client.get.return_value = resp
    fake_client.__enter__.return_value = fake_client   # support `with Client(...)`

    with patch("mymod.Client", return_value=fake_client):
        assert mymod.fetch("https://x") == {"ok": True}   # assert on behavior
        fake_client.get.assert_called_once_with("https://x")
```

The cleaner alternative is to **not patch at all**: pass the client in as an argument (dependency injection) and hand the test a fake. Patching is the tool when you cannot change the signature.

## autospec vs spec vs spec_set

| Form | What it enforces | Use when |
|---|---|---|
| `Mock()` (no spec) | nothing — any attribute exists | almost never; this is the false-green factory |
| `Mock(spec=Klass)` | attribute names match `Klass`, signatures **not** checked on the instance | a quick guard against typo'd attributes |
| `create_autospec(Klass)` / `patch(..., autospec=True)` | attribute names **and** call signatures recursively | the default for any non-trivial fake |
| `Mock(spec_set=Klass)` | like spec, and **setting** an unknown attr also raises | locking a fake so the test can't drift |

Autospec is recursive: `create_autospec(Client).get.return_value.json` is itself signature-checked. The cost is that you configure return values explicitly, which is the point — the fake can't quietly diverge from the real object.

## return_value, side_effect, asserting calls

```python
m.return_value = 42                      # every call returns 42
m.side_effect = ConnectionError("down")  # every call raises
m.side_effect = [1, 2, 3]                # successive calls return 1, then 2, then 3
m.side_effect = lambda x: x * 2          # compute from args

m.assert_called_once_with(url, timeout=5)   # exact args, exactly once
m.assert_not_called()
assert m.call_count == 2
args, kwargs = m.call_args                  # inspect the last call when needed
```

Assert on the **return value or observable effect** of the code under test, plus the *contract* with the boundary (it was called with the right URL). Never assert on `m._mock_children`, `m._mock_calls` internals, or other private attributes — those break on refactors that didn't change behavior.

## Faking time

Do not `time.sleep`. Inject or patch the clock.

```python
# Best: the code reads a clock you can swap.
def expired(token, *, now=time.time):
    return token.exp < now()

def test_expired(monkeypatch):
    assert expired(tok, now=lambda: 10_000)   # no patching needed at all
```

For pervasive `datetime.now()` use `freezegun`:

```python
from freezegun import freeze_time

@freeze_time("2026-06-02T12:00:00Z")
def test_stamp():
    assert record().created_at.year == 2026
```

## Faking HTTP

Two clean options:

- **`respx`** (for `httpx`) / **`responses`** (for `requests`): intercept at the transport layer, so your real client code runs and you assert on the request.

```python
import respx, httpx
@respx.mock
def test_fetch():
    route = respx.get("https://x").mock(return_value=httpx.Response(200, json={"ok": True}))
    assert mymod.fetch("https://x") == {"ok": True}
    assert route.called
```

- **autospec the client** (shown above) when you want zero network layer at all.

Prefer transport interception when you care that the right request was built; prefer autospec when the client is an injected dependency.

## Faking the DB and filesystem

- **Filesystem:** use the built-in `tmp_path` (a `pathlib.Path` to a unique temp dir) and `tmp_path_factory` for session scope. Never write to the repo or `/tmp` by hand.
- **DB:** prefer a real in-memory or `tmp_path` sqlite over a mock — it tests your SQL, not your mock of SQL. Mock the DB only when the boundary is a remote service you don't run in CI.

```python
def test_store(tmp_path):
    store = Store(tmp_path / "t.db")   # real sqlite, isolated, auto-cleaned
    store.put("k", "v")
    assert store.get("k") == "v"
```

## Async code

Use `AsyncMock` (it returns awaitables) and run under `pytest.mark.asyncio` or `anyio`:

```python
from unittest.mock import AsyncMock, patch

async def test_afetch():
    with patch("mymod.aget", new_callable=AsyncMock) as m:
        m.return_value = {"ok": True}
        assert await mymod.afetch("https://x") == {"ok": True}
        m.assert_awaited_once_with("https://x")   # note: awaited, not called
```

`create_autospec` of an async function yields an `AsyncMock` automatically, so autospec still applies.
