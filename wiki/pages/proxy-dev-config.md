---
title: Proxy dev config
type: howto
sources: [S043, S044, S045]
updated: 2026-09-26
---

The dev config is `litellm/proxy/dev_config.yaml`: a real, runnable YAML with model entries for Anthropic, Bedrock, Vertex, Azure AI Foundry, OpenAI, and one Voyage embedder (S044). Every key is read from `.env` via `os.environ/...` (the OS-environ adapter), so no secrets live in the file (S044).

## Minimal start

```bash
python litellm/proxy/proxy_cli.py \
  --config litellm/proxy/dev_config.yaml \
  --detailed_debug --reload --use_v2_migration_resolver \
  2>&1 | tee litellm.log
```

What each flag does (S043):

- `--config` / `-c` — path to the proxy YAML (`proxy_cli.py`: "Path proxy configuration file (e.g. config.yaml). Usage `litellm --config config.yaml`").
- `--detailed_debug` — turn on detailed debug logs; envvar `DETAILED_DEBUG`.
- `--reload` — uvicorn hot reload, dev only; also reloads when the `--config` YAML changes ("Incompatible with --num_workers>1, --run_gunicorn, and --run_hypercorn").
- `--use_v2_migration_resolver` — "Deprecated and ignored: the v2 migration resolver is now the default, so this flag has no effect." Keep it on the command so older docs/scripts still parse (S043). To opt back into v1 use `--use_legacy_migration_resolver` or `USE_V2_MIGRATION_RESOLVER=false`.

Run the Admin UI separately with `npm run dev` in `ui/litellm-dashboard` (port 3000).

## What dev_config.yaml looks like

Anthropic native block (S044):

```yaml
model_list:
  - model_name: anthropic-sonnet-4-6
    litellm_params:
      model: anthropic/claude-sonnet-4-6
      api_key: os.environ/ANTHROPIC_API_KEY
```

Bedrock converse, Vertex, and Azure AI Foundry blocks follow the same shape with `aws_region_name: us-east-1` / `vertex_project: ...` / `api_base: os.environ/AZURE_AI_API_BASE`. Master key and feature flags live under `general_settings: master_key: os.environ/LITELLM_MASTER_KEY` (S044).

## Example config templates

`litellm/proxy/example_config_yaml/` holds short, single-purpose YAML templates (S045). Names map to a use case:

- `simple_config.yaml` — minimal `model_list` with one model.
- `load_balancer.yaml` — three `gpt-3.5-turbo` entries with `tpm` / `rpm`, plus an `openrouter/...` fallback, demonstrating the router's same-`model_name` load balancing.
- `multi_instance_simple_config.yaml` — one model + `general_settings.coordination_redis` (host / port / password from env) for running more than one proxy against the same DB so they coordinate spend/rate budgets.
- `azure_config.yaml` — Azure OpenAI with per-deployment `tpm`, `timeout`, `stream_timeout`, `max_retries`.
- `langfuse_config.yaml` / `opentelemetry_config.yaml` — callback wiring (`litellm_settings.success_callback: ["langfuse"]`; `general_settings.otel: true`).
- `pass_through_config.yaml` — `general_settings.pass_through_endpoints` plus a custom auth import from a sibling `.py`.
- `aliases_config.yaml` — same API name (`gpt-4`, `gpt-3.5-turbo`) routed to ollama models; the model-name aliasing behaviour used in the router.
- `spend_tracking_config.yaml` — combined with `multi_instance_simple_config.yaml`'s coordination Redis to test spend accounting across instances.
- `disable_schema_update.yaml`, `tool_permission_example.yaml`, `adaptive_router_example.yaml`, `enterprise_config.yaml`, `store_model_db_config.yaml`, `websearch_interception_config.yaml`, `code_interpreter_interception_config.yaml`, `agentcore_websearch_config.yaml`, `bing_grounding_websearch_config.yaml`, `oai_misc_config.yaml`, `reject_clientside_metadata_tags_config.yaml`, `otel_test_config.yaml`, `_health_check_test_config.yaml` — more targeted scenarios.

Custom callback, auth, and guardrail hooks live as importable `.py` files alongside the YAMLs (`custom_callbacks.py`, `custom_callbacks1.py`, `custom_auth.py`, `custom_auth_basic.py`, `custom_guardrail.py`, `custom_handler.py`, `custom_team_metadata_validate.py`, `pipeline_test_guardrails.py`, `team_metadata_validator_e2e.py`).

## Verifying

`curl -s http://localhost:4000/health/liveliness` then run a chat completion against `http://localhost:4000/v1/chat/completions`. Logs land in `litellm.log` via `tee`. This is the proof-of-fix loop — `pytest` is not (see [Repo dev loop](./dev-loop.md)).

Related: [Proxy server](./proxy-server.md), [Repo dev loop](./dev-loop.md), [Router strategies](./router-strategies.md), [Test conventions](./test-conventions.md).
