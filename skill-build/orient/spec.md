# Design — `orient`: always-on guidance (la brújula)

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation plan
**Author:** Eric Risco

## Problem

The rsc harness already does most of what a non-programmer needs to build their own
workspace by talking: a plain-language CLI (`npx rsc`), a repo detector, an always-on
installer (`suggest`), a front-door profiler (`init`), and a self-improving wiki
(`harness`). What it does **not** do systematically is **keep the human oriented at
every step**.

Today, guidance happens in patches — `suggest` proposes an install, `init` profiles
once — but there is no coherent, always-present "compass" voice. Skills can end a turn
"en seco" (dead-end), leaving a non-technical user unsure what they just did, why, where
they are in the project, or what to do next.

The goal is not to fix a specific gap. The goal is to make the harness **always orient
the user** — to turn a tool that executes and falls silent into a mentor that walks
alongside.

## What "orienting" means (validated with the user)

All four pillars, on every interaction, in one coherent voice, calibrated to the user's
level:

1. **Always propose the next step** — never end in seco. After any action: "this is
   done → the logical next thing is X or Y, which one?" The user is never left without
   knowing what to do.
2. **Teach the why** — not just what, but why, so the user gains technical judgement over
   time, scaled to their level.
3. **Situate on the map** — always remind the user where they are: what is built, what is
   missing, what phase they are in. A "where am I?" compass.
4. **Ask before deciding** — at any fork, ask orienting questions instead of deciding
   alone, so the user feels in control and understands each decision.

## Approach (chosen: A + C)

Two complementary mechanisms, plus enforcement:

- **A — a dedicated always-on `orient` skill** owns the protocol and the voice (single
  source of truth, installable, configurable, versionable).
- **C — a lightweight footer contract** that high-traffic skills reference, so the
  behavior is anchored in the skills users hit most — **without editing ~90 files**.
- **Enforcement** — a new rubric dimension so "always orient" is measured, not promised.

Rejected:
- **B (bake into `harness`)** — `harness` is heavy and not always loaded, so "always"
  breaks.
- **Pure C (footer in every SKILL.md)** — 100-file churn that desyncs.

## Components

### 1. The `orient` skill (the brújula)

- **Location:** `skills/orient/SKILL.md` (+ `references/orientation-contract.md`,
  `evals/cases.yaml`, `evals/README.md`).
- **Profiles:** `[minimal, core, full]` — part of the floor, loaded every session like
  `suggest`.
- **Tags:** include `meta`, `always-on`.
- **Type:** flexible (adapts tone), not rigid.
- **Role split (explicit, to avoid overlap with `suggest`):**
  - `suggest` → "you're missing a skill, install it?" (equips the session)
  - `orient` → "you are here, you did this, for this reason, next is X — which?" (guides
    the human)
- **Reads:** `02-DOCS/wiki/harness/user-profile.md` for `technical_level` +
  `accompaniment_level`, and calibrates how much it explains.
- **Writes:** updates `accompaniment_level` in the profile when the user asks for
  more/less explanation (see §5).
- **Core rule:** *no skill ends a turn in seco.* Every turn closes with a brújula block.

### 2. The brújula block (what the user sees)

Every turn closes with a coherent block mapping to the four pillars:

```
📍 Dónde estás — project phase/state (the map)
✅ Qué acabas de hacer — one line, in the user's language
🧭 Por qué — the technical why, calibrated to the dial (1 line at L0, more at L2+)
➡️ Siguiente — 1-3 concrete options, ending in a question. Never in seco.
```

Calibration by dial:
- **L0 (cavernícola):** only `✅` + `➡️`, one option, a yes/no question. Minimal jargon.
- **L1 (breve):** the four lines, one line of why.
- **L2+ (mentor):** the four lines with real why and genuine forks.

The block is a **format guide, not a rigid template** — `orient` adapts wording to the
moment; the four intents are what must always be present at the level's depth.

### 3. The footer contract (C) without 100-file churn

- The **format and the rule** ("no skill ends in seco") live **once** in
  `skills/orient/SKILL.md` and `skills/orient/references/orientation-contract.md`.
- A **2-line footer that references the contract** (not copies it) is injected **now**
  into the high-traffic floor/SDD skills only:
  `init`, `harness`, `suggest`, `clarify`, `specify`, `tasks`, `implement`, `verify`,
  `ship`.
- The footer is added to the **`author-skill` template** so every *future* skill is born
  with it.
- The remaining ~90 skills **inherit the behavior via the always-on `orient` skill** — no
  edits needed.

### 4. Enforcement in the behavioral eval

- Add an **"Orientation" signal** to `scripts/skill-behavior-rubric.md`: did the turn
  situate the user (map), teach the why at the right level, and propose a next step ending
  in a question?
- It participates in the /10 the same way the existing quality axes do (via
  `scripts/lib/behavior-score.js`), so a skill that leaves the user lost **does not pass
  the gate**.
- The blind, independent grader stays as-is (treatment vs. baseline, X/Y slotting).

### 5. Spoken dial configuration

- `orient` recognizes "explícame más / menos / no me expliques tanto / enséñame" and
  adjusts `accompaniment_level` in `02-DOCS/wiki/harness/user-profile.md`, confirming the
  change in one line. Orientation adapts from that point on.

## Out of scope (YAGNI)

- No rewrite of the ~90 catalog skills.
- No new CLI UI/commands in `npx rsc`.
- No changes to `recommend.js` / ranking.
- Net change: 1 new skill + ~9 referenced footers + author-skill template + 1 rubric
  signal.

## Affected files (anticipated)

- **New:** `skills/orient/SKILL.md`, `skills/orient/references/orientation-contract.md`,
  `skills/orient/evals/cases.yaml`, `skills/orient/evals/README.md`.
- **Edited (footer ref):** `skills/{init,harness,suggest,clarify,specify,tasks,implement,verify,ship}/SKILL.md`.
- **Edited (template):** `skills/author-skill/SKILL.md` (or its template/reference).
- **Edited (enforcement):** `scripts/skill-behavior-rubric.md`, possibly
  `scripts/lib/behavior-score.js`.
- **Regenerated:** `manifest.json` via `scripts/build-manifest.js`.

## Success criteria

1. `orient` is in the `minimal` profile and loads every session.
2. A turn run under any floor/SDD skill ends with a brújula block calibrated to the dial,
   never in seco.
3. Saying "explícame menos" persists a lower `accompaniment_level` and visibly reduces the
   why depth on the next turn.
4. `orient` passes both eval gates (`absolute_score ≥ 8.5`, `lift ≥ +1.0`), and the new
   Orientation signal is scored across the touched skills.
5. The role split with `suggest` is clean — no duplicated "install?" prompts.

## Open questions for the plan

- Exact placement of the Orientation signal in the score formula (new axis vs.
  `must_include`-style coverage item) — decide in the plan so the /10 stays auditable.
- Whether the footer reference should also carry a 1-line inline fallback for when
  `orient` is not loaded (e.g. someone installs a single skill without the floor).
