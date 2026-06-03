---
name: suggest
description: "Always-on. Use whenever the current task would clearly benefit from an rsc skill that is not yet installed — detect the gap, name the skill, and (with a one-word confirm) install it via `npx @ericrisco/rsc add <id>`. Triggers on any task that maps to a known rsc capability the session lacks: building a web/app/API, a database, security, deployment, agents, content, or connecting/documenting a company."
tags: [suggest, detect, install, meta, always-on]
recommends: []
profiles: [minimal, core, full]
---

# rsc-suggest — detect & install the skill the task needs

You are always loaded. Your only job: keep the session equipped — nothing else.

When the current task would clearly benefit from an rsc skill that is **not installed**:

1. Name it in plain language: "Para esto va bien `<id>`, que aún no tienes."
2. Ask one short confirm: "¿La instalo? (sí/no)".
3. On yes, run `npx @ericrisco/rsc add <id>` (Bash). Then continue the task.

Rules:

- Installing changes the user's environment — always confirm first.
- To know what exists, run `npx @ericrisco/rsc consult "<the task>"` instead of guessing.
- For a project-level view, prefer `.rsc/skill-registry.json` when present; if it is missing or stale, suggest `npx @ericrisco/rsc registry refresh`. This is a cheap index, not a reason to load every skill.
- Never recommend something already installed (`npx @ericrisco/rsc list`).
- One suggestion at a time. Don't interrupt the flow for nice-to-haves.

## Onboarding gate (first contact)

Before handling the first request of the session, check the workspace state:

- If `02-DOCS/wiki/harness/user-profile.md` is **missing** AND `.rsc/.no-harness` is **missing**, the harness has never been set up here — your FIRST action is to invoke `init` (auto-onboarding), which opens with the two gauging questions (technical level + accompaniment dial). Don't wait to be asked; don't start the user's task until first contact is done.
- If the user declines or says they don't want a harness here ("sin harness", "solo código", "no quiero esto") — create an empty `.rsc/.no-harness` and never auto-start `init` in this repo again. Confirm in one line.
- Once `02-DOCS/wiki/harness/user-profile.md` exists, this gate is inert — never re-onboard.

This is the universal layer every assistant reads. On Claude Code a SessionStart hook also prints this reminder deterministically, but the rule above is what makes it fire everywhere.

## Orientación (siempre)

Cierra cada turno con el **bloque-brújula** (📍 dónde estás · ✅ qué hiciste · 🧭 por qué · ➡️ siguiente, terminando en pregunta), calibrado al dial de `02-DOCS/wiki/harness/user-profile.md`. **Nunca termines en seco.** Protocolo completo: skill `orient` → `skills/orient/references/orientation-contract.md`. (Defiere a `suggest` el "¿instalo la skill que falta?".)

