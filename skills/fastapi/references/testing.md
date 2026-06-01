# Testing async FastAPI

Deep-dive companion to `SKILL.md → Testing (embedded summary)`. The goal: fast, isolated,
async-correct tests that hit the real ASGI app over `httpx.ASGITransport`, run against a
**real PostgreSQL 16** inside a per-test transaction that rolls back, and gate CI on
coverage. No `TestClient`-only patterns, no SQLite-as-Postgres pretending, no leaking state
between tests.

## Setup & config

Configure pytest once in `pyproject.toml`. `asyncio_mode = "auto"` means every `async def
test_*` runs without an explicit `@pytest.mark.asyncio`.

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
addopts = [
    "--strict-markers",
    "--cov=app",
    "--cov-report=term-missing",
    "--cov-fail-under=85",
]
filterwarnings = ["error"]
```

Install the test toolchain as dev dependencies:

```bash
uv add --dev pytest pytest-asyncio pytest-cov httpx respx testcontainers[postgres]
```

## Test DB strategy

Test against a **real PostgreSQL 16**, not SQLite. SQLite lacks Postgres types (`UUID`,
`JSONB`, arrays, `tsvector`), enforces constraints differently, and has different SQL
semantics — green-on-SQLite tests routinely break on production Postgres. Spin up a
disposable container with `testcontainers` (or point at a dedicated throwaway test DB).
A session-scoped engine fixture creates the schema once and disposes it at the end.

```python
import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from testcontainers.postgres import PostgresContainer

from app.db.base import Base


@pytest.fixture(scope="session")
async def engine():
    with PostgresContainer("postgres:16-alpine") as pg:
        url = pg.get_connection_url().replace("psycopg2", "asyncpg")
        eng = create_async_engine(url)
        async with eng.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        yield eng
        await eng.dispose()
```

For an existing test DB instead of a container, read its URL from an env var
(`APP_TEST_DATABASE_URL`) and skip the `PostgresContainer` block; everything downstream is
identical.

## Transactional isolation fixture

The canonical SQLAlchemy 2.0 async per-test rollback recipe. Open a connection, begin an
outer transaction on it, and bind an `AsyncSession` with
`join_transaction_mode="create_savepoint"`. With that mode, every `session.commit()` the
service code runs only releases an internal SAVEPOINT — the outer transaction stays open and
is rolled back at teardown, so the DB is pristine between tests with no `create_all` /
`drop_all` per test. The mode is built into SQLAlchemy 2.0+, so the old
`after_transaction_end` event listener that manually restarted savepoints is no longer
needed.

```python
import pytest
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.fixture
async def db_session(engine) -> AsyncSession:
    async with engine.connect() as connection:
        outer = await connection.begin()
        session = AsyncSession(
            bind=connection,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",  # commits become SAVEPOINT releases
        )
        try:
            yield session
        finally:
            await session.close()
            await outer.rollback()  # discard everything the test wrote
```

The session's `commit()` calls never reach the database as real commits, so each test sees a
clean schema and the rollback at teardown leaves no residue for the next test.

## The async client fixture

Put this in `conftest.py`. It builds the app, swaps the request `get_db` for the
transactional test session, and drives it over `ASGITransport` (in-process, no socket).
`base_url="http://test"` satisfies httpx's absolute-URL requirement.

Build the app in its own fixture so other fixtures (auth, feature flags) can register
`dependency_overrides` on the *same* instance the client drives — no reaching into
`client._transport.app`.

```python
import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.deps import get_db
from app.main import create_app


@pytest.fixture
def app(db_session) -> FastAPI:
    application = create_app()
    application.dependency_overrides[get_db] = lambda: db_session
    return application


@pytest.fixture
async def client(app: FastAPI) -> AsyncClient:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
```

The override yields the **same** `db_session` the test sees, so assertions made directly on
the session observe exactly what the handler wrote (before rollback).

## Auth override fixture

Two strategies. Use (a) for the common case — you want to test business logic, not the JWT
machinery. Use (b) when you are specifically exercising the decode/claims path.

```python
# (a) Inject a fixed user, bypassing the real token decode.
import pytest
from fastapi import FastAPI

from app.api.deps import get_current_user
from app.models.user import User


@pytest.fixture
async def auth_client(app: FastAPI, client, db_session) -> AsyncClient:
    user = User(email="auth@example.com", full_name="Auth", hashed_password="x")
    db_session.add(user)
    await db_session.flush()
    # Override on the same app the client drives — no client._transport.app reach-in.
    app.dependency_overrides[get_current_user] = lambda: user
    return client
```

```python
# (b) Mint a real JWT and send it through the real get_current_user decode path.
import pytest

from app.core.security import create_access_token


@pytest.fixture
async def bearer_headers(db_session) -> dict[str, str]:
    from app.models.user import User

    user = User(email="real@example.com", full_name="Real", hashed_password="x")
    db_session.add(user)
    await db_session.flush()
    token = create_access_token(subject=str(user.id))
    return {"Authorization": f"Bearer {token}"}
```

## Factories & fixtures

Prefer plain async builder functions over global factory state — explicit, mypy-friendly,
no hidden sequences. Override any field per call.

```python
from app.models.user import User
from sqlalchemy.ext.asyncio import AsyncSession


