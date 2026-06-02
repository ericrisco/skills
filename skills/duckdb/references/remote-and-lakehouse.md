# DuckDB — remote data & lakehouse

Offloaded from the SKILL body. DuckDB v1.5.2 / LTS 1.4.x.

## httpfs: read from S3 / GCS / Azure / HTTP in place

```sql
INSTALL httpfs;        -- one-time per database/install
LOAD httpfs;           -- per session
SELECT count(*) FROM read_parquet('https://host/path/data.parquet');  -- plain HTTP works immediately
```

`httpfs` streams remote files with HTTP range requests, so Parquet row-group and column pushdown still
apply — you fetch only the bytes you read, not the whole object.

## CREATE SECRET — credentials done right

Never inline keys into SQL. Use a secret; prefer the credential chain so creds come from the environment
or an instance/role rather than being typed.

```sql
-- Pick up env vars / instance role / SSO automatically (recommended):
CREATE SECRET s3 (TYPE s3, PROVIDER credential_chain);

-- Explicit, when you must (e.g. a non-default region / endpoint):
CREATE SECRET s3 (
    TYPE s3,
    KEY_ID '...', SECRET '...',
    REGION 'eu-west-1'
);

-- GCS (S3-compatible) and Azure have their own TYPEs:
CREATE SECRET gcs (TYPE gcs, KEY_ID '...', SECRET '...');
CREATE SECRET az  (TYPE azure, CONNECTION_STRING '...');
```

```sql
SELECT region, sum(amount) AS rev
FROM read_parquet('s3://bkt/sales/year=*/month=*/*.parquet', filename = true)
GROUP BY ALL;
```

## Hive-partitioned globs

A glob over `key=value/` directories auto-derives partition columns; filter on them and DuckDB prunes
whole directories before reading any data.

```sql
SELECT *
FROM read_parquet('s3://bkt/events/year=*/month=*/*.parquet', hive_partitioning = true)
WHERE year = 2025 AND month = 4;     -- only the matching partition dirs are scanned
```

## Iceberg

```sql
INSTALL iceberg; LOAD iceberg;
SELECT * FROM iceberg_scan('s3://bkt/warehouse/db/table');   -- read a table snapshot
```

## Delta Lake

```sql
INSTALL delta; LOAD delta;
SELECT * FROM delta_scan('s3://bkt/delta/events');
```

## DuckLake — DuckDB's own lakehouse catalog

DuckLake (ducklake.select) stores table metadata in a SQL catalog with Parquet data files — DuckDB's
native lakehouse format. Attach it and query like a normal schema.

```sql
INSTALL ducklake; LOAD ducklake;
ATTACH 'ducklake:metadata.ducklake' AS lake (DATA_PATH 's3://bkt/lake/');
USE lake;
CREATE TABLE sales AS FROM read_parquet('s3://bkt/raw/*.parquet');
```

## Partitioned write (handoff)

```sql
COPY (SELECT * FROM 'raw/*.parquet')
  TO 's3://bkt/curated/' (FORMAT parquet, PARTITION_BY (year, month), OVERWRITE_OR_IGNORE);
```

Writes a hive-partitioned dataset so any reader (DuckDB, Spark, ClickHouse, pandas) can prune partitions.

## MotherDuck — scale-out / share escape hatch

MotherDuck is managed DuckDB-as-a-service with hybrid local+cloud execution. Reach for it to share a
database or push heavy work to the cloud without running a server yourself — not the default.

```sql
ATTACH 'md:';                       -- connect to your MotherDuck account (auth via token)
USE my_cloud_db;
SELECT * FROM cloud_table LIMIT 10; -- query can run partly local, partly in the cloud
```

When the real need is many concurrent users or always-on production serving, that is
`clickhouse-analytics`, not MotherDuck.
