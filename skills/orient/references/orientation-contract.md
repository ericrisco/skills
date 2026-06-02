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
