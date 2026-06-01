# DESIGN SPEC — `fastapi` skill ("FastAPI & modern Python services")

Status: design spec only. Do **not** generate skill files from this yet; this is the
blueprint the build step will execute.

Target stack versions (state explicitly inside the skill): **Python 3.12+**,
**FastAPI 0.115+**, **Starlette 0.41+**, **Pydantic v2 (2.9+) + pydantic-settings 2.x**,
**SQLAlchemy 2.0 (async)**, **Alembic 1.13+**, **asyncpg 0.30 / psycopg 3**,
**httpx 0.28+**, **pytest 8 + pytest-asyncio 0.24+ (asyncio_mode=auto)**,
**ruff 0.7+**, **mypy 1.13+ strict**, **uv 0.5+ (pip-tools as fallback)**,
**uvicorn 0.32+ / gunicorn 23+**, **PyJWT 2.9 (or python-jose)**, **argon2-cffi 23+**,
**pip-audit 2.7+**, **PostgreSQL 16**. Calibration floor = the six ECC skills
read on disk; this skill must exceed them in density, currency and copy-pasteability.

---

## 1. Purpose & precise trigger

**One-line purpose:** The single authoritative skill for building, reviewing, testing,
securing and shipping an async FastAPI / modern-Python service — Python 3.12 idioms +
FastAPI + Pydantic v2 + SQLAlchemy 2.0 async + pytest + security + production, all in
one place.

**`description` frontmatter (trigger-rich, starts with "Use when"):**
> Use when building, reviewing, testing, securing or deploying a FastAPI / async Python
> service. Triggers: creating endpoints/routers, Pydantic v2 models (Create/Update/Response),
> dependency injection, async SQLAlchemy 2.0 + Alembic, OAuth2/JWT auth + RBAC, pytest +
> httpx ASGITransport tests, CORS / rate limiting / secret handling, uvicorn/gunicorn +
> structured logging + healthchecks + graceful shutdown, pyproject + ruff + mypy strict +
> uv. Any `.py` file importing `fastapi`, `pydantic`, `sqlalchemy`, `starlette`, or a
> `pyproject.toml` declaring those. origin: risco.

**When to use (in SKILL.md):**
- Writing or reviewing any FastAPI route, router, dependency, schema, or app factory.
- Designing async DB access (SQLAlchemy 2.0), migrations (Alembic), or eager-loading.
- Adding auth (OAuth2 password flow + JWT), RBAC, password hashing.
- Writing pytest suites for an async API (ASGITransport, dependency_overrides, transactional DB).
- Hardening (CORS, rate limit, secrets, log redaction, dependency audit) or productionizing
  (workers, logging, health, graceful shutdown, pagination, caching) a Python service.
- Setting up `pyproject.toml`, ruff+mypy strict, uv/pip-tools dependency management.

**When NOT to use (in SKILL.md):**
- Django / Flask / DRF apps → not this skill (note: ECC `api-design` shows DRF; this skill
  is FastAPI-only).
- Sync WSGI services, data-science notebooks, CLI-only scripts with no HTTP surface.
- Pure REST contract questions independent of FastAPI (status codes, URL naming, versioning,
  cursor vs offset semantics) → **See Also `api-design`**; this skill references it instead
  of re-deriving it.
- Frontend/Next.js, Go, Flutter work in the same monorepo → their own skills.
- Generic secure-coding rules not specific to Python/FastAPI → **See Also `secure-coding`**.
- Container/Compose/CI deploy mechanics → **See Also `deployment`** (skill keeps only a
  Docker *note*, not a full Dockerfile tutorial).

---

## 2. Exact `SKILL.md` outline

Target length **~320–420 lines**. One H1. Frontmatter: `name: fastapi`, `description`
(above), `origin: risco`. Progressive disclosure: every deep topic gets a 1–2 paragraph
canonical pattern in SKILL.md + an explicit pointer into `references/`.

