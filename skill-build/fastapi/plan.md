# IMPLEMENTATION PLAN — `fastapi` skill

This plan is executable verbatim by an implementer subagent. The source of truth is
`/Volumes/EXTERN/DEV/skills/skill-build/fastapi/spec.md`. Do not deviate. Every code block
below must be written **exactly** as specified (or filled out faithfully per the directive),
correct and runnable in context, with language tags. No placeholders, no `TODO`, no `etc.`.

Pinned stack versions to state inside the skill (use these literally where versions appear):
Python 3.12+, FastAPI 0.115+, Starlette 0.41+, Pydantic v2 (2.9+) + pydantic-settings 2.x,
SQLAlchemy 2.0 async, Alembic 1.13+, asyncpg 0.30 / psycopg 3, httpx 0.28+,
pytest 8 + pytest-asyncio 0.24+ (`asyncio_mode=auto`), ruff 0.7+, mypy 1.13+ strict,
uv 0.5+, uvicorn 0.32+ / gunicorn 23+, PyJWT 2.9, argon2-cffi 23+, pip-audit 2.7+,
PostgreSQL 16.

---

## 0. File list (exact paths)

Create exactly these files under `/Volumes/EXTERN/DEV/skills/skills/fastapi/`:

```text
/Volumes/EXTERN/DEV/skills/skills/fastapi/SKILL.md
/Volumes/EXTERN/DEV/skills/skills/fastapi/references/testing.md
/Volumes/EXTERN/DEV/skills/skills/fastapi/references/database.md
/Volumes/EXTERN/DEV/skills/skills/fastapi/references/security.md
/Volumes/EXTERN/DEV/skills/skills/fastapi/references/production.md
/Volumes/EXTERN/DEV/skills/skills/fastapi/scripts/verify.sh
```

Create the `references/` and `scripts/` directories first (`mkdir -p`). After writing
`verify.sh`, run `chmod +x` on it. Do **not** execute `verify.sh` in this repo.

---

## 1. `SKILL.md` — ordered section spec

Budget: **320–420 lines** total. One H1. Frontmatter exactly as below. Every deep topic gets
a 1–2 paragraph canonical pattern inline + an explicit `→ references/<file>.md` pointer. Keep
long material in references. All code blocks tagged (`python`, `toml`, `bash`, `text`).

### 1.0 Frontmatter (verbatim)

```yaml
---
name: fastapi
description: >
  Use when building, reviewing, testing, securing or deploying a FastAPI / async Python
  service. Triggers: creating endpoints/routers, Pydantic v2 models (Create/Update/Response),
  dependency injection, async SQLAlchemy 2.0 + Alembic, OAuth2/JWT auth + RBAC, pytest +
  httpx ASGITransport tests, CORS / rate limiting / secret handling, uvicorn/gunicorn +
  structured logging + healthchecks + graceful shutdown, pyproject + ruff + mypy strict + uv.
  Any .py file importing fastapi, pydantic, sqlalchemy, starlette, or a pyproject.toml
  declaring those.
origin: risco
---
```

### 1.1 `# FastAPI & modern Python services` (H1)

Opening 2 sentences: purpose + mental model. Write this paragraph:

> The single authoritative skill for building, reviewing, testing, securing and shipping an
> async FastAPI service on Python 3.12+. The mental model: **the app is a thin async HTTP
> layer over typed dependencies, a service/repository core, and explicit DB sessions. Routes
> validate and delegate; they never own business logic, raw SQL, or secrets.**

Then a one-line version banner listing the pinned stack (single sentence, the versions above).

### 1.2 `## When to use`

Bullets (from spec §1):
- Writing or reviewing any FastAPI route, router, dependency, schema, or app factory.
- Designing async DB access (SQLAlchemy 2.0), migrations (Alembic), or eager-loading.
- Adding auth (OAuth2 password flow + JWT), RBAC, password hashing.
- Writing pytest suites for an async API (ASGITransport, `dependency_overrides`, transactional DB).
- Hardening (CORS, rate limit, secrets, log redaction, dependency audit) or productionizing.
- Setting up `pyproject.toml`, ruff + mypy strict, uv/pip-tools dependency management.

### 1.3 `## When NOT to use`

Bullets:
- Django / Flask / DRF apps → not this skill.
- Sync WSGI services, data-science notebooks, CLI-only scripts with no HTTP surface.
- Pure REST contract questions (status codes, URL naming, versioning, cursor vs offset) → **See Also `api-design`**.
- Frontend/Next.js, Go, Flutter work → their own skills.
- Generic secure-coding rules not specific to Python/FastAPI → **See Also `secure-coding`**.
- Container/Compose/CI deploy mechanics → **See Also `deployment`** (this skill keeps only a Docker *note*).

### 1.4 `## Decision rules`

