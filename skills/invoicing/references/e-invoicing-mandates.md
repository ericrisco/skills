# E-invoicing mandates — the jurisdiction table

The EU is moving from "any human-readable invoice" to **structured e-invoices**: machine-readable XML carrying the EN 16931 semantic data model, usually exchanged over the **Peppol BIS** network. A PDF — even a flawless one — is *not* a structured e-invoice; it is an image of one. This file is the per-country detail behind the jurisdiction gate in SKILL.md.

All dates and facts accessed 2026-06-02 (sources: Fiskaly E-invoicing Europe 2026 roadmap; Fonoa Peppol 2026; European Commission eInvoicing country pages; Marosa Verifactu guide; Vertex Crea y Crece guide).

## What "structured" means

| | PDF / paper | Structured e-invoice |
| --- | --- | --- |
| Format | Image / printable doc | XML (UBL, Facturae, CII, EDIFACT) |
| Data model | None enforced | EN 16931 semantic core |
| Transport | Email / post | Peppol BIS, national portal, or clearance platform |
| Machine-readable | No | Yes — tax authority can parse it |
| Compliant past a mandate date | **No** | Yes |

## Country mandate table

| Country | Scope | Live / deadline | Format(s) | Transport / model |
| --- | --- | --- | --- | --- |
| Belgium | B2B | **1 Jan 2026** (in force) | EN 16931 (Peppol BIS) | Peppol (decentralised) |
| France | B2B/B2G, phased | from **Sep 2026** | Factur-X / UBL / CII | DGFiP = national Peppol Authority (since Jul 2025) |
| Germany | B2B, turnover bands | > EUR 800k by **1 Jan 2027**; all businesses 2028 | XRechnung / ZUGFeRD | Peppol / EN 16931 |
| Spain — Verifactu | Invoicing *software* | **1 Jan 2027** (corporate-tax payers; delayed by RD-ley 15/2025) | tamper-evident records + **mandatory QR** | chained-hash log, signature + timestamp |
| Spain — Crea y Crece | B2B structured invoice | phased ~Oct 2026; large firms (>EUR 8M) ~Oct 2027 | Facturae / UBL / CII / EDIFACT | + acceptance & payment-date reporting |
| Italy | B2B/B2C | already live | FatturaPA (XML) | SdI clearance |
| Poland | B2B | KSeF rollout | FA(2) XML | KSeF clearance |
| **EU-wide (ViDA)** | intra-EU B2B/B2G | **1 Jul 2030** (hard) | EN 16931 | Digital Reporting Requirements |

## Spain: two mandates, do not confuse them

- **Verifactu** governs the *software* that issues invoices — chained-hash tamper-evident records, signature + timestamp, a full event log, and a **mandatory QR code on every invoice**. It is about *how the record is produced and protected*.
- **Crea y Crece** governs the *exchange format* — a structured B2B e-invoice (UBL, Facturae, CII or EDIFACT) with acceptance and payment-date reporting. It is about *what document moves between businesses*.

A Spanish business can be subject to both, on different timelines.

## Practical gate

1. Where is the **customer** established?
2. Is the transaction **B2B, B2G, or B2C**? (mandates hit B2B/B2G first)
3. Is today **past that country's deadline**?

If yes to all three: do not email a PDF — generate the country's structured format and send it over the mandated channel. For building the actual integration to a Peppol access point or national portal, that is an engineering task — hand to `../stripe/SKILL.md` or an API-connector skill, not this skill.
