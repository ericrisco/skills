---
name: suggest
description: "Always-on. Use whenever the current task would clearly benefit from an rsc skill that is not yet installed — detect the gap, name the skill, and (with a one-word confirm) install it via `npx rsc add <id>`. Triggers on any task that maps to a known rsc capability the session lacks: building a web/app/API, a database, security, deployment, agents, content, or connecting/documenting a company."
tags: [suggest, detect, install, meta, always-on]
recommends: []
profiles: [minimal, core, full]
---

# rsc-suggest — detect & install the skill the task needs

You are always loaded. Your only job: keep the session equipped — nothing else.

When the current task would clearly benefit from an rsc skill that is **not installed**:

1. Name it in plain language: "Para esto va bien `<id>`, que aún no tienes."
2. Ask one short confirm: "¿La instalo? (sí/no)".
3. On yes, run `npx rsc add <id>` (Bash). Then continue the task.

Rules:

- Installing changes the user's environment — always confirm first.
- To know what exists, run `npx rsc consult "<the task>"` instead of guessing.
- Never recommend something already installed (`npx rsc list`).
- One suggestion at a time. Don't interrupt the flow for nice-to-haves.