Numbered list 1–8, directive, verbatim intent from spec §2:
1. `async def` for any I/O route; use async drivers (asyncpg, httpx) — never `requests`, never sync `psycopg2`, never blocking calls in the event loop (offload with `await anyio.to_thread.run_sync` / `run_in_threadpool`).
2. Three Pydantic models per resource: `XCreate` / `XUpdate` / `XResponse` (`from_attributes=True`). Response models never leak hashes/tokens/internal flags.
3. All request-scoped resources via `Depends` (`Annotated[T, Depends(...)]`), never constructed inline in handlers — so tests can override them.
4. One DB session per request via `get_db` with commit-on-success / rollback-on-exception.
5. Every error leaves as the same envelope `{"error":{"code","message","details?"}}` via centralized handlers. Never leak stack traces / SQL.
6. Settings come from `pydantic-settings` (`BaseSettings`), never `os.getenv` scattered in code.
7. Validate JWT `exp`, `iss`, `aud`, and pin `algorithms=["RS256"|"HS256"]` explicitly.
8. Tests use `ASGITransport` + `dependency_overrides` against a transactional DB; CI gates on `ruff`, `mypy --strict`, `pytest --cov`, `pip-audit`.

### 1.5 `## Project layout`

One `text` fenced block (src-layout). Write exactly:

```text
app/
├── main.py            # create_app() factory + lifespan; app = create_app()
├── core/
│   ├── config.py      # Settings(BaseSettings) + get_settings()
│   ├── security.py    # hashing, JWT encode/decode
│   └── logging.py     # structlog / JSON logging setup
├── api/
│   ├── deps.py        # get_db, get_current_user, Pagination, require_roles
│   └── routers/
│       ├── users.py
│       └── health.py
├── schemas/           # Pydantic v2 models (Create/Update/Response)
│   └── user.py
├── models/            # SQLAlchemy 2.0 DeclarativeBase models
│   └── user.py
├── db/
│   ├── base.py        # engine, async_sessionmaker, Base
│   └── repository.py  # generic async Repository[ModelT]
├── services/          # business logic (no FastAPI imports)
│   └── user_service.py
├── exceptions.py      # AppError hierarchy + register_exception_handlers
tests/                 # pytest-asyncio + ASGITransport
alembic/               # async env.py + versions/
pyproject.toml         # ruff + mypy strict + pytest config
```

One sentence after: routers thin, services hold logic, repository/CRUD owns persistence.

### 1.6 `## Application factory + lifespan`

One `python` block. Copy-paste `create_app()` with `@asynccontextmanager lifespan`. Must show:
engine init on enter, `await engine.dispose()` on exit, CORS middleware (explicit methods/headers),
exception handler registration, router registration, `app = create_app()` at bottom. Write:

```python
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routers import health, users
from app.core.config import get_settings
from app.db.base import engine
from app.exceptions import register_exception_handlers


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: connections/caches are created here, never at import time.
    yield
    # Shutdown: release pooled connections so workers exit cleanly.
    await engine.dispose()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.api_title, version=settings.api_version, lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,            # explicit list, never ["*"] with creds
        allow_credentials=bool(settings.cors_origins),
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
        allow_headers=["Authorization", "Content-Type"],
    )

    register_exception_handlers(app)
    app.include_router(health.router, prefix="/health", tags=["health"])
    app.include_router(users.router, prefix="/api/v1/users", tags=["users"])
    return app


app = create_app()
```

Then a **Good/Bad** one-liner: Bad = `allow_origins=["*"]` with `allow_credentials=True`
(browsers reject it, Starlette disallows it for credentialed requests). Pointer:
`→ references/production.md` for proxy headers / logging wiring at startup.

### 1.7 `## Configuration (pydantic-settings)`

One `python` block: `Settings(BaseSettings)` with `SettingsConfigDict(env_file=".env",
extra="ignore")`, typed fields, `SecretStr` for the JWT secret + DB password, `@lru_cache
get_settings()`. Write:

```python
from functools import lru_cache

from pydantic import PostgresDsn, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="APP_", extra="ignore")

    api_title: str = "Service API"
    api_version: str = "1.0.0"
    environment: str = "development"
    database_url: PostgresDsn
    jwt_secret: SecretStr
    jwt_algorithm: str = "HS256"
    jwt_issuer: str = "service-api"
    jwt_audience: str = "service-clients"
    access_token_ttl_seconds: int = 900
    cors_origins: list[str] = []


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]  # values come from env/.env
```

**Good/Bad**: Bad = `DB_URL = os.environ["DB_URL"]` at import time (crashes on import, untyped,
unmockable). Good = inject `get_settings` as a dependency.

### 1.8 `## Pydantic v2 models (Create/Update/Response split)`

One `python` block showing the three-model pattern + v2 idioms (`Annotated[str, Field(...)]`,
`ConfigDict(from_attributes=True)`, `EmailStr`, `computed_field`). Write:

```python
from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, computed_field


class UserBase(BaseModel):
    email: EmailStr
    full_name: Annotated[str, Field(min_length=1, max_length=100)]


class UserCreate(UserBase):
    password: Annotated[str, Field(min_length=12, max_length=128)]


class UserUpdate(BaseModel):
    email: EmailStr | None = None
    full_name: Annotated[str | None, Field(min_length=1, max_length=100)] = None


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime

    @computed_field  # type: ignore[prop-decorator]
    @property
    def display(self) -> str:
        return f"{self.full_name} <{self.email}>"
```

Then a **v2 migration cheat** mini-list (inline bullets): use `.model_dump()` not `.dict()`;
`.model_validate(obj)` not `.from_orm()`; `model_config = ConfigDict(...)` not class `Config`;
`field_validator`/`model_validator` not `@validator`/`@root_validator`.

