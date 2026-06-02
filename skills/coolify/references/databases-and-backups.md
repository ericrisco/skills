# Managed databases & backups — deep dive

Source facts: coolify.io/docs/databases/backups and database docs, accessed 2026-06-02.

Coolify provisions Postgres, MySQL, MariaDB, MongoDB, Redis (and more) in-product with generated
credentials. This skill provisions and backs up; SQL/schema/tuning is the `postgresdb` skill; backup
strategy/RPO/RTO doctrine across systems is the `backups` skill. Here we wire the concrete in-product job.

## Connection wiring

Each managed database gets an **internal Docker network hostname** (the service name Coolify assigns).
Connect apps to it over that private hostname — never a public IP.

```text
# GOOD — app env var points at the internal hostname on the private network:
DATABASE_URL=postgres://<user>:<password>@<internal-db-hostname>:5432/<db>

# Inject <password> as a Coolify secret, not a committed literal.
```

Do **not** enable the database's "public port" toggle unless an external client genuinely needs it. An
open 5432/3306/27017/6379 is scanned within minutes. If you must expose it, bind deliberately and firewall
to known source IPs at the cloud layer.

**Every database service needs a named volume.** Recreating a service with only an anonymous volume wipes
the data — the most common Coolify data-loss incident. Coolify's managed DBs set this up; verify it before
trusting the instance with real data.

## Scheduled backups

Coolify runs the engine's native dump on a cron expression, stores it locally, and optionally pushes to
S3-compatible storage.

| Engine | Dump command Coolify runs | Restore = |
| --- | --- | --- |
| PostgreSQL | `pg_dump` | download → decompress → `psql`/`pg_restore` replay |
| MySQL / MariaDB | `mysqldump` | download → decompress → `mysql <` replay |
| MongoDB | `mongodump` | download → `mongorestore` |

Configure per database:

1. **Enable scheduled backup** on the resource.
2. **Cron schedule** — e.g. `0 3 * * *` nightly 03:00; `0 */6 * * *` every 6h. Match to your tolerable
   data loss (RPO).
3. **Retention** — keep N copies/days so storage doesn't grow unbounded.
4. **Destination** — local only, or local + an S3-compatible target (below).

## S3-compatible destinations

Add these as Coolify storage destinations. Provide endpoint + region + bucket + access key/secret — always
as Coolify secrets, never in a committed file.

| Provider | Endpoint shape | Notes |
| --- | --- | --- |
| AWS S3 | `s3.<region>.amazonaws.com` | Standard region + bucket |
| Cloudflare R2 | `https://<accountid>.r2.cloudflarestorage.com` | Region usually `auto`; zero egress fees |
| Backblaze B2 | `https://s3.<region>.backblazeb2.com` | S3-compatible endpoint, cheap storage |
| MinIO (self-hosted) | `https://minio.example.com` | Your own object store; force path-style if needed |
| Wasabi | `https://s3.<region>.wasabisys.com` | Flat-rate storage |

Off-box storage is the entire point: a dump sitting on the same disk as the database dies with the disk.

## The restore runbook — run it before you need it

A backup you have never restored is a guess. Do this once now, and on a recurring drill.

```bash
# 1. Pull the latest dump from the destination (UI download, or via the S3 client).
#    e.g. from R2/B2/MinIO/S3 with the AWS CLI pointed at the endpoint:
aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://$BUCKET/<path>/dump.sql.gz" ./dump.sql.gz

# 2. Decompress.
gunzip dump.sql.gz

# 3. Replay into a THROWAWAY database (never the live one during a drill).
#    Postgres:
psql "postgres://user:pass@host:5432/restore_test" < dump.sql
#    MySQL/MariaDB:
mysql -h host -u user -p restore_test < dump.sql
#    MongoDB (from a mongodump archive/dir):
mongorestore --uri "mongodb://user:pass@host:27017/restore_test" ./dump

# 4. VERIFY: compare row counts / key tables against production expectations.
#    e.g. Postgres:
psql "postgres://.../restore_test" -c "SELECT count(*) FROM orders;"

# 5. Drop the throwaway DB. Record the drill date in 02-DOCS/wiki/stack/coolify.md.
```

## Consistency caveats

- These dumps are **logical, point-in-time snapshots at dump start**, not continuous PITR. Between dumps,
  writes are unprotected — size the cron to your RPO.
- For true point-in-time recovery (WAL archiving / continuous replication) you need engine-level setup
  beyond Coolify's scheduled dump — that is `postgresdb` / `backups` territory.
- For a large/active database, a logical dump can take time and add load; schedule it off-peak and watch
  that the dump window doesn't overlap the next one.
- Test restores against the **same major engine version**; cross-version replays can fail or silently
  change behavior.
