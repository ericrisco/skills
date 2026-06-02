# Retention schedule — template + worked example

This is the copy-ready artifact the body points to. Fill the template, validate
every period against local + sector law, and end the document with the DPO /
counsel sign-off line. Nothing here is legal advice.

## The fillable template

One row per personal-data category. No row ships without a period, a lawful
basis, and an expiry action.

```text
| Data category | Purpose | Lawful basis (Art. 6) | Retention period | Expiry action | System of record | Legal-hold flag | Review date |
|---------------|---------|-----------------------|------------------|---------------|------------------|-----------------|-------------|
|               |         |                       |                  | delete/anon/archive |            | yes/no          | YYYY-MM-DD  |
```

Column rules:

- **Retention period** — a concrete duration or named criteria ("36 months
  after last order"), never "as long as necessary" alone.
- **Lawful basis** — the specific Art. 6 sub-paragraph, not just "GDPR".
- **Expiry action** — exactly one of delete / anonymize / archive (see note).
- **System of record** — the actual store(s) the deletion job must touch,
  including the warehouse and backups, not just the live table.
- **Legal-hold flag** — whether rows here can be put under hold (litigation /
  regulatory), which the deletion job must skip.
- **Review date** — when this row is re-validated against current law.

## Populated example schedule

Periods below are common working defaults — **starting points, validate against
local + sector law** (Usercentrics; Secure Privacy, 2026). They are not asserted
as universally lawful.

```text
| Data category        | Purpose                  | Lawful basis        | Retention period            | Expiry action | System of record            | Legal-hold | Review date |
|----------------------|--------------------------|---------------------|-----------------------------|---------------|-----------------------------|------------|-------------|
| HR / payroll records | employment + statutory   | Art. 6(1)(b)+(c)    | 6 years after employment ends | archive     | HRIS + payroll backups      | yes        | 2027-01-01  |
| Accounting / tax     | statutory bookkeeping    | Art. 6(1)(c)        | 10 years (statutory, EU)    | archive       | ERP + cold storage          | yes        | 2027-01-01  |
| Customer / CRM       | fulfil + relationship    | Art. 6(1)(b)+(f)    | 3 years after last interaction | anonymize  | Postgres `customers` + DWH  | yes        | 2027-01-01  |
| Marketing consent    | email campaigns          | Art. 6(1)(a)        | life of consent + proof     | delete        | CDP + consent log           | no         | 2027-01-01  |
| Support tickets      | resolve + audit          | Art. 6(1)(b)+(f)    | 2 years after ticket closed | delete        | Zendesk (processor)         | yes        | 2027-01-01  |
| Server / access logs | security + debugging     | Art. 6(1)(f)        | 90 days                     | delete        | log store + backup rotation | no         | 2027-01-01  |
```

## delete vs anonymize vs archive

Pick the expiry action deliberately:

- **delete** — destroy the record everywhere it lives. The default when no
  lawful reason to keep remains.
- **anonymize** — strip identifiers so the data is no longer personal data;
  storage limitation then no longer applies. Valid only if re-identification is
  genuinely infeasible (a pseudonym you can reverse is *not* anonymization).
  Useful when you want aggregate analytics after the personal purpose ends.
- **archive** — retain under Art. 89(1) safeguards for archival, statistical,
  scientific, or statutory purposes (e.g. tax records). Move out of live
  systems, restrict access, document the lawful long-term purpose.

## Local + sector law validation checklist

Run this before adopting any schedule. A copied default can be unlawful in a
given jurisdiction or sector.

- [ ] Each period checked against the relevant **statutory minimum** (tax,
      employment, healthcare records) for every country you operate in.
- [ ] Each period checked against the relevant **maximum** / minimization duty —
      keeping longer than necessary is itself a violation.
- [ ] Sector rules applied (healthcare 10y DE to 20y FR; financial-services and
      regulated industries carry their own keep-periods).
- [ ] CPRA / US-state rules handled where applicable: disclose the retention
      period (or criteria) at or before collection, and don't keep longer than
      reasonably necessary for the disclosed purpose.
- [ ] AI reuse stated explicitly (purpose limitation, Art. 5(1)(b)).
- [ ] Backups and archives covered by the same periods as live data.
- [ ] DPO / privacy counsel sign-off obtained before adoption.

---

**Not legal advice.** Retention periods are jurisdiction- and sector-specific. A
qualified DPO or privacy counsel must validate this schedule before it is
adopted.