async def make_user(db: AsyncSession, **overrides) -> User:
    defaults = {"email": "u@example.com", "full_name": "U", "hashed_password": "x"}
    user = User(**{**defaults, **overrides})
    db.add(user)
    await db.flush()
    return user
```

Parametrize with readable `ids=` so failures name the case:

```python
import pytest


@pytest.mark.parametrize(
    ("payload", "expected_field"),
    [
        ({"email": "bad", "full_name": "A", "password": "x" * 12}, "email"),
        ({"email": "a@b.com", "full_name": "", "password": "x" * 12}, "full_name"),
        ({"email": "a@b.com", "full_name": "A", "password": "short"}, "password"),
    ],
    ids=["bad-email", "empty-name", "short-password"],
)
async def test_validation_fields(client, payload, expected_field) -> None:
    resp = await client.post("/api/v1/users", json=payload)
    assert resp.status_code == 422
    assert resp.json()["error"]["details"][0]["field"] == expected_field
```

## Testing endpoints

Cover the happy path, the created-201 contract, the validation envelope, and domain errors.

```python
from httpx import AsyncClient

from tests.factories import make_user


async def test_list_users_pagination(client: AsyncClient, db_session) -> None:
    for i in range(3):
        await make_user(db_session, email=f"u{i}@example.com")
    resp = await client.get("/api/v1/users", params={"limit": 2, "offset": 0})
    assert resp.status_code == 200
    assert len(resp.json()) == 2


async def test_create_user_201_location(client: AsyncClient) -> None:
    resp = await client.post("/api/v1/users", json={
        "email": "new@example.com", "full_name": "New", "password": "correct-horse-battery",
    })
    assert resp.status_code == 201
    assert resp.headers["Location"].startswith("/api/v1/users/")
    assert "hashed_password" not in resp.json()


async def test_create_user_validation_envelope(client: AsyncClient) -> None:
    resp = await client.post("/api/v1/users", json={"email": "nope"})
    assert resp.status_code == 422
    body = resp.json()
    assert body["error"]["code"] == "validation_error"
    assert body["error"]["details"][0]["field"]


async def test_duplicate_email_conflict(client: AsyncClient, db_session) -> None:
    await make_user(db_session, email="dupe@example.com")
    resp = await client.post("/api/v1/users", json={
        "email": "dupe@example.com", "full_name": "Dupe", "password": "correct-horse-battery",
    })
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "conflict"
```

## Testing background tasks & external calls

Mock outbound httpx with **respx** — never hit the network in unit tests.

```python
import httpx
import respx


@respx.mock
async def test_outbound_call(client: httpx.AsyncClient) -> None:
    route = respx.post("https://payments.example.com/charge").mock(
        return_value=httpx.Response(200, json={"status": "ok"})
    )
    resp = await client.post("/api/v1/orders", json={"amount": 100})
    assert resp.status_code == 201
    assert route.called
```

For `BackgroundTasks`, assert the side effect by overriding the task target with a spy
(e.g. `monkeypatch.setattr("app.services.email.send_welcome_email", spy)`) and asserting the
spy was awaited with the expected args — the task runs after the response is sent, so make
the override visible before the request.

## TDD discipline

Red → green → refactor for a new `GET /users/{id}`. Follow
`superpowers:test-driven-development`: write the failing test first, watch it fail, then
write the minimum to pass.

```python
# RED — write this first; it fails (404/route missing).
async def test_get_user_by_id(client, db_session) -> None:
    user = await make_user(db_session, email="byid@example.com")
    resp = await client.get(f"/api/v1/users/{user.id}")
    assert resp.status_code == 200
    assert resp.json()["email"] == "byid@example.com"
```

```python
# GREEN — minimal handler + service to pass.
# app/services/user_service.py
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import NotFoundError
from app.models.user import User


async def get_user(db: AsyncSession, user_id: UUID) -> User:
    user = await db.get(User, user_id)
    if user is None:
        raise NotFoundError("User", str(user_id))
    return user


# app/api/routers/users.py
from uuid import UUID

from app.api.deps import DbSession
from app.schemas.user import UserResponse


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: UUID, db: DbSession) -> UserResponse:
    return await user_service.get_user(db, user_id)
```

Refactor step: once green, extract shared lookup, add the 404-envelope test, and confirm the
suite stays green before moving on.

## Coverage gate & CI

```bash
uv run pytest --cov=app --cov-report=term-missing
```

`--cov-fail-under=85` in `pyproject.toml` is the single source of truth — do not pass a
second threshold on the command line. Add `--cov-branch` for branch coverage; the lines that
*must* be covered are the auth and error paths: 401, 403, 404, 409, 422, and the catch-all
500. In CI, run `uv run pytest` after `ruff` and `mypy` so a failing lint/type check blocks
before the (slower) test job.

## See Also

- [`database.md`](database.md) — the engine/session wiring these fixtures build on.
- [`security.md`](security.md) — `create_access_token` and `get_current_user` used by the auth fixtures.
- `superpowers:test-driven-development` — red/green/refactor discipline these tests follow.