**Good/Bad**: Bad response model that includes `hashed_password: str` (leaks the hash). Good =
the `UserResponse` above (no secret fields). Pointer: `→ references/security.md`.

### 1.9 `## Dependency injection`

One `python` block. Show the type-alias pattern + a `Pagination` dep + `require_roles` factory
sketch. Write:

```python
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.base import async_session_factory


async def get_db() -> AsyncIterator[AsyncSession]:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


DbSession = Annotated[AsyncSession, Depends(get_db)]


@dataclass(frozen=True)
class Pagination:
    limit: int
    offset: int


def get_pagination(
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> Pagination:
    return Pagination(limit=limit, offset=offset)


PageParams = Annotated[Pagination, Depends(get_pagination)]
```

Pointers: `→ references/database.md` for `async_session_factory` wiring; `→ references/security.md`
for `get_current_user` and `require_roles`.

### 1.10 `## Routers & endpoints`

One `python` block: `APIRouter` with typed deps, `response_model`, `status_code=201`, Location
header, delegating to a service. Write:

```python
from fastapi import APIRouter, Response, status

from app.api.deps import CurrentUser, DbSession, PageParams
from app.schemas.user import UserCreate, UserResponse
from app.services import user_service

router = APIRouter()


@router.get("", response_model=list[UserResponse])
async def list_users(db: DbSession, page: PageParams) -> list[UserResponse]:
    return await user_service.list_users(db, limit=page.limit, offset=page.offset)


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(payload: UserCreate, db: DbSession, response: Response) -> UserResponse:
    user = await user_service.create_user(db, payload)
    response.headers["Location"] = f"/api/v1/users/{user.id}"
    return user
```

**Good/Bad**: Bad = hashing the password + building `select()` + business rules inline in the
route. Good = `await user_service.create_user(db, payload)` (route stays thin). Note `CurrentUser`
is defined in `references/security.md`.

### 1.11 `## Error handling & envelope`

One `python` block: `AppError(code, status, message, details)` base + subclasses +
`register_exception_handlers`. Write:

```python
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.core.logging import logger


class AppError(Exception):
    def __init__(self, message: str, code: str, status_code: int = 500,
                 details: list[dict] | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.code = code
        self.status_code = status_code
        self.details = details or []


class NotFoundError(AppError):
    def __init__(self, resource: str, ident: str) -> None:
        super().__init__(f"{resource} not found: {ident}", "not_found", 404)


class ConflictError(AppError):
    def __init__(self, message: str) -> None:
        super().__init__(message, "conflict", status.HTTP_409_CONFLICT)


class Unauthorized(AppError):
    def __init__(self, message: str = "Authentication required") -> None:
        super().__init__(message, "unauthorized", status.HTTP_401_UNAUTHORIZED)


class Forbidden(AppError):
    def __init__(self, message: str = "Insufficient permissions") -> None:
        super().__init__(message, "forbidden", status.HTTP_403_FORBIDDEN)


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(request: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": {"code": exc.code, "message": exc.message, "details": exc.details}},
        )

    @app.exception_handler(RequestValidationError)
    async def _validation(request: Request, exc: RequestValidationError) -> JSONResponse:
        details = [{"field": ".".join(map(str, e["loc"][1:])), "message": e["msg"], "code": e["type"]}
                   for e in exc.errors()]
        return JSONResponse(
            status_code=422,
            content={"error": {"code": "validation_error", "message": "Request validation failed",
                               "details": details}},
        )

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("unhandled_error", path=request.url.path)
        return JSONResponse(
            status_code=500,
            content={"error": {"code": "internal_error", "message": "An unexpected error occurred"}},
        )
```

Pointer: `→ See Also error-handling` (ECC) for cross-language typed-error theory.

### 1.12 `## Async SQLAlchemy 2.0 (essentials)`

One `python` block: engine + `async_sessionmaker(expire_on_commit=False)` + a `Mapped[]` model +
a `select()` in a service. Write:

```python
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from app.core.config import get_settings

engine = create_async_engine(str(get_settings().database_url), pool_pre_ping=True)
async_session_factory = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    email: Mapped[str] = mapped_column(unique=True, index=True)
    full_name: Mapped[str]
    hashed_password: Mapped[str]
    created_at: Mapped[datetime] = mapped_column(server_default="now()")


async def list_users(db: AsyncSession, limit: int, offset: int) -> list[User]:
    result = await db.execute(
        select(User).order_by(User.created_at.desc()).limit(limit).offset(offset)
    )
    return list(result.scalars().all())
```

Hard pointer: `→ references/database.md` for relationships, N+1 / eager loading, repository,
Alembic, pooling.

### 1.13 `## Background tasks vs real queues`

Two short `python` snippets in one block: `BackgroundTasks` for fire-and-forget in-request work,
and the boundary statement. Write:

```python
from fastapi import APIRouter, BackgroundTasks

router = APIRouter()


# Good: in-request, non-durable side effect (best-effort email).
@router.post("/signup")
async def signup(background: BackgroundTasks) -> dict[str, str]:
    background.add_task(send_welcome_email, "user@example.com")
    return {"status": "accepted"}
```

Then a directive paragraph: anything needing **retries, durability, or cross-process execution**
(payment webhooks, large jobs) goes to a real broker (Celery / Arq / Dramatiq), **never**
`BackgroundTasks` — it runs in-process and dies with the worker, with no retry or visibility.

