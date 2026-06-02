# `orient` — Always-On Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an always-on `orient` skill (the brújula) that keeps the user guided on every turn, anchor it in high-traffic skills via a referenced footer, and enforce it in the behavioral eval.

**Architecture:** A new floor skill `skills/orient/` owns the orientation protocol and voice (single source of truth) and is loaded every session like `suggest`. A 2-line footer that *references* the contract is added to 9 high-traffic floor/SDD skills and to the `author-skill` guidance, so the behavior is anchored without editing the ~90 remaining skills (they inherit it via the always-on skill). Enforcement is added to `skill-behavior-rubric.md` and baked as `must_include` items in `orient`'s capability scenarios — reusing the existing grader, no scoring-formula change.

**Tech Stack:** Markdown SKILL.md + YAML evals; Node build (`scripts/build-manifest.js`); `scripts/eval-lint.sh`; `node --test`. Spec: [skill-build/orient/spec.md](spec.md).

---

## File Structure

- **New** `skills/orient/SKILL.md` — the brújula skill (protocol + voice + dial calibration).
- **New** `skills/orient/references/orientation-contract.md` — the format + "no seco" rule, referenced by footers.
- **New** `skills/orient/evals/cases.yaml` — triggers + capability scenarios with orientation `must_include`.
- **New** `skills/orient/evals/README.md` — human summary of the eval intent.
- **Modify** `skills/{init,harness,suggest,clarify,specify,tasks,implement,verify,ship}/SKILL.md` — append the referenced footer.
- **Modify** `skills/author-skill/SKILL.md` — require the footer in new skills.
- **Modify** `scripts/skill-behavior-rubric.md` — document the Orientation expectation.
- **Regenerate** `manifest.json` via `npm run manifest`.

Convention note: this repo's plans/specs live under `skill-build/<skill>/`, not `docs/` (which is gitignored).

---

## Task 1: Scaffold the `orient` skill body

**Files:**
- Create: `skills/orient/SKILL.md`

- [ ] **Step 1: Create `skills/orient/SKILL.md` with this exact content**

```markdown
---
name: orient
description: "Always-on. The brújula: after every action keep the human oriented — situate them on the project map, say what just happened, teach the why at their level, and propose the next step as a question. NEVER end a turn in seco (dead-end). Reads technical_level + accompaniment_level from 02-DOCS/wiki/harness/user-profile.md and calibrates how much it explains; rewrites the dial when the user asks for more/less ('explícame más', 'explícame menos', 'no me expliques tanto', 'enséñame'). Complements suggest (which installs missing skills) — orient guides the person, not the toolbox. Fires on every turn that finishes an action, reaches a decision fork, or leaves the user unsure what to do next."
tags: [orient, guide, compass, dial, meta, always-on]
recommends: []
profiles: [minimal, core, full]
origin: risco
---

# orient — the brújula that never leaves the user lost

You are always loaded. Your one job: **after anything happens, keep the human oriented.** A tool executes and falls silent; a mentor walks alongside. You make the harness a mentor.

`suggest` keeps the *session* equipped ("you're missing a skill, install it?"). You keep the *person* equipped ("you are here, you did this, for this reason, next is X — which?"). Never duplicate `suggest`'s install prompt; that is its job.

## The one rule

**No turn ends in seco.** Every turn that finishes an action, reaches a fork, or could leave the user unsure closes with the brújula block, calibrated to the dial.

## The brújula block

Close the turn with these four intents (the wording adapts; the intents are fixed):

```
📍 Dónde estás — the project phase/state (the map)
✅ Qué acabas de hacer — one line, in the user's language
🧭 Por qué — the technical why, scaled to the dial
➡️ Siguiente — 1-3 concrete options, ending in a question. Never in seco.
```

## Calibrate to the dial

Read `02-DOCS/wiki/harness/user-profile.md` for `technical_level` and `accompaniment_level` before you write the block.

| Level | How the block behaves |
|-------|-----------------------|
| L0 — cavernícola | Only `✅` + `➡️`. One next option, a yes/no question. Zero jargon. |
| L1 — breve | The four lines; `🧭` is one line of why. |
| L2+ — mentor | The four lines with a real why and genuine forks to choose between. |

If the profile is missing, assume **L0** (non-technical-first) and offer to set the dial.

## Spoken dial config

When the user says "explícame más / menos", "no me expliques tanto", or "enséñame", update `accompaniment_level` in `02-DOCS/wiki/harness/user-profile.md`, confirm the change in one line, and apply the new depth from this turn on.

## Rules

- Adapt tone to the dial — you are a **flexible** skill, not a rigid template.
- One brújula block per turn, at the end. Do not interrupt mid-work to orient.
- Ask before deciding at any real fork; do not decide alone when the user can choose.
- Never invent project state — situate the user from what is actually built (read the Knowledge map / repo if unsure).
- Defer the "install a missing skill?" prompt to `suggest`.
```

