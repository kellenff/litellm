---
title: Model scope and fallback naming
type: concept
sources: [S069, S070]
updated: 2026-10-28
---

The fallback chain is looked up by the **requested** model name, while the scope is matched against the **selected deployment's model group**. A probe with a `model_group_alias` confirmed the difference: keying the fallback on the requested name reached the second deployment, keying it on the group did not, and the request simply did not fall back (S069).

An operator exposing one client-facing name over two model groups therefore writes three different names: the client-facing name in `model_group_alias`, the fallback key using that same client-facing name, and the scope entry using the model group name. Getting it wrong fails silently as a missing fallback rather than as an error, so the operator guide says it out loud (S070).

## Rejected alternative, a per-deployment flag

A `litellm_params` flag on each deployment was rejected because the operator's unit is a model or model group, and one declaration covers the deployment (S069). Rejected alternative, a client-selectable credential, because the scope is operator configuration and the caller supplies only its own credential.

## Plan rejection stays ordinary

A 400 from a plan-backed target is an ordinary upstream 400 and follows the ordinary fallback path. The router's own `fallback_on_unsupported_params` default is on, and the 400-to-fallback gate already lets a 400 fall through when it is (S069). A 429 stays on the existing retry and cooldown path. The proxy does not predict plan eligibility before the request is attempted and does not classify plan rejections separately (S070).

Related: [Model-scoped credential forwarding](./model-scoped-credential-forwarding.md), [Forwarded client credentials](./forwarded-client-credentials.md).
