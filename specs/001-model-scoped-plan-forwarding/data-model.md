# Data Model: Model-scoped token-plan forwarding

**Feature**: `specs/001-model-scoped-plan-forwarding`
**Date**: 2026-10-28

## Entities

### Plan scope

The operator's declaration that the caller's forwarded ChatGPT credential is the credential for the targets it names

| Field | Type | Meaning |
|-------|------|---------|
| `provider` | `str` | The provider whose forwarded-credential forwarding this scope narrows. One scope per provider |
| `models` | `Sequence[str]` | The model groups the operator declares in scope. Matched with alias and wildcard handling |

**Validation rules**

- `provider` MUST be a provider that accepts a forwarded client credential. The set is `_FORWARDED_CREDENTIAL_ISOLATION_PROVIDERS` at `litellm/router.py:566`, currently `{"chatgpt", "anthropic"}`. A scope for any other provider is rejected at configuration load rather than silently ignored
- `models` MUST be a non-empty sequence of model group names. An empty scope is rejected, because an empty scope with a narrow meaning would be ambiguous between "nothing is covered" and "no scope declared"
- Each entry is matched against the selected deployment's **model group** (`deployment["model_name"]`), which is the operator-facing name and the name their callers request. The provider-prefixed spelling (`chatgpt/gpt-5.3-codex`) is not the match key
- An entry that is a router **model-group alias** resolves to its target group before the comparison, using the router's own alias map. An entry that is a **wildcard** matches under the proxy's existing wildcard rule. The match key is always the group, so one entry covers both spellings of a request

**Relationships**

- A scope belongs to exactly one provider
- A deployment is in scope when its model group matches an entry of the scope declared for the deployment's provider
- A provider with no scope declared has no scope object at all. That is distinct from a provider with an empty scope, which is rejected

### Selected target

The deployment the router resolved for the current routing attempt. This is what a scope is matched against

| Field | Source | Meaning |
|-------|--------|---------|
| `model_group` | `deployment["model_name"]` | The operator-facing name, the scope match key |
| `provider` | `deployment["litellm_params"]["model"]` or `custom_llm_provider` | Decides which scope applies |
| `deployment_model` | `deployment["litellm_params"]["model"]` | The provider-prefixed upstream model |

**Relationships**

- Exactly one scope can apply to a selected target, the one declared for the target's provider
- A selected target is either in scope or out of scope, and the answer is recomputed for every routing attempt

### Forwarded client credential

The caller's own ChatGPT subscription bearer, carried on the inbound request in the `provider_specific_header` request kwarg

| Field | Type | Meaning |
|-------|------|---------|
| `authorization` | `str` | The bearer value. Scoped to the `chatgpt` provider by `add_provider_specific_headers_to_request` at `litellm/proxy/litellm_pre_call_utils.py:4345-4394` |
| `account_id` | `str \| None` | The caller's ChatGPT account id, carried alongside the bearer in the same scoped header |

**Relationships**

- Travels on the request, scoped to a provider
- Reaches the upstream by two independent routes, the router's credential substitution at `litellm/router.py:4826-4841` and the outbound header merge at `litellm/main.py:5743` and `litellm/responses/utils.py:243`
- The gate's rewrite removes it from the request-scoped scoped header for an out-of-scope target, which closes both routes at once

### Routing attempt

One attempt of a request against one selected target. A request makes a new attempt each time it retries or falls back, and each attempt makes its own scope decision

| Field | Type | Meaning |
|-------|------|---------|
| `selected_target` | `Selected target` | The target this attempt resolved |
| `in_scope` | `bool` | Whether the target matched the scope for its provider |
| `credential_served` | `str` | Which credential the attempt used, `forwarded_client_credential` or `configured_target_credential` |

**State transitions**

A request starts with an attempt against the first selected target. On failure the router may retry the same target or fall back to another, producing a new attempt with its own scope decision. The attempt that succeeds is the one whose credential attribution is recorded

**Relationships**

- Exactly one scope decision per attempt, made against that attempt's selected target
- The credential attribution recorded on the request is the one from the attempt that served it

### Configured target credential

The credential a target carries on its own, a configured key or a stored subscription login. It authenticates every request to a target outside every declared scope

**Relationships**

- Owned by the deployment, never by the request
- Used by an out-of-scope attempt, because the gate removes the caller's bearer from that attempt's outbound request

### Credential attribution record

The per-request record naming which credential served the request and marking the request as plan-covered

| Field | Type | Meaning |
|-------|------|---------|
| `used_client_oauth_token` | `bool` | The caller's forwarded ChatGPT credential served the request |
| `plan_covered` | `bool` | The request was served under a plan-covered target. True when `used_client_oauth_token` is true |

**Relationships**

- Travels on the request metadata, so it reaches both the spend log and the request log
- Reuses the existing `used_client_oauth_token` flag, typed at `litellm/types/utils.py:3374` and stored on spend logs at `litellm/proxy/_types.py:3770`
- The proxy's existing pre-routing stamp at `litellm/proxy/litellm_pre_call_utils.py:2658` is the fallback for requests the router did not route
