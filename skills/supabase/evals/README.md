# Evals — supabase

These cases are run by the repository's skill eval runner, not by hand. `should_trigger` asserts the
router selects `supabase` for each prompt (including the Spanish phrasing and the non-obvious
trust-boundary / Broadcast-vs-Postgres-Changes cases). `should_not_trigger` asserts the router instead
routes to the named sibling (`postgresdb`, `drizzle-orm`, `firebase`, `nextjs`) — these are the nearby
skills most likely to be confused with this one. The `capability` case is graded against its
`must_include` rubric: a passing answer for the multi-tenant SaaS scenario covers the key trust
boundary, RLS enablement and performance (`(select auth.uid())`, indexes, `to authenticated`),
team_id authorization via a security-definer helper, `@supabase/ssr` middleware + `getUser()`, storage
RLS, and the data-API exposure gotcha. Run with the repo's standard eval command pointed at this
`cases.yaml`.
