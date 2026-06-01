# Running FastAPI in production

Shipping an async FastAPI service: ASGI server + worker math, structured JSON logging with
request correlation, liveness vs readiness probes, graceful shutdown, pagination and caching at
scale, performance defaults, and observability. For the container image and CI/CD pipeline,
**See Also [`deployment`](../../deployment/SKILL.md)** — this file keeps only a Docker *note*.

## ASGI server

```bash
# Dev: one process, autoreload on file change.
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

# Prod: gunicorn process manager + uvicorn workers (install the `uvicorn-worker` package).
# Worker count rule of thumb: (2 * CPU cores) + 1
gunicorn app.main:app \
  -k uvicorn_worker.UvicornWorker \
  --workers 5 --timeout 30 --graceful-timeout 30 \
  --bind 0.0.0.0:8000 --forwarded-allow-ips '*'
```

Never run `--reload` in prod: it watches the filesystem, spawns a reloader process, and
disables key optimizations. gunicorn gives you a battle-tested process manager (restart on
crash, graceful reload). The worker class lives in the standalone `uvicorn-worker` package
(`pip install uvicorn-worker`) — the old `uvicorn.workers.UvicornWorker` was deprecated in
uvicorn 0.30 and only emits a warning today. `uvicorn app.main:app --workers 5` is a fine
gunicorn-free alternative.
`--timeout` kills a worker stuck on a single request; `--graceful-timeout` is the drain window on
shutdown. For async workloads the `(2×CPU)+1` formula is a starting point — profile real
concurrency, since one async worker handles many in-flight requests.

## Structured logging

Emit JSON so logs are queryable, and bind a request id so every line in a request correlates.

```python
import logging

import structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.dict_tracebacks,
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
    cache_logger_on_first_use=True,
)
logger = structlog.get_logger()
```

```python
import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.types import ASGIApp
import structlog


class RequestIDMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        structlog.contextvars.bind_contextvars(request_id=request_id, path=request.url.path)
        try:
            response = await call_next(request)
        finally:
            structlog.contextvars.clear_contextvars()
        response.headers["X-Request-ID"] = request_id
        return response
```

`merge_contextvars` injects the bound `request_id` into every log emitted during the request,
so a single trace id stitches the whole call together. Route uvicorn's own loggers (`uvicorn`,
`uvicorn.access`) into the same JSON handler so access logs match your format; set log level by
environment (`DEBUG` in dev, `INFO`/`WARNING` in prod).

## Health & readiness

Split liveness from readiness: liveness must not touch dependencies (a flaky DB should not kill
the pod), readiness must verify them (a pod with a dead DB should leave the load balancer).

```python
from fastapi import APIRouter, Response, status
from sqlalchemy import select

from app.api.deps import DbSession

router = APIRouter()


@router.get("")
async def liveness() -> dict[str, str]:
    return {"status": "ok"}        # no dependencies — "is the process up?"


@router.get("/ready")
async def readiness(db: DbSession, response: Response) -> dict[str, str]:
    try:
        await db.execute(select(1))
    except Exception:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "unavailable"}
    return {"status": "ready"}     # pings DB/cache — "can it serve traffic?"
```

In Kubernetes, a failing **liveness** probe restarts the pod; a failing **readiness** probe only
removes it from the Service endpoints until it recovers. Wire `/health` to liveness and
`/health/ready` to readiness accordingly.

## Graceful shutdown

```python
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.db.base import engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    # Drain: stop accepting work, finish in-flight requests, then release resources.
    await engine.dispose()         # close pooled DB connections so the DB sees a clean exit
```

On `SIGTERM`, gunicorn/uvicorn stop accepting new connections and give in-flight requests up to
`--graceful-timeout` to finish before forcing exit; the lifespan teardown then runs. Make
shutdown **idempotent** (safe if called twice) and ensure any in-process background work is
drained or handed off — connection draining at the load balancer plus the graceful window
prevents dropped requests during a rolling deploy.

## Pagination at scale

Offset pagination (`LIMIT/OFFSET`) is simple but degrades: large offsets force the DB to scan
and discard rows, and concurrent inserts shift the window (duplicates/skips). Keyset (cursor)
pagination stays O(page size) and stable.

```python
from base64 import urlsafe_b64decode, urlsafe_b64encode
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


async def keyset_page(db: AsyncSession, after: UUID | None, limit: int) -> tuple[list[User], str | None]:
    stmt = select(User).order_by(User.created_at.desc(), User.id.desc()).limit(limit)
    if after is not None:
        stmt = stmt.where(User.id < after)            # seek past the last id of the prev page
    rows = list((await db.execute(stmt)).scalars().all())
    next_cursor = urlsafe_b64encode(str(rows[-1].id).encode()).decode() if len(rows) == limit else None
    return rows, next_cursor
```

Always include a unique tiebreaker (`id`) in the `ORDER BY` so the ordering is total and stable.
`COUNT(*)` for a total is expensive on large tables — make it optional or approximate. Return a
`meta`/`links` envelope with the encoded cursor and a `next`/`prev` link; the contract here is
a REST-design concern, while the keyset SQL above is the FastAPI-side implementation.

## Caching

