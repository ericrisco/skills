# Evals — rsc-suggest

The always-on detector. These cases check that it proposes the right missing
skill (and stays quiet when the task needs nothing new).

| Prompt | Expected |
|---|---|
| "crear la tabla de pedidos en la base de datos" | suggests `postgresdb` |
| "publicar mi web online con docker" | suggests `deployment` |
| "renombra esta variable" | no suggestion (trivial, nothing to install) |

A pass = the detector names the expected skill, asks a one-word confirm, and on
"sí" runs `npx @ericrisco/rsc add <id>`. It must never auto-install without confirmation and
must not recommend a skill already in `npx @ericrisco/rsc list`.
