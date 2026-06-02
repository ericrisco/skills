# references/evaluation.md — measuring a RAG pipeline

Faithfulness is not correctness, and "it looks good" is not a metric. This file gives the golden
set, the four RAGAS metrics with plain-English formulas and sensible thresholds, the
failure → metric → fix mapping, and a CI gate that fails the build below threshold.

Sources: RAGAS docs; Cohorte "Evaluating RAG Systems in 2025"; Confident AI / Maxim "RAG
Evaluation 2025" (accessed 2026-06-02).

## 1. Build a golden set

A golden set is 30–50 questions with known-good answers and, ideally, the ids of the chunks that
*should* be retrieved.

- Cover the real query distribution: factual lookups, multi-hop, "not in the corpus" (so you can
  test the refusal path), and paraphrased duplicates.
- Include at least a few questions whose answer is **not** in the corpus — a good pipeline must
  refuse these, and you cannot measure refusal without them.
- Store as a tiny YAML/JSON: `{question, ground_truth_answer, ground_truth_chunk_ids}`.

```yaml
- question: "How many vacation days do new employees get?"
  ground_truth_answer: "15 days in the first year."
  ground_truth_chunk_ids: ["handbook#42"]
- question: "What is the company's policy on Mars colonization?"
  ground_truth_answer: null   # not in corpus — must refuse
  ground_truth_chunk_ids: []
```

## 2. The four RAGAS metrics

| Metric | Plain-English formula | What it catches |
|---|---|---|
| **faithfulness** | decompose the answer into atomic claims; fraction of claims supported by retrieved context. 1.0 = fully grounded | answer states things not in the sources |
| **answer relevancy** | how directly the answer addresses the question (low if padded/off-topic) | on-topic-but-evasive answers |
| **context precision** | are the relevant chunks ranked at the top of what was retrieved | relevant chunks exist but rank below junk |
| **context recall** | fraction of ground-truth chunks that actually got retrieved | the needed chunk never gets retrieved |

Faithfulness specifically decomposes the answer into atomic claims and checks each against the
retrieved context; a score of 1.0 means every claim is grounded.

## 3. Failure → metric → fix

| Symptom you observe | Metric that drops | Fix, in order |
|---|---|---|
| Confident statements absent from sources | faithfulness | tighten grounding prompt; enforce refusal clause |
| Answer rambles / dodges the question | answer relevancy | query rewriting; tighter prompt |
| Right chunk present but buried | context precision | add/strengthen reranker; tune RRF k |
| Right chunk never retrieved | context recall | fix chunking; add contextual retrieval; go hybrid |

Always read **context recall first** — if it is low, every downstream metric is capped, because
the model cannot ground an answer on a chunk it never saw.

## 4. Suggested thresholds

Start strict and relax only with evidence:

```text
faithfulness       >= 0.90   # near-zero tolerance for ungrounded claims
context recall     >= 0.85   # the right chunk must almost always be retrieved
context precision  >= 0.70
answer relevancy   >= 0.80
```

## 5. CI gate

Score the golden set on every change and fail the build below threshold so regressions cannot
ship silently.

```python
# eval_gate.py — run in CI; exit non-zero on regression.
import sys
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_precision, context_recall

THRESHOLDS = {"faithfulness": 0.90, "context_recall": 0.85,
              "context_precision": 0.70, "answer_relevancy": 0.80}

result = evaluate(dataset,                      # built from your golden set + pipeline outputs
                  metrics=[faithfulness, answer_relevancy,
                           context_precision, context_recall])
scores = result.to_pandas().mean(numeric_only=True).to_dict()

failed = {m: scores[m] for m, t in THRESHOLDS.items() if scores.get(m, 0) < t}
for m, t in THRESHOLDS.items():
    print(f"{m}: {scores.get(m, 0):.3f} (gate {t})")
if failed:
    print("FAIL:", failed); sys.exit(1)
print("RAG eval gate passed"); sys.exit(0)
```

```yaml
# .github/workflows/rag-eval.yml (excerpt)
- name: RAG eval gate
  run: python eval_gate.py
```

The general-purpose eval harness (arbitrary tasks, non-RAG agents) is the `agent-eval` skill;
these four metrics and this gate are the RAG-specific part that lives with `rag`.