- [ ] **Step 2: Validate the frontmatter**

Run: `npm run validate`
Expected: `frontmatter OK` (no errors; `orient` parses with valid name/description/tags/profiles).

- [ ] **Step 3: Commit**

```bash
git add skills/orient/SKILL.md
git commit -m "Add orient skill — always-on brújula (protocol + voice)"
```

---

## Task 2: Write the orientation contract reference

**Files:**
- Create: `skills/orient/references/orientation-contract.md`

- [ ] **Step 1: Create `skills/orient/references/orientation-contract.md` with this exact content**

```markdown
# Orientation contract

The single definition of how the harness keeps the user oriented. The `orient` skill owns
it; other skills reference this file in a short footer instead of copying it.

## The rule

**No turn ends in seco (dead-end).** Every turn that finishes an action, reaches a fork, or
could leave the user unsure closes with the brújula block.

## The brújula block

```
📍 Dónde estás — project phase/state (the map)
✅ Qué acabas de hacer — one line, in the user's language
🧭 Por qué — the technical why, scaled to the dial
➡️ Siguiente — 1-3 concrete options, ending in a question. Never in seco.
```

## Calibration (the dial)

Read `02-DOCS/wiki/harness/user-profile.md`:

- **L0 — cavernícola:** only `✅` + `➡️`, one option, yes/no question, zero jargon.
- **L1 — breve:** the four lines; one line of why.
- **L2+ — mentor:** the four lines with a real why and genuine forks.

Missing profile → assume L0 and offer to set the dial.

## Division of labor

- `orient` guides the **person** (this contract).
- `suggest` equips the **session** ("install the missing skill?"). Defer install prompts to it.
```

- [ ] **Step 2: Commit**

```bash
git add skills/orient/references/orientation-contract.md
git commit -m "Add orientation contract reference"
```

---

## Task 3: Write the `orient` evals

**Files:**
- Create: `skills/orient/evals/cases.yaml`
- Create: `skills/orient/evals/README.md`

Minimums enforced by `scripts/eval-lint.sh`: ≥5 `should_trigger`, ≥4 `should_not_trigger`, ≥1 `capability`.

- [ ] **Step 1: Create `skills/orient/evals/cases.yaml` with this exact content**

