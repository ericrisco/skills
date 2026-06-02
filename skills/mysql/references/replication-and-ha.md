# Replication and HA

MySQL 8.4 / MariaDB 11.8 replication mechanics: binlog formats, GTID, the topologies, lag diagnosis,
and failover. Backup *strategy* as a discipline lives in `backups`; this owns the binlog/PITR and
replication-setup mechanics.

## Binlog format — ROW, and why

| Format | What it logs | Verdict |
|---|---|---|
| `ROW` | The actual before/after row images | **The only safe default.** Deterministic; replicas apply exactly what happened. |
| `STATEMENT` | The literal SQL text | Non-deterministic statements (`NOW()`, `UUID()`, `LIMIT` without `ORDER BY`, triggers) replicate *differently* on the replica → silent data drift. |
| `MIXED` | STATEMENT, switching to ROW when it detects non-determinism | Better than STATEMENT but the detection is imperfect; prefer ROW outright. |

```ini
# my.cnf — the replication baseline.
[mysqld]
server_id              = 1            # unique per host in the topology
log_bin                = mysql-bin
binlog_format          = ROW
gtid_mode              = ON
enforce_gtid_consistency = ON
binlog_expire_logs_seconds = 604800   # 7 days of binlog retained for replicas/PITR
```

## GTID-based replication, end to end

A GTID (Global Transaction ID) tags every committed transaction with `source_uuid:sequence`. The
replica records which GTIDs it has applied, so with `SOURCE_AUTO_POSITION=1` it requests exactly the
transactions it's missing — no manual log-file/position bookkeeping, and each transaction applies
**at most once** (auto-skip on reconnect/failover).

**MySQL 8.4 adds tagged GTIDs**: an optional third, colon-separated component
(`source_uuid:tag:sequence`) that groups related transactions — useful to mark, filter, or
selectively skip a logical batch.

```sql
-- On the replica (8.4 syntax: CHANGE REPLICATION SOURCE TO, not the old CHANGE MASTER TO).
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='primary.db',
  SOURCE_USER='repl',
  SOURCE_PASSWORD='***',
  SOURCE_SSL=1,                 -- caching_sha2_password needs TLS
  SOURCE_AUTO_POSITION=1;       -- GTID auto-positioning
START REPLICA;
SHOW REPLICA STATUS\G
```

The replication user authenticates with `caching_sha2_password` by default, so the channel must use
`SOURCE_SSL=1` or the first-time auth fails.

## Topology chooser

| Topology | Durability on primary loss | Use when |
|---|---|---|
| **Async** (default) | Can lose the last un-replicated transactions | Read scaling, geo replicas, where small data-loss-on-failover is acceptable |
| **Semi-synchronous** | Primary waits for ≥1 replica to *receive* (not apply) each commit | You need "committed means at least one replica has it" without full consensus cost |
| **Group Replication / InnoDB Cluster** | Quorum-committed (Paxos-style); automatic failover | You need automatic failover and a single logical primary with managed membership |

InnoDB Cluster = Group Replication + MySQL Shell (`dba.createCluster()`) for orchestration + **MySQL
Router** as the connection front-end that routes writes to the primary and reads to replicas. Apps
connect to the Router's port (6446 read-write / 6447 read-only), never directly to a node, so a
failover is transparent to the application.

```ini
# Semi-sync (loadable component in 8.4): primary waits for one replica to ACK receipt.
[mysqld]
rpl_semi_sync_source_enabled  = 1
rpl_semi_sync_source_timeout  = 1000   # ms before falling back to async if no ACK
rpl_semi_sync_replica_enabled = 1
```

## Replica-lag diagnosis — read the field, don't eyeball

```sql
SHOW REPLICA STATUS\G
-- Read in this order:
--   Replica_IO_Running  / Replica_SQL_Running  → both must be 'Yes'
--   Last_IO_Error / Last_SQL_Error             → why it stopped
--   Seconds_Behind_Source                      → coarse; NULL means BROKEN, not "0 lag"
```

`Seconds_Behind_Source` is a blunt instrument (it's relative to the SQL thread's current event, and
goes NULL the moment a thread stops). For real, per-worker lag use performance_schema:

```sql
SELECT WORKER_ID,
       LAST_APPLIED_TRANSACTION,
       APPLYING_TRANSACTION,
       APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP
FROM performance_schema.replication_applier_status_by_worker;

-- End-to-end lag = now() - the original commit timestamp of the transaction being applied.
```

If lag is structural, enable multi-threaded apply (`replica_parallel_workers > 0`,
`replica_parallel_type = LOGICAL_CLOCK`) so the replica applies independent transactions in parallel.

## Failover

- **Async/semi-sync, manual**: pick the most-caught-up replica (highest applied GTID set), point the
  other replicas and the app at it, `RESET REPLICA ALL` on the new primary. GTID auto-positioning
  means surviving replicas resync from exactly where they were.
- **InnoDB Cluster**: failover is automatic — the group elects a new primary; MySQL Router redirects
  writes. Your job is to monitor `cluster.status()` and re-add the recovered node with
  `cluster.rejoinInstance()`.
- Always confirm the old primary is truly down (fenced) before promoting — a split brain where two
  nodes both accept writes is the worst outcome, far worse than a few seconds of downtime.

## Read-replica routing

Route reads to replicas but **never read your own just-written row from a lagging async replica** —
that's the read-after-write consistency trap. Either route a user's reads to the primary for a short
window after their write, or use `WAIT_FOR_EXECUTED_GTID_SET()` on the replica to block until it has
caught up to the GTID your write produced. InnoDB Cluster's Router can be configured for this.
