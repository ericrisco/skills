# <TOOL_NAME>

> One sentence: what this tool is and what we use it for.

## When to use

> 1–2 sentences in business terms. Which operational flow does it enable?

## Setup

1. `cp .env.example .env && chmod 600 .env`
2. Fill in the real values from the provider dashboard (link in `CREDENTIALS.md`).
3. `./test_connection.sh` (or `python3 test_connection.py`) — should end with
   `OK — …`.

## Scripts

| Script | What it does | Example |
|--------|--------------|---------|
| `test_connection.{sh,py}` | Smoke-test: confirms `.env` authenticates. | `./test_connection.sh` |
| `<verb_object>.{sh,py}`  | <one-line description>                    | `./<verb_object>.sh <args>` |

## Operational notes

- Rate limits, sandbox vs production, gotchas, costs.