### 1.14 `## Testing (embedded summary)`

One `python` block: the canonical async client fixture + an assertion. Write:

```python
import pytest
from httpx import ASGITransport, AsyncClient

from app.api.deps import get_db
from app.main import create_app


@pytest.fixture
async def client(db_session):  # db_session: transactional fixture, see references/testing.md
    app = create_app()
    app.dependency_overrides[get_db] = lambda: db_session
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()


async def test_create_user(client: AsyncClient) -> None:
    resp = await client.post("/api/v1/users", json={
        "email": "a@example.com", "full_name": "Alice", "password": "correct-horse-battery",
    })
    assert resp.status_code == 201
    assert "hashed_password" not in resp.json()
```

Inline notes: `pytest-asyncio` with `asyncio_mode = "auto"` (no `@pytest.mark.asyncio` needed);
TDD red→green one-liner. Hard pointer: `→ references/testing.md` (transactional `begin_nested`
fixture, auth overrides, respx, coverage gate).

### 1.15 `## Security (embedded summary)`

Inline must-do checklist (bullets), then pointers. Bullets:
- Hash with **argon2-cffi** (`PasswordHasher`); never MD5/SHA/plain; rehash-on-login when params change.
- Validate JWT `exp`/`iss`/`aud` and **pin `algorithms=[...]`**; reject `alg=none`.
- Env-specific CORS origins; never `["*"]` with credentials.
- Rate-limit auth + write endpoints via a **shared store** (Redis/gateway), not per-process counters.
- Bound params / SQLAlchemy expressions only — never f-string SQL.
- `SecretStr` for secrets; redact `Authorization`, cookies, tokens, passwords, PII from logs.
- Run `pip-audit` in CI; pin + hash lockfiles (`uv pip compile --generate-hashes`).

Hard pointer: `→ references/security.md`; **See Also `secure-coding`**.

### 1.16 `## Production (embedded summary)`

Inline: one `bash` block with the gunicorn command + worker formula, then bullets. Write:

```bash
# Worker count rule of thumb: (2 * CPU cores) + 1
gunicorn app.main:app \
  --worker-class uvicorn.workers.UvicornWorker \
  --workers 5 --timeout 30 --graceful-timeout 30 \
  --bind 0.0.0.0:8000 --forwarded-allow-ips '*'
```

Bullets:
- `/health` = liveness (no deps); `/health/ready` = readiness (pings DB/cache).
- Graceful shutdown via lifespan (`await engine.dispose()`); drain background work; idempotent.
- Structured JSON logging + request-id middleware; correlate by env.
- Pagination + caching (`ETag`/`Cache-Control`, Redis cache-aside) at scale.
- `ORJSONResponse` default; never `--reload` in prod.

Hard pointer: `→ references/production.md`; **See Also `deployment`** (Dockerfile/CI).

### 1.17 `## Anti-patterns / rationalizations → STOP`

Markdown table, 2 columns, the exact 12 rows from spec §2 (copy verbatim):

| Rationalization | Reality → STOP |
|---|---|
| "I'll just call `requests` in this async route, it's one call" | Blocks the event loop → use `httpx.AsyncClient`. |
| "`.dict()` still works" | Pydantic v2: use `.model_dump()`; `.dict()`/`from_orm` are deprecated. |
| "Return the ORM object directly, FastAPI will handle it" | Leaks columns + lazy-loads in serializer → declare `response_model`. |
| "`allow_origins=['*']` + credentials is fine for now" | Browser rejects it; Starlette blocks it. Pin origins. |
| "I'll decode the JWT without checking `exp`/`aud`" | Forged/replayed tokens. Validate exp/iss/aud + pin alg. |
| "Build the WHERE with an f-string, it's internal" | SQLi. Bound params / SQLAlchemy expressions only. |
| "One global session for the whole app is simpler" | Cross-request data bleed + concurrency bugs. One session per request. |
| "Catch `Exception` and return the message to the client" | Leaks internals. Log it, return generic 500. |
| "`BackgroundTasks` is good enough for the payment webhook retry" | No durability/retry. Use a real broker. |
| "mypy strict is too noisy, I'll skip it" | Strict catches the bugs FastAPI's runtime won't. Keep it. |
| "Commit inside the handler so I control it" | Let `get_db` own commit/rollback; handlers stay thin. |
| "Default-mutable arg / module-level engine at import is fine" | Mutable defaults bite; engine must live in lifespan. |

### 1.18 `## Quick reference`

Markdown table, 2 columns (Task | Idiom). Rows:

| Task | Idiom |
|---|---|
| Async route doing I/O | `async def` + `httpx.AsyncClient` / asyncpg |
| Request DB session | `db: Annotated[AsyncSession, Depends(get_db)]` |
| Run a query | `await db.execute(select(Model).where(...))` |
| Get rows | `result.scalars().all()` / `.scalar_one_or_none()` |
| Get by PK | `await db.get(Model, pk)` |
| Eager-load collection | `selectinload(Model.items)` |
| Eager-load many-to-one | `joinedload(Model.parent)` |
| Settings | `Annotated[Settings, Depends(get_settings)]` |
| Serialize ORM → schema | `model_config = ConfigDict(from_attributes=True)` |
| Created response | `status_code=201` + `Location` header |
| Test client | `AsyncClient(transport=ASGITransport(app=app))` |
| Override a dependency | `app.dependency_overrides[dep] = fake` |
| Hash password | `argon2.PasswordHasher().hash(pw)` |
| Verify JWT | `jwt.decode(t, key, algorithms=[...], audience=..., issuer=...)` |

