# Demand signals — source catalog and grading rubric

How to tell a real demand signal from vanity interest, and how to grade the sources
you cite. Secondary forms the hypothesis; primary decides the call.

## Signal-source catalog

| Source | What it gives | Watch out for |
| --- | --- | --- |
| **Google Trends** | RELATIVE search interest (0–100, normalized) over time + by region | Never absolute volume; never convert a curve into a market size; small terms are noisy |
| **Keywords Everywhere** | Absolute monthly search volume + CPC per keyword | Paid; volumes are estimates — use for order-of-magnitude, not precision |
| **Exploding Topics** | Breakout niches; flags topics growing >5,000% | Early signal, small base — a breakout topic is a hypothesis, not a proven market |
| **Statista / analyst reports** | Published market sizes, growth rates, segment splits | Check publication date and methodology; fast sectors go stale in months |
| **Government / industry registries** | Account counts, establishment counts, official statistics | Authoritative but lagging; definitions may not match your ICP |
| **Company filings (10-K, annual reports)** | Real revenue, segment disclosures from public players | Public-co skew; not the whole market |
| **Primary surveys** | Current, quantifiable intent from your target buyers | Slow; sampling bias; leading questions ruin it |
| **Primary interviews / focus groups** | The *why* behind the buy, paying-intent, objections | Tiny n; great for hypotheses, weak for sizing |

## Secondary first, primary to decide

- **Secondary** (reports, gov stats, filings, analyst data) is cheap, fast, and right
  for the **first pass** — but vet recency and credibility in fast-moving sectors.
  Use it to form the hypothesis and to size top-down.
- **Primary** (surveys, interviews) is current, specific, and controllable but slow and
  small-sample. Spend it on **the one question that decides yes/no** — usually
  "will the ICP actually pay the ACV?" — not on facts a report already answers.

## Real signal vs vanity interest

A signal is **real** when independent indicators stack:

```text
Real    rising Google Trends curve
        + absolute volume confirms a meaningful base (Keywords Everywhere)
        + Exploding Topics flags it breakout
        + a primary interview shows paying intent at your price
        → triangulated demand

Vanity  one viral spike on a single Trends curve
        a report with no date
        "everyone needs this" with no search or interview evidence
        → discard or downgrade
```

The same discipline as sizing: one indicator is a guess, stacked independent indicators
are a finding.

## Source-grading rubric

Grade every secondary source before you cite it. A figure from a low-grade source needs
a primary cross-check before it becomes load-bearing.

| Dimension | High grade | Low grade (cross-check before relying) |
| --- | --- | --- |
| **Recency** | Published/updated within the sector's half-life (months for fast tech) | Older than the last major market shift |
| **Methodology** | States how the number was derived (sample, model, definitions) | Black-box "industry estimates" with no method |
| **Sample / coverage** | Large, representative, matches your geography + ICP | Tiny, skewed, or a different market than yours |
| **Credibility** | Named analyst/gov/registry with a track record | Vendor marketing page sizing its own category |
| **Independence** | Not selling the thing being sized | The report's author profits from a big number |

Record the grade implicitly by what you do: a high-grade source can stand alone in the
sources table; a low-grade one must be paired with a second source or a primary check,
and both rows carry their dates.
