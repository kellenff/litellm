---
title: Prisma migration rule
type: decision
sources: [S020, S007]
updated: 2026-09-26
---

Prisma migrations in this repo apply **synchronously at proxy boot, before the process serves traffic** (S007). A migration must therefore only change schema, never rewrite rows: no `UPDATE`, no `DELETE`, no `MERGE`, and no `INSERT ... SELECT` (S007). On a spend-log-sized table, any of those is minutes of unavailability plus a doubled heap that plain autovacuum will not give back (S007).

The mechanical enforcer is `tests/code_coverage_tests/check_migrations_no_data_rewrites.py` (S020). It scans every `migration.sql` under `litellm-proxy-extras/litellm_proxy_extras/migrations/` and reports a violation for any statement whose leading keyword rewrites existing rows (S020). It also flags one schema change outright: `ALTER TABLE ... ADD COLUMN ... DEFAULT` on a request-log table (`LiteLLM_SpendLogs` or `LiteLLM_ErrorLogs`), which on Postgres 10 rewrites the whole heap under an `ACCESS EXCLUSIVE` lock; on Postgres 11 the same construct is metadata-only and passes (S020). Every other table is small enough that the rule does not reach it (S020).

## What is banned, by leading keyword (S020)

- `UPDATE` — rewrites every matching row, and `WHERE` does not bound the scan.
- `DELETE` — same scan, and the dead tuples outlive the migration.
- `MERGE` — both of the above in one statement.
- `INSERT` — only when its rows come from a query rather than a literal `VALUES` list. A `TABLE t` row source counts as much as `SELECT`. `INSERT INTO "t" (SELECT ...)` and a `VALUES` joined to a query by `UNION`/`INTERSECT`/`EXCEPT` both copy rows. Scalar subqueries inside the `VALUES` list, and `RETURNING` / `ON CONFLICT` clauses after it, do not.
- `WITH` — any CTE-led statement whose body contains one of the above.
- `ALTER TABLE` on a request-log table when one of its actions adds a column with a `DEFAULT`.

The scanner reads inside `DO $$ ... $$` bodies (this repo's idiom for conditional DDL), inside single-quoted literals that `EXECUTE` or `DO` runs as SQL, and inside `CREATE FUNCTION`/`CREATE PROCEDURE` bodies that the same migration later calls; a routine defined and never invoked is left alone, since defining it only stores the body (S020). A `FOR ... LOOP` header is split off from its body so a row-by-row backfill cannot hide behind a shared semicolon (S020).

## The marker convention (S020)

When a rewrite is genuinely bounded and must ship inside the migration, mark the statement:

```sql
-- data-migration-ok: <what bounds it>
UPDATE ...
```

The reason after the colon is required. A marker on its own line exempts the statement below it; one sharing a line with code exempts only the statement it follows, never a second on the same line. A marker on `EXECUTE` or on the assignment feeding it covers the SQL the statement hands off, so it sits where the migration reads, not inside the string. A marker inside a dollar-quoted body must sit on the rewrite itself; a marker on a `DO` block would silence a rewrite added to that block later.

`GRANDFATHERED` in the check script freezes pre-existing violations. Prisma records a checksum for every applied migration and applied files are treated as immutable, so those files cannot take an inline marker. The set is closed; a new migration belongs nowhere in it.

The script exits non-zero when any non-grandfathered migration violates, prints `GUIDANCE`, and flags any name in `GRANDFATHERED` that no longer violates, so the closed set does not drift. It runs as part of `make check`.

Related: [Spend logging](./spend-logging.md), [Repo dev loop](./dev-loop.md), [PR target branch](./pr-target-branch.md), [Test conventions](./test-conventions.md).