### 1.19 `## See Also`

Bullets (links relative to siblings):
- `api-design` — REST contract (status codes, URL naming, pagination semantics, versioning).
- `secure-coding` — language-agnostic injection/secret/authz hardening.
- `deployment` — Dockerfile, Compose, CI/CD, container runtime.
- `error-handling` — cross-language typed-error theory.
- References: [`references/testing.md`](references/testing.md), [`references/database.md`](references/database.md), [`references/security.md`](references/security.md), [`references/production.md`](references/production.md).
- Verify gate: [`scripts/verify.sh`](scripts/verify.sh).

---

## 2. `references/testing.md` — "Testing async FastAPI"

Target 250–450 lines. One H1: `# Testing async FastAPI`. H2 sub-sections in this order. Every
code block tagged. Include the exact code described.

### 2.1 `## Setup & config`
One `toml` block: `[tool.pytest.ini_options]` with `asyncio_mode = "auto"`,
`addopts = ["--strict-markers", "--cov=app", "--cov-report=term-missing", "--cov-fail-under=85"]`,
`testpaths = ["tests"]`. Plus a `bash` block listing dev deps install:
`uv add --dev pytest pytest-asyncio pytest-cov httpx respx testcontainers[postgres]`.

### 2.2 `## Test DB strategy`
Prose + `python` block. Explain: use a **real PostgreSQL 16** via `testcontainers` (or a
dedicated test DB) for parity; SQLite caveat (no Postgres-specific types, different SQL). Show a
session-scoped engine fixture that creates/drops the schema:

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

### 2.3 `## Transactional isolation fixture`
The **canonical SQLAlchemy 2.0 async** per-test rollback recipe in full. One `python` block:

```python
import pytest
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.fixture
async def db_session(engine) -> AsyncSession:
    connection = await engine.connect()
    trans = await connection.begin()
    session = AsyncSession(bind=connection, expire_on_commit=False)
    await connection.begin_nested()

    from sqlalchemy import event

    @event.listens_for(session.sync_session, "after_transaction_end")
    def _restart_savepoint(sess, transaction):
        if transaction.nested and not transaction._parent.nested:
            sess.begin_nested()

    yield session

    await session.close()
    await trans.rollback()
    await connection.close()
```

One sentence: every test runs inside an outer transaction + SAVEPOINT that is rolled back, so
the DB is pristine between tests even though service code calls `commit()`.

### 2.4 `## The async client fixture`
One `python` block: `ASGITransport(app=create_app())` + `dependency_overrides[get_db]` yielding
the test session; `base_url="http://test"`; `.clear()` teardown. (Same shape as SKILL.md 1.14 but
full, in `conftest.py` context.)

### 2.5 `## Auth override fixture`
Two `python` blocks. (a) Override `get_current_user` to inject a fixed test user. (b) A variant
that mints a real JWT via `create_access_token` and sends `Authorization: Bearer ...` to exercise
the real decode path. Show both.

### 2.6 `## Factories & fixtures`
One `python` block: lightweight builder functions (no global state) — e.g.
`async def make_user(db, **overrides) -> User`. Plus a `parametrize` example with `ids=`.

### 2.7 `## Testing endpoints`
One `python` block with 4 tests: list+pagination (assert length/order), POST 201 + `Location`
header, 422 validation shape (assert `error.code == "validation_error"` and `details[0].field`),
404/409 envelope assertions.

### 2.8 `## Testing background tasks & external calls`
One `python` block using **respx** to mock outbound httpx:

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

Plus a sentence on asserting `BackgroundTasks` side effects (override the task target with a spy).

### 2.9 `## TDD discipline`
Concrete red→green→refactor walk-through for a new `GET /users/{id}` endpoint: write the failing
test first (`python` block), then the minimal handler/service (`python` block), then note the
refactor step. Reference `superpowers:test-driven-development` discipline in one line.

### 2.10 `## Coverage gate & CI`
`bash` block: `uv run pytest --cov=app --cov-report=term-missing`. Prose: `--cov-fail-under=85`
in pyproject is the single source of truth; branch coverage with `--cov-branch`; 100% must cover
auth + error paths (401/403/404/409/422/500).

End with `## See Also`: `references/database.md`, `references/security.md`, ECC `python-testing`.

---

## 3. `references/database.md` — "Async SQLAlchemy 2.0 + Alembic"

Target 300–500 lines. One H1: `# Async SQLAlchemy 2.0 + Alembic`. H2 order:

### 3.1 `## Engine & session factory`
One `python` block: `create_async_engine(url, pool_size=10, max_overflow=20,
pool_pre_ping=True, pool_recycle=1800)`, `async_sessionmaker(expire_on_commit=False)`, and the
canonical `get_db` dependency (commit/rollback). This is the wiring SKILL.md references.

