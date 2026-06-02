# Ollama local API reference

Daemon base URL: `http://localhost:11434`. Bind elsewhere with `OLLAMA_HOST=0.0.0.0:11434`.
Two surfaces share the daemon: the **native** API (`/api/*`) and the **OpenAI-compatible** layer
(`/v1/*`).

## Native endpoint catalog

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/api/generate` | single-turn completion (`prompt`) |
| POST | `/api/chat` | multi-turn chat (`messages`); supports `tools`, `images`, `think` |
| POST | `/api/embed` | embeddings (`input` string or array); legacy alias `/api/embeddings` |
| POST | `/api/create` | create a model from a Modelfile / quantize |
| POST | `/api/pull` | download a model |
| POST | `/api/push` | upload a model |
| POST | `/api/show` | model template, params, context length, quant |
| POST | `/api/copy` | duplicate a model under a new name |
| DELETE | `/api/delete` | remove a model |
| GET | `/api/tags` | models on disk (≈ `ollama list`) |
| GET | `/api/ps` | models loaded in memory (≈ `ollama ps`) |
| GET | `/api/version` | daemon version |

## Request fields (generate / chat)

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `model` | string | — | **required**; a pulled tag |
| `prompt` | string | — | `/api/generate` only |
| `messages` | array | — | `/api/chat`; `{role, content, images?, tool_calls?}` |
| `stream` | bool | `true` | NDJSON stream; set `false` for a single object |
| `format` | string \| object | — | `"json"` or a JSON Schema object to constrain output |
| `options` | object | — | runtime params: `temperature`, `num_ctx`, `top_p`, `seed`, `num_predict`, `stop`, … |
| `keep_alive` | string \| int | `"5m"` | how long to keep loaded; `0` unloads now, `-1` keeps forever |
| `tools` | array | — | tool/function definitions for tool calling |
| `images` | array | — | base64 images for multimodal models |
| `think` | bool | — | enable/disable reasoning on models that support it |

`options.num_ctx` is per-request and does not persist. Bake a permanent context window into a
Modelfile with `PARAMETER num_ctx`.

## Response fields

Final object (streaming or not) carries: `done` (bool), `done_reason`, `total_duration`,
`load_duration`, `prompt_eval_count`, `prompt_eval_duration`, `eval_count`, `eval_duration`.
Tokens/sec ≈ `eval_count / (eval_duration / 1e9)`.

Streaming = NDJSON: one JSON object per line; accumulate `message.content` (chat) or `response`
(generate) until `done: true`.

```python
import requests, json

with requests.post("http://localhost:11434/api/chat",
                   json={"model": "qwen3:8b",
                         "messages": [{"role": "user", "content": "Count to 3."}]},
                   stream=True) as r:
    for line in r.iter_lines():
        if line:
            obj = json.loads(line)
            print(obj.get("message", {}).get("content", ""), end="", flush=True)
            if obj.get("done"):
                break
```

## Structured output via `format`

Pass a JSON Schema as `format`; the model is constrained to emit conforming JSON. Pair with a low
temperature and an explicit instruction to return JSON.

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "qwen3:8b",
  "messages": [{"role": "user", "content": "List two EU capitals as JSON."}],
  "stream": false,
  "options": {"temperature": 0},
  "format": {
    "type": "object",
    "properties": {
      "capitals": {"type": "array", "items": {"type": "string"}}
    },
    "required": ["capitals"]
  }
}'
```

## Tool calling

Define `tools`; the response may contain `message.tool_calls`. Execute the tool, append a
`{"role": "tool", "content": "<result>"}` message, and call again.

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "qwen3:8b",
  "stream": false,
  "messages": [{"role": "user", "content": "Weather in Andorra?"}],
  "tools": [{
    "type": "function",
    "function": {
      "name": "get_weather",
      "description": "Current weather for a city",
      "parameters": {
        "type": "object",
        "properties": {"city": {"type": "string"}},
        "required": ["city"]
      }
    }
  }]
}'
```

## Embeddings

```bash
curl http://localhost:11434/api/embed -d '{
  "model": "nomic-embed-text",
  "input": ["first chunk", "second chunk"]
}'
```

Returns `embeddings` (array of float arrays). For the retrieval pipeline around these vectors, that's
`rag` / `embeddings-search`, not this skill.

## OpenAI-compatible layer (`/v1`)

| OpenAI path | Ollama support |
| --- | --- |
| `POST /v1/chat/completions` | yes — drop-in for chat |
| `POST /v1/completions` | yes — legacy text completion |
| `POST /v1/embeddings` | yes |
| `GET /v1/models` | lists pulled models |

Point any OpenAI SDK at the base URL with any non-empty key (it is ignored):

```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")

# streaming
for chunk in client.chat.completions.create(
        model="qwen3:8b",
        messages=[{"role": "user", "content": "hi"}],
        stream=True):
    print(chunk.choices[0].delta.content or "", end="")
```

Native-only knobs (`keep_alive`, `format` as a JSON Schema, `think`) aren't expressible through the
OpenAI layer — use `/api/chat` when you need them.
