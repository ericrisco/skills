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