### 3.2 `## Declarative models (2.0 style)`
One `python` block: `DeclarativeBase`, `Mapped[int]`, `mapped_column(primary_key=True)`, typed
columns, `server_default=func.now()`, and a `TimestampMixin` with `created_at`/`updated_at`
(`onupdate`). Use `from sqlalchemy import func`.

### 3.3 `## Relationships`
One `python` block: `relationship()` with `Mapped[list["Order"]]`, FK via
`mapped_column(ForeignKey("users.id"))`, `back_populates`, `cascade="all, delete-orphan"`.

### 3.4 `## Querying`
One `python` block covering: `select().where().order_by()`, `.scalars().all()`,
`.scalar_one_or_none()`, `await db.get(Model, pk)`, Core `update()`/`delete()` with
`.returning(Model.id)`, and `func.count()`.

### 3.5 `## N+1 & eager loading`
The unmissable section. Prose: **lazy loading is unsafe in async SQLAlchemy** — accessing an
unloaded relationship outside a sync context raises `MissingGreenlet`/triggers implicit I/O.
**Bad** `python` block (iterate users, access `user.orders` → fails / N queries). **Good**
`python` block using `selectinload(User.orders)` (collections) and `joinedload(Order.user)`
(many-to-one). One sentence: choose `selectinload` for collections (avoids row multiplication),
`joinedload` for scalar many-to-one.

### 3.6 `## Repository / CRUD layer`
One `python` block: a generic `Repository[ModelT]` with `get`, `list`, `add`, `delete` keeping
`select`/`commit` out of routers:

```python
from typing import Generic, TypeVar
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.base import Base

ModelT = TypeVar("ModelT", bound=Base)


class Repository(Generic[ModelT]):
    def __init__(self, model: type[ModelT], db: AsyncSession) -> None:
        self.model = model
        self.db = db

    async def get(self, pk: UUID) -> ModelT | None:
        return await self.db.get(self.model, pk)

    async def list(self, limit: int, offset: int) -> list[ModelT]:
        result = await self.db.execute(select(self.model).limit(limit).offset(offset))
        return list(result.scalars().all())

    async def add(self, obj: ModelT) -> ModelT:
        self.db.add(obj)
        await self.db.flush()
        return obj
```

### 3.7 `## Transactions`
One `python` block: `async with db.begin():` for multi-statement atomicity; nested savepoints
via `async with db.begin_nested():`. Note: with the `get_db` commit-on-success pattern, prefer
`flush` inside services and let the dependency own the outer commit.

### 3.8 `## Alembic (async)`
The full async `env.py` (one `python` block) configured for `async_engine_from_config` +
`run_sync(do_run_migrations)`; a `ini` snippet for `sqlalchemy.url` driven from env; a `bash`
block: `alembic revision --autogenerate -m "create users"` then `alembic upgrade head`. Caveat
prose: autogenerate misses some changes (server defaults, CHECK constraints, type changes) —
**always review the generated migration**. Mention `alembic upgrade head --sql` for offline SQL.

### 3.9 `## Connection pooling & production`
Prose + `python` block. Pool sizing vs worker math: total connections ≈
`workers × (pool_size + max_overflow)` must stay under Postgres `max_connections`. `pool_pre_ping`
for stale connections. Behind **pgbouncer** (transaction pooling), use `poolclass=NullPool` and
disable prepared-statement caching for asyncpg (`prepared_statement_cache_size=0` via
`connect_args`). Set a statement timeout via `connect_args={"server_settings": {"statement_timeout": "5000"}}`.

End with `## See Also`: `references/production.md`, ECC `backend-patterns`.

---

## 4. `references/security.md` — "Securing a FastAPI service"

Target 300–500 lines. One H1: `# Securing a FastAPI service`. H2 order:

### 4.1 `## Password hashing`
One `python` block: argon2-cffi `PasswordHasher`, `hash`, `verify` (constant-time, raises
`VerifyMismatchError`), and rehash-on-login via `ph.check_needs_rehash(...)`. Prose: never
MD5/SHA/plain; bcrypt acceptable fallback. Write:

```python
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

ph = PasswordHasher()


def hash_password(plain: str) -> str:
    return ph.hash(plain)


def verify_password(stored_hash: str, plain: str) -> tuple[bool, str | None]:
    try:
        ph.verify(stored_hash, plain)
    except VerifyMismatchError:
        return False, None
    new_hash = ph.hash(plain) if ph.check_needs_rehash(stored_hash) else None
    return True, new_hash
```

### 4.2 `## OAuth2 password flow + JWT`
Two `python` blocks. (a) `OAuth2PasswordBearer` + `/auth/login` returning an access token. (b)
`create_access_token` (sets `exp`, `iat`, `iss`, `aud`, `sub`) and `decode_token` validating
`exp`/`iss`/`aud` and **pinning algorithms**. Use PyJWT. Write the decode with full validation:

```python
from datetime import UTC, datetime, timedelta

import jwt

from app.core.config import get_settings


def create_access_token(subject: str) -> str:
    s = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": subject, "iss": s.jwt_issuer, "aud": s.jwt_audience,
        "iat": now, "exp": now + timedelta(seconds=s.access_token_ttl_seconds),
    }
    return jwt.encode(payload, s.jwt_secret.get_secret_value(), algorithm=s.jwt_algorithm)


def decode_token(token: str) -> dict:
    s = get_settings()
    return jwt.decode(
        token, s.jwt_secret.get_secret_value(),
        algorithms=[s.jwt_algorithm],          # pinned — never accept the header's alg
        audience=s.jwt_audience, issuer=s.jwt_issuer,
        options={"require": ["exp", "iss", "aud", "sub"]},
    )
```

