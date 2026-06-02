# Web endpoints & scaling — deep dive

The four web decorators, concurrency/batching, and the cold-start vs cost tradeoff.
All Modal 1.0+ (modal 1.4.3). Stack order is always: `@app.function` outermost, then optional
`@modal.concurrent`, then the web decorator innermost.

## The four web decorators

### `@modal.fastapi_endpoint()` — one function, one URL

The lightest option: turn a single function into a GET/POST endpoint. Needs
`fastapi[standard]` in the image.

```python
image = modal.Image.debian_slim().uv_pip_install("fastapi[standard]")


@app.function(image=image)
@modal.fastapi_endpoint(method="POST", docs=True)
def predict(payload: dict) -> dict:
    return {"echo": payload}
```

Pass `method=` for the verb and `docs=True` to expose the OpenAPI docs page. Good for a quick
inference URL; reach for `asgi_app` when you need routing.

### `@modal.asgi_app()` — a full FastAPI / Starlette app

Return an ASGI app object. Use when you want multiple routes, middleware, or a real API surface.

```python
@app.function(image=image)
@modal.concurrent(max_inputs=20)
@modal.asgi_app()
def api():
    from fastapi import FastAPI

    web = FastAPI()

    @web.get("/items/{item_id}")
    def read(item_id: int):
        return {"item_id": item_id}

    return web
```

The *design* of this FastAPI app (Pydantic models, dependencies, error envelopes) is the
`fastapi` sibling's job — Modal only hosts it.

### `@modal.wsgi_app()` — Flask / Django

Return a WSGI callable. Same stacking; install the framework in the image.

```python
@app.function(image=modal.Image.debian_slim().uv_pip_install("flask==3.1.0"))
@modal.wsgi_app()
def flask_app():
    from flask import Flask

    web = Flask(__name__)

    @web.route("/")
    def index():
        return "ok"

    return web
```

### `@modal.web_server(port=...)` — run your own server

When the workload spawns its own HTTP server (vLLM, TGI, a uvicorn process), use `web_server`
and let Modal proxy the port.

```python
@app.function(image=vllm_image, gpu="H100")
@modal.web_server(port=8000, startup_timeout=300)
def serve():
    import subprocess

    subprocess.Popen("vllm serve <model> --port 8000", shell=True)
```

`startup_timeout` covers slow model loads before health checks begin.

## Concurrency: `@modal.concurrent`

One container, many simultaneous inputs. Replaces the removed `allow_concurrent_inputs=` arg.

```python
@app.function(image=image)
@modal.concurrent(max_inputs=100)
def handler(x): ...
```

Set `max_inputs` to what a single container can handle concurrently without resource
contention — for I/O-bound work it can be high; for GPU inference it's bounded by VRAM and
batch capacity. Too high → OOM / latency spikes; too low → you pay for more containers than
needed.

## Batching: `@modal.batched`

Coalesce individual calls into batches server-side (great for GPU inference throughput).

```python
@app.function(image=image, gpu="A100")
@modal.batched(max_batch_size=16, wait_ms=50)
def embed(texts: list[str]) -> list[list[float]]:
    # Modal collects up to 16 calls (or waits 50ms) and passes them as one list.
    ...
```

`max_batch_size` caps the batch; `wait_ms` is how long to wait to fill it. Trade a little
latency for much higher GPU utilization.

## Scaling & cold-start tradeoff

| Param | Lower value | Higher value |
|---|---|---|
| `min_containers` | Scale fully to zero — cheapest, cold starts on first hit | Warm pool always ready — no cold start, pays idle 24/7 |
| `buffer_containers` | No pre-warm buffer | Absorbs traffic bursts before autoscale catches up |
| `scaledown_window` | Containers die fast after idle — cheaper, more cold starts | Stay warm longer — fewer cold starts, more idle cost |

Tuning order for a latency-sensitive endpoint: first widen `scaledown_window` so nearby
requests reuse a hot container; only set `min_containers >= 1` if you truly need zero cold
starts (e.g. a customer-facing API with an SLA). For a GPU endpoint, even `min_containers=1`
is a real ongoing cost — measure before pinning it.

## Custom domains, auth, proxy tokens

- **Custom domain:** map your domain to the deployed app in the Modal dashboard; the
  deployment URL is stable after `modal deploy`.
- **Endpoint auth:** protect a `fastapi_endpoint`/`asgi_app` with Modal proxy auth tokens so
  only callers with the token reach it — configure tokens on the function and pass them as
  request headers. Prefer this over hand-rolling auth inside the handler for machine-to-machine
  endpoints.
- **Dev vs prod:** iterate with `modal serve` (hot reload, ephemeral URL); ship with
  `modal deploy` (persistent named app, stable URL). Never rely on a `modal serve` URL in
  production — it dies when you stop the process.
