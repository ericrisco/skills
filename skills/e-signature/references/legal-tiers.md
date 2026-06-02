# Legal tiers — SES / AES / QES (NOT legal advice)

This is engineering orientation so you wire the right provider features. It is **not legal advice**. For anything high-stakes or jurisdiction-specific, escalate to a lawyer and to `../contracts/SKILL.md`.

## US: no tiers

The **ESIGN Act** (federal) and **UETA** (state-adopted) make an electronic signature legally equivalent to a wet-ink one, with no tiered system. What matters: intent to sign, consent to do business electronically, association of the signature with the record, and retention of the record. A typed name with a captured audit trail is generally binding.

## EU: three tiers under eIDAS

**eIDAS** (and **eIDAS 2.0 — Reg (EU) 2024/1183**, in force since May 2024, which drives the EUDI Wallet) defines:

| Tier | Definition | Legal weight |
|------|-----------|--------------|
| **SES** — Simple | Data in electronic form used to sign; minimal identity assurance | Admissible, but the burden of proving it is on you |
| **AES** — Advanced | Uniquely linked to and capable of identifying the signer; signer-controlled; tamper-evident | Strong evidentiary value |
| **QES** — Qualified | AES + a qualified certificate from a **Qualified Trust Service Provider (QTSP)** + qualified signature-creation device | Legally equivalent to a handwritten signature EU-wide; explicitly required by some laws |

Use SES for routine B2B. Step up to AES when you need identity assurance / tamper-evidence (enable ID Verification, SMS/access-code auth). Use QES only when a law mandates it (certain real-estate, government, regulated finance) — it requires a QTSP relationship, not just a flag.

## The audit trail is the load-bearing evidence

Whatever the tier, the **audit trail is what defends the signature in court**: who signed, what they signed, when, from where, and proof the document was not altered after. DocuSign emits a **Certificate of Completion**; Dropbox Sign provides an **audit-trail PDF**. Without it, even a valid SES is hard to defend.

### Court-admissibility checklist

- [ ] Signer identity captured (email, name, and for AES/QES an identity check)
- [ ] Intent to sign recorded (the signing action, not a pre-checked box)
- [ ] Consent to electronic process captured
- [ ] Timestamp + IP / location in the audit trail
- [ ] Tamper-evidence / document hash so post-signature edits are detectable
- [ ] Both the signed PDF AND the audit-trail document retrieved and stored
- [ ] Retention period defined for the signed doc + its PII (policy → `../gdpr-privacy/SKILL.md`)

## When to escalate

Escalate to a lawyer (and route contract-text questions to `../contracts/SKILL.md`) when: the document is high-value or high-risk; a specific law may mandate QES; the deal crosses jurisdictions with different e-signature rules; or someone asks whether a particular signature would "hold up in court." You implement the flow — you do not rule on legal sufficiency.