**Good/Bad**: Bad = `jwt.decode(token, key, algorithms=["none"])` or omitting `algorithms`
(accepts `alg=none`, forgeable). Then a `python` block for `get_current_user` (decode → load user,
raise `Unauthorized` on failure) defining `CurrentUser = Annotated[User, Depends(get_current_user)]`.

### 4.3 `## RBAC`
One `python` block: `require_roles(*roles)` dependency factory reading a `role` claim, raising
`Forbidden` (403) when missing. Prose on the 403-vs-404 ownership-leak decision (return 404 to
avoid confirming existence to non-owners on private resources).

### 4.4 `## CORS`
Prose + `python` snippet: env-specific origins, credentials rules, preflight. Restate the
`["*"]` + credentials trap with the fix (explicit origin list per environment).

### 4.5 `## Rate limiting`
Prose: must use a **shared store** (Redis / gateway), not per-process counters — per-process fails
open across replicas / serverless. One `python` block: `slowapi` `Limiter(key_func=...,
storage_uri="redis://...")`, a `@limiter.limit("5/minute")` decorator on `/auth/login`, and a 429
handler returning the envelope + `Retry-After`.

### 4.6 `## Injection`
Prose + Good/Bad `python` block: Bad = `text(f"SELECT ... WHERE email = '{email}'")`. Good =
`select(User).where(User.email == email)` or bound `text(...).bindparams(...)`. Pydantic validates
bodies; `Query(ge=, le=)` / `Path(...)` bound path & query params.

### 4.7 `## Secret handling`
Bullets + `python` snippet: `SecretStr`, `.get_secret_value()` only at point of use, `.env`
gitignored, read from a secret manager in prod, rotate keys. Never log `SecretStr` (its `repr`
shows `**********`).

### 4.8 `## Log redaction`
One `python` block: a redacting structlog processor / logging filter that strips
`authorization`, `cookie`, `set-cookie`, `password`, `token`, and known PII keys before emit.

### 4.9 `## Security headers & misc`
Prose + `python` snippet: `TrustedHostMiddleware(allowed_hosts=...)`, HSTS/CSP via a small
response middleware note, request size limits, disabling `/docs` + `/redoc` in prod
(`docs_url=None` when `environment == "production"`).

### 4.10 `## Dependency audit`
`bash` block: `uv run pip-audit`, `uv pip compile --generate-hashes -o requirements.lock`,
Dependabot mention. Prose: gate CI on `pip-audit`.

End with `## See Also`: `secure-coding`, `references/production.md`, ECC `error-handling`.

---

## 5. `references/production.md` — "Running FastAPI in production"

Target 300–500 lines. One H1: `# Running FastAPI in production`. H2 order:

### 5.1 `## ASGI server`
`bash` block: dev `uvicorn app.main:app --reload`; prod `gunicorn ... UvicornWorker` with the
`(2×CPU)+1` formula, `--timeout`, `--graceful-timeout`, `--forwarded-allow-ips`. Prose: why not
`--reload` in prod; alternatively `uvicorn --workers N` without gunicorn.

### 5.2 `## Structured logging`
One `python` block: **structlog** config emitting JSON (`structlog.processors.JSONRenderer`),
plus a request-id middleware (`python` block) that sets a contextvar / `X-Request-ID` and binds
it to the logger so all logs in a request are correlated. Note integrating uvicorn's loggers.

### 5.3 `## Health & readiness`
One `python` block: `/health` liveness returns `{"status":"ok"}` with no deps; `/health/ready`
pings the DB (`await db.execute(select(1))`) and returns 503 on failure. Note k8s probe semantics
(liveness restarts the pod; readiness removes from the LB).

### 5.4 `## Graceful shutdown`
One `python` block: lifespan teardown (`await engine.dispose()`, drain background work);
SIGTERM handling via uvicorn/gunicorn graceful-timeout; idempotent shutdown. One sentence on
connection draining.

### 5.5 `## Pagination at scale`
Prose + `python` block: offset vs keyset/cursor; `count` cost; consistent ordering (always
include a tiebreaker like `id`). Envelope `meta`/`links`. Link to `api-design` for cursor
semantics (do not re-derive).

### 5.6 `## Caching`
One `python` block: HTTP cache headers (`ETag`, `Cache-Control`) and a Redis cache-aside helper
with explicit invalidation; `@lru_cache` for pure config. Prose: cache stampede note (lock /
`SETNX` / jittered TTL).

### 5.7 `## Performance`
One `python` block: set `default_response_class=ORJSONResponse` on `FastAPI(...)`. Prose:
`--proxy-headers` + `forwarded-allow-ips` behind a proxy; GZip/Brotli tradeoff (CPU vs payload);
avoid sync I/O on the event loop; profiling pointers (py-spy).

### 5.8 `## Observability`
Prose + short `python` note: OpenTelemetry FastAPI instrumentation / Prometheus middleware; RED
metrics (Rate, Errors, Duration). Keep it a pointer, not a full setup.