```yaml
skill: orient

# The always-on brújula. It fires at the END of a turn to keep the user oriented:
# map + what happened + why (scaled to the dial) + a next step phrased as a question.
# It defers "install a missing skill?" to suggest and does not interrupt mid-work.

should_trigger:
  - prompt: "Ya está instalado el postgresdb. ¿Y ahora qué?"
    why: "An action just finished and the user is explicitly unsure what to do next — orient must situate them and propose the next step."

  - prompt: "Vale, hemos creado la landing. ¿Qué hago con esto?"
    why: "A step finished and the user asks for direction — orient closes with the map + next options as a question."

  - prompt: "No sé por dónde seguir con mi proyecto."
    why: "The user is lost — the core trigger: situate on the map and propose 1-3 next steps."

  - prompt: "Explícame menos, que me agobio con tanto detalle."
    why: "A spoken dial request — orient lowers accompaniment_level, confirms it, and applies the new depth."

  - prompt: "¿En qué punto del proyecto vamos?"
    why: "A 'where am I?' question — orient renders the map (what's built, what's missing, what phase)."

  - prompt: "Acabo de terminar el spec. Listo."
    why: "A turn ends after finishing work — orient must not end in seco; it proposes the next phase as a question."

should_not_trigger:
  - prompt: "Renombra esta variable a `userCount`."
    route_to: "none"
    why: "A trivial mechanical edit mid-flow — orient does not interrupt with a full brújula block over a one-line change."

  - prompt: "Necesito una base de datos para guardar pedidos."
    route_to: "suggest"
    why: "This is an install gap — suggest owns it. orient must not duplicate the 'install it?' prompt."

  - prompt: "Optimiza esta query de Postgres que va lenta."
    route_to: "postgresdb"
    why: "A concrete task owned by another skill; orient adds the closing block but does not drive the work."

  - prompt: "Arregla el test que falla."
    route_to: "debug"
    why: "Root-cause work owned by debug; orient does not take over the task itself."

capability:
  - scenario: "The user just ran `npx rsc add postgresdb` and says 'ya está, ¿y ahora qué?'. The profile shows technical_level L0. Show how orient closes the turn."
    must_include:
      - "Situates the user on the map ('📍 dónde estás' / what is built vs missing)"
      - "States what just happened in one plain-language line ('✅ instalaste la base de datos')"
      - "Proposes a concrete next step ending in a question, never leaving the turn in seco"
      - "At L0, keeps it to ✅ + ➡️ with a single yes/no option and zero jargon"
      - "Does NOT re-prompt to install a skill (defers that to suggest)"

  - scenario: "Mid-project, the user says 'explícame menos'. The profile shows accompaniment_level L2. Show how orient responds."
    must_include:
      - "Updates accompaniment_level in 02-DOCS/wiki/harness/user-profile.md to a lower level"
      - "Confirms the change in one line"
      - "Re-renders guidance at the reduced depth from this turn on"
      - "Still closes with a next-step question (no seco)"
```

- [ ] **Step 2: Create `skills/orient/evals/README.md` with this exact content**

```markdown
# Evals — orient

The always-on brújula. These cases check that it keeps the user oriented at the end of a
turn (map + what happened + why-at-level + next step as a question) and that it defers
install prompts to `suggest` and never interrupts trivial mid-flow edits.

| Prompt | Expected |
|---|---|
| "ya está instalado, ¿y ahora qué?" | situate + next step as a question |
| "no sé por dónde seguir" | render the map + 1-3 next options |
| "explícame menos" | lower the dial, confirm, apply reduced depth |
| "renombra esta variable" | no full brújula block (trivial mid-flow) |
| "necesito una base de datos" | defer to `suggest` (no duplicate install prompt) |

A pass = orient closes the turn without leaving the user in seco, scales the why to the
dial, and never duplicates `suggest`'s install prompt.
```

- [ ] **Step 3: Run the eval linter**

Run: `bash scripts/eval-lint.sh`
Expected: passes for `orient` (≥5 triggers, ≥4 non-triggers, ≥1 capability) with no errors.

- [ ] **Step 4: Commit**

```bash
git add skills/orient/evals/cases.yaml skills/orient/evals/README.md
git commit -m "Add orient evals (triggers + capability with orientation must_include)"
```

---

## Task 4: Regenerate the manifest with `orient` in the floor

**Files:**
- Modify: `manifest.json` (generated)

- [ ] **Step 1: Rebuild the manifest**

