# Templates — investor update & one-pager

Fill-in templates with filled mini-examples, plus the vague-ask banlist. Keep the structure;
replace the bracketed content. Strip every bracket before shipping — `scripts/verify.sh` flags
leftover placeholders.

## Monthly investor update (6 sections, ~250 words)

```text
Subject: [Company] Investor Update — [Month Year]

Hi all,

HEADLINE
[One sentence: the month in a line — the single thing that mattered.]

HIGHLIGHTS
- [Win 1 — specific, with a number]
- [Win 2]
- [Win 3]
(3–5 bullets max)

METRICS
| Metric        | This month | Target | Last month |
| ------------- | ---------- | ------ | ---------- |
| [KPI 1]       | [actual]   | [tgt]  | [prior]    |
| [KPI 2]       | [actual]   | [tgt]  | [prior]    |
| [KPI 3]       | [actual]   | [tgt]  | [prior]    |
| Cash runway   | [N] mo     | —      | [N] mo     |

CHALLENGES
- [Challenge 1] — fix: [what you're doing about it]
- [Challenge 2] — learning: [what it taught you]
(each challenge PAIRED with a solution or learning — never naked)

ASKS
- [Named, specific: "intro to a [role] at [company type]" — not "let me know"]
- [Hiring/partnership ask if any]

CASH / RUNWAY
Cash: $[X]. Monthly burn: $[Y]. Runway: [N] months.

Thanks,
[Founder]
```

### Filled mini-example

```text
Subject: Tabl Investor Update — May 2026

Hi all,

HEADLINE
Crossed $42k MRR and signed our first two restaurant groups — both upsells from single-location pilots.

HIGHLIGHTS
- MRR $38k → $42k (+11%); two multi-location upgrades drove it.
- Shipped the payroll-export integration; cut customer onboarding from 9 days to 3.
- Hired our first AE, starting June.

METRICS
| Metric        | This month | Target | Last month |
| ------------- | ---------- | ------ | ---------- |
| MRR           | $42k       | $45k   | $38k       |
| New logos     | 7          | 8      | 5          |
| Net churn     | 1.2%       | <2%    | 1.8%       |
| Cash runway   | 14 mo      | —      | 15 mo      |

CHALLENGES
- Sales cycle stretched to 70 days — fix: added a security-review pack to the deck; two stalled deals re-accelerated.
- Support load spiked with the new integration — learning: shipped 6 help-center articles, ticket volume already down 30%.

ASKS
- Warm intro to a Head of RevOps at a 200+ seat Series-B SaaS — building our outbound playbook.
- Know a senior backend eng open to seed-stage? Hiring our second engineer in Q3.

CASH / RUNWAY
Cash: $580k. Monthly burn: $41k. Runway: 14 months.

Thanks,
Mara
```

## Investor one-pager (7 blocks)

```text
[COMPANY] — [one-line: what you do, for whom]

PROBLEM
[The pain, sized and concrete — who suffers it and how much it costs them.]

SOLUTION
[Your product in one or two lines — what it is and how it works.]

TRACTION
- [Metric 1 — MRR / ARR]
- [Metric 2 — growth %]
- [Metric 3 — logos / users / retention]

MARKET
TAM [$X] · SAM [$Y] · SOM [$Z you can realistically win]

TEAM
[Why THIS team wins THIS market — the unfair advantage, prior wins, domain depth.]

THE ASK
Raising [$amount] [round] — [use of funds + milestone it buys].
```

- **Pre-revenue:** move **TEAM** above **TRACTION** — lead with the strongest card.
- **Post-traction:** keep **TRACTION** near the top.
- **Teaser variant:** identical blocks, but NO confidential P&L, full cap table, or named customer financials — those live behind the data-room link.

### Filled mini-example

```text
TABL — Payroll & scheduling for multi-location restaurant groups

PROBLEM
Restaurant groups run payroll across 5–50 locations on spreadsheets and 3 disconnected tools;
weekly close takes a manager 6+ hours and errors trigger compliance penalties.

SOLUTION
Tabl unifies scheduling, time-tracking, and payroll into one system; weekly close drops to 20 minutes.

TRACTION
- $42k MRR, +11% MoM, $500k ARR run-rate
- 38 restaurant groups, 1.2% net monthly churn
- 3-day onboarding (down from 9)

MARKET
TAM $14B (US restaurant payroll) · SAM $3.1B (multi-location groups) · SOM $180M (target segments, 3yr)

TEAM
Founders ran payroll ops for a 120-location franchise; CTO built scheduling at [prior co], 2 prior exits between them.

THE ASK
Raising $1.5M seed — 18-month runway: 4 engineering hires, 2 GTM hires, to reach $1M ARR.
```

## Vague-ask banlist (Bad → Good)

Vague asks get ignored; named asks convert passive backers to active allies. Never ship the left column.

| Bad (vague) | Good (named, specific) |
| --- | --- |
| "Let me know if you can help with anything." | "Warm intro to a Head of RevOps at a 200+ seat Series-B SaaS." |
| "Any introductions appreciated." | "Intro to the VP Sales at Acme — we're a fit for their Q3 vendor review." |
| "We're hiring, spread the word." | "Hiring a senior backend eng (Go/Postgres) — who do you rate and would intro?" |
| "Feedback welcome." | "Would value 20 min on our pricing-tier change before we ship it June 15." |
| "Help us grow!" | "Two enterprise logos would unlock our Series A story — who do you know at [segment]?" |