```python
from hashlib import sha256

import orjson
import redis.asyncio as aioredis
from fastapi import Response

redis = aioredis.from_url("redis://redis:6379/0")


async def cached_json(key: str, ttl: int, build):
    cached = await redis.get(key)
    if cached is not None:
        return orjson.loads(cached)
    value = await build()
    await redis.set(key, orjson.dumps(value), ex=ttl)   # explicit TTL; invalidate on write
    return value


def set_etag(response: Response, payload: bytes) -> None:
    etag = sha256(payload).hexdigest()
    response.headers["ETag"] = f'"{etag}"'
    response.headers["Cache-Control"] = "private, max-age=30"
```

Invalidate the cache key explicitly on any write to the underlying resource — TTL alone serves
stale data. Guard against cache stampede (many misses recomputing at once) with a short lock
(`SET key val NX EX`) or jittered TTLs. Use `@lru_cache` only for pure, process-local config
like `get_settings`.

## Performance

```python
from fastapi import FastAPI
from fastapi.responses import ORJSONResponse

app = FastAPI(default_response_class=ORJSONResponse)   # orjson: faster, handles UUID/datetime
```

Behind a reverse proxy or load balancer, pass `--proxy-headers` (uvicorn) /
`--forwarded-allow-ips` (gunicorn) so `X-Forwarded-For`/`-Proto` are trusted and `request.url`
reflects the public scheme. Add `GZipMiddleware` for large JSON responses — it trades CPU for
bandwidth, so only enable above a size threshold (`minimum_size=1000`). Never run sync/blocking
I/O on the event loop; offload CPU-bound work with `await anyio.to_thread.run_sync(...)`. Profile
hot paths with `py-spy record` against a running worker (no code changes, no restart).

## Observability

Instrument with OpenTelemetry (`opentelemetry-instrumentation-fastapi`) for distributed traces,
or a Prometheus middleware (`prometheus-fastapi-instrumentator`) for metrics. Track the RED
signals — **R**ate (requests/sec), **E**rrors (5xx ratio), **D**uration (p50/p95/p99 latency) —
per route, and alert on error ratio and tail latency rather than averages.

```python
# from prometheus_fastapi_instrumentator import Instrumentator
# Instrumentator().instrument(app).expose(app, endpoint="/metrics")
```

Keep this a pointer: pick one tracing and one metrics backend, export to your collector, and
correlate traces with the `request_id` from the logging middleware.

## Customizing the OpenAPI schema

FastAPI builds the OpenAPI document lazily and caches it on `app.openapi_schema`. To inject
extra metadata (servers, security schemes, a logo, tags) build the base schema once, mutate
it, cache it, and **assign your function to `app.openapi`** — assigning the callable (not
calling it eagerly) preserves the lazy-build-and-cache contract and lets `/docs` and
`/openapi.json` pick it up.

```python
from typing import Any

from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi


def customize_openapi(app: FastAPI) -> None:
    def build() -> dict[str, Any]:
        if app.openapi_schema:                 # serve the cached doc on later calls
            return app.openapi_schema
        schema = get_openapi(
            title=app.title,
            version=app.version,
            description="Authenticate via the OAuth2 password flow at /auth/login.",
            routes=app.routes,
        )
        schema["servers"] = [{"url": "https://api.example.com", "description": "production"}]
        schema.setdefault("components", {})["securitySchemes"] = {
            "bearerAuth": {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"},
        }
        app.openapi_schema = schema
        return schema

    app.openapi = build  # type: ignore[method-assign]  # assign, don't call — keep it lazy
```

Call `customize_openapi(app)` inside `create_app()` before returning. **Bad** =
`app.openapi_schema = customize_openapi(app)()` at import time — it forces the schema to
build before every route is registered, so late `include_router` calls go missing from the
docs.

## AppError subclasses

The base `AppError` + `register_exception_handlers` live in `SKILL.md` (Error handling &
envelope). Each concrete failure is a subclass that fixes a `code` and HTTP status, so call
sites stay declarative (`raise NotFoundError("User", ident)`) and the handler renders the
shared envelope.

```python
from fastapi import status

from app.exceptions import AppError


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
```

`Unauthorized` and `Forbidden` are the ones raised by the auth/RBAC dependencies in
[`security.md`](security.md). Prefer `NotFoundError` (404) over `Forbidden` (403) for private
resources whose existence should not leak to an unauthorized caller.

## Docker note

```dockerfile
FROM python:3.12-slim AS base
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY app ./app
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').status==200 else 1)"
CMD ["uv", "run", "gunicorn", "app.main:app", "-k", "uvicorn_worker.UvicornWorker", "--workers", "5", "--bind", "0.0.0.0:8000"]
```

A slim base, a non-root user, a frozen lockfile install, an explicit `EXPOSE`, and a
`HEALTHCHECK` hitting `/health`. For multi-stage builds, Compose, registries, and CI/CD,
**See Also `deployment`** — do not duplicate the pipeline here.

## See Also

- [`database.md`](database.md) — pool sizing vs worker count, pgbouncer, statement timeouts.
- [`security.md`](security.md) — TLS, proxy headers, security headers, secret injection.
- [`deployment`](../../deployment/SKILL.md) — Dockerfile, Compose, CI/CD, container runtime.
- [`postgresdb`](../../postgresdb/SKILL.md) — connection-pool ceilings, PgBouncer modes, partitioning at scale.
