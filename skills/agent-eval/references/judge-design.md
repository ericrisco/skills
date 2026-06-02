# LLM-as-judge design and calibration

Depth offloaded from `SKILL.md`. A judge is a scorer, so the one rule binds hardest here:
**calibrate against human gold and report agreement before you trust a single judge score.**
Judge–human agreement reaches ~85% in 2026 (higher than two humans on the same task) — but
only with a capable judge model and a rubric that forces a written rationale.

## Pointwise rubric template

Pointwise (rate one answer) is convenient but inflates and clusters at 8–9. Use it only when
you cannot run pairwise, and always force the rationale first.

```text
You are grading an answer against a reference. The dimension is FAITHFULNESS:
every claim in the answer must be supported by the provided context.

Context:
{context}

Answer:
{answer}

Steps (do them in order):
1. List each factual claim in the answer.
2. For each claim, mark SUPPORTED or UNSUPPORTED against the context.
3. Only then output a JSON object: {"rationale": "...", "score": <0.0-1.0>}
   where score = supported_claims / total_claims.
```

The order matters: a rubric that asks for the number first gets a vibe; asking for the
claim-by-claim breakdown first forces the reasoning that earns the ~85% agreement.

## Pairwise rubric template (preferred)

"Is A or B better?" is more reproducible than an absolute rating. Use it for before/after and
A/B comparisons.

```text
Compare two answers, A and B, against the reference for HELPFULNESS.

Reference: {reference}
Answer A: {a}
Answer B: {b}

1. One sentence on what A does well/badly vs the reference.
2. One sentence on what B does well/badly vs the reference.
3. Output JSON: {"rationale": "...", "winner": "A" | "B" | "tie"}
```

## Position-swap harness (kills position bias)

Judges favor whichever answer appears first. Run each comparison twice with positions swapped
and only count a clear win as a win.

```python
def pairwise(judge, reference, a, b):
    """Return 'a', 'b', or 'tie' after canceling position bias."""
    first  = judge.compare(reference, a, b)   # A in slot 1
    second = judge.compare(reference, b, a)   # A in slot 2 -> remap
    remap = {"A": "b", "B": "a", "tie": "tie"}
    r1 = {"A": "a", "B": "b", "tie": "tie"}[first]
    r2 = remap[second]
    if r1 == r2:
        return r1                # consistent across positions -> trust it
    return "tie"                 # judge flipped with position -> not a real signal
```

A judge that flips when you swap positions has told you it cannot separate the two — record a
tie, do not pick the first-slot winner.

## Calibration script (agreement and Cohen's kappa vs human gold)

You need a small human-labeled gold slice (~10% of cases, the ambiguous ones). Run the judge
on it and measure how often it agrees with the humans. Report this number in `eval-report.json`
and refuse to gate if it is low.

```python
def cohen_kappa(human: list[int], judge: list[int]) -> float:
    """Agreement corrected for chance. 1.0 perfect, 0 chance-level."""
    n = len(human)
    po = sum(h == j for h, j in zip(human, judge)) / n        # raw agreement
    labels = set(human) | set(judge)
    pe = sum((human.count(k) / n) * (judge.count(k) / n) for k in labels)
    return (po - pe) / (1 - pe) if pe != 1 else 1.0

def calibration_report(human, judge):
    raw = sum(h == j for h, j in zip(human, judge)) / len(human)
    return {"raw_agreement": round(raw, 3),
            "cohen_kappa": round(cohen_kappa(human, judge), 3)}
```

Rules of thumb for the kappa: < 0.4 the judge is unusable, fix the rubric or model; 0.4–0.6
marginal, widen the human slice; > 0.6 with raw agreement ~0.85 is the working zone. These are
thresholds for *trusting the judge*, not for gating the system.

## G-Eval vs DAG

- **G-Eval** — you give the judge an evaluation-criteria sentence; it generates the
  chain-of-thought steps and a weighted score. Fast to author, good for fuzzy semantic
  dimensions (coherence, helpfulness). Less reproducible for hard rules.
- **DAG (Decision Graph)** — you author an explicit decision tree of yes/no checks; the score
  is deterministic given the answers. Use for compliance-style "must / must-not" criteria where
  you want auditability over flexibility. DeepEval v4 ships this as first-class.

Pick G-Eval for taste, DAG for rules.

## Judge bias catalog and mitigations

| Bias | Symptom | Mitigation |
| --- | --- | --- |
| Position | Favors the first answer shown | Position-swap harness above; count only consistent wins |
| Length | Scores longer answers higher regardless of quality | Add "ignore length; reward density" to the rubric; spot-check long losers |
| Self-preference | A model prefers text in its own style | Use a different model family as judge than the system under test |
| Verbosity-of-rationale | Long rationale read as more correct | Score the claim breakdown, not the prose |
| Anchoring on reference wording | Penalizes correct paraphrases | Grade meaning vs reference, not surface overlap; test with known-good paraphrases |

Re-run the calibration slice whenever you change the judge model or rubric — a judge swap is a
scorer change, and an uncalibrated scorer is back to a number you cannot defend.