### `# FastAPI & modern Python services`
Opening: 2-sentence purpose + the mental model — *"The app is a thin async HTTP layer over
typed dependencies, a service/repository core, and explicit DB sessions. Routes validate
and delegate; they never own business logic, raw SQL, or secrets."*

### `## When to use` / `## When NOT to use`
The bullet lists from §1. Dense, scannable.

### `## Decision rules` (core principles, numbered, directive)
Delivers the non-negotiable rules an agent applies on every change:
1. `async def` for any I/O route; use async drivers (asyncpg, httpx) — never `requests`,
   never sync `psycopg2`, never blocking calls in the event loop (offload with
   `await anyio.to_thread.run_sync` / `run_in_threadpool`).
2. Three Pydantic models per resource: `XCreate` / `XUpdate` / `XResponse`
   (`from_attributes=True`). Response models never leak hashes/tokens/internal flags.
3. All request-scoped resources via `Depends` (`Annotated[T, Depends(...)]`), never
   constructed inline in handlers — so tests can override them.
4. One DB session per request via `get_db` with commit-on-success / rollback-on-exception.
5. Every error leaves as the same envelope `{"error":{"code","message","details?"}}` via
   centralized handlers. Never leak stack traces / SQL.
6. Settings come from `pydantic-settings` (`BaseSettings`), never `os.getenv` scattered in code.
7. Validate JWT `exp`, `iss`, `aud`, and pin `algorithms=["RS256"|"HS256"]` explicitly.
8. Tests use `ASGITransport` + `dependency_overrides` against a transactional DB; CI gates
   on `ruff`, `mypy --strict`, `pytest --cov`, `pip-audit`.

### `## Project layout`
Delivers: a `src/`-layout tree (`app/main.py`, `core/`, `api/routers/`, `schemas/`,
`models/`, `db/`, `services/`, `deps.py`, `tests/`, `alembic/`, `pyproject.toml`).
Note rationale: routers thin, services hold logic, repository/CRUD owns persistence.

### `## Application factory + lifespan`
Delivers copy-paste `create_app()` with `@asynccontextmanager lifespan` (init engine /
warm caches on enter, `await engine.dispose()` on exit), middleware, router registration,
exception-handler registration, `app = create_app()` at module bottom.
Code: factory + lifespan + CORS wiring (explicit methods/headers, **Good/Bad** contrast:
Bad = `allow_origins=["*"]` with `allow_credentials=True`).

### `## Configuration (pydantic-settings)`
Delivers `Settings(BaseSettings)` with `SettingsConfigDict(env_file=".env", extra="ignore")`,
typed fields, `SecretStr` for secrets, `@lru_cache get_settings()` provider used as a dep.
Good/Bad: Bad = `os.environ["X"]` at import time.

### `## Pydantic v2 models (Create/Update/Response split)`
Delivers the three-model pattern with `Annotated[str, Field(min_length=…)]`,
`ConfigDict(from_attributes=True)`, `EmailStr`, `model_validator`, `computed_field`,
and the **v2 migration cheats** (`.model_dump()` / `.model_validate()` not `.dict()/.from_orm()`;
`model_config = ConfigDict(...)` not class `Config`). Good/Bad: response model that
accidentally includes `hashed_password` (Bad) vs explicit safe response (Good).

### `## Dependency injection`
Delivers `Annotated`-style deps: `get_db` (async session, commit/rollback),
`get_current_user` (decode token → load user), `Pagination` dataclass dep (limit/offset
with bounds), `require_roles(...)` factory. Uses `DbSession = Annotated[AsyncSession, Depends(get_db)]`
type-alias pattern to keep signatures clean. Pointer → `references/database.md` for the
session_factory wiring, → `references/security.md` for auth deps.

### `## Routers & endpoints`
Delivers an `APIRouter` with typed deps, `response_model`, `status_code=201`,
`Annotated[int, Query(ge=1, le=100)]`, dependency-injected pagination, and a 201+Location
create. Good/Bad: business logic inline in route (Bad) vs delegating to a service (Good).

