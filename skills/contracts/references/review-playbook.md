# Review playbook

How to redline a counterparty's draft in the operator's favor. Read the clause they wrote, decide demand / concede / flag, propose plain-language replacement text. Always close with the attorney-review reminder.

## Pass order

Parties → scope → price/payment → risk clauses → boilerplate. The money is in the risk clauses; do not let boilerplate fatigue make you skim past them.

## Demand / concede / flag per clause

| Clause | Demand (non-negotiable) | Can concede | Flag if you see |
|---|---|---|---|
| Limitation of liability | A mutual cap with confidentiality + indemnity carve-outs | The exact multiple of fees | No cap at all; a cap that also limits *their* confidentiality breach |
| Indemnity | Narrow scope (breach/negligence/third-party IP); cap; survival 3–5 yr | Survival length within 3–5 yr | "any and all claims"; one-way indemnity running only from you |
| Force majeure | Defined term + catch-all + notice + mitigation | The persistence period before termination | Exhaustive list with no catch-all; excuses *their* payment obligations |
| Termination | Mutual for-cause with cure period | The notice window | One-way termination-for-convenience; no cure period |
| IP / ownership | Your background IP stays yours; deliverables assigned on payment | License vs assignment for edge assets | A grab of pre-existing/background IP; assignment before payment |
| Confidentiality | Defined info, set term, return-or-destroy | Term length | Perpetual confidentiality with no return-of-info clause |
| Auto-renewal | Short, mutual opt-out notice | Renewal term length | Auto-renew with a long (e.g. 90-day) opt-out window |
| Governing law/venue | One explicit, workable jurisdiction | Which of two reasonable venues | Unstated venue; a venue you can't realistically litigate in |

## Tells of a one-sided draft

- An uncapped indemnity (or a cap that conveniently excludes only *their* breaches).
- "Mutual" obligations that, read closely, only bind one party.
- A liability cap with no confidentiality/indemnity carve-out — good for the drafter, bad for you.
- A termination-for-convenience right held by only one side.
- Auto-renewal with a long opt-out notice window.
- IP language that sweeps in your pre-existing/background IP.

## MSA ↔ SOW reconciliation

1. List every term the SOW sets that the MSA also covers (price, liability, IP, payment).
2. For each overlap, check the SOW does not contradict the MSA.
3. If it does, decide which controls and state it in writing (default: the MSA controls unless the SOW expressly overrides and is signed by both).
4. Resolve all conflicts *before* either document is signed — not after a dispute.

## Jurisdiction caveats for the signing handoff

The signature mechanics belong to `../e-signature/SKILL.md`, but flag the right tier when you hand off:

- **US** — single, technology-neutral tier (ESIGN + UETA). Enforceability needs intent to sign, consent to do business electronically, a verifiable signer↔signature association, and retained reproducible records. Some documents are excluded (wills, certain family-law and notarial documents).
- **EU (eIDAS)** — three tiers: Simple, Advanced, Qualified. A Qualified Electronic Signature (QES) carries the legal effect of a handwritten signature across all member states and needs a qualified certificate from a Qualified Trust Service Provider. eIDAS 2.0 adds the European Digital Identity Wallet.

If a contract spans both regions or its enforceability depends on which signature tier is used, that is exactly the kind of cross-jurisdiction question a licensed attorney should confirm.

---

Reminder: a redline is a negotiating position, not legal advice. Have a licensed attorney review the final draft before signing.
