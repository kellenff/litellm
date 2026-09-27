---
title: Proxy server
type: component
sources: [S042, S043]
updated: 2026-09-26
---

The proxy is a FastAPI app defined in `litellm/proxy/proxy_server.py`. Boot is driven by the CLI in `litellm/proxy/proxy_cli.py`, which imports `app`, `KeyManagementSettings`, `ProxyConfig`, and `save_worker_config` from `proxy_server` and hands them to uvicorn (S043). Everything below happens before the first `/v1/...` request is served.

## Boot order

1. **CLI parses flags**, including `--config`, `--detailed_debug`, `--reload`, `--use_v2_migration_resolver` (now a no-op; the v2 resolver is default), `--use_legacy_migration_resolver`, and `--enforce_prisma_migration_check` (S043).
2. **CLI imports `app`** from `proxy_server` so `proxy_startup_event` is registered as the FastAPI lifespan (S043).
3. **`app = FastAPI(...)`** is constructed at import time with `lifespan=proxy_startup_event`. V2 OTEL middleware must be attached at construction (`instrument_fastapi_app(app)`); once the lifespan runs, the middleware stack is frozen and the call raises (S042).
4. **Lifespan `proxy_startup_event`** runs in this order (S042):
   - `init_verbose_loggers()`
   - Optional worker startup hooks from `LITELLM_WORKER_STARTUP_HOOKS` (`module:fn` CSV)
   - License check via `_license_check.is_premium()`
   - `master_key = get_secret_str("LITELLM_MASTER_KEY")`
   - **Config load**: `CONFIG_FILE_PATH` → `proxy_config.load_config(...)`; else `WORKER_CONFIG` → file or dict via `initialize_from_worker_config`
   - `master_key_boot_verdict(...)` — runs after config so it can read `user_config_file_path` and `general_settings`
   - **Prisma client setup**: `ProxyStartupEvent._setup_prisma_client(...)` only if `prisma_client is None` and `DATABASE_URL` is set
   - **Migrations (sync, blocks startup)**: `await migrate_if_requested(...)` — see next section
   - Background migrations after Prisma is up: password → scrypt, legacy agent grant id rewrite
   - Coordination Redis from DB overlay applied before consumers see it
5. **uvicorn listens** on the chosen host/port.

## Prisma-sync-at-boot rule

`migrate_if_requested` runs synchronously at startup, before the lifespan yields to serve traffic (S042). Three CLI knobs control it (S043):

- `--use_prisma_db_push` uses `prisma db push` instead of `prisma migrate deploy`. Off by default.
- `--enforce_prisma_migration_check` makes a migration failure exit non-zero instead of warning. Off by default.
- `--use_legacy_migration_resolver` opts back into the v1 resolver. Off by default; v2 is the only safe choice under rolling deploys because it skips the diff-and-force recovery path that thrashes schema when two LiteLLM versions contend for the same DB.

The rule that matters here: proxy boot applies pending schema changes inline, so a migration on this startup path must only change schema, never rewrite rows; rewriting `spend_log`-sized tables would block boot for minutes (see [Prisma migration rule](./prisma-migration-rule.md)). `use_prisma_db_push` shares the same caveat.

## Globals and shared state

Module-level globals the lifespan mutates: `prisma_client`, `master_key`, `llm_router`, `llm_model_list`, `general_settings`, `use_background_health_checks`, `shared_aiohttp_session`, `store_model_in_db`, `db_writer_client`, `_license_check`, `premium_user`, `proxy_budget_rescheduler_*_time` (S042). Spend counters live in `spend_counter_cache` (a `DualCache`) and the `redis_usage_cache` written from `proxy_startup_event` after the coordination overlay lands (S042). Custom auth and callback slots (`user_custom_auth`, `user_custom_key_generate`, etc.) are placeholders filled by config-driven Python imports during boot.

## dev_config.yaml

`litellm/proxy/dev_config.yaml` is the runnable config used for the documented dev loop (see [Proxy dev config](./proxy-dev-config.md) and [Repo dev loop](./dev-loop.md)). It is not an example; it is the canonical "real models in `.env`" config for local PR verification (S044).

Related: [Prisma migration rule](./prisma-migration-rule.md), [Spend logging](./spend-logging.md), [Proxy dev config](./proxy-dev-config.md), [Router strategies](./router-strategies.md).