Run: `npm run manifest`
Expected: writes `manifest.json`; `skills` count increases by 1.

- [ ] **Step 2: Verify `orient` landed in the minimal floor**

Run: `node -e "const m=require('./manifest.json'); const o=m.skills.find(s=>s.id==='orient'); console.log(JSON.stringify(o))"`
Expected: prints the `orient` entry with `\"profiles\":[\"minimal\",\"core\",\"full\"]` and `always-on` in `tags`.

- [ ] **Step 3: Commit**

```bash
git add manifest.json
git commit -m "Regenerate manifest with orient in the floor"
```

---

## Task 5: Anchor the footer in 9 high-traffic skills

The footer **references** the contract — it does not copy it. This is the C half of A+C.

**Files (append the footer at the end of each):**
- Modify: `skills/init/SKILL.md`
- Modify: `skills/harness/SKILL.md`
- Modify: `skills/suggest/SKILL.md`
- Modify: `skills/clarify/SKILL.md`
- Modify: `skills/specify/SKILL.md`
- Modify: `skills/tasks/SKILL.md`
- Modify: `skills/implement/SKILL.md`
- Modify: `skills/verify/SKILL.md`
- Modify: `skills/ship/SKILL.md`

- [ ] **Step 1: Append this exact block to the end of each of the 9 files**

```markdown

## Orientación (siempre)

Cierra cada turno con el **bloque-brújula** (📍 dónde estás · ✅ qué hiciste · 🧭 por qué · ➡️ siguiente, terminando en pregunta), calibrado al dial de `02-DOCS/wiki/harness/user-profile.md`. **Nunca termines en seco.** Protocolo completo: skill `orient` → `skills/orient/references/orientation-contract.md`. (Defiere a `suggest` el "¿instalo la skill que falta?".)
```

- [ ] **Step 2: Verify the footer is present in all 9 files**

Run: `for s in init harness suggest clarify specify tasks implement verify ship; do grep -q "Orientación (siempre)" skills/$s/SKILL.md && echo "$s OK" || echo "$s MISSING"; done`
Expected: nine lines, all `OK`.

- [ ] **Step 3: Re-validate frontmatter (footer edits are body-only, must not break parsing)**

Run: `npm run validate`
Expected: `frontmatter OK`.

- [ ] **Step 4: Commit**

```bash
git add skills/init/SKILL.md skills/harness/SKILL.md skills/suggest/SKILL.md skills/clarify/SKILL.md skills/specify/SKILL.md skills/tasks/SKILL.md skills/implement/SKILL.md skills/verify/SKILL.md skills/ship/SKILL.md
git commit -m "Anchor orientation footer in 9 high-traffic skills"
```

---

## Task 6: Make new skills inherit the footer (author-skill)

**Files:**
- Modify: `skills/author-skill/SKILL.md`

- [ ] **Step 1: Find the section where author-skill lists what a SKILL.md body must contain**

Run: `grep -n "^## " skills/author-skill/SKILL.md`
Expected: a list of section headers; pick the body/structure section (e.g. one about what the body should include) to insert after.

- [ ] **Step 2: Add this exact subsection to `skills/author-skill/SKILL.md` (after the body-structure section identified above)**

```markdown
## Orientation footer (required in every new skill)

Every new skill MUST end with the orientation footer so the harness never leaves the user
in seco. Append verbatim:

\`\`\`markdown

## Orientación (siempre)

Cierra cada turno con el **bloque-brújula** (📍 dónde estás · ✅ qué hiciste · 🧭 por qué · ➡️ siguiente, terminando en pregunta), calibrado al dial de \`02-DOCS/wiki/harness/user-profile.md\`. **Nunca termines en seco.** Protocolo completo: skill \`orient\` → \`skills/orient/references/orientation-contract.md\`. (Defiere a \`suggest\` el "¿instalo la skill que falta?".)
\`\`\`

The full protocol lives once in the \`orient\` skill; the footer only references it.
```

