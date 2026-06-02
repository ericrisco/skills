# Consent matrix, ROPA, and the legitimate-interest worksheet

The copy-ready artifacts behind the consent and ROPA sections. Validate with a
DPO before adoption; nothing here is legal advice.

## ROPA template (Art. 30)

One row per processing activity. Art. 30 columns are mandatory; the lawful-basis
line is recommended even though Art. 30 doesn't strictly require it — it speeds
audits, DPIAs, and notice updates.

```text
Activity:      <name of the processing activity>
Purpose:       <why you process this data>
Data cats:     <categories of personal data>        | Subjects: <categories of data subjects>
Recipients:    <internal teams + processors + third parties>
Transfers:     <country + transfer mechanism, e.g. SCCs; or "none">
Retention:     <period + expiry action — must match the retention schedule>
Security:      <RBAC, encryption, logging, ...>
Lawful basis:  <Art. 6 sub-paragraph>               ← recommended, not strictly required
```

### Worked rows

```text
Activity:      Customer support ticketing
Purpose:       resolve and track support requests
Data cats:     name, email, account ID, message content | Subjects: customers
Recipients:    internal support team; Zendesk (processor)
Transfers:     US (SCCs in place)
Retention:     2 years after ticket closed, then delete
Security:      RBAC, encryption at rest, access logging
Lawful basis:  Art. 6(1)(b) contract

Activity:      Product analytics
Purpose:       understand feature usage to improve the product
Data cats:     pseudonymous event data, device, coarse location | Subjects: users
Recipients:    internal product team; analytics processor
Transfers:     none (EU-hosted)
Retention:     14 months, then anonymize
Security:      pseudonymization, RBAC, encryption at rest
Lawful basis:  Art. 6(1)(a) consent (non-essential analytics)
```

## Consent matrix template

```text
| Purpose | Lawful basis (Art. 6(1)(a)) | Capture point | Proof fields stored | Withdrawal mechanism | Refresh cadence |
|---------|-----------------------------|---------------|---------------------|----------------------|-----------------|
|         |                             |               | timestamp, text version, scope, method | | ~12 mo / on material change |
```

### Worked example

```text
| Purpose           | Lawful basis | Capture point   | Proof fields stored                | Withdrawal       | Refresh             |
|-------------------|--------------|-----------------|------------------------------------|------------------|---------------------|
| Marketing email   | Art. 6(1)(a) | signup checkbox | ts, text v2.1, scope, method       | one-click unsub  | 12 mo / on change   |
| Product analytics | Art. 6(1)(a) | cookie banner   | ts, banner vN, categories, method  | re-open banner   | 12 mo / on change   |
```

Capture rules (Art. 4(11) / Art. 7): affirmative opt-in, never pre-ticked;
granular per purpose; reject as easy as accept (no dark patterns); withdrawal as
easy as giving. The ePrivacy Regulation was withdrawn Feb 2025 — the ePrivacy
Directive still governs cookies and trackers.

## Consent withdrawal / refresh workflow

1. **Withdraw** — subject clicks the one-click control (unsubscribe link, banner
   re-open). No friction, no retention-by-dark-pattern.
2. **Stop processing** — the purpose tied to that consent halts immediately.
3. **Log** — write the withdrawal event (timestamp, scope withdrawn, method)
   to the consent log; keep proof of withdrawal as you keep proof of consent.
4. **Honor downstream** — propagate to processors and suppress in the CDP/ESP.
5. **Refresh** — re-request consent after ~12 months or whenever the
   consent text materially changes; re-prompting resets the proof record.

## Legitimate-interest balancing test (Art. 6(1)(f))

Run and document this before relying on legitimate interest. Anchor to EDPB
Guidelines 1/2024 (Oct 2024).

1. **Purpose test** — Is there a legitimate interest, clearly articulated?
   (e.g. fraud prevention, network security, direct B2B marketing.)
2. **Necessity test** — Is the processing actually necessary for that interest,
   or would less data / a less intrusive method achieve it?
3. **Balancing test** — Do the individual's interests, rights, and reasonable
   expectations override the interest? Consider the relationship, the data
   sensitivity, and whether the subject would expect this use.

If the balance tips against you, fall back to consent or contract — or don't
process. Record the outcome; a regulator can ask to see the assessment.

---

**Not legal advice.** A qualified DPO or privacy counsel must validate the
lawful-basis register, ROPA, and consent model before adoption.
