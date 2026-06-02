# Evals — domains-dns

These cases exercise the skill's routing and coverage. `should_trigger` lists prompts the
`domains-dns` skill must claim (pointing a domain at a host, TLS chain debugging, CAA gating,
expired-cert auto-renew, nameserver cutover, the SPF/DKIM/DMARC *rows*), including a non-obvious
symptom (`dig +trace` shows the old IP), an error-string trigger (`NET::ERR_CERT_AUTHORITY_INVALID`),
and a Spanish phrasing. `should_not_trigger` lists adjacent prompts that must route elsewhere
(email-deliverability, cloudflare, deployment, monitoring, vercel) — each names the real sibling it
belongs to. The `capability` case checks the body actually produces a correct apex+www+TLS+CAA setup
with the right verification and cutover discipline.

To run: feed `cases.yaml` to the repo's eval harness, which scores the skill description and body
against each prompt's expected routing and the capability rubric. To check by hand, read `cases.yaml`
and confirm `SKILL.md` (plus its references) answers each should_trigger prompt, sends each
should_not_trigger prompt to the named sibling, and covers every `must_include` item in the
capability scenario.
