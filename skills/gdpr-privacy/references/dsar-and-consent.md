# DSAR runbook, LIA template & consent banner

## Data-subject-rights (DSAR) runbook

**The clock: one month from receipt** (Art. 12(3)). Extendable by **two further months** for complex or numerous requests — *only if* you tell the person within the first month, with reasons. Silent extension is a breach.

1. **Log receipt + date.** The date the request arrives starts the clock — log it the day it lands, not the day you notice it.
2. **Verify identity proportionately.** Confirm who they are using data you already hold where possible. Do not over-collect to verify (no passport scan to release an email you already have). Over-collection is itself a processing violation.
3. **Route by right:**

| Right | Article | What you deliver |
|---|---|---|
| Access | 15 | A copy of the data + purposes, recipients, retention, source, rights context |
| Rectification | 16 | Correct inaccurate/incomplete data and tell recipients |
| Erasure | 17 | Delete, subject to the exceptions below |
| Restriction | 18 | Stop processing but keep storing, on stated grounds |
| Portability | 20 | The data the person provided, in a structured, commonly used, machine-readable format |
| Objection | 21 | Stop processing based on legitimate interest / direct marketing |

4. **Apply erasure exceptions** (Art. 17(3)) — erasure is *not* absolute. Carve-outs: legal-obligation retention (e.g. tax records), establishment/exercise/defence of legal claims, and freedom of expression and information. State which exception applies and why; erase the rest.
5. **Charge / refuse only for manifestly unfounded or excessive requests** (Art. 12(5)) — then a reasonable fee or refusal, *with reasons* and the right to complain. Default is free of charge.

## Legitimate Interests Assessment (LIA) — three-part template

Required (Art. 6(1)(f)) before relying on legitimate interest. Date it and keep it on file. No LIA, no legitimate-interest basis.

```text
LIA — [PURPOSE], dated [DATE], owner [NAME]

1. PURPOSE TEST — Is there a legitimate interest?
   Interest: [STATE THE INTEREST]
   Whose: [controller's / third party's]
   Legitimate & specific? [yes/no + why]

2. NECESSITY TEST — Is the processing necessary for it?
   Could you achieve the purpose a less-intrusive way? [yes/no]
   If yes, you cannot rely on legitimate interest — minimise or change basis.

3. BALANCING TEST — Do the individual's rights override the interest?
   Reasonable expectations: would the person expect this? [yes/no]
   Impact on the individual: [low/medium/high + why]
   Safeguards (opt-out, minimisation, transparency): [LIST]
   Conclusion: [interest prevails / does not — change basis or stop]
```

## Compliant cookie-banner config shape

Three controls at equal weight; non-essential categories off until the user chooses; nothing fires before consent.

```json
{
  "blockUntilConsent": true,
  "controls": [
    { "id": "accept-all", "label": "Accept all",  "weight": "primary" },
    { "id": "reject-all", "label": "Reject all",  "weight": "primary" },
    { "id": "customize",  "label": "Customize",   "weight": "primary" }
  ],
  "categories": [
    { "id": "necessary",   "default": true,  "lockable": true,  "purpose": "strictly necessary" },
    { "id": "analytics",   "default": false, "purpose": "usage measurement" },
    { "id": "marketing",   "default": false, "purpose": "advertising" },
    { "id": "preferences", "default": false, "purpose": "personalization" }
  ],
  "withdrawable": true,
  "note": "ePrivacy Directive transposed per member state — confirm per-country rules"
}
```

Key invariants: `reject-all` is present and at the same `weight` as `accept-all`; `blockUntilConsent` is `true`; only `necessary` defaults to `true`; consent is `withdrawable`.

## verify.sh banlist rationale

`scripts/verify.sh <artifact>` is a heuristic completeness/parity check on an emitted artifact, not a judge of legal correctness. It exists because the two most common, mechanical failures are catchable by text:

- **Privacy policy** missing an Art. 13/14 load-bearing token — a lawful basis, a rights mention, a retention mention, the right to complain to a supervisory authority, a contact. These are the precise omissions the 2026 transparency enforcement action targets.
- **Boilerplate-lie / placeholder leftovers** — unfilled `[BRACKET]`, "any and all data" catch-alls, "industry-standard security" with no Article 32 reference. These signal a blind template, not a ROPA-derived policy.
- **Cookie banner** with an `accept` control but no `reject`/`decline`/`rebuig`/`rechazar` control — encodes the reject-as-easy-as-accept rule mechanically.

It exits 0 when given no argument (never blocks) and only fails on a real artifact that violates a rule. It does not and cannot replace counsel review.

---

**Before relying on any DSAR decision, LIA, or banner:** have a qualified privacy counsel / your DPO review it. Drafting aid, not legal advice.