### `## Error handling & envelope`
Delivers domain exception base (`AppError(code,status,message,details)`) + subclasses
(`NotFoundError`, `ConflictError`, `ValidationFailed`, `Unauthorized`, `Forbidden`),
`register_exception_handlers(app)` covering `AppError`, `RequestValidationError`
(reshape 422 to the envelope), and a catch-all `Exception` (log via `logger.exception`,
return generic 500). Pointer → ECC `error-handling` See-Also for cross-language theory.

### `## Async SQLAlchemy 2.0 (essentials)`
Delivers the minimum inline: `create_async_engine`, `async_sessionmaker(expire_on_commit=False)`,
a `select()` query in a handler, `Mapped[]` / `mapped_column()` model. Then a hard pointer
→ `references/database.md` for relationships, N+1/eager loading, Alembic, pooling.

### `## Background tasks vs real queues`
Delivers `BackgroundTasks` for fire-and-forget *in-request* side effects (email, cache warm)
+ the explicit boundary: anything needing retries/durability/cross-process → real broker
(Celery/Arq/Dramatiq), not `BackgroundTasks`. Good/Bad contrast.

### `## Testing (embedded summary)`
Delivers the canonical async test: `pytest-asyncio` (`asyncio_mode=auto`),
`AsyncClient(transport=ASGITransport(app=app))`, `app.dependency_overrides[get_db]`,
transactional rollback fixture. Coverage gate + TDD red/green one-liner. Hard pointer →
`references/testing.md`.

### `## Security (embedded summary)`
Delivers the must-do checklist inline (argon2 hashing, JWT claim validation + alg pinning,
env-specific CORS, rate-limit auth/write endpoints, bound params only, secret + log
redaction, `pip-audit` in CI). Hard pointer → `references/security.md` and See-Also
`secure-coding`.

### `## Production (embedded summary)`
Delivers inline: uvicorn worker count = `(2×CPU)+1` rule of thumb, gunicorn+UvicornWorker,
structured JSON logging note, `/health` (liveness) vs `/health/ready` (readiness, checks
DB), graceful shutdown via lifespan, pagination + caching pointers. Hard pointer →
`references/production.md`, See-Also `deployment`.

### `## Anti-patterns / rationalizations → STOP` (table)
Delivers a 2-column table (Rationalization | Reality/STOP). ~12 rows. Examples:

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

### `## Quick reference` (table)
Delivers a dense lookup: task → idiom. Rows: async route I/O → `async def`+httpx/asyncpg;
session → `Annotated[AsyncSession, Depends(get_db)]`; query → `await db.execute(select(...))`;
scalars → `.scalars().all()`; eager load → `selectinload()`; settings → `get_settings()` dep;
serialize → `model_config = ConfigDict(from_attributes=True)`; 201 → `status_code=201`+Location;
test client → `AsyncClient(transport=ASGITransport(app))`; override dep →
`app.dependency_overrides[dep]`; hash → `argon2`; verify JWT → `jwt.decode(..., audience=, issuer=, algorithms=[...])`.

### `## See Also`
- `api-design` — REST contract (status codes, URL naming, pagination semantics, versioning).
- `secure-coding` — language-agnostic injection/secret/authz hardening.
- `deployment` — Dockerfile, Compose, CI/CD, container runtime.
- `error-handling` (ECC) — cross-language typed-error theory.
- References: `references/testing.md`, `references/database.md`, `references/security.md`,
  `references/production.md`. Verify gate: `scripts/verify.sh`.

---

## 3. `references/` files — outlines & key code

Each 200–500 lines, one sub-topic, real runnable code, Good/Bad contrasts, one H1.

### 3a. `references/testing.md` — "Testing async FastAPI"
Outline (H2s):
- **Setup & config** — `pyproject.toml` `[tool.pytest.ini_options]` with
  `asyncio_mode = "auto"`, `addopts` (`--cov=app --cov-fail-under=85 --strict-markers`),
  dev deps list.
