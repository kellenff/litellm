# Contract: Plan scope configuration

**Feature**: `specs/001-model-scoped-plan-forwarding`
**Date**: 2026-10-28

## Operator-facing configuration

The scope is declared in `router_settings`, so it reaches the enforcement point through the existing `router_settings` to `Router.__init__` path at `litellm/proxy/proxy_server.py:7300-7311`

```yaml
router_settings:
  forward_client_credentials_to_model_groups:
    chatgpt:
      - gpt-5.3-codex
      - codex-alias
```

The value is a mapping from provider to the model groups that provider's scope covers

| Key | Type | Meaning |
|-----|------|---------|
| `forward_client_credentials_to_model_groups` | `Mapping[str, Sequence[str]] \| None` | Per-provider allowlist of model groups whose deployments authenticate with the caller's forwarded credential. `None` or absent means no scope is declared for any provider and today's provider-wide forwarding is preserved |

### Rules

- A provider key MUST be a provider that accepts a forwarded client credential. The set is `_FORWARDED_CREDENTIAL_ISOLATION_PROVIDERS` at `litellm/router.py:566`, currently `{"chatgpt", "anthropic"}`. An unknown provider is rejected at configuration load with a message naming the allowed providers
- A provider's model list MUST be non-empty. An empty list is rejected, because it is ambiguous between "nothing is covered" and "no scope declared"
- Entries are model group names, matched against the selected deployment's model group. An entry that is a router model-group alias resolves to its target group first, and an entry that is a wildcard matches under the proxy's existing wildcard rule
- A provider absent from the mapping keeps today's provider-wide forwarding. Declaring a scope for `chatgpt` does not change the `anthropic` forwarding

### What the operator sees

| Situation | Behavior |
|-----------|----------|
| No `forward_client_credentials_to_model_groups` | Today's behavior. The caller's bearer reaches every deployment of a forwarded-credential provider, exactly as it does today |
| `chatgpt: [gpt-5.3-codex]` and the router selects a `gpt-5.3-codex` deployment | The caller's bearer is forwarded |
| `chatgpt: [gpt-5.3-codex]` and the router selects any other `chatgpt` deployment | That target authenticates with its own configured credential. The caller's bearer is absent from the outbound request |
| `chatgpt: [gpt-5.3-codex]` and the router selects an `anthropic` deployment | The `anthropic` forwarding is unchanged, because `anthropic` has no scope declared |
| The caller's plan does not actually cover a declared target | The request is attempted, upstream rejects it, and the ordinary fallback path carries the request onward. The proxy does not predict coverage |

## Router constructor argument

The setting reaches the router as a constructor keyword argument, so a bare `Router` used from the SDK configures it the same way the proxy does

```python
router = Router(
    model_list=[...],
    forward_client_credentials_to_model_groups={"chatgpt": ["gpt-5.3-codex"]},
)
```

The argument is validated at construction. An invalid provider or an empty model list raises, so a misconfiguration surfaces at boot rather than at the first request that would have leaked a credential

## Runtime updates

The scope is a static routing decision, not a runtime-togglable one. It is not added to `RUNTIME_UPDATABLE_ROUTER_SETTINGS` at `litellm/constants.py:57-79`, so a runtime settings update cannot change which targets receive a forwarded credential while requests are in flight

## What this contract deliberately does not define

- A per-deployment `litellm_params` flag. The operator's unit is a model or model group, and one declaration covers the deployment
- A client-selectable credential. The scope is operator configuration. A caller can supply its own credential and nothing else
- A provider outside the forwarded-credential set. The scope narrows forwarding, it never widens it
