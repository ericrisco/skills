# Restore runbook + scheduled-test discipline

A backup you can't restore under pressure is worthless. Fill this in *before* the disaster, and rehearse it on the cadence below.

## Restore runbook (fill-in template)

```text
SERVICE / DATA STORE: ____________________
RUNBOOK OWNER:        ____________________   LAST REHEARSED: __________

PRECONDITIONS
- [ ] Isolated restore target provisioned (NOT production, separate credentials)
- [ ] Backup source identified: repo / bucket = __________________
- [ ] Decryption key available from: __________ (must NOT be the lost system)
- [ ] Target recovery time / point: __________________

STEPS
1. Provision the isolated target ............... cmd: ______________
2. Pull the base/full backup ................... cmd: ______________
3. Replay change log to target time (PITR) ..... cmd: ______________
4. Bring the store up in isolation ............. cmd: ______________
5. VALIDATE (do not skip):
   - row counts vs. expected ................... query: ___________
   - latest known-good record present ......... query: ___________
   - app smoke test against restored data ..... ______________
6. Cut over (only if this is a real recovery) .. ______________

SIGN-OFF
- Restore succeeded: Y / N
- Data validated correct (not just present): Y / N
- Actual recovery time: __________  (start ____ → serving ____)
- Issues / follow-ups: ______________________________
```

## Scheduled restore-test checklist

Run on the cadence from SKILL.md §6. Tick every box or the test does not count.

```text
[ ] Restore ran in an ISOLATED environment (no prod credentials, no shared bucket write access)
[ ] Restored to a specific point in time (not just "latest"), to exercise PITR
[ ] Ran integrity verify first (restic/borg check, pgbackrest verify)
[ ] Ran a validation query proving data is CORRECT, not merely present
[ ] Recorded the ACTUAL recovery time (see log below)
[ ] Compared actual time against the stated RTO; flagged if RTO is now fiction
[ ] Logged any step that was slower/harder than the runbook claims; updated the runbook
[ ] Torn down the isolated target afterwards (cost + stale-data hygiene)
```

Cadence reminder:
- Monthly: file/single-object/single-table restore.
- Quarterly: full application recovery (app stands up against restored data).
- Annually: full-environment failover in an isolated account/region.

## Actual-RTO log

Keep this table in the repo. The RTO you publish should be the worst recent *measured* number, not an estimate.

| Date | Test type | Target point | Restored OK? | Validated correct? | Actual RTO | Notes |
|------|-----------|--------------|--------------|--------------------|------------|-------|
| 2026-06-01 | file | latest-1d | Y | Y | 00:12 | clean |
| 2026-06-30 | app recovery | 2026-06-30 02:00 | Y | Y | 00:48 | DNS step slow |
| 2026-09-30 | full failover | 2026-09-29 23:00 | Y | Y | 03:41 | RTO target was 2h — fix |

If a row says "Restored OK? N" or "Validated correct? N", that is an incident, not a footnote. Treat it like a production outage you got to schedule.