- **Test DB strategy** — engine + `async_sessionmaker` against a disposable Postgres
  (testcontainers or a dedicated test DB) vs SQLite caveat (note: prefer real Postgres for
  parity); create/drop schema in a session-scoped fixture.
- **Transactional isolation fixture** — per-test outer transaction + `SAVEPOINT`
  (`begin_nested` + `after_transaction_end` reconnect) rolled back after each test; the
  canonical SQLAlchemy 2.0 async recipe in full.
- **The async client fixture** — `ASGITransport(app=create_app())` +
  `dependency_overrides[get_db]` yielding the test session; `base_url="http://test"`;
  `.clear()` teardown.
- **Auth override fixture** — override `get_current_user` to inject a test user; and a
  variant that exercises the real JWT path.
- **Factories & fixtures** — lightweight builder functions / `factory_boy`-style helpers
  (no global state); `pytest.mark.parametrize` with `ids=`.
- **Testing endpoints** — GET/list pagination, POST 201+Location, validation 422 shape,
  404/409 envelope assertions.
- **Testing background tasks & external calls** — `respx`/`httpx.MockTransport` for outbound
  HTTP; asserting `BackgroundTasks` side effects.
- **TDD discipline** — red→green→refactor loop applied to a new endpoint, concrete walk-through.
- **Coverage gate & CI** — `--cov-fail-under`, branch coverage, what 100% must cover (auth,
  error paths).
Key code: the `begin_nested` rollback fixture; the `AsyncClient`+override fixture; a full
`test_create_user.py` showing red→green; a `respx` outbound-mock test.

### 3b. `references/database.md` — "Async SQLAlchemy 2.0 + Alembic"
Outline (H2s):
- **Engine & session factory** — `create_async_engine(url, pool_size, max_overflow,
  pool_pre_ping=True, pool_recycle)`, `async_sessionmaker(expire_on_commit=False)`,
  `get_db` dependency (commit/rollback) — the canonical wiring referenced from SKILL.md.
- **Declarative models (2.0 style)** — `DeclarativeBase`, `Mapped[int]`,
  `mapped_column(primary_key=True)`, typed columns, `server_default`, timestamps mixin.
- **Relationships** — `relationship()` with `Mapped[list["X"]]`, FK, `back_populates`,
  `cascade`.
- **Querying** — `select()`, `where`, `order_by`, `.scalars()`, `.scalar_one_or_none()`,
  `await db.get(Model, pk)`, inserts/updates/deletes (`update()`/`delete()` Core),
  `returning()`.
- **N+1 & eager loading** — the problem shown (lazy load in async raises / triggers per-row
  queries), fixed with `selectinload()` (collections) and `joinedload()` (many-to-one);
  Good/Bad. Note: lazy loading is unsafe in async — load explicitly.
- **Repository / CRUD layer** — generic async repo pattern keeping `select`/`commit` out of
  routers.
- **Transactions** — `async with db.begin():` for multi-statement atomicity; nested savepoints.
- **Alembic (async)** — `env.py` async configuration, `alembic.ini`, autogenerate workflow,
  `alembic revision --autogenerate -m`, `alembic upgrade head`, migration review caveats
  (autogen misses some changes), offline SQL.
- **Connection pooling & production** — pool sizing vs worker count math, `pool_pre_ping`,
  pgbouncer + `NullPool`/`poolclass` note, statement timeout.
Key code: full async `env.py` for Alembic; `selectinload` vs lazy Good/Bad; generic
`Repository[ModelT]`; pool config block.

### 3c. `references/security.md` — "Securing a FastAPI service"
Outline (H2s):
- **Password hashing** — argon2-cffi (`PasswordHasher`) primary, bcrypt fallback; never
  MD5/SHA/plain; constant-time verify; rehash-on-login policy.
- **OAuth2 password flow + JWT** — `OAuth2PasswordBearer`, `/auth/login` returning access
  (+ refresh) token, `create_access_token` (set `exp`, `iss`, `aud`, `sub`, `iat`),
  `decode_token` validating `exp`/`iss`/`aud` and **pinning `algorithms`** (RS256 preferred
  for asymmetric; never accept `alg=none`). Good/Bad: unpinned-alg decode.
