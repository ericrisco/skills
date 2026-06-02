# Pitfalls — why "inconclusive" tests usually mean a broken design

This is the diagnosis layer. When a test "won't go significant" or "flip-flops," it is almost always one
of the failure modes below, not bad luck.

## Peeking and optional stopping

A fixed-horizon test is designed so that, under the null, you cross p < 0.05 about 5% of the time **when
you look exactly once, at the planned n**. If you look every day and stop the first time you see p < 0.05,
you take many independent-ish shots at that 5% door. With enough looks the cumulative chance of crossing
0.05 under a true null climbs well past 5% — a pure-noise test can be "significant" the majority of the
time if you peek long enough. The reported p-value is then a lie about a single planned look.

Fixes, in order of preference:

1. **Fixed horizon.** Commit to n/date; read once. Tightest read for declaring a winner.
2. **Sequential / always-valid inference.** Confidence sequences and anytime-valid CIs (e.g. Netflix's
   anytime-valid approach) stay valid under continuous monitoring — you may look every day and the
   guarantee holds. Trade-off: wider intervals, so they are excellent for **stopping a clear loser early**
   and comparatively weak for **declaring a winner early**. Use them when early stopping has real value,
   not as a license to peek on a fixed-horizon design.

Never: a fixed-horizon design read repeatedly and stopped at first significance.

## Multiple comparisons

Every metric, every variant, every segment is another hypothesis test. Test 20 independent nulls at
α = 0.05 and you expect ~1 false positive by chance alone. Two corrections:

- **Bonferroni** — divide α by the number of tests. Controls the chance of *any* false positive
  (family-wise error). Simple and conservative; right for a small, pre-declared set of decision metrics.
- **Benjamini-Hochberg (FDR)** — controls the *expected fraction* of false positives among the discoveries.
  Far more powerful on large exploratory scans. Illustrative example: scanning 20 metrics with true
  effects, an FDR procedure recovered ~17 while Bonferroni's stricter threshold recovered only ~12.

Rule: Bonferroni for the handful of metrics a decision rests on; Benjamini-Hochberg for the big
exploratory sweep where you can tolerate a known false-discovery rate.

## Sample ratio mismatch (SRM)

The observed split materially diverges from the intended ratio (chi-square p < 0.001). This is not a
statistical nuance — it is a signal the experiment is mechanically broken: a bot filter dropping one arm,
a redirect, differential caching, a bucketing-hash bug, or logging that fires on one variant only.
Consequence: the arms are no longer comparable, so the treatment effect is confounded. Do not adjust,
reweight, or "note it as a caveat." Find the cause, fix instrumentation, and rerun. The SRM chi-square
snippet is in `sample-size-and-cuped.md`.

## Underpowered ≠ "no effect"

A non-significant result with a small sample means you could not have detected even a meaningful effect —
absence of evidence, not evidence of absence. Before concluding "no difference," check whether the test
reached its planned n and report the CI: "the effect is somewhere in [−0.8pp, +1.2pp]" is honest;
"no effect" is not.

## Novelty and primacy effects

A shiny new variant can spike because regulars click it out of curiosity (novelty) — or dip because they
are disoriented by a changed UI (primacy). Both fade. If the effect is concentrated in the first days and
decays, you are measuring reaction-to-change, not the steady-state effect. Run long enough for the curve
to flatten, and inspect new-user vs returning-user segments separately.

## Simpson's paradox across segments

An aggregate lift can reverse inside every segment (or vice versa) when segment mix differs between arms —
often itself a symptom of SRM or a non-random assignment. If the overall result and the per-segment
results disagree in direction, distrust the aggregate and find what is unbalanced between the arms before
believing either number.

## HARKing — hypothesizing after results are known

Slicing the data until something is significant, then writing the hypothesis to match, is a fishing
expedition wearing a lab coat. Any "finding" discovered this way must be treated as a hypothesis for a
*fresh* experiment, never as a confirmed result. Pre-register the hypothesis and primary metric before
launch so the analysis you run is the analysis you committed to.
