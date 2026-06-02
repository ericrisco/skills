# Budget & justification

The budget is scored as part of implementation/feasibility. A reviewer who cannot map a euro to an activity cuts it. This file is the depth behind the SKILL.md "Budget & justification" section.

## Allowability — the four tests

Every cost charged to a federal award (and most public grants by analogy) must pass all four:

1. **Necessary** — needed to carry out the funded work; not nice-to-have.
2. **Reasonable** — a prudent person would pay this; defensible price.
3. **Allocable** — the award actually benefits from it, in proportion to what you charge.
4. **Consistently treated** — you don't charge a cost type as direct here and as indirect elsewhere.

**The consistency trap:** you cannot charge a cost **direct** if a *like* cost is recovered as **indirect**. If office supplies sit in your indirect pool, you can't also line-item office supplies as a direct cost on this award.

## Direct vs. indirect

- **Direct costs** are identifiable to the specific project: project staff salaries + fringe, project travel, equipment, materials, subcontracts, participant costs.
- **Indirect (F&A) costs** support operations broadly and can't be traced to one project: general admin, HR, facilities, accounting, utilities.

## The 15% de minimis (2 CFR 200.414)

Under the **Oct 2024 OMB Uniform Guidance** revision, an entity **without a negotiated indirect rate** may charge a **de minimis rate of up to 15% of modified total direct costs (MTDC)** — raised from the prior 10%. If you hold a negotiated rate, you use that and **declare it**; otherwise the de minimis is your ceiling.

**MTDC base** = total direct costs, **minus** these exclusions:
- Equipment and capital expenditures.
- The portion of **each subaward over $50,000** (you may apply indirect to the first $50k of each subaward only).
- Participant support costs, rent, scholarships/fellowships.

### Worked calculation

```text
Direct costs
  Personnel (salary + fringe)        180,000
  Travel                               12,000
  Materials & supplies                 18,000
  Equipment (EXCLUDED from MTDC)       40,000
  Subaward A (first $50k counts)       80,000   -> 50,000 in base, 30,000 out
  Participant support (EXCLUDED)       25,000
  -----------------------------------------------
  Total direct costs                  355,000

MTDC base = 180,000 + 12,000 + 18,000 + 50,000              = 260,000
            (equipment 40k, subaward overage 30k, participant 25k all excluded)

Indirect @ 15% de minimis = 0.15 × 260,000                  = 39,000
Total budget = 355,000 + 39,000                             = 394,000
```

Compute indirect on the **MTDC base, never on total direct costs**. Charging 15% of the full $355k (= $53,250) overstates indirect by $14,250 and is a common rejection cause.

## Matching / co-funding

If the call requires a match (cost-share), show:
- The **source** (named, committed — not "to be confirmed").
- Whether it is **cash or in-kind**, and that the in-kind valuation is documented (e.g. donated staff time at a defensible rate).
- That the matched cost is **itself allowable** — you can't match with an unallowable cost.

## Line-item → justification mapping

Every line gets one sentence tying it to a workplan activity. The justification, not the number, is what survives review.

| Line item | Amount | Justification (ties to activity) |
|---|---|---|
| Project Lead 0.5 FTE | 45,000 | Runs WP1–WP3; 50% allocation matches 50% of effort on this award |
| Trainer 1.0 FTE | 55,000 | Delivers the 10 cohorts in Activity 2; sole training resource |
| Travel | 12,000 | 3 SME pilot sites × 4 visits (Activity 3) at documented per-diem |
| Materials | 18,000 | Curriculum print + LMS licences for 200 trainees (Activity 2) |
| Indirect @ 15% MTDC | 39,000 | De minimis; no negotiated rate; computed on MTDC base above |

If a line has no activity to point at, it is padding — cut it before a reviewer does.
