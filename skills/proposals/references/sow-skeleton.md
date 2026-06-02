# SOW skeleton

Full Statement of Work template. The SOW is the child of an MSA: it scopes one project,
references the MSA for legal/payment/IP/dispute terms, and does not re-litigate them.
The four load-bearing sections are **exclusions**, **acceptance criteria**,
**change order**, and **payment schedule** — verify.sh fails a SOW missing any of them.

## Template

```markdown
# Statement of Work — [Project name]
**Client:** [name] · **Provider:** [name] · **Effective:** [date]
**Governed by:** Master Services Agreement dated [date] ("the MSA"). This SOW is an
annex under the MSA; the MSA's terms (liability, IP, governing law, dispute resolution)
control and are not restated here.

## 1. Scope — included
1. [Specific, quantified work item.]
2. [Specific, quantified work item.]
3. [...]

## 2. Scope — EXCLUDED (read this section to both sides on kickoff)
The following are explicitly NOT part of this SOW and require a separate SOW or
change order:
- [Adjacent task the client might assume is included.]
- [Maintenance / support beyond the window in §1.]
- [Third-party costs, licenses, content the client must provide.]
- Anything not listed in §1 is out of scope.

## 3. Deliverables and acceptance criteria
| # | Deliverable | Acceptance criteria (third-party testable) | Due |
|---|-------------|--------------------------------------------|-----|
| 1 | [name]      | [pass/fail an outsider can judge]          | Wk[x] |
| 2 | [name]      | [pass/fail an outsider can judge]          | Wk[x] |
Acceptance: client reviews within [N] business days; silence past [N] days = accepted.

## 4. Milestones and timeline
| Milestone | Deliverable(s) | Target date |
|-----------|----------------|-------------|
| Kickoff   | —              | [date]      |
| [phase]   | #1             | [date]      |
| Final     | #2, acceptance | [date]      |

## 5. Change-order process
Any change to scope, timeline, or budget requires a written change order signed by
both parties before work begins. Each change order states the revised deliverables,
the cost delta, and the new dates, and attaches to this SOW. Verbal requests and
out-of-scope work in progress are not authorized and are not billable until a change
order is signed.

## 6. Payment schedule (tied to milestones, not the calendar)
| Trigger                  | Amount   |
|--------------------------|----------|
| On signature             | [%]      |
| On [milestone]           | [%]      |
| On acceptance of #[last] | [%]      |
Invoices issued per the MSA; collection and billing handled separately (invoicing).

## 7. Assumptions and client responsibilities
- [What the client must provide, by when; delay shifts the timeline 1:1.]
- [Access, environments, decision-maker availability.]
```

## Change-order clause — drop-in text

```text
Change orders. Either party may request a change to scope, schedule, or fees. No
requested change is in effect, and no out-of-scope work is billable, until both
parties sign a written change order stating: (a) the revised or added deliverables,
(b) the change in fees, and (c) the revised dates. Signed change orders attach to and
amend this SOW; the MSA continues to govern all other terms.
```

## MSA-annex note

Keep the SOW about *this project's scope and money*. Liability caps, indemnity, IP
ownership/assignment, confidentiality, governing law, and signature-for-enforceability
live in the MSA — route any of that to `../../contracts/SKILL.md`. If there is no MSA
yet, flag it: the SOW should not carry the legal weight of one.
