# Serverless workers — fuller patterns

Depth for the SKILL.md "Serverless worker handler" section. The `runpod` Python SDK drives
all of this.

## start() options

```python
import runpod

runpod.serverless.start({
    "handler": handler,                 # required: sync or async callable
    "return_aggregate_stream": True,    # generator handlers: also expose joined output via /runsync
    "concurrency_modifier": adjust,     # callable -> max concurrent jobs this worker takes
})
```

## Async handler

Use `async def` when the handler awaits I/O (model server, HTTP, DB). The runtime awaits it.

```python
import runpod

async def handler(job):
    job_input = job["input"]
    result = await run_model(job_input["prompt"])
    return {"output": result}

runpod.serverless.start({"handler": handler})
```

## Streaming via async generator

`yield` chunks instead of returning once. Clients read them from the `/stream/<id>` endpoint.
Set `return_aggregate_stream: True` if you also want the joined result on `/runsync`.

```python
import runpod

async def handler(job):
    for token in generate(job["input"]["prompt"]):
        yield {"token": token}

runpod.serverless.start({"handler": handler, "return_aggregate_stream": True})
```

## Concurrency modifier

By default a worker takes one job at a time. For lightweight or batched work, let one worker
hold several concurrent jobs — fewer cold starts, lower bill. Return the max concurrency
given the current count.

```python
def adjust_concurrency(current_concurrency):
    # Cap at 4 concurrent jobs per worker.
    return min(current_concurrency + 1, 4)

runpod.serverless.start({"handler": handler, "concurrency_modifier": adjust_concurrency})
```

## Error shape

Raise to fail a job, or return a dict with an `error` key. Failed jobs surface in the
endpoint status; a worker that errors repeatedly can be refresh-cycled.

```python
def handler(job):
    job_input = job["input"]
    if "prompt" not in job_input:
        return {"error": "missing 'prompt' in input"}
    return {"output": run(job_input["prompt"])}
```

## Local testing

Always exercise the handler locally before building/pushing an image.

- **One-shot:** create `test_input.json`, then `python worker.py`. The SDK detects the file,
  runs the handler once against its `input`, prints the output, and exits.

  ```json
  { "input": { "prompt": "hello" } }
  ```

- **HTTP server:** `python worker.py --rp_serve_api` starts a local server at
  `http://localhost:8000` emulating the deployed endpoint, so you can POST to `/runsync` and
  `/run` exactly as the platform would.

## Endpoint HTTP API

Once deployed, an endpoint exposes (auth with your API key as a bearer token):

| Endpoint | Purpose |
| --- | --- |
| `POST /run` | Submit an async job, returns a job id immediately. |
| `POST /runsync` | Submit and block for the result (short jobs, ~90s ceiling). |
| `GET /stream/<id>` | Pull streamed chunks from a generator handler. |
| `GET /status/<id>` | Poll an async job's status + output. |
| `POST /cancel/<id>` | Cancel a queued or running job. |
| `GET /health` | Worker counts and queue depth for the endpoint. |
