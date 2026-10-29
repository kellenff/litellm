---
title: Credential attribution on spend logs
type: component
sources: [S069, S070, S071]
updated: 2026-10-28
---

The `metadata` JSON on a spend-log row carries two boolean flags that answer two different questions about which credential served a request.

`used_client_oauth_token` marks that the request was served by the caller's own forwarded **Anthropic** credential rather than the deployment's configured credential (S069, S070). It is typed at `litellm/types/utils.py` and stored on the spend-log model at `litellm/proxy/_types.py`. `resolve_used_client_oauth_token` in `litellm/llms/anthropic/common_utils.py` gates it on `ANTHROPIC_OAUTH_FORWARD_PROVIDERS`, which is `frozenset({"anthropic"})`, so a request the router sent to Bedrock or Vertex paid with its own key and reads false. A row written before the flag existed leaves it null, so a null is not a negative (S069).

`used_client_subscription_credential` marks that the caller's forwarded **ChatGPT** credential served the request, making a plan-covered request identifiable in the log even though it reports no spend (S071). The router writes it per routing attempt, so the value on the request belongs to the attempt that served it.

## Why two fields rather than one

The Anthropic gate collapses both values to false for a `chatgpt` provider, so the existing flag cannot express the subscription distinction for the provider that needs it (S071). Widening `ANTHROPIC_OAUTH_FORWARD_PROVIDERS` was rejected because it also decides which providers the Anthropic OAuth credential headers are scoped to, so widening it would forward Anthropic headers to chatgpt deployments and break the pinned case where a request the router sent to Bedrock or Vertex must not read true.

The router's value reaches the spend log through the request metadata, with no new column. `litellm/main.py` reads `metadata = kwargs.get("metadata", None)` and passes that same object into `get_litellm_params`, which stores it as `litellm_params["metadata"]` without copying it (S071).

Related: [Spend logging](./spend-logging.md), [Model-scoped credential forwarding](./model-scoped-credential-forwarding.md), [Forwarded client credentials](./forwarded-client-credentials.md).
