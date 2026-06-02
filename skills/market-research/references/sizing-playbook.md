# Sizing playbook — top-down, bottom-up, triangulation, and the memo template

Worked numbers for one example market so you can copy the *shape*, not the figures.
Replace every number with your own, sourced and dated.

## The example market

Hypothesis: *"Is there a venture-scale market for a B2B scheduling tool for dental
clinics in Spain?"* Assumed ACV (annual contract value): **€1,200/clinic/year**.

## Bottom-up (lead with this one)

Bottom-up = `ACV × number of ICP-fitting accounts`. It is grounded in your own
pricing and a reachable account count, so it survives scrutiny.

```text
ICP            independent dental clinics in Spain, 1–4 chairs, already digital-booking-curious
Account count  ~22,000 dental clinics in Spain (gov/industry registry)   [source + date]
                × 60% that fit the ICP (size + digital readiness)         = 13,200 accounts
ACV            €1,200/clinic/year                                          [your pricing]
Bottom-up TAM  13,200 × €1,200                                            = €15.8M
```

Note what each line needs: the **account count** needs a sourced, dated registry
figure; the **ICP filter %** needs a stated rationale; the **ACV** comes from
`../pricing/SKILL.md`. If any of the three is a vibe, the whole number is a vibe.

## Top-down (the cross-check)

Top-down = `published industry size × your segment share %`. Fast, but it inherits
the report's error and tempts you to hand-wave the share.

```text
Industry figure   Spain dental-practice-management software market ~€90M   [Statista/analyst, date]
Your segment      scheduling/booking module ≈ 18% of that spend            = €16.2M
Top-down TAM      €16.2M
```

## The triangulation gate

```text
Bottom-up   €15.8M
Top-down    €16.2M
Divergence  |16.2 − 15.8| / 15.8 = 2.5%   →  well within ~15–20%  →  CREDIBLE
Lead with   €15.8M (bottom-up), cross-checked by €16.2M (top-down).
```

Convergence reading:

| Divergence | Verdict | Action |
| --- | --- | --- |
| ≤ ~15–20% | Credible | Ship it; lead with bottom-up |
| ~20–100% | Shaky | Re-check the weakest input (usually the segment share % or the ICP filter) |
| 3–5× apart | Broken | Assumptions are wrong — do NOT pick the bigger; find which input lies |

The divergence is the *finding*. A clean convergence is your credibility; a 4× gap is
a bug report telling you which assumption to fix.

## SAM and SOM (derive, never assume 20%/10%)

TAM/SAM/SOM are nested. Derive each from a real constraint and state it:

```text
TAM   €15.8M    all Spanish dental clinics that could buy scheduling software
SAM   €9.5M     Castilian/Catalan-language product, mainland + islands, cloud-only
                = the slice your model + geography + language can actually serve (~60% of TAM)
SOM   €1.4M     3-year realistic capture: 2 incumbents hold most accounts, you have
                a 4-rep capacity → ~15% of SAM near-term
```

Write the *reason* beside each ratio. "SAM is 60% of TAM because the product ships in
Castilian/Catalan and excludes clinics on legacy on-prem suites" is defensible.
"SAM = 20% of TAM" with no reason is the anti-pattern.

## Market-memo template

The fixed artifact. Keep it Markdown so `scripts/verify.sh` can parse it.

```markdown
# Market memo — <market name>

## Hypothesis
<the one-line market question being tested>

## Sizing (TAM / SAM / SOM)
- TAM: €15.8M  — bottom-up: 13,200 ICP accounts × €1,200 ACV
- TAM (top-down cross-check): €16.2M — 18% of a €90M segment
- Convergence: 2.5% → credible. Lead with bottom-up €15.8M.
- SAM: €9.5M  — Castilian/Catalan, cloud-only, ~60% of TAM (reason stated)
- SOM: €1.4M  — ~15% of SAM, 3-yr, given 2 incumbents + 4-rep capacity
- Nesting check: SOM €1.4M ≤ SAM €9.5M ≤ TAM €15.8M ✓

## Segments
| Segment | Axis | The job they hire for | Reachable via | Beachhead? |
|---|---|---|---|---|
| Solo urban clinics | firmographic + JTBD | "fill last-minute cancellations" | dental-supplier channel | ★ beachhead |
| Small chains (2–4) | firmographic | "centralize multi-site booking" | direct sales | no (later) |

## Demand signals
- Google Trends "cita dentista online" rising (RELATIVE interest — not size)
- Keywords Everywhere: ~40K/mo absolute searches [source + date]
- Exploding Topics: flags "online dental booking" breakout [source + date]
- 5 clinic-owner interviews: 4 of 5 would pay at €1,200 [primary, date]

## Sources
| Figure | Source / URL | Date accessed |
|---|---|---|
| 22,000 clinics in Spain | <registry url> | 2026-06-02 |
| €90M PMS software market | <Statista url> | 2026-06-02 |
| 40K/mo search volume | <Keywords Everywhere> | 2026-06-02 |

## Hand-off
Sizing → pitch-deck; SOM → financial-model; beachhead → lead-gen;
incumbents → competitor-watch; ACV → pricing.
```

## The provenance rule

Every figure in the sizing and signals sections must appear as a row in the **Sources**
table with both a citation/URL **and** a date (access or publication). A number without
a sources-table row is undated and does not ship — that is the rule `verify.sh` enforces.
