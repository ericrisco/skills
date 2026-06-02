# Threat model: OWASP Agentic Top 10 (2026) → controls

Mapping of the named agentic risks to the control in `../SKILL.md` that mitigates each.
Sources: OWASP Gen AI Security Project, "OWASP Top 10 for Agentic Applications for 2026"
(genai.owasp.org); OWASP Top 10 for LLM Applications v2025; OWASP AI Agent Security Cheat
Sheet (cheatsheetseries.owasp.org). All accessed 2026-06-02.

| Agentic risk                       | What it is                                                              | Control in this skill                                   |
| ---------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------- |
| Memory poisoning (T1)              | Contamination persists across sessions, re-attacking every future run   | Memory hygiene: validate before store, isolate, expire  |
| Tool misuse & exploitation         | Abuse via unsafe composition / recursion / excessive calls *with* valid perms | Tool gating + runtime kill-switches (rate/loop caps)    |
| Privilege compromise               | Broad or stolen creds let the loop act beyond its task                  | Task-scoped short-lived tokens; least agency            |
| Indirect prompt injection (LLM01)  | Untrusted content carries instructions the model executes               | Trust-boundary table; segregate data from instructions  |
| Excessive agency                   | Acting without check-back on irreversible/external actions              | HITL by risk class; deny-by-default scope               |
| Data exfiltration                  | Stolen data leaves via tool output / outbound calls                     | Output schema validation; exfil-shape detection         |

The OWASP framing of root causes — excessive **functionality**, **permissions**,
**autonomy** — maps one-to-one onto the three excesses in the SKILL body. Cutting all three
is the deny-by-default + least-agency posture.

## Pre-ship guardrail checklist

Before an autonomous loop reaches production, confirm:

- [ ] Allowed task domain is declared in the system prompt as a hard boundary.
- [ ] Tools are deny-by-default; each enabled tool has a written task justification.
- [ ] Every tool has a profile (read / write / exec / send) and an allowlist, not a wildcard.
- [ ] No tool can read `*.key` / `*.pem` / `*secret*` / `*.env` or run with destructive flags.
- [ ] Creds are task-scoped and short-lived, not one broad session token.
- [ ] All external content (web, email, RAG, API, other agents) is delimited as untrusted.
- [ ] Tool-call args are schema-validated; recipients/domains are allowlisted (exfil guard).
- [ ] HITL is gated by risk class; irreversible/external actions require approval bound to exact params.
- [ ] Memory is validated before store, isolated per user/session, expiring, PII-redacted.
- [ ] Runtime caps exist and fail closed: rate, cost, loop/step, wall-clock timeout.
- [ ] Every tool call is logged (redacted); repeated approval-bypass alerts.

## Incident triage: "the agent did X"

When an agent has already done something it should not have, work the loop in order:

1. **Contain.** Revoke the task tokens / creds the loop is holding; trip the kill-switch
   (pause the loop). Stop the bleeding before diagnosing.
2. **Find the trust boundary it crossed.** Which untrusted source reached a privileged
   tool? Trace the action's parameters back to their origin — usually an email body, RAG
   chunk, fetched page, or a poisoned memory entry.
3. **Purge poisoned memory.** If the bad behavior repeats across sessions, the cause is
   stored, not in-context. Delete the contaminated entries; do not just restart the session.
4. **Add the missing gate.** Reclassify that action's risk, move it behind HITL or block,
   tighten the tool allowlist, or add the schema/exfil check that would have caught it.
5. **Confirm with a replay.** Re-run the triggering input against the new guardrail and
   verify the action is now refused or escalated.
