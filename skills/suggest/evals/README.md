# Evals — rsc-suggest

The always-on detector. These cases check that it proposes the right missing
skill (and stays quiet when the task needs nothing new).

| Prompt | Expected |
|---|---|
| "crear la tabla de pedidos en la base de datos" | suggests `postgresdb` |
| "publicar mi web online con docker" | suggests `deployment` |
| "quiero montar una pagina web para vender cursos online" | during agent use, consults the catalog and suggests the first missing startup/web skill, usually `nextjs` after base install |
| "Automatiza el flujo de leads desde el formulario hasta mi CRM" | during agent use, consults the catalog and suggests the first missing automation/connector skill |
| "Write a cold email sequence to sell my SaaS to agencies" | during agent use, consults the catalog and suggests the first missing email/marketing skill |
| "renombra esta variable" | no suggestion (trivial, nothing to install) |

A pass = the detector names the expected skill, asks a one-word confirm, and on
"sí" runs `npx @ericrisco/rsc add <id>`. It must never auto-install without confirmation and
must not recommend a skill already in `npx @ericrisco/rsc list`.
