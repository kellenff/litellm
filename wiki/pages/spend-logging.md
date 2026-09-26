---
title: Spend logging
type: component
sources: [S050, S051, S052, S053, S054, S055, S056, S050, S058, S055]
updated: 2026-09-26
---

The proxy writes one row per request to the `LiteLLM_SpendLogs` Prisma table, plus a parallel `LiteLLM_ErrorLogs` table for failures. Rows power `/spend/logs`, `/spend/logs/v2`, `/spend/logs/ui`, team/user/key/team report endpoints, and the dashboard (S055, S055).

## What gets logged

The canonical row shape lives in two places that must agree: the Prisma model `LiteLLM_SpendLogs` in `litellm/proxy/schema.prisma` (S051) and the Pydantic mirror `LiteLLM_SpendLogs` re-exported from `litellm/models/spend_logs.py` (S052). Fields cover identity (`request_id`, `api_key` hash, `user`, `team_id`, `organization_id`, `end_user`, `session_id`, `requester_ip_address`), model (`model`, `model_id`, `model_group`, `custom_llm_provider`, `api_base`), cost and tokens (`spend`, `total_tokens`, `prompt_tokens`, `completion_tokens`, `response_cost`, `cost_breakdown`, `saved_cache_cost`, `autorouter_savings`), timing (`startTime`, `endTime`, `completionStartTime`, `request_duration_ms`), lifecycle (`status`, `status_fields.llm_api_status`, `status_fields.guardrail_status`, `cache_hit`, `cache_key`), and payload (`messages`, `response`, `metadata`, `request_tags`, `mcp_namespaced_tool_name`) (S051, S058). Error rows mirror that shape in `LiteLLM_ErrorLogs` with `exception_type`, `status_code`, `exception_string` (S052).

The dict that becomes a row is built by `get_standard_logging_object_payload()` in `litellm/litellm_core_utils/litellm_logging.py`, which assembles the `StandardLoggingPayload` TypedDict from the `Logging` object's hidden params, response usage, pricing lookup, and metadata (S050, S058). Cost figures come from `model_prices_and_context_window.json` via the cost calculator (S050); see [Pricing source of truth](./pricing-source-of-truth.md).

## Where it lands

`SpendLogsRepository` in `litellm/repositories/table_repositories.py` is the typed Prisma gateway for the table; `DBSpendUpdateWriter._record_spend_log` calls `_insert_spend_log_to_db` (and `_claim_batch_cost_spend_log` for Batch API retrieves) to upsert the row (S053, S054). The proxy entry point `ProxyUpdateSpend` in `litellm/proxy/utils.py` is what completion handlers route through (S056).

## Request lifecycle

`Logging` is constructed at the start of every completion with `start_time`, `litellm_trace_id`, `litellm_call_id`, and `model_call_details` (S050). On success, `Logging` iterates configured success callbacks via `log_success_event` / `async_log_success_event`; on failure it iterates `async_log_failure_event` (S050). The async path is what enqueues the `SpendLogsPayload` into the batched writer, where `update_spend_logs_job` drains the queue and `enqueue_spend_logs` / `dequeue_spend_logs` handle backpressure and poison-row isolation (S055). Rows are flushed after post-call guardrails if `_defer_async_logging` is set, so guardrail blocks never miss their spend record (S050).

## Retention hooks

Six knobs in `litellm/proxy/_types.py` govern the lifecycle (S055): `store_prompts_in_spend_logs` toggles `messages`/`response` capture; `maximum_spend_logs_retention_period` (e.g. `7d`) sets the cleanup horizon; `use_spend_logs_partitioning` switches the cleanup job from row-by-row DELETE to partition DROP via `db_scripts/partition_spend_logs.sql`; `maximum_spend_logs_cleanup_batch_size`, `maximum_spend_logs_cleanup_max_batches`, and `maximum_spend_logs_cleanup_run_budget` bound each run; and `maximum_spend_logs_cleanup_batch_timeout` sets Postgres `statement_timeout` / `lock_timeout` per DELETE. Per-row tagging goes through the `spend_logs_metadata` JSON key parsed by `litellm/proxy/common_utils/http_parsing_utils.py`.

## Why row rewrites at migration time are forbidden

`LiteLLM_SpendLogs` is the highest-volume table the proxy owns: every chat, embed, batch retrieve, and rerank writes a row. Migrations run synchronously at proxy boot before traffic is served, so any `UPDATE`, `DELETE`, `MERGE`, or `INSERT ... SELECT` against it stalls boot for minutes while Postgres rewrites the heap, then leaves dead tuples the next autovacuum can only reclaim slowly (S051, S055). `ALTER TABLE ... ADD COLUMN ... DEFAULT` is also flagged on this table on Postgres 10 for the same reason; on Postgres 11+ it is metadata-only and exempt (see [Prisma migration rule](./prisma-migration-rule.md)). The rule is enforced by `tests/code_coverage_tests/check_migrations_no_data_rewrites.py` and inherited by the boot path documented in [Proxy server](./proxy-server.md).