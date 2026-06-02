# Cog packaging — full reference

Cog (open source, https://github.com/replicate/cog · https://cog.run) packages an ML model into a
production Docker container. Two files drive it: `cog.yaml` (build + which predictor) and a Python
module with a `BasePredictor`. `cog predict` runs it locally; `cog push r8.im/owner/model` builds and
ships it, and Replicate auto-generates the API server on its GPU cluster. Building needs Docker.

## Full `cog.yaml`

```yaml
build:
  gpu: true                       # provisions a CUDA base image; omit/false for CPU-only
  python_version: "3.11"          # quoted — "3.10" not 3.10
  system_packages:                # apt packages baked into the image
    - "ffmpeg"
    - "libgl1-mesa-glx"
  python_packages:                # pinned pip deps
    - "torch==2.4.0"
    - "transformers==4.44.0"
    - "pillow==10.4.0"
  run:                            # extra build steps, run after pip install
    - "pip install --no-cache-dir flash-attn==2.6.3"
predict: "predict.py:Predictor"   # module path : class name
```

Notes:
- Quote `python_version` and every package version. Unpinned packages make builds non-reproducible.
- `build.gpu: true` selects a CUDA image automatically — do not hand-install CUDA in `run:`.
- `system_packages` is apt; `python_packages` is pip; `run:` is for anything neither covers.
- For LLMs, you can add a `concurrency.max` to allow batched concurrent predict calls per instance.

## Full `predict.py`

```python
from cog import BasePredictor, Input, Path
import torch

class Predictor(BasePredictor):
    def setup(self) -> None:
        """Runs ONCE per instance boot. Load weights here."""
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model = torch.load("weights/model.pth", map_location=self.device)
        self.model.eval()

    def predict(
        self,
        prompt: str = Input(description="Text prompt"),
        guidance: float = Input(description="Guidance scale", default=7.5, ge=1.0, le=20.0),
        seed: int = Input(description="Random seed; -1 = random", default=-1),
    ) -> Path:
        """Runs PER request. Keep it pure inference."""
        if seed == -1:
            seed = int(torch.randint(0, 2**31 - 1, (1,)).item())
        result = self.model.generate(prompt, guidance=guidance, seed=seed)
        out = Path("/tmp/out.png")
        result.save(out)
        return out                  # Cog uploads it and returns a FileOutput to callers
```

Rules that matter:
- **`setup()` once, `predict()` every call.** Weight loading, model compilation, and warmup belong in
  `setup()`. Putting them in `predict()` makes every request pay the load cost.
- Type every `predict()` argument and wrap it in `Input(...)` — Cog turns these into the model's API
  schema, validation, and the website's input form. Use `default=`, `ge`/`le`, `choices=[...]`.
- Return `Path` for file outputs (Cog uploads them), or a JSON-serializable value / `list[Path]`.
- Bake weights into the image or download them in `setup()` to a cached path — never per request.

## Local run, build, push

```bash
cog predict -i prompt="a cat" -i guidance=6.0     # run locally end to end (needs Docker)
cog build -t my-model                              # build the image without pushing
cog push r8.im/owner/model                         # build + push; creates a new version
cog login                                          # if you haven't authenticated the CLI
```

Each `cog push` creates an immutable **version** (a SHA). Pin to a specific version in production calls
(`owner/model:<version>`) so a later push does not silently change behavior; deployments target a
version explicitly.

## Common build failures

| Symptom | Cause | Fix |
|---|---|---|
| `cog push` hangs / OOM on build | Huge weights copied into image | Download weights in `setup()` instead of baking, or use a slimmer base |
| CUDA / torch version mismatch | `gpu: true` CUDA vs pinned torch wheel | Pin a torch build that matches the CUDA the image ships |
| `predict.py:Predictor` not found | Wrong module path or class name in `predict:` | Match `file.py:ClassName` exactly |
| Local works, push image broken | Relying on host files not in the image | Ensure weights/assets are in the build context or fetched in `setup()` |
| `flash-attn` build error | Compiled against missing toolchain | Install via `run:` after torch, or use a prebuilt wheel |
