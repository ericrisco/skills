# Operating rhythm — schema, calendar, evidence, audit prep

The register is the source of truth. The cadence calendar, evidence catalog, and
audit-prep runbook are all generated from it.

## Control-register schema

A control register is a flat table, one row per control. Markdown or CSV — both
lint cleanly with `scripts/verify.sh`.

| Column | Required | Notes |
| --- | --- | --- |
| `control-id` | yes | Stable internal id, e.g. `AC-02`, `IR-01` |
| `framework` | yes | Every framework this control satisfies, multi-tagged |
| `owner` | yes | A named person/role — never "the team" |
| `evidence` | yes | The exact proving artifact and where it lives |
| `cadence` | yes | Review frequency, sized by risk |
| `last-verified` | recommended | Timestamp of the last attestation |
| `status` | recommended | `met` / `gap` / `in-progress` |

Optional leading `scope:` line names the frameworks in play, so `verify.sh` can
warn if a scoped framework has zero mapped controls:

```text
scope: SOC2, ISO27001, GDPR
| control-id | framework | owner | evidence | cadence | last-verified | status |
| --- | --- | --- | --- | --- | --- | --- |
| AC-02 | ISO27001 A.5.18, SOC2 CC6.2 | Head of IT | quarterly IdP access export, signed | quarterly | 2026-05-30 | met |
| IR-01 | ISO27001 A.5.24, SOC2 CC7.3 | Security Lead | incident runbook + last tabletop log | annual | 2026-04-12 | met |
```

## Cadence calendar

| Cadence | Work | Typical owner |
| --- | --- | --- |
| Daily | Automated control monitoring, drift/alert review | Security/Ops |
| Weekly | **Control-health review** — open gaps, stale evidence, overdue owners | Compliance lead |
| Monthly | Evidence refresh (high-risk controls); vuln-scan review | Control owners |
| Quarterly | Access recertification; vendor/third-party risk reassessment | IT / Vendor mgmt |
| Annual | Full risk assessment; policy review; pen test; audit prep | Compliance lead |

The **weekly control-health review** is the heartbeat. Without it, gaps surface
as audit findings instead of five-minute fixes.

## Evidence-source catalog

For each control, name where its evidence actually comes from. Common sources:

- **IdP / SSO** — access exports, MFA-enforcement config, deprovisioning logs.
- **Ticketing** — change-management approvals, incident records.
- **CI/CD** — build provenance, dependency-scan results, deploy approvals.
- **Cloud config** — encryption-at-rest settings, network rules, logging config.
- **HR system** — onboarding/offboarding timestamps, training completion.
- **Vendor portal / DPAs** — third-party security attestations, signed DPAs
  (drafted by `../contracts/SKILL.md`).
- **Policy repo** — versioned policy docs (text owned by `../data-policy/SKILL.md`,
  `../gdpr-privacy/SKILL.md`, `../terms-conditions/SKILL.md`).

Each evidence item must be **timestamped, mapped to the framework clause, and
owner-attested**.

## Audit-prep runbook

When an audit is announced (or T-90 days):

1. **Confirm scope** — frameworks, criteria/Annex selections, the audit window
   (for SOC 2 Type II, the 3–12 month period under test).
2. **Run a gap pass** — filter the register to `status != met`; assign each gap
   an owner and a close-by date.
3. **Refresh evidence** — for every in-scope control, confirm evidence exists,
   is timestamped within the window, and is owner-attested.
4. **Dry-run the interview** — for each control, can the owner produce the
   evidence and explain the control in one sentence? If not, that's a finding
   waiting to happen.
5. **Stand the rhythm back up** — the audit is a checkpoint, not the goal; the
   weekly review continues so the next audit is a non-event.

A program running the weekly review all year treats the audit as confirmation,
not as a crisis.
