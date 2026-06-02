# Output contracts: per-provider strict recipes

Pick the strongest mechanism the provider gives you. Provider APIs and version notes
below verified 2026-06-02 (access date); each external figure carries its own source
date inline — do not read the access banner as the date a cited number was published.

## OpenAI — strict `json_schema` via `response_format`

Highest reliability: the provider compiles the schema into a token-masking FSM, so the
output is guaranteed to parse against the schema (**<0.1% schema-failure rate** — figure
published by OpenAI at the Aug 2024 Structured Outputs launch, not a 2026 number). Set
`strict: true` and mark every field required (use unions/nullable for optional).

```python
from openai import OpenAI
from pydantic import BaseModel

class Triage(BaseModel):
    category: str  # "bug" | "billing" | "other"

client = OpenAI()
resp = client.chat.completions.parse(
    model="gpt-…",                       # resolve the model id from config, not here
    messages=[{"role": "user", "content": prompt}],
    response_format=Triage,              # SDK emits strict json_schema under the hood
)
result = resp.choices[0].message.parsed  # already a Triage, or None on refusal
```

Raw form (no SDK helper):

```json
{
  "type": "json_schema",
  "json_schema": {
    "name": "triage",
    "strict": true,
    "schema": {
      "type": "object",
      "properties": { "category": { "type": "string", "enum": ["bug", "billing", "other"] } },
      "required": ["category"],
      "additionalProperties": false
    }
  }
}
```

## Anthropic — strict tool use

Reliable schema adherence, close behind OpenAI strict. Define a single tool whose
`input_schema` is your contract and force it. **Assistant-prefill structured output is
dead in the latest models** — Anthropic's migration guide states prefill returns a `400`
on Sonnet 4.6 / Opus 4.6 / Opus 4.7 and routes you to structured outputs / `output_config.format`
(platform.claude.com/docs/en/about-claude/models/migration-guide). Do not use prefill to
coerce a shape.

```python
import anthropic
client = anthropic.Anthropic()
msg = client.messages.create(
    model="claude-…",                    # from config
    max_tokens=256,
    tools=[{
        "name": "emit_triage",
        "description": "Return the ticket category.",
        "input_schema": {
            "type": "object",
            "properties": {"category": {"type": "string", "enum": ["bug", "billing", "other"]}},
            "required": ["category"],
        },
    }],
    tool_choice={"type": "tool", "name": "emit_triage"},
    messages=[{"role": "user", "content": prompt}],
)
block = next(b for b in msg.content if b.type == "tool_use")
result = block.input  # {"category": "..."}
```

**Streaming caveat:** Anthropic tool-use output arrives as ONE block at end of stream —
you cannot read fields progressively. OpenAI/Gemini stream field-by-field. If your UI
parses-as-it-streams, that path does not exist on Claude tool use.

## Google Gemini — `responseSchema`

Set `response_mime_type: "application/json"` and a `response_schema`. Validate after,
same as any JSON path.

```json
{ "generationConfig": { "response_mime_type": "application/json", "response_schema": { "type": "OBJECT", "properties": { "category": { "type": "STRING", "enum": ["bug","billing","other"] } } } } }
```

## TypeScript schema surface (zod)

```typescript
import { z } from "zod";
const Triage = z.object({ category: z.enum(["bug", "billing", "other"]) });
// OpenAI: zodResponseFormat(Triage, "triage"); Anthropic: zodToJsonSchema(Triage) as input_schema.
const parsed = Triage.parse(JSON.parse(raw));   // throws -> trigger retry
```

## Retry-on-parse-fail (for JSON mode / freeform only)

Strict mechanisms above rarely need this. When you only have JSON mode or freeform,
bound the retries and feed the parser error back:

```python
def call_with_retry(prompt, schema, parse, max_tries=2):
    last_err = None
    for _ in range(max_tries + 1):
        raw = call_model(prompt if last_err is None
                         else f"{prompt}\n\nYour previous output failed: {last_err}. Return only valid output.")
        try:
            return parse(raw, schema)          # raises on invalid
        except Exception as e:
            last_err = str(e)
    raise ValueError(f"contract not met after retries: {last_err}")
```

Keep `max_tries` small (1-2). If a strict mechanism is available, use it instead of
spending tokens on retries.
