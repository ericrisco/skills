# Images, GPU & state cookbook

Deep recipes for `modal.Image` builds, GPU selection, and Volume/Secret-backed state.
All forms are Modal 1.0+ (modal 1.4.3). GPU is always a string; `modal.gpu.X()` is removed.

## Image recipes

### Torch + CUDA inference

```python
import modal

image = (
    modal.Image.debian_slim(python_version="3.12")
    .uv_pip_install(
        "torch==2.5.1",
        "transformers==4.46.0",
        "accelerate==1.1.1",
    )
)
```

`debian_slim` already ships a CUDA-capable userspace for the GPU you attach — you do not
install CUDA yourself. Pin every wheel so a rebuild is byte-for-byte reproducible.

### vLLM server (own HTTP server via web_server)

```python
vllm_image = (
    modal.Image.debian_slim(python_version="3.12")
    .uv_pip_install("vllm==0.6.4", "fastapi[standard]")
)


@app.function(image=vllm_image, gpu="H100", scaledown_window=300, timeout=600)
@modal.concurrent(max_inputs=32)
@modal.web_server(port=8000, startup_timeout=300)
def serve():
    import subprocess

    # vLLM exposes its own OpenAI-compatible server on :8000; web_server proxies it.
    subprocess.Popen(
        "vllm serve meta-llama/Llama-3.1-8B-Instruct --port 8000",
        shell=True,
    )
```

`web_server` is the right decorator when the process *is* the server (vLLM, TGI, a custom
uvicorn). Use `startup_timeout` to allow weight loading before health checks begin.

### Diffusers image generation

```python
diff_image = modal.Image.debian_slim(python_version="3.12").uv_pip_install(
    "diffusers==0.31.0", "torch==2.5.1", "transformers==4.46.0", "accelerate==1.1.1"
)
```

### System binaries (ffmpeg, git)

```python
image = (
    modal.Image.debian_slim()
    .apt_install("ffmpeg", "git")     # system layer first — rarely changes
    .uv_pip_install("imageio-ffmpeg==0.5.1")
)
```

### Custom base image

```python
image = modal.Image.from_registry(
    "nvidia/cuda:12.4.0-devel-ubuntu22.04", add_python="3.12"
).uv_pip_install("xformers==0.0.28.post3")
```

Reach for `from_registry` only when `debian_slim` can't express what you need (a specific CUDA
devel toolchain, a vendor image). It's heavier and slower to pull.

## GPU selection matrix

| GPU string | Rough fit | Notes |
|---|---|---|
| `"T4"` | Cheap small-model inference, embeddings | 16GB; cheapest |
| `"L4"` | Efficient inference, light vision | 24GB |
| `"A10"` | Mid-range inference | 24GB |
| `"L40S"` | Mid/large inference, some training | 48GB |
| `"A100-40GB"` / `"A100-80GB"` | Training, 7–70B serving | colon for count: `"A100:4"` |
| `"H100"` | Fast large-model training/serving | 80GB |
| `"H200"` | Larger memory frontier work | 141GB |
| `"B200"` | Frontier-scale | newest |
| `"RTX-PRO-6000"` | Workstation-class | |

Multi-GPU: `gpu="A100:8"`. Fallbacks for capacity: `gpu=["H100", "A100", "any"]` — Modal grabs
the first available so a job isn't stuck waiting for one exact type. Always start with the
smallest GPU your model fits in; step up only when you OOM.

## Volume-backed weight cache (download once, mount everywhere)

The pattern that makes GPU cold starts cheap: download weights into a Volume once, then mount
the same Volume read-mostly into every serving container.

```python
import modal

app = modal.App("cached-llm")
cache = modal.Volume.from_name("hf-cache", create_if_missing=True)
image = modal.Image.debian_slim(python_version="3.12").uv_pip_install(
    "huggingface_hub==0.26.2", "transformers==4.46.0", "torch==2.5.1"
)
CACHE_DIR = "/cache"


@app.function(
    image=image,
    volumes={CACHE_DIR: cache},
    secrets=[modal.Secret.from_name("hf-token")],
    timeout=1800,
)
def warm_cache(repo: str = "meta-llama/Llama-3.1-8B-Instruct"):
    import os
    from huggingface_hub import snapshot_download

    snapshot_download(repo, cache_dir=CACHE_DIR, token=os.environ["HF_TOKEN"])
    cache.commit()  # persist the download so serving containers can read it


@app.function(image=image, gpu="H100", volumes={CACHE_DIR: cache})
def generate(prompt: str):
    cache.reload()  # see what warm_cache committed
    import os

    os.environ["HF_HOME"] = CACHE_DIR  # transformers reads weights from the mounted cache
    # ... load model from CACHE_DIR, no re-download ...
```

Run `modal run app.py::warm_cache` once, then deploy the serving function. Without
`cache.commit()` the download evaporates with the container; without `cache.reload()` the
serving container may not see it yet.

## Secret patterns

```python
# Reference an existing named Secret (created via dashboard or `modal secret create`).
hf = modal.Secret.from_name("hf-token")       # injects HF_TOKEN env var
openai = modal.Secret.from_name("openai")     # injects OPENAI_API_KEY

# Ad-hoc inline (for local dev only; prefer named Secrets in prod).
inline = modal.Secret.from_dict({"MY_FLAG": "1"})


@app.function(secrets=[hf, openai])
def call():
    import os

    return os.environ["OPENAI_API_KEY"][:6]
```

Secrets become environment variables inside the container. Never put them in the image, in
`run_commands`, or in source — those persist in layer history and in git.
