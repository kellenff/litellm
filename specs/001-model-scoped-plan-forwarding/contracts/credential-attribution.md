# Contract: Credential attribution on the request record

**Feature**: `specs/001-model-scoped-plan-forwarding`
**Date**: 2026-10-28

## What the operator needs to read

For any request, the operator can tell from the request's own record which credential served it, and can tell whether the request was plan-covered

## The record

The request metadata carries a boolean flag, `used_client_subscription_credential`

| Value | Meaning |
|-------|---------|
| `true` | The caller's forwarded ChatGPT credential served the request. The request is plan-covered |
| `false` | The target's own configured credential served the request |
| absent | The request never reached the router, so no routing decision was made about its credential |

A plan-covered request reports no spend, because every `chatgpt/` row in `litellm/model_prices_and_context_window_backup.json` carries no rates, 20 rows in total. The flag is what makes such a request identifiable. Pricing subscription models is separate work and is out of scope

## Why this is a new field rather than the existing `used_client_oauth_token`

The existing flag looks like it fits, but it carries a different fact and cannot be reused

`used_client_oauth_token` answers "was the client's Anthropic OAuth bearer forwarded to an Anthropic deployment". The gate that enforces it is `resolve_used_client_oauth_token` at `litellm/llms/anthropic/common_utils.py:336`

```python
def resolve_used_client_oauth_token(client_sent_oauth_token: object, custom_llm_provider: str | None) -> bool | None:
    if not isinstance(client_sent_oauth_token, bool):
        return None
    return client_sent_oauth_token and custom_llm_provider in ANTHROPIC_OAUTH_FORWARD_PROVIDERS
```

and `ANTHROPIC_OAUTH_FORWARD_PROVIDERS` at `litellm/llms/anthropic/common_utils.py:333` is `frozenset((LlmProviders.ANTHROPIC.value,))`. A probe confirmed what that gate does to a chatgpt request

```
  stamped=True  provider=chatgpt    -> False
  stamped=False provider=chatgpt    -> False
```

Both values collapse to `False`, so "the caller's bearer served it" and "the target's own credential served it" become indistinguishable for exactly the provider this feature is about

Widening `ANTHROPIC_OAUTH_FORWARD_PROVIDERS` to include chatgpt is not available either, because the same constant decides which providers the Anthropic OAuth credential headers are scoped to at `litellm/proxy/litellm_pre_call_utils.py:4341`. Widening it would forward Anthropic OAuth headers to chatgpt deployments, and it would break the pinned case at `tests/unit/proxy/spend_tracking/test_spend_tracking_utils.py:4116`, where a request the router sent to Bedrock or Vertex paid with the configured key and must not read true

So the two facts get two fields. The existing flag keeps its existing meaning and its existing behavior, unchanged

## Who writes it

The router writes it, once per routing attempt

The router knows, for the attempt it is about to make, whether the attempt is in scope. An in-scope attempt forwards the caller's bearer, so the attempt served the request under the caller's credential and the value is `true`. An out-of-scope attempt has the bearer stripped, so the target authenticates with its own credential and the value is `false`

The router writes the value onto the request metadata for that attempt, in the bucket named by `get_router_metadata_variable_name`, and in the other of the two metadata bucket names as well. Both are written because the spend-log reader prefers `litellm_metadata` while the router's own bucket for chat completions is `metadata`. `litellm/router_utils/fallback_event_handlers.py:302` already writes to both bucket names, with `_ROUTER_METADATA_BUCKETS`

Because the write happens on every attempt and each attempt owns its own request kwargs, the value on the request is the one belonging to the attempt that served it. A fallback to an out-of-scope target leaves `false` on the request, and a fallback to an in-scope target leaves `true`

## Where it is read

The flag reaches the spend log through the request metadata, with no new column

`litellm/main.py:5535` reads `metadata = kwargs.get("metadata", None)` and `litellm/main.py:5956` passes that same object into `get_litellm_params`, which at `litellm/litellm_core_utils/get_litellm_params.py:237` stores it as `litellm_params["metadata"]` without copying it. A probe confirmed the identity

```
=== identity ===
  litellm_params['metadata'] is the metadata object: True
```

The spend log reads the metadata bucket, so the router's value arrives with the request and no new spend-log column is needed

The flag is a boolean and never carries a credential value

## What the operator sees

| Situation | `used_client_subscription_credential` |
|-----------|------------------------------|
| A request resolved to an in-scope `chatgpt` target | `true`, and the request reports no spend |
| A request resolved to an out-of-scope `chatgpt` target | `false`, and the request reports whatever the target's own credential costs |
| A request that fell back from an in-scope target to an out-of-scope one | `false`, because the attempt that served it used the target's own credential |
| A request that fell back from an out-of-scope target to an in-scope one | `true`, because the attempt that served it forwarded the caller's bearer |
| A request the proxy answered without routing | absent, because no routing decision was made |

The last two rows are the point of the feature. The flag reflects the attempt that served the request, not the first attempt

## What this contract does not define

- A change to `used_client_oauth_token`. It keeps its current meaning, its current provider gate, and its current behavior on the Anthropic path
- A per-token price for subscription models. That is separate work, blocked on the cost map carrying rates
- A plan-ineligibility classification. The proxy does not classify a plan rejection apart from any other 400, by the operator's explicit decision
- A separate field naming the credential class. The operator needs a boolean distinction between the caller's bearer and the target's own credential, and a free-form string is not filterable the way a boolean is
