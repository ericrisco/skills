# Accompaniment & Profile — the non-technical-first script, the dial, and how it persists

This file holds the runtime detail behind the SKILL.md section "Non-technical-first + the accompaniment dial". It defines: the first-contact script, the dial, the exact `02-DOCS` file formats, and the rules every downstream skill follows to adapt.

## Why this matters

The single biggest failure mode of a developer-built harness is talking like a developer to someone who is not one. This system inverts the default: it assumes non-technical, asks before assuming otherwise, and lets the user turn explanation up or down at will. The profile is the contract; every skill honors it.

## The first-contact script

Ask exactly two things, in order, before anything else. Do not bundle them with discovery questions.

### Question 1 — technical level (the literal first message)

Spanish:

> "Antes de nada, para hablarte como te resulte más cómodo: ¿te manejas con código y términos técnicos, o prefieres que te lo explique todo en cristiano? No hay respuesta mala — solo me ayuda a no aburrirte ni perderte."

English:

> "First, so I talk to you the right way: are you comfortable with code and technical terms, or would you rather I explain everything in plain language? There's no wrong answer — it just helps me not bore you or lose you."

Map the answer to one of:

- `non-technical` — plain language, analogies, no jargon, no code shown unless asked.
- `mixed` — comfortable with concepts, not necessarily syntax; define terms once.
- `technical` — full jargon OK, can read code and configs.

If the user does not answer clearly, assume `non-technical`. Never guess "technical" from the fact that they opened a terminal — many non-technical people are handed one.

### Question 2 — the accompaniment dial

Present all four levels with their plain descriptions (do not show only labels):

- **L0 — "Modo cavernícola"**: mínimas palabras. Hago las cosas y ya, casi sin explicar.
- **L1 — "Breve"**: una línea de *por qué* en cada paso.
- **L2 — "Explica decisiones"**: justifico cada decisión relevante a medida que avanzo.
- **L3 — "Acompañamiento total"**: te lo explico TODO, te hago muchas preguntas para entender tu contexto, y razono cada decisión. Ideal para no-técnicos.

Defaults when the user gives no preference: `non-technical → L3`, `mixed → L2`, `technical → L1`. The user can change the dial any time by saying so ("ponlo en breve", "explícamelo todo"); update `user-profile.md` when they do.

## How every skill adapts

Both values combine. `accompaniment_level` controls **how much** is said and **how many questions** are asked; `technical_level` controls **the vocabulary**.

| Level | Output verbosity | Questions before acting | On a decision |
| --- | --- | --- | --- |
| L0 | Result line only | None beyond hard blockers | Pick the recommended option, log it, mention it in one line |
| L1 | One *why* line per step | Only on genuine ambiguity | Present the 3 options tersely, recommend, proceed on confirm |
| L2 | Justify each relevant decision | Ask before each significant decision | Full 3-option pattern with trade-offs |
| L3 | Narrate reasoning throughout | Many — contextualize every choice | Full 3-option pattern + explain each option in plain language and check understanding |

Vocabulary modifier:

- `non-technical` — translate every term ("a database is where the app remembers things"), prefer analogies, never paste raw config without explaining it.
- `mixed` — use the term, define it inline the first time.
- `technical` — use the term directly; skip the 101 explanations even at L3.

**Rule:** read `user-profile.md` at the start of every session. If it is missing, you are likely being run before `init` — run the first-contact script before doing the requested work, or at minimum default to `non-technical` + `L3` and note that the profile is unset.

## Persistence format

Both files live under `02-DOCS/wiki/harness/`. `init` creates this directory even on greenfield; the rest of `02-DOCS` is built by the `harness` skill.

### `02-DOCS/wiki/harness/user-profile.md`

A living document — updated whenever the user reveals new goals, context, constraints, or changes the dial. It is the single source of truth other skills read.

```markdown
# User Profile

> Source of truth for how every rsc skill talks to this user. Updated continuously.

## Levels
- technical_level: non-technical            <!-- non-technical | mixed | technical -->
- accompaniment_level: L3                    <!-- L0 | L1 | L2 | L3 -->
- language: es                               <!-- the user's working language -->
- last_updated: 2026-06-01

## Who they are
- One or two lines: role, relationship to the project, what they already know.

## What they want to build or govern
- domain: non-code-harness                   <!-- software | non-code-harness -->
- one-line description of the thing.
- software surfaces (if any): backend | frontend | mobile | agents
- non-code surfaces (if any): company/ops | research | personal-knowledge | content

## Goals
- The outcome that means "this worked".
- Secondary goals.

## Context
- Greenfield or brownfield, detected stack/state.
- Tools/providers already in play (email, CRM, payments, hosting…).
- Team size and ops comfort.

## Constraints
- Budget, timeline, data region/residency, compliance, non-negotiables.

## Open questions
- Anything not yet answered, to revisit.
```

### `02-DOCS/wiki/harness/decisions.md`

**Append-only.** Never edit or delete an entry — if a decision is reversed, append a new entry that supersedes the old one and references it. This is the audit trail of why the project is the way it is.

```markdown
# Decisions Log (append-only)

> One entry per significant decision. Never edit or delete; supersede by appending.

---
## D-0001 — Deploy target
- date: 2026-06-01
- context: ~500 users expected, 20 concurrent, EU data residency required, small team, low budget.
- options considered:
  1. Hetzner VPS + Coolify — cheap, full control, self-managed.
  2. Vercel — zero-ops, managed, scales; pricey at scale.
  3. Fly.io — managed containers, EU region, middle ground.
- decision: Hetzner VPS + Coolify (Falkenstein, EU).
- why: budget + EU residency + team OK self-managing one box.
- supersedes: none
---
## D-0002 — …
```

### Linking from the root `CLAUDE.md`

Add (or update) a `## Knowledge map` section that links BOTH files. Create `CLAUDE.md` if absent; if it exists, only add/update this section — never delete user content.

```markdown
## Knowledge map

- [User profile](02-DOCS/wiki/harness/user-profile.md) — technical level, accompaniment dial, goals, context, constraints. **Every skill reads this first and adapts its verbosity and questions.**
- [Decisions log](02-DOCS/wiki/harness/decisions.md) — append-only record of every significant decision and why.
```

When the `harness` skill later builds the full wiki, it extends this same `## Knowledge map` with links to the rest of `02-DOCS/` — it does not replace the harness entries written here.
