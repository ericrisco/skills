# Evals for the `neon` skill

These cases are routing and trigger checks, not executed code. Run them by reading each prompt and
confirming the behavior: every `should_trigger` prompt should make an agent load and apply this skill
(including the non-obvious "too many connections" / cold-start phrasings and the Spanish/Catalan
ones); every `should_not_trigger` prompt should route to the named sibling (`postgresdb`,
`drizzle-orm`, `supabase`, `vercel`, `backups`) instead of firing here. The `capability` case is a
rubric: have an agent answer the Neon-wiring scenario and grade the response against each
`must_include` item — pooled-vs-direct strings, HTTP vs WebSocket choice, Pool lifecycle inside the
handler, atomic-operation handling, per-PR branching with teardown, and deferring engine craft to
postgresdb. No network or database is required.