- [ ] **Step 3: Verify it landed**

Run: `grep -q "Orientation footer (required in every new skill)" skills/author-skill/SKILL.md && echo OK || echo MISSING`
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add skills/author-skill/SKILL.md
git commit -m "Require orientation footer in author-skill template"
```

---

## Task 7: Enforce orientation in the behavioral rubric

This reuses the existing grader: the rubric documents the expectation, and `orient`'s
capability scenarios already carry orientation `must_include` items (Task 3). No change to
`behavior-score.js` (YAGNI — the formula already scores `must_include` coverage).

**Files:**
- Modify: `scripts/skill-behavior-rubric.md`

- [ ] **Step 1: Add this exact subsection to `scripts/skill-behavior-rubric.md` after the "What the grader returns (per output)" section**

```markdown
## Orientation signal (the brújula)

User-facing, conversational skills should keep the user oriented. When a skill's capability
scenario ends a turn the user acts on, the grader expects the output to:

- **Situate** the user (where they are / what is built vs missing).
- **Teach the why**, scaled to the dial (`technical_level` / `accompaniment_level`).
- **Propose a next step phrased as a question** — never end in seco.

Encode this as `must_include` items in those skills' capability scenarios (see
`skills/orient/evals/cases.yaml` for the canonical pattern). It scores through the existing
coverage axis — no separate formula. Skills that own a purely mechanical task (lint, a
single rename) are exempt and should not be penalized.
```

- [ ] **Step 2: Verify it landed**

Run: `grep -q "Orientation signal (the brújula)" scripts/skill-behavior-rubric.md && echo OK || echo MISSING`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add scripts/skill-behavior-rubric.md
git commit -m "Document orientation signal in behavioral rubric"
```

---

## Task 8: Full validation gate

**Files:** none (verification only)

- [ ] **Step 1: Validate frontmatter across the catalog**

Run: `npm run validate`
Expected: `frontmatter OK`.

- [ ] **Step 2: Confirm the manifest is in sync with the skills on disk**

Run: `npm run manifest:check`
Expected: exits clean (manifest matches generated output). If it reports drift, run `npm run manifest`, then `git add manifest.json` and amend the Task 4 commit area with a follow-up commit.

- [ ] **Step 3: Lint every skill's evals**

Run: `bash scripts/eval-lint.sh`
Expected: all skills pass; `orient` included.

- [ ] **Step 4: Run the unit test suite**

Run: `npm test`
Expected: all tests pass (existing tests unaffected; this change adds no new JS).

- [ ] **Step 5: Final review of the working tree**

Run: `git status && git log --oneline -8`
Expected: clean tree; commits for Tasks 1-7 present.

---

## Self-Review

**Spec coverage:**
- §1 `orient` skill → Task 1. ✅
- §2 brújula block (with dial calibration) → Tasks 1 + 2. ✅
- §3 footer contract without churn (9 skills + author-skill template) → Tasks 5 + 6. ✅
- §4 eval enforcement → Tasks 3 + 7. ✅
- §5 spoken dial config → Task 1 (skill body) + Task 3 (capability scenario). ✅
- §6 YAGNI (no CLI/recommend.js changes) → respected; no such tasks. ✅
- Floor membership / always-on → Task 4 verifies `minimal` + `always-on`. ✅

**Open questions from the spec, resolved here:**
- Score placement → reuse `must_include` coverage; no `behavior-score.js` change (Task 7).
- Inline fallback when `orient` is not loaded → the footer itself carries the brújula format inline, so a skill installed without the floor still has the rule (Tasks 5/6).

**Placeholder scan:** none — every file's full content is inline.

**Naming consistency:** `orient`, `accompaniment_level`, `technical_level`, `02-DOCS/wiki/harness/user-profile.md`, and the footer heading `Orientación (siempre)` are used identically across all tasks.
