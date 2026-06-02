# Forecasting math — worked examples and the column contract

This is the simple stage-weighted roll-up that falls out of a clean pipeline.
It is **not** statistical forecasting — no scenarios, no time-series, no cohort
projection. If the ask needs those, route to `forecasting`.

All figures use the load-bearing benchmarks: stage probabilities from the stage
model, the current **~18% B2B win rate** (down from ~21%, with cycles ~12%
longer YoY — *Ebsta/Pavilion 2025 B2B Sales Benchmark*), and the segment
coverage benchmarks below. *(Drivetrain / Coefficient / forecastio.ai; ORM Tech;
First Page Sage — all accessed 2026-06-02.)*

## 1 — Weighted forecast on a 5-deal list

`weighted_value = value × stage win_prob`, then apply stale decay (no touch
14+ days → halve; 30+ days → drop from the roll-up).

| id | value | stage | win_prob | last_touch age | adjustment | weighted |
|---|---|---|---|---|---|---|
| D-1 | 40,000 | Discovery | 0.30 | 3 d | none | 12,000 |
| D-2 | 25,000 | Negotiation | 0.65 | 6 d | none | 16,250 |
| D-3 | 60,000 | Proposal | 0.40 | 18 d | halve (14d+) | 12,000 |
| D-4 | 30,000 | Qualification | 0.10 | 40 d | **drop** (30d+) | 0 |
| D-5 | 50,000 | Negotiation | 0.65 | 2 d | none | 32,500 |

- Raw weighted (no decay): 12,000 + 16,250 + 24,000 + 3,000 + 32,500 = **87,750**.
- Decayed weighted forecast: 12,000 + 16,250 + 12,000 + 0 + 32,500 = **72,750**.

The 15,000 gap is exactly the cost of stale deals — which is why you decay
before you report, never after.

## 2 — Pipeline coverage by segment

`coverage = Total Qualified Pipeline Value ÷ Revenue Target`. "Qualified"
excludes stale (30d+) deals.

| segment | win rate | min | target |
|---|---|---|---|
| Enterprise ($100K+ ACV) | 15–20% | 5× | 6–7× |
| Commercial ($25–100K) | 20–30% | 3.5× | 4–5× |
| SMB (<$25K) | 30–40% | 2.5× | 3–4× |

*(ORM Tech, accessed 2026-06-02.)*

**Worked:** a Commercial team with a $250K quarterly target and $900K of
qualified (non-stale) pipeline has coverage = 900 / 250 = **3.6×**. That clears
the 3.5× minimum but sits below the 4–5× target — adequate, not comfortable.
If coverage drops two weeks running with no closes, escalate; that is the red
flag, not a single low snapshot.

## 3 — Pipeline velocity

`velocity = (Open opps × Avg deal size × Win rate) ÷ Sales-cycle length (days)`
→ dollars/day. *(Salesmotion / ORM Tech.)*

**Worked:** 40 open opps × $30,000 avg × 0.18 win ÷ 90-day cycle =
216,000 / 90 = **$2,400/day**.

Cycle length is the highest-leverage term: cut the 90-day cycle ~20% to 72 days
and velocity rises to 216,000 / 72 = **$3,000/day** — a ~25% lift from one
lever. Use your **real, current** cycle length; a shorter historical cycle
flatters the number the same way an old win rate does.

## 4 — The column contract `verify.sh` enforces

The pipeline artifact (CSV or markdown table) must have a header containing at
least these columns; `verify.sh` is a structural + arithmetic lint over them,
not a judgement of deal quality.

| column | check |
|---|---|
| `stage` | present in header; each value in the allowed set: Prospecting, Qualification, Discovery, Proposal/Demo (or Proposal / Demo), Negotiation, Closed (Won/Lost) |
| `value` | present; numeric |
| `win_prob` | present; `0 ≤ win_prob ≤ 1` |
| `weighted_value` | present; equals `round(value × win_prob)` within tolerance |
| `close_date` | present and non-empty on every **open** deal |
| `next_step` | present and non-empty on every **open** deal |
| `last_touch` | present and non-empty on every **open** deal |

Plus: at least one **coverage** summary line/row must be present somewhere in
the file (a line matching `coverage`). An empty or missing-content file is a
clean pass — the lint never false-fails on nothing.