- **RBAC** — `require_roles("admin")` dependency factory + role claim; resource-ownership
  check pattern (403 vs 404 leakage decision).
- **CORS** — env-specific origins, credentials rules, preflight; the `*`+credentials trap.
- **Rate limiting** — must use shared store (Redis / gateway), not per-process counters
  (note the serverless/multi-replica failure mode, echoing ECC backend-patterns); `slowapi`
  example + 429 + `Retry-After` envelope.
- **Injection** — SQLi via bound params only (SQLAlchemy expressions), no f-string SQL;
  Pydantic validates all bodies; path/query bounds.
- **Secret handling** — `SecretStr`, no secrets in code/logs/repo, rotate, `.env` gitignored,
  read from secret manager in prod.
- **Log redaction** — strip `Authorization`, cookies, tokens, passwords, PII from structured
  logs; a redacting filter/processor.
- **Security headers & misc** — HSTS/CSP via middleware note, `TrustedHostMiddleware`,
  request size limits, disable docs in prod if required.
- **Dependency audit** — `pip-audit`, `uv pip compile` pinned/hashed lockfiles, Dependabot.
Key code: argon2 hash/verify; full `decode_token` with claim validation + alg pin;
`require_roles` factory; slowapi limiter; log-redaction filter. See-Also `secure-coding`.

### 3d. `references/production.md` — "Running FastAPI in production"
Outline (H2s):
- **ASGI server** — uvicorn for dev; gunicorn + `uvicorn.workers.UvicornWorker` (or
  `uvicorn --workers`) for prod; worker count math `(2×CPU)+1`, `--timeout`, `--graceful-timeout`;
  why not `--reload` in prod.
- **Structured logging** — JSON logs (structlog or stdlib `logging` + `python-json-logger`),
  request-id middleware, correlating logs, log levels by env; integrate with uvicorn's loggers.
- **Health & readiness** — `/health` liveness (no deps) vs `/health/ready` (pings DB/cache);
  k8s probe semantics.
- **Graceful shutdown** — lifespan teardown (`engine.dispose()`, drain background work),
  SIGTERM handling, connection draining; idempotent shutdown.
- **Pagination at scale** — offset vs keyset/cursor (link to `api-design`), `count` cost,
  consistent ordering; envelope `meta`/`links`.
- **Caching** — HTTP cache headers (`ETag`, `Cache-Control`), app-level Redis cache-aside
  with explicit invalidation, `@lru_cache` for pure config; cache stampede note.
- **Performance** — `orjson`/`ORJSONResponse`, response compression tradeoff, avoid sync I/O,
  `--proxy-headers` + `forwarded-allow-ips` behind a proxy, GZip/Brotli note, profiling pointers.
- **Observability** — OpenTelemetry/Prometheus middleware note, RED metrics.
- **Docker note** — short: slim base, non-root user, `uv`-built venv, `EXPOSE`, healthcheck;
  then **See Also `deployment`** for the full pipeline (do not duplicate it here).
Key code: gunicorn command + worker formula; structlog config + request-id middleware;
readiness endpoint pinging DB; lifespan graceful shutdown; ORJSONResponse default.

---

## 4. `verify.sh` contract

Path: `skills/fastapi/scripts/verify.sh`. Executable (`chmod +x` after write). The **end
user runs it inside their own FastAPI project** — never executed in this skills repo.

Header: `#!/usr/bin/env bash` then `set -euo pipefail`. Top usage comment block explaining
purpose, that it auto-detects tooling, skips (yellow warn) what's missing, and exits non-zero
only on real failures. Prefer `uv run <tool>` when `uv` is present, else fall back to the
bare tool on `PATH`.

