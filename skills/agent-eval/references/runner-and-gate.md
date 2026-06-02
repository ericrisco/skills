# The runner, the gate, and framework equivalents

Depth offloaded from `SKILL.md`. A provider-neutral runner you can drop into any repo, the CI
wiring, and the same eval expressed in DeepEval and Inspect AI so you can switch tools without
relearning the craft.

## The five stages, in code

`dataset → runner → scorers → metrics → gate`. Keep them separable so each can be swapped.

### Dataset loader (JSONL, decontaminated, versioned)

```python
import json
from pathlib import Path

REQUIRED = {"id", "input", "expected"}

def load_cases(path: str) -> list[dict]:
    cases = []
    for i, line in enumerate(Path(path).read_text().splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        case = json.loads(line)
        missing = REQUIRED - case.keys()
        if missing:
            raise ValueError(f"{path}:{i} missing keys {missing}")
        cases.append(case)
    return cases
```

### Scorer registry

Every scorer satisfies one protocol — deterministic and judge are interchangeable. See
`judge-design.md` for the judge implementations.

```python
from dataclasses import dataclass
from typing import Callable

@dataclass
class Scorer:
    name: str
    fn: Callable[[dict, str], float]   # (case, output) -> 0.0..1.0

def exact_match(case, output):
    return 1.0 if output.strip() == case["expected"].strip() else 0.0

def latency_under(threshold_s):
    def _fn(case, output):
        return 1.0 if case["meta"].get("latency_s", 0) <= threshold_s else 0.0
    return _fn

REGISTRY = [
    Scorer("exact_match", exact_match),
    Scorer("latency_2s", latency_under(2.0)),
    # Scorer("faithfulness", FaithfulnessJudge(judge_model).score),  # 30% judge
]
```

### Runner + bootstrap-CI metrics

The bootstrap CI is what stops judge noise from flapping the gate: only a drop beyond the
interval counts as a real regression.

```python
import random, statistics

def run(system, cases, scorers):
    rows = []
    for case in cases:
        output = system(case["input"])               # the system under test
        row = {"id": case["id"],
               "failure_mode": case["meta"].get("failure_mode", "none")}
        for s in scorers:
            row[s.name] = s.fn(case, output)
        rows.append(row)
    return rows

def metrics(rows, scorers, n_boot=1000):
    out = {}
    for s in scorers:
        vals = [r[s.name] for r in rows]
        mean = statistics.fmean(vals)
        boots = [statistics.fmean(random.choices(vals, k=len(vals)))
                 for _ in range(n_boot)]
        boots.sort()
        out[s.name] = {"mean": round(mean, 4),
                       "ci_low": round(boots[int(0.025 * n_boot)], 4),
                       "ci_high": round(boots[int(0.975 * n_boot)], 4)}
    return out
```

### Gate (block on regression vs committed baseline)

```python
import json, sys

def gate(current: dict, baseline: dict, report_path="eval-report.json") -> int:
    regressed = []
    for metric, m in current.items():
        base = baseline.get(metric, {}).get("mean")
        # Real regression: the current CI is entirely below the baseline mean.
        if base is not None and m["ci_high"] < base:
            regressed.append({"metric": metric, "baseline": base,
                              "now": m["mean"], "ci_high": m["ci_high"]})
    report = {"metrics": current, "baseline": baseline,
              "regressed": regressed, "passed": not regressed}
    Path(report_path).write_text(json.dumps(report, indent=2))
    for r in regressed:
        print(f"REGRESSION {r['metric']}: {r['baseline']} -> {r['now']}",
              file=sys.stderr)
    return 1 if regressed else 0
```

Update the baseline deliberately — commit a new `eval-baseline.json` in the PR that *intends*
to move the metric, so the move is reviewed, not silent.

## GitHub Actions wiring

```yaml
name: eval-gate
on: [pull_request]
jobs:
  eval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r evals/requirements.txt
      - name: Run eval gate
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: python evals/run.py          # exits non-zero on regression -> blocks merge
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: eval-report, path: eval-report.json }
```

The non-zero exit is the gate. Upload the report `if: always()` so a failed run still shows
*which* metric and failure mode regressed.

## Same eval in DeepEval (pytest-native)

```python
from deepeval import assert_test
from deepeval.test_case import LLMTestCase
from deepeval.metrics import FaithfulnessMetric

def test_faithfulness():
    case = LLMTestCase(
        input="Where is my refund for order 4821?",
        actual_output=system("Where is my refund for order 4821?"),
        retrieval_context=["policy: refunds 5-7 business days"],
    )
    assert_test(case, [FaithfulnessMetric(threshold=0.8)])
```

DeepEval v4.0.3 reads like tests and runs under pytest; reach for it when CI is already Python.

## Same eval in Inspect AI (Task / Solver / Scorer)

```python
from inspect_ai import Task, task
from inspect_ai.dataset import json_dataset
from inspect_ai.solver import generate
from inspect_ai.scorer import model_graded_qa

@task
def refund_quality():
    return Task(
        dataset=json_dataset("evals/cases.jsonl"),
        solver=generate(),
        scorer=model_graded_qa(),   # judge with rationale; bootstrap CIs built in
    )
# inspect eval refund_quality.py --model openai/gpt-... -> pass/fail + CIs
```

Inspect AI v0.3.225 (UK AISI) gives first-class tool-use and trajectory logging plus bootstrap
CIs out of the box; reach for it when you are multi-provider or need real trajectory scoring.
Both express the identical `dataset → scorer → gate` pipeline — the tool is a detail.
