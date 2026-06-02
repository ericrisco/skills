# Data room — the 8-category checklist

The reference list behind the SKILL.md data-room section. A complete room is ~50–70 documents
across 8 numbered categories. **Seed** rooms skew 30–40 docs; **Series A** rooms 55–70. The
inclusion flag tells you what to include at each stage so you neither under-build (looks
unprepared) nor over-build (drafts dilute focus).

- ✅ = include at this stage  · ◐ = include if it exists / if material · — = usually omit at this stage

## File-naming & versioning convention

Every file: `YYYY-MM_Doc-Name_vN.ext`, inside its numbered category folder.

```text
07_CapTable_Equity/2026-03_Cap-Table_v2.xlsx
02_Financial/2026-03_Financial-Model_v4.xlsx
07_CapTable_Equity/2026-02_SAFE-AngelRound_v1.pdf
```

- **Date** (`YYYY-MM`) so recency is obvious — investors diligence the newest file as truth.
- **Version** (`vN`) so a superseded draft is never mistaken for current.
- **Hyphenate** the doc name (no spaces, no `(2)`, no `FINAL_FINAL`).
- One **current** version visible per doc; archive prior versions in a `_archive/` subfolder, not loose.

## 01 — Corporate

| Document | Seed | Series A |
| --- | --- | --- |
| Certificate of incorporation / formation | ✅ | ✅ |
| Bylaws / operating agreement | ✅ | ✅ |
| Board consents & minutes | ◐ | ✅ |
| Shareholder / founder agreements | ✅ | ✅ |
| Cap table summary (full detail in 07) | ✅ | ✅ |
| Prior financing docs (SAFE/note/round) | ◐ | ✅ |

## 02 — Financial

| Document | Seed | Series A |
| --- | --- | --- |
| Financial model (3-statement projection) | ✅ | ✅ |
| Historical P&L | ◐ | ✅ |
| Balance sheet | ◐ | ✅ |
| Cash-flow statement | — | ✅ |
| Bank statements (recent 3–6 mo) | ◐ | ✅ |
| Burn & runway summary | ✅ | ✅ |
| Budget vs actuals | — | ✅ |

> The financial model is built by `financial-model`; you reference and surface it, you do not author it.

## 03 — Legal & contracts

| Document | Seed | Series A |
| --- | --- | --- |
| Customer contracts / key MSAs | ◐ | ✅ |
| Supplier / vendor agreements | — | ◐ |
| NDAs & key partnership agreements | ◐ | ✅ |
| Office / equipment leases | ◐ | ✅ |
| Litigation log (or "none" attestation) | ✅ | ✅ |
| Insurance policies | — | ◐ |

## 04 — IP

| Document | Seed | Series A |
| --- | --- | --- |
| Trademark registrations / applications | ◐ | ✅ |
| Patents / provisional filings | ◐ | ◐ |
| Domain & brand-asset list | ✅ | ✅ |
| IP-assignment agreements (founders + contractors) | ✅ | ✅ |
| Open-source / license inventory | — | ◐ |

## 05 — Team & HR

| Document | Seed | Series A |
| --- | --- | --- |
| Org chart | ✅ | ✅ |
| Founder employment & vesting agreements | ✅ | ✅ |
| Key employment agreements | ◐ | ✅ |
| Option plan & grant ledger | ◐ | ✅ |
| Contractor / advisor agreements | ◐ | ✅ |
| Hiring plan | ✅ | ✅ |

## 06 — Product & metrics

| Document | Seed | Series A |
| --- | --- | --- |
| Product overview / one-pager | ✅ | ✅ |
| Roadmap | ✅ | ✅ |
| KPI dashboard (current metrics) | ✅ | ✅ |
| Cohort / retention data | ◐ | ✅ |
| Pipeline / sales data | ◐ | ✅ |
| Technical / security overview | — | ◐ |

## 07 — Cap table & equity

| Document | Seed | Series A |
| --- | --- | --- |
| Cap table (fully diluted) | ✅ | ✅ |
| SAFEs / convertible notes | ✅ | ✅ |
| Prior round legal docs | ◐ | ✅ |
| Option pool details | ◐ | ✅ |
| 409A valuation | — | ◐ |

> Investors spend 8–12 minutes here alone. Make the cap table and SAFEs current, clean, and impossible to miss.

## 08 — Tax & compliance

| Document | Seed | Series A |
| --- | --- | --- |
| Tax filings / returns | ◐ | ✅ |
| Business registrations & licenses | ✅ | ✅ |
| R&D / tax-credit filings | — | ◐ |
| Regulatory / compliance certificates | — | ◐ |
| Data-protection / GDPR posture | ◐ | ◐ |

## Surface first vs omit until ready

**Surface first** (most-scrutinized — current version, impossible to miss):

- Cap table (07) and SAFEs / convertibles (07)
- Financial model (02)
- KPI dashboard (06)

**Omit until ready** (a draft here is worse than its absence):

- Half-finished contracts, unsigned agreements, placeholder tax folders.
- A note ("available on request") beats an empty or stub file.
- Anything you would not want diligenced as final.

## Sharing & analytics

- One **access link per investor** (DocSend-style) — not a public folder.
- Read the analytics: who opened what, time-per-page, whether it was forwarded.
- Use drop-off to fix weak materials; use warmth signals to prioritize follow-up.
- You advise this practice and read the data; building the VDR tooling is out of scope.