### 5.9 `## Docker note`
Short `dockerfile` block: slim base (`python:3.12-slim`), non-root user, `uv`-built venv,
`EXPOSE 8000`, `HEALTHCHECK` hitting `/health`. Then **See Also `deployment`** for the full
pipeline (do not duplicate it).

End with `## See Also`: `references/database.md`, `references/security.md`, `deployment`, `api-design`.

---

## 6. `scripts/verify.sh` — exact contract

Write this file **verbatim**, then `chmod +x` it. Do not run it in this repo.

```bash
#!/usr/bin/env bash
#
# verify.sh — quality gate for a FastAPI / async Python project.
#
# Usage:
#   ./scripts/verify.sh [TARGET_PATH]
#
# Runs lint, format-check, type-check, tests+coverage, and a dependency audit.
# Auto-detects each tool. If a tool is missing it prints a yellow SKIP and continues
# (it does NOT fail). Prefers `uv run <tool>` when `uv` is present, else the bare tool
# on PATH. Exits non-zero only if a tool actually ran and reported a failure.
# Coverage threshold is read from the project's pyproject.toml (--cov-fail-under);
# this script does not hardcode a second threshold. Idempotent: re-running yields the
# same result (read-only beyond whatever the project's own pytest does).

set -euo pipefail

TARGET="${1:-.}"

# --- color helpers (guarded for non-TTY) ---
if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi
warn() { printf '%s%s%s\n' "$YELLOW" "$*" "$RESET"; }
ok()   { printf '%s%s%s\n' "$GREEN" "$*" "$RESET"; }
fail() { printf '%s%s%s\n' "$RED" "$*" "$RESET"; }

PASSED=0; SKIPPED=0; FAILED=0

have() { command -v "$1" >/dev/null 2>&1; }

# runner prefix: prefer `uv run` when available
RUNNER=()
if have uv; then RUNNER=(uv run); fi

# run_step <label> <tool> <args...>
run_step() {
  local label="$1"; local tool="$2"; shift 2
  if ! have "$tool" && ! { [ "${#RUNNER[@]}" -gt 0 ] && have uv; }; then
    warn "SKIP: ${label} (${tool} not installed)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  printf '==> %s\n' "$label"
  if "${RUNNER[@]}" "$tool" "$@"; then
    ok "PASS: ${label}"
    PASSED=$((PASSED + 1))
  else
    fail "FAIL: ${label}"
    FAILED=$((FAILED + 1))
  fi
}

run_step "ruff check"        ruff check "$TARGET"
run_step "ruff format check" ruff format --check "$TARGET"
run_step "mypy"              mypy "$TARGET"
run_step "pytest + coverage" pytest --cov --cov-report=term-missing
run_step "pip-audit"         pip-audit

printf '\n%d passed, %d skipped, %d failed\n' "$PASSED" "$SKIPPED" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  fail "verify.sh: failures detected"
  exit 1
fi
ok "verify.sh: ok"
exit 0
```

Note for the implementer: the `have "$tool"` guard combined with the `uv run` prefix means a tool
installed only as a `uv` dependency still runs (because `uv run <tool>` resolves it); the SKIP
branch only triggers when neither the bare tool nor `uv` can provide it. Keep this logic exactly.

---

## 7. Acceptance checks (implementer self-verifies before finishing)

Run/verify each of these. Do not finish until all pass:

1. All six files exist at the exact paths in §0; `references/` and `scripts/` dirs created.
2. `scripts/verify.sh` is executable: `test -x scripts/verify.sh` (after `chmod +x`). It begins
   with `#!/usr/bin/env bash` and `set -euo pipefail` and has the usage header. **Not executed here.**
3. `SKILL.md` has exactly one H1, valid YAML frontmatter with `name: fastapi`, a `description`
   starting with `Use when `, and `origin: risco`. Line count is 320–420.
4. Every reference file has exactly one H1, the H2 sections in the specified order, and is
   200–500 lines.
5. Every fenced code block in every file has a language tag (`python`, `toml`, `bash`, `ini`,
   `text`, `dockerfile`, `yaml`). No untagged fences.
6. No placeholders, `TODO`, `FIXME`, `...` (as hand-waving), or `etc.` anywhere. Every code
   snippet is correct and importable in context (imports present, names consistent across files:
   `get_db`, `get_settings`, `async_session_factory`, `create_app`, `AppError`, `decode_token`,
   `CurrentUser`, `DbSession`, `PageParams`).
7. Pydantic is v2 throughout (`model_dump`/`model_validate`/`ConfigDict`); SQLAlchemy is 2.0
   (`Mapped`/`mapped_column`/`DeclarativeBase`); no `typing.Optional/List/Dict`, use `X | None`,
   `list[...]`, `dict[...]`. No `requests`, no sync `psycopg2`, no `.dict()`/`from_orm`.
8. The anti-patterns table has the 12 rows; the quick-reference table is present; both render as
   valid Markdown tables.
9. `## See Also` in SKILL.md links the sibling skills (`api-design`, `secure-coding`,
   `deployment`, `error-handling`) and the four `references/*.md` files and `scripts/verify.sh`.
   Each reference file ends with its own `## See Also`.
10. Headings are consistent (`##` for sections, `###`/`####` only where nested); no skipped
    levels; no trailing whitespace; files end with a single newline.
```
