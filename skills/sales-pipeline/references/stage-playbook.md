# Stage playbook — the six gated stages in full

The default model is six stages. Five stages with clear exit criteria beat nine
stages with none. A deal advances **only** when the exit criterion (a verifiable
buyer action) is met **and** a next step is on the calendar. The stage carries
the win-probability; the rep never hand-sets it. *(Cirrus Insight / Prospeo,
accessed 2026-06-02.)*

## The stages

### 1 — Prospecting · default win_prob 0.05
- **Exit criterion:** the buyer has agreed to a first real conversation — a
  meeting is on the calendar (not "they opened my email").
- **Required fields:** `id`, `company`, `owner`, `next_step` (the meeting),
  `last_touch`.
- A deal here is barely a deal; do not let Prospecting volume flatter coverage.

### 2 — Qualification · default win_prob 0.10
- **Exit criterion:** BANT (or MEDDIC above ~$25K ACV) documented as a "yes" —
  budget exists, you are talking to or have a path to authority, there is a real
  need, and there is a timeline.
- **Required fields:** add `value` (first real estimate), `close_date` (first
  estimate), the qualification notes.

### 3 — Discovery · default win_prob 0.30
- **Exit criterion:** the buyer has confirmed the problem and their success
  criteria, and you know the **buying process** — review layers, legal steps,
  procurement. "If you don't know the criteria, timeline, review layers and
  legal steps, the close date is a guess." *(Routine / weflow / HubSpot.)*
- **Required fields:** firmed `value`, firmed `close_date`, the buying-process
  notes, `next_step`.

### 4 — Proposal/Demo · default win_prob 0.40
- **Exit criterion:** the proposal or demo has been delivered **and
  acknowledged**, and the buyer is engaging on it (questions, redlines, internal
  circulation) — not just "sent and silent."
- The proposal document itself is written by `proposals`, not here.

### 5 — Negotiation · default win_prob 0.65 (band 0.50–0.80)
- **Exit criterion:** terms and price are under active discussion, there is
  verbal intent, and you have a **mutual close plan** with dates.
- Pick within the 0.50–0.80 band on real signal (legal in motion, MSA in
  redline → higher end). Never reflexively set 0.80.

### 6 — Closed · win_prob 1.0 (Won) / 0.0 (Lost)
- **Won:** signed. The deal leaves this skill — handoff/kickoff is
  `client-onboarding`.
- **Lost:** formally lost, with a reason. Losing cleanly keeps the win-rate
  honest; do not let dead deals linger as "open."

## Qualification: BANT vs MEDDIC — pick by deal size

Run **BANT as a ~60-second screen** on every deal; switch to **MEDDIC/SPICED
above ~$25K ACV** where the buying process is complex enough to need it.
*(Routine / weflow / HubSpot, accessed 2026-06-02.)*

| | BANT (fast screen, < $25K) | MEDDIC (complex, $25K+ ACV) |
|---|---|---|
| B / M | **B**udget | **M**etrics — the quantified business outcome |
| A / E | **A**uthority | **E**conomic buyer — who signs |
| N / D | **N**eed | **D**ecision criteria + **D**ecision process |
| T / I | **T**imeline | **I**dentify pain + **C**hampion |

The exit criterion for Qualification is a documented "yes" across the relevant
framework **plus** a calendared next step. A "yes" with no next step is not a
pass.

## Forecast categories — map separately from stages

Categories are a judgement of *confidence to land this period*; stages are
*where the deal is in the process*. They are not the same axis. *(Gary Smith
Partnership / Salesforce default categories, accessed 2026-06-02.)*

| category | meaning | rough in-quarter landing |
|---|---|---|
| Pipeline | open, qualified, not yet committed | ~25% lands this quarter |
| Best Case | upside if things go well | ~1/3 to 1/2 lands |
| Commit | you are willing to put your name on it | near-all lands |
| Closed | signed (Won) or lost | done |
| Omitted | excluded from the forecast (e.g. stale 30d+) | not counted |

Rule: a deal's category must match documented evidence. A Discovery-stage deal
in "Commit" is a defect — demote it. Stale deals (30+ days no touch) move to
Omitted so they stop flattering the commit number.
