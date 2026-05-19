---
description: Rules for data work — migrations, ETL pipelines, schema evolution.
globs: ["migrations/**", "db/migrate/**", "schema/**", "etl/**", "pipelines/**", "**/*.migration.*", "**/migration_*", "dbt/**", "**/*.sql"]
---

# Data / migration code rules

## Migrations

- **Migrations are forward-only by default.** Down-migrations are nice but rarely run in production. Write the up carefully.
- **Schema changes are zero-downtime.** Use the expand-contract pattern: add new column, dual-write, backfill, switch reads, remove old. Never break the current code path.
- **No data in schema migrations, no schema in data migrations.** Mixing them makes them hard to roll back and hard to test.
- **Test migrations on a copy of production data, not toy data.** Toy data doesn't have your real edge cases.
- **Long-running migrations are batched.** Don't `UPDATE 50M rows` in one transaction — chunk it, with sleep between batches, monitored.
- **Index creation is `CREATE INDEX CONCURRENTLY`** (Postgres) or equivalent. Locking an index build on a hot table = outage.

## Schema design

- **Foreign keys exist and are enforced** in production. Eventually-consistent FKs are an anti-pattern for OLTP.
- **Soft-delete sparingly.** Tombstone rows accumulate. Prefer real deletes + audit log when you can.
- **`created_at`/`updated_at` on every table.** Boring, universal, saves you in every incident.
- **Money is integer cents (or `NUMERIC`, never `FLOAT`).** Float math will lose you a penny eventually.
- **Timestamps are UTC.** Always. Timezone conversion happens at display time, not in the DB.

## ETL / pipelines

- **Idempotent transforms.** Re-running a pipeline with the same input produces the same output. Track watermarks; don't drop or duplicate.
- **Schema contracts between stages.** Each stage validates its input schema. A breaking change upstream fails fast, not 4 stages later.
- **Lineage is captured.** "Where did this row come from?" should be answerable from logs/metadata.
- **PII handling is explicit.** Mark which columns are PII. Mask in logs, restrict at the SQL/role level.
- **Backfills are scripted and rerunnable.** Manual SQL paste during incident = dangerous. Have the backfill checked in before you need it.

## Don't

- Don't `DROP TABLE` or `TRUNCATE` in production without a verified backup AND a written rollback plan.
- Don't pre-compute aggregates without a way to recompute from source — bug in the aggregate = poisoned data with no recovery.
- Don't trust the application to enforce DB constraints. The application restarts; the DB doesn't.
- Don't write migrations that depend on the application code being deployed. They run before deploys, sometimes.