**Behavior contract:**
- Define color helpers (`warn` yellow, `ok` green, `fail` red) guarded for non-TTY.
- A `have <cmd>` helper (`command -v`) and a `run_step <label> <cmd...>` wrapper that, when
  the tool is missing, prints a yellow `SKIP: <tool> not installed` and continues (does not
  fail), and on tool failure records non-zero and continues so all checks report before exit.
- Track a `FAILED` accumulator; exit `1` at the end if any step failed, else `0`.
- Run from the project root; respect an optional first arg as target path (default `.`).

**Exact tool order:**
1. `ruff check .` — lint. (skip if no `ruff`)
2. `ruff format --check .` — formatting drift. (skip if no `ruff`)
3. `mypy .` — type check (strict via project config). (skip if no `mypy`)
4. `pytest --cov --cov-report=term-missing` — tests + coverage; honor the project's
   `--cov-fail-under` from `pyproject.toml` (do not hardcode a second threshold). (skip if no `pytest`)
5. `pip-audit` — dependency vulnerability scan. (skip if no `pip-audit`; if `uv` present,
   also acceptable: `uv pip compile`/audit path — keep it to `pip-audit` for clarity.)

Skip vs fail: **missing tool = yellow SKIP, exit unaffected.** **Tool ran and returned
non-zero = red FAIL, accumulate.** Final line prints a summary (`N passed, M skipped, K failed`)
and exits non-zero iff `K>0`. Idempotent: read-only except whatever the user's own pytest does;
running twice yields the same result.

---

## 5. Quality differentiators (why this beats the ECC equivalents)

1. **One skill, full lifecycle.** ECC splits this across `fastapi-patterns`, `python-patterns`,
   `python-testing`, `api-design`, `backend-patterns`, `error-handling`. This skill unifies
   build→test→secure→ship for FastAPI specifically, with hard pointers out to siblings only
   for genuinely orthogonal concerns — no context-switching across six files for one PR.
2. **Strictly current.** ECC `python-patterns` still shows `typing.Optional/List/Dict`,
   `requires-python = ">=3.9"`, py39 ruff config, and Pydantic-less dataclasses. This skill is
   Python 3.12+, `X | None`, `Annotated`, Pydantic **v2** (`model_dump`/`model_validate`,
   `ConfigDict`), SQLAlchemy **2.0** (`Mapped`/`mapped_column`), uv-first — and explicitly
   flags the v1→v2 / 1.x→2.0 traps ECC predates.
3. **Async-correct end to end.** ECC's FastAPI test fixtures use Flask-style
   `app.test_client()` (wrong for FastAPI). This skill uses `httpx.ASGITransport` AsyncClient,
   `asyncio_mode=auto`, and a real **transactional `begin_nested` rollback** DB fixture — the
   pattern most tutorials get wrong.
4. **Security with teeth.** Goes beyond ECC's checklist: pins JWT `algorithms`, validates
   `exp/iss/aud`, rejects `alg=none`, argon2 rehash-on-login, shared-store rate limiting with
   the serverless failure-mode warning, and a concrete log-redaction filter — not just "validate
   JWT" as a bullet.
5. **N+1 made unmissable.** Dedicated `database.md` shows that **lazy loading is unsafe in
   async SQLAlchemy** and gives the `selectinload`/`joinedload` fix with Good/Bad — ECC only
   warns abstractly in TypeScript/Supabase terms.
6. **Production that k8s respects.** Liveness vs readiness split, worker-count math,
   graceful-shutdown via lifespan with `engine.dispose()`, proxy-header handling — concrete and
   runnable, where ECC stops at structured-logging snippets.
7. **A real gate the user runs.** `verify.sh` is an idempotent, tool-detecting CI-grade gate
   (ruff/format/mypy/pytest-cov/pip-audit) that skips gracefully — ECC only lists commands prose.
8. **Anti-pattern table calibrated to FastAPI's real footguns** (sync calls in async routes,
   returning ORM objects, global sessions, `.dict()`, unpinned JWT alg, f-string SQL,
   `BackgroundTasks` as a queue) — directive STOP framing matching the house style of
   `risco-project-harness`.
