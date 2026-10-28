---
title: Forwarded client credentials
type: component
sources: [S069, S070]
updated: 2026-10-28
---

The proxy lets a caller forward its own provider credential instead of the proxy's, which is how ChatGPT-subscription ("plan") traffic is served. The caller's bearer enters on the inbound request and reaches the upstream by **two independent routes**, and closing one does not close the other (S069).

**Route 1, credential substitution.** The router's provider-wide forwarding block replaces the deployment's credential with the caller's bearer when the selected deployment's provider accepts a forwarded credential. The forwarded value rides on the request kwarg `provider_specific_header` (S070).

**Route 2, outbound header merge.** The provider's environment validation merges the same request-scoped `provider_specific_header` into the outbound headers, so the bearer travels as a header even when it never became the `api_key` (S069).

Both routes read the **same** request-scoped value. Rewriting that one value per routing attempt therefore closes both routes at once, which is what makes a scope gate possible without a second enforcement point (S070).

## Why the rewrite is per attempt

The router copies the request kwargs per attempt, so a rewrite applied to one attempt's kwargs does not reach the next attempt. A probe capturing the value at the entry of every attempt across a two-hop chain confirmed each attempt starts from the request's own value and none inherits the previous attempt's rewrite (S069). That is what makes fallback re-evaluation work: each hop decides against the target it actually selected (S070).

## What happens when the credential is absent

Removing the caller's bearer leaves the provider's existing credential precedence to fall through, with no provider-side change. At `litellm/llms/chatgpt/responses/transformation.py` the order is a client credential in the headers, then the configured key, then the proxy's stored subscription login (S069). So stripping the bearer hands the request to the target's own configured credential rather than breaking it.

## The two provider credential sets

`_FORWARDED_CREDENTIAL_ISOLATION_PROVIDERS` in `litellm/router.py` names the providers that accept a forwarded client credential, currently `{"chatgpt", "anthropic"}`. It is the allowlist a scope declaration draws from (S070).

## Related: [Model-scoped credential forwarding](./model-scoped-credential-forwarding.md), [Spend logging](./spend-logging.md), [Routing decisions](./routing-decisions.md).
