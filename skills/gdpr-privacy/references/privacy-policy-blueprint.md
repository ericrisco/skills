# Privacy policy blueprint (Articles 13/14)

Fill-in sections for an Art. 13/14-complete privacy policy. Each carries a one-line **why required**. Replace every `[BRACKET]` — leftover brackets are a `verify.sh` failure and a signal the policy is a blind template. Write each section to match the ROPA; never describe data the product does not process.

Order: controller → DPO → purposes + basis → recipients → transfers → retention → rights → complaint → automated decision-making → source.

## 1. Controller identity & contact

```text
Data controller: [LEGAL ENTITY NAME], [REGISTERED ADDRESS].
Contact: [EMAIL] / [POSTAL ADDRESS].
EU representative (if controller is outside the EEA): [NAME / CONTACT, or "not applicable"].
```
Why required: Art. 13(1)(a) — the data subject must know who is responsible and how to reach them.

## 2. Data Protection Officer

```text
DPO contact: [DPO EMAIL / ADDRESS, or "We have not appointed a DPO because [REASON]."]
```
Why required: Art. 13(1)(b) — if a DPO exists or is mandatory, their contact must be published.

## 3. Purposes and lawful basis (one block per purpose)

```text
Purpose: [e.g. "Account creation and service delivery"]
  Data used: [CATEGORIES]
  Lawful basis: [consent | contract | legal obligation | vital interests |
                 public task | legitimate interests]
  If legitimate interests, the interest is: [STATE IT; LIA on file dated [DATE]]
```
Why required: Art. 13(1)(c) — purposes and the lawful basis *per purpose* are mandatory; legitimate interest must name the interest.

## 4. Recipients / categories of recipients

```text
We share personal data with:
  - [SUB-PROCESSOR / CATEGORY] — [purpose, e.g. "hosting", "analytics", "email"]
  - [...]
```
Why required: Art. 13(1)(e) — the data subject must know who receives their data.

## 5. International transfers

```text
We transfer personal data outside the EEA to: [COUNTRY / IMPORTER].
Transfer mechanism: [2021 Standard Contractual Clauses, module [C2C|C2P|P2P|P2C] |
                     EU-US Data Privacy Framework (importer certified [DATE]) |
                     adequacy decision].
Transfer impact assessment: [completed [DATE] | "not applicable, no transfer"].
```
Why required: Art. 13(1)(f) / 44-49 — transfers outside the EEA need a stated mechanism; SCCs without a TIA where one is needed is incomplete.

## 6. Retention

```text
We retain [CATEGORY] for [PERIOD], then [delete | anonymise].
Where no fixed period applies, the criteria are: [CRITERIA].
```
Why required: Art. 13(2)(a) — retention period or the criteria to set it must be disclosed; "as long as necessary" alone is not enough.

## 7. Data-subject rights

```text
You have the right to: access, rectification, erasure, restriction, objection,
and data portability, and to withdraw consent at any time where processing is
based on consent.
To exercise any right, contact [EMAIL/CHANNEL]. We respond within one month.
```
Why required: Art. 13(2)(b) + Art. 15-22 — the rights list and *how* to exercise it are mandatory.

## 8. Right to lodge a complaint

```text
You have the right to lodge a complaint with a supervisory authority, in
particular in your country of residence or work — for example [AUTHORITY NAME,
e.g. the AEPD in Spain / the APDCAT in Catalonia / the CNIL in France].
```
Why required: Art. 13(2)(d) — the right to complain to a supervisory authority is a mandatory disclosure (a frequent omission `verify.sh` checks for).

## 9. Automated decision-making / profiling

```text
[We do not carry out automated decision-making with legal or similarly
significant effects. | We use automated decision-making for [PURPOSE];
the logic is [MEANINGFUL DESCRIPTION] and the consequences are [...].]
```
Why required: Art. 13(2)(f) / 22 — existence and meaningful logic of automated decisions must be disclosed.

## 10. Source of data (Art. 14 case only)

```text
Where we did not collect your data from you directly, the source is: [SOURCE].
```
Why required: Art. 14(2)(f) — when data is obtained from a third party, the source must be disclosed.

---

**Before publishing:** have a qualified privacy counsel or your DPO review this policy against the actual processing. This blueprint is a drafting aid, not legal advice.
