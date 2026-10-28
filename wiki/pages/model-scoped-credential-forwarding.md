---
title: Model-scoped credential forwarding
type: decision
sources: [S069, S070]
updated: 2026-10-28
---

An operator who fronts ChatGPT-subscription models and ordinary models behind one proxy wants a single client-facing name whose upstream credential follows the model the router actually selected. The proxy holds no representation of which models a plan covers, and it binds credentials to deployments rather than to selections (S069).

The design makes the forwarded credential follow the routing decision. The operator declares, per provider, the model groups whose deployments authenticate with the caller's forwarded bearer. The router decides per routing attempt, at the point where it already binds a credential to the selected deployment, and expresses the decision by rewriting the request-scoped scoped header for that attempt (S070).

## The enforcement point

`Router._update_kwargs_with_deployment` is the single place the decision is made. It already runs on every routing attempt for every surface and already holds the selected deployment, so it is the only point where the routing decision and the credential binding meet (S070). Rejected alternative: enforce in the proxy pre-call layer; rejected because the proxy receives the request before the router has selected a deployment, so it cannot know the eventual target. Rejected alternative: enforce per provider surface; rejected because the same leak would have to be closed once per surface (S069).

## The scope is keyed by provider

The setting is a mapping from provider to the model groups that provider's scope covers. A provider absent from the mapping keeps provider-wide forwarding, so an operator who opts in nothing sees no change. A provider present in the mapping is narrowed to its declared targets (S070). Rejected alternative: one flat list of models across all providers; rejected because declaring a ChatGPT scope would then silently stop the bearer reaching an Anthropic target, which changes a shipped flow that is out of scope (S069).

## The match key is the model group

A target is in scope when the selected deployment's **model group** matches a listed entry. A probe at the enforcement point confirmed `deployment["model_name"]` is always the group, even when the caller requested an alias, so one scope entry covers both spellings of a request (S069).

A listed entry that is a router model-group alias resolves to its target group before the comparison, using the router's own alias map. A listed entry that is a wildcard matches under the proxy's existing wildcard rule (S069). Rejected alternative: reuse the proxy's `check_model_access_helper` directly; rejected because it lives under `litellm/proxy/auth/` and the router core does not depend on the proxy layer, and because it resolves access groups and team model aliases rather than the router's `model_group_alias`, which is the alias that matters for a model group. Its wildcard primitive is reused instead (S069).

A forwarded client credential is scoped per selected deployment rather than per provider, so the credential follows the routing decision instead of the deployment table (S069). The scope is keyed by provider, a provider absent from the mapping keeps provider-wide forwarding, and the match key is the selected deployment's model group, which is the group even when the caller requested an alias. The fallback chain is keyed on the requested name instead, so an operator writing one client-facing name over two groups writes three distinct names across the alias, the fallback, and the scope (S069).

Related: [Forwarded client credentials](./forwarded-client-credentials.md), [Routing decisions](./routing-decisions.md), [Model scope and fallback naming](./model-scope-and-fallback-naming.md).