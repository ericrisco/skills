# Engine recipes

Copy-paste starting points per data store. Adapt paths, regions, and retention to your RPO/RTO. Each block ends with the one gotcha that bites in production.

## Self-hosted PostgreSQL — pgBackRest

Current standard: full weekly + differential daily, zstd compression, parallel by disk count, async archiving.

```ini
# /etc/pgbackrest/pgbackrest.conf
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=4
repo1-type=s3
repo1-s3-bucket=my-pgbackrest-backups
repo1-s3-region=eu-west-1
compress-type=zst
process-max=4          # tune to DISK count, not CPU — backup is I/O-bound
archive-async=y        # avoids the WAL storm under write load

[main]
pg1-path=/var/lib/postgresql/18/main
```

```bash
pgbackrest --stanza=main stanza-create
pgbackrest --stanza=main --type=full backup       # weekly
pgbackrest --stanza=main --type=diff backup        # daily
pgbackrest --stanza=main check                     # archive + backup reachable
pgbackrest --stanza=main verify                    # re-checksum the repo (the "0")
```

PITR restore to a target time (restore into an ISOLATED target, never over prod):

```bash
pgbackrest --stanza=main --type=time \
  --target="2026-06-02 13:59:00+00" \
  --target-action=promote restore
```

Gotcha: `repo1-retention-full` controls how much WAL is kept. Expire it too aggressively and the chain to your target time is gone — PITR silently fails. Keep WAL at least as long as the oldest full you might restore.

WAL-G is the cloud-native alternative (env-driven, smaller footprint):

```bash
export WALG_S3_PREFIX=s3://my-bucket/wal-g
export AWS_REGION=eu-west-1
wal-g backup-push /var/lib/postgresql/18/main
wal-g backup-fetch /var/lib/postgresql/18/restore LATEST
# then recovery_target_time in postgresql.conf + restore_command = 'wal-g wal-fetch %f %p'
```

## Amazon RDS — PITR via AWS CLI

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier prod-db \
  --target-db-instance-identifier prod-db-restore-test \
  --restore-time 2026-06-02T13:59:00Z \
  --db-subnet-group-name isolated-restore-subnet
```

Gotcha: this restores into the **same region**. AWS Backup can *copy* a backup cross-region but does **not** support a PITR restore in another region. Retention ceiling is 35 days; for longer, export a manual snapshot.

## MySQL / MariaDB — XtraBackup + binlog

```bash
# Physical hot backup
xtrabackup --backup --target-dir=/backup/base --user=backup --password=...
xtrabackup --prepare --target-dir=/backup/base

# PITR = restore base, then replay binlog to a stop point
mysqlbinlog --stop-datetime="2026-06-02 13:59:00" \
  /var/lib/mysql/binlog.000042 | mysql -u root -p
```

Gotcha: `mysqldump` alone gives no PITR. If you must use it, add `--single-transaction --source-data=2` and ship binlogs separately, or you can only restore to the dump instant. (`--master-data` is the deprecated alias — replaced by `--source-data` since 8.0.26.)

## Redis — RDB + AOF

```conf
# redis.conf — only if Redis is a system of record, not just a cache
save 900 1
appendonly yes
appendfsync everysec   # ~1s RPO; 'always' is durable but slow
```

Gotcha: if Redis is purely a cache, backing it up is usually wasted effort — rebuild from the source of truth instead. Decide which Redis you have first.

## Files / app data — restic to an Object-Lock bucket

```bash
export RESTIC_REPOSITORY=s3:s3.amazonaws.com/my-immutable-backups/app
export RESTIC_PASSWORD_FILE=/etc/restic/pass   # key lives OUTSIDE this bucket
restic init
restic backup /srv/app/data --exclude-file=/etc/restic/excludes
restic check --read-data-subset=10%            # integrity verify
restic restore latest --target /restore/test   # into isolated path
```

Borg equivalent (smaller repos, one exclusive lock per repo):

```bash
borg init --encryption=repokey-blake2 /backup/repo
borg create /backup/repo::'{hostname}-{now}' /srv/app/data
borg check /backup/repo
borg extract /backup/repo::archive-name        # restore
```

Gotcha: both encrypt with AES-256, but the key/password must live in a *different* blast radius than the data. An encrypted backup whose key died with the source is unrecoverable.

## S3 Object Lock (the immutability layer)

```bash
aws s3api create-bucket --bucket my-immutable-backups --object-lock-enabled-for-bucket \
  --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1
aws s3api put-object-lock-configuration --bucket my-immutable-backups \
  --object-lock-configuration '{"ObjectLockEnabled":"ENABLED","Rule":{"DefaultRetention":{"Mode":"COMPLIANCE","Days":90}}}'
```

`COMPLIANCE` mode cannot be shortened or bypassed even by root — that is the point. Use a separate IAM principal for writing backups vs. one (rarely used) for lifecycle administration.
