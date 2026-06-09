---
name: suggest
description: "Always-on. Use whenever the current user turn would clearly benefit from an rsc skill that is not yet installed — detect the gap during normal agent use, name the skill, and (with a one-word confirm) install it via `npx @ericrisco/rsc add <id>`. Triggers on capability intent in any language: building technology, creating content/assets, automating workflows, analyzing data, connecting tools, shipping/deploying, security, business ops, marketing, education, research, or company/documentation harness work."
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

## Mid-task capability intent detector

This runs **inside the agent conversation**, not only in the `rsc` CLI. At the start of
each user turn, before planning, coding, writing, researching, or answering in depth,
check whether the user is asking to create, build, fix, connect, automate, analyze,
publish, sell, teach, govern, secure, deploy, or document something that maps to a
known rsc capability.

This is broader than "start a project". It includes mid-conversation requests such as:

- Technology: "quiero montar una pagina web", "necesito una API", "build me a mobile app", "conecta Stripe", "automatiza este flujo", "deploy this", "review security".
- Creation: "haz una landing que convierta", "write a cold email sequence", "crea un pitch deck", "monta un curso", "edita shorts", "make social posts".
- Data and AI: "analiza estos datos", "build a dashboard", "quiero un agente de IA", "haz RAG sobre mis documentos", "extrae datos de PDFs".
- Business and ops: "organiza mi empresa", "prepara facturas", "monta CRM/pipeline", "haz contratos", "reduce churn", "gestiona soporte".
- Knowledge and research: "documenta cómo funciona esto", "crea una wiki", "procesa este inbox", "research competitors", "turn this into SOPs".
- Other languages: any equivalent phrasing. Match the user's intent, not exact words.

When a capability intent appears:

1. Run `npx @ericrisco/rsc list` to know what is already installed.
2. Run `npx @ericrisco/rsc consult "<the user's exact intent>"`.
3. Read the ordered result as the install queue, but pick only the **first missing**
   skill that is useful right now. Skip `suggest` and any installed skill.
4. Ask before installing: "Para esto instalaría `<id>`, que aún no tienes. ¿La instalo? (sí/no)".
5. On yes, run `npx @ericrisco/rsc add <id>` and then continue the original request.

Example: if the user says "quiero montar una pagina web para vender cursos online",
do not just start building. Check the installed list, consult that exact phrase, and
recommend the first missing skill from the returned queue. In a base install, `init`
and `harness` may already exist, so the first missing skill is usually `nextjs`. In a
bare install, `init` may be first. Install one skill at a time.

Example: if the user says "hazme una secuencia de cold emails para vender mi SaaS",
consult that exact phrase and recommend the first missing email/marketing skill rather
than writing generic copy with no specialist loaded.

## Onboarding gate (first contact)

Before handling the first request of the session, check the workspace state:

- If `02-DOCS/wiki/harness/user-profile.md` is **missing** AND `.rsc/.no-harness` is **missing**, the harness has never been set up here — your FIRST action is to invoke `init` (auto-onboarding), which opens with the two gauging questions (technical level + accompaniment dial). Don't wait to be asked; don't start the user's task until first contact is done.
- If the user declines or says they don't want a harness here ("sin harness", "solo código", "no quiero esto") — create an empty `.rsc/.no-harness` and never auto-start `init` in this repo again. Confirm in one line.
- Once `02-DOCS/wiki/harness/user-profile.md` exists, this gate is inert — never re-onboard.

This is the universal layer every assistant reads. On Claude Code a SessionStart hook also prints this reminder deterministically, but the rule above is what makes it fire everywhere.

## Orientación (siempre)

Cierra cada turno con el **bloque-brújula** (📍 dónde estás · ✅ qué hiciste · 🧭 por qué · ➡️ siguiente, terminando en pregunta), calibrado al dial de `02-DOCS/wiki/harness/user-profile.md`. **Nunca termines en seco.** Protocolo completo: skill `orient` → `skills/orient/references/orientation-contract.md`. (Defiere a `suggest` el "¿instalo la skill que falta?".)
