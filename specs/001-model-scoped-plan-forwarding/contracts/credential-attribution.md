# Contract: Credential attribution on the request record

**Feature**: `specs/001-model-scoped-plan-forwarding`
**Date**: 2026-10-28

## What the operator needs to read

For any request, the operator can tell from the request's own record which credential served it, and can tell whether the request was plan-covered

## The record

The request metadata carries `used_client_oauth_token`, an existing boolean flag typed at `litellm/types/utils.py:3374` and stored on spend logs at `litellm/proxy/_types.py:3770`

| Value | Meaning |
|-------|---------|
| `true` | The caller's forwarded ChatGPT credential served the request. The request is plan-covered |
| `false` | The target's own configured credential served the request |

A plan-covered request reports no spend, because every `chatgpt/` row in `litellm/model_prices_and_context_window_backup.json` carries no rates, 20 rows in total. The flag is what makes such a request identifiable. Pricing subscription models is separate work and is out of scope

## Who writes it

Two writers, in a fixed order

The router writes the per-attempt answer. When the router resolves a deployment for an attempt, it knows whether the attempt was in scope and therefore which credential served it. It writes that answer onto the request metadata for that attempt

The proxy's pre-routing stamp is the fallback. At `litellm/proxy/litellm_pre_call_utils.py:2658` the proxy already stamps the flag from the inbound request, before routing:

```python
data[_metadata_variable_name]["used_client_oauth_token"] = add_provider_specific_headers_to_request(
    data=data, headers=_headers
)
```

A request the router served takes the router's per-attempt value, because the router's value is the one that reflects the attempt that actually served the request. A request that never reached the router, such as one the proxy answered directly, keeps the proxy's stamp

## Where it is read

The flag reaches the spend log through `resolve_used_client_oauth_token` at `litellm/proxy/spend_tracking/spend_tracking_utils.py:814-816`, and is filterable from the spend-logs endpoint at `litellm/proxy/spend_tracking/spend_management_endpoints.py:2559`

The router's per-attempt value is written into the same request metadata the spend log reads, so no new column and no new filter are needed

## What the operator sees

| Situation | `used_client_oauth_token` |
|-----------|----------------------------|
| A request resolved to an in-scope `chatgpt` target | `true`, and the request reports no spend |
| A request resolved to an out-of-scope `chatgpt` target | `false`, and the request reports whatever the target's own credential costs |
| A request that fell back from an in-scope target to an out-of-scope one | `false`, because the attempt that served it used the target's own credential |
| A request that fell back from an out-of-scope target to an in-scope one | `true`, because the attempt that served it forwarded the caller's bearer |

The last two rows are the point of the feature. The flag reflects the attempt that served the request, not the first attempt

## What this contract does not define

- A separate field naming the credential class. `used_client_oauth_token` already means "a client subscription credential served this request". Two fields for one fact is worse than one
- A per-token price for subscription models. That is separate work, blocked on the cost map carrying rates
- A plan-ineligibility classification. The proxy does not classify a plan rejection apart from any other 400, by the operator's explicit decision
