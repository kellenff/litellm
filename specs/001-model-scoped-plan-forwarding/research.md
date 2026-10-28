# Research: Model-scoped token-plan forwarding

**Feature**: `specs/001-model-scoped-plan-forwarding`
**Date**: 2026-10-28

Every claim below was verified against the tree at commit `180f030292`, and the load-bearing ones were verified by executing the code in a scratch virtualenv (`uv venv --python 3.11`, `uv pip install -e .`). The probes live in the scratch cache and are described inline so a reviewer can reproduce them

## Decision 1: the gate belongs in the router, at the selected-deployment credential binding

**Decision**: The scope decision is made in `Router._update_kwargs_with_deployment`, the method that already binds a credential to a selected deployment, and it is expressed as a rewrite of the request-scoped `provider_specific_header` for that hop

**Rationale**: `_update_kwargs_with_deployment` is the only point in the request path where the selected deployment is known. It is called on every routing attempt, for every surface (chat completions, responses, embeddings, images, batches, generic calls), so a gate placed there covers all of them at once. The alternative, gating at the proxy pre-call layer, cannot work: the proxy does not know which deployment the router will select

**Alternatives considered**:

- Gate in the proxy pre-call path (`litellm/proxy/litellm_pre_call_utils.py:2658`, where the scoped header is first built). Rejected, because the pre-call path runs before routing and cannot see the selected deployment. It would also be the wrong layer for a per-hop re-evaluation
- Gate inside the ChatGPT provider transformation (`litellm/llms/chatgpt/responses/transformation.py:58`). Rejected, because the provider sees only its own call, not the routing decision that produced it, and because the same provider serves every ChatGPT target
- Add a per-deployment `litellm_params` flag such as `use_client_subscription: true`. Rejected as the primary vocabulary because the operator's unit is a model or model group, and the proxy's own model-access vocabulary is a list of model names. It also cannot express "these targets are covered by the caller's plan" as a single declaration

## Decision 2: the forwarded bearer reaches the upstream by two independent routes, and both must be gated

**Decision**: The gate rewrites the request-scoped `provider_specific_header` so that, for an out-of-scope target, the caller's bearer is absent from the outbound request entirely. That closes both routes with one rewrite, because both read the same request-scoped value

**Rationale**: The probe confirmed two distinct carriers

Route 1, credential substitution, `litellm/router.py:4826-4841`:

```python
forwarded_authorization: Final = (
    ProviderSpecificHeaderUtils.forwarded_authorization(
        request_context.get("provider_specific_header"), deployment_provider
    )
    if deployment_provider in _FORWARDED_CREDENTIAL_ISOLATION_PROVIDERS
    else None
)
if is_clientside_credential(request_kwargs=kwargs) or forwarded_authorization is not None:
    deployment_pydantic_obj: Final = self._handle_clientside_credential(
        deployment=deployment,
        kwargs={
            **kwargs,
            **({"api_key": forwarded_authorization} if forwarded_authorization is not None else {}),
        },
        function_name=function_name,
    )
```

Route 2, header merge into the outbound request, at `litellm/main.py:5743` for chat completions and `litellm/responses/utils.py:243` (`merge_provider_specific_headers`) for the responses surface. Both read the request-scoped value, and the ChatGPT provider then prefers the caller's credential over the target's own, at `litellm/llms/chatgpt/responses/transformation.py:65-70`:

```python
client_credential: Final = get_chatgpt_client_credential(headers)
if client_credential is not None:
    return {
        **get_chatgpt_default_headers(client_credential.access_token, client_credential.account_id, session_id),
        **strip_chatgpt_client_credential_headers(headers),
    }
```

**Probe**: a router with one `chatgpt/` deployment carrying its own `api_key`, called with a request-scoped `provider_specific_header` holding a JWT-shaped bearer, produced this at the two carrier points

```
=== ROUTE 1: router api_key substitution (_handle_clientside_credential) ===
called: 1
  api_key passed in: 'Bearer eyJhbG...ture'
  == caller's bearer? True

=== ROUTE 2: chatgpt validate_environment (merged outbound headers) ===
called: 1
  authorization header: 'Bearer eyJhbG...ture'
  == caller's bearer? True
  litellm_params.provider_specific_header: {'custom_llm_provider': 'chatgpt', 'extra_headers': {'authorization': 'Bearer eyJhbG...ture'}}
  litellm_params.api_key: 'eyJhbG...ture'
```

Two consequences. First, gating route 1 alone is not enough, because route 2 would still deliver the bearer to an out-of-scope target, which is the leak the spec's FR-004 forbids. Second, `litellm_params.provider_specific_header` on the per-request deployment carries the bearer too, so the rewrite has to reach that path, not just the request kwargs

**Alternatives considered**:

- Gate only the router's `forwarded_authorization` computation. Rejected, it leaves route 2 open
- Gate only the ChatGPT provider's credential precedence. Rejected, it does not cover the router's api_key substitution, and it puts the routing decision in the provider layer

## Decision 3: a per-hop rewrite is hop-local, so the scope decision is re-made per attempt

**Decision**: The gate computes the scope decision on each routing attempt, from the deployment selected for that attempt. The rewrite targets the attempt's own request kwargs, and the next attempt recomputes the decision against its own deployment

**Rationale**: The router reuses one kwargs dict across the whole fallback chain, which is exactly why the scope decision cannot be made once per request. The probe confirmed that a rewrite of `kwargs["provider_specific_header"]` inside `_update_kwargs_with_deployment` does not leak into the next hop: the next attempt sees the original value

**Probe**: the spy captured the value as found at the entry of each attempt, before its own rewrite

```
=== hop entries ===
  model_group=codex-alias psh_at_entry_is_original=True
```

A second probe, with a rewrite that strips the bearer and a two-hop chain, produced this. The first three attempts are retries of `group-a` and the last three are the fallback to `group-b`. Every attempt found the original at entry, so no attempt inherited the previous attempt's rewrite

```
=== hops observed ===
  hop 0: model_group=group-a psh_at_entry=None
  hop 1: model_group=group-a psh_at_entry=None
  hop 2: model_group=group-a psh_at_entry=None
  hop 3: model_group=group-b psh_at_entry=None
  hop 4: model_group=group-b psh_at_entry=None
  hop 5: model_group=group-b psh_at_entry=None
```

The `None` here is because that probe's request carried no scoped header. The first probe above, which did carry one, showed `psh_at_entry_is_original=True`. Both agree that each attempt starts from the request's own value

The mechanism is that the fallback chain copies the request kwargs at `litellm/router_utils/fallback_event_handlers.py:8552-8557`, and each attempt's rewrite lands on that attempt's own dict

**Alternatives considered**:

- Decide the scope once per request, before the fallback chain. Rejected, because the whole point of the feature is that the credential follows the decision the router actually made on the attempt that serves the request. A fallback target outside the scope would inherit the plan credential
- Strip the bearer from the shared request kwargs permanently on the first out-of-scope attempt. Rejected, because the request may fall back to an in-scope target, which then must forward the bearer

## Decision 4: the scope is declared per provider, so one provider's scope does not narrow another provider's forwarding

**Decision**: The scope declaration is keyed by provider. A provider with no scope declared keeps today's provider-wide forwarding. A provider with a scope declared forwards the caller's bearer only to the targets in that scope

**Rationale**: Today's forwarding is provider-scoped, via `_FORWARDED_CREDENTIAL_ISOLATION_PROVIDERS` at `litellm/router.py:566`:

```python
_FORWARDED_CREDENTIAL_ISOLATION_PROVIDERS: Final = frozenset({"chatgpt", "anthropic"})
```

Narrowing to model scope for one provider must not narrow it for another. The Anthropic subscription flow is explicitly out of scope for this feature, and an operator running an Anthropic deployment alongside a ChatGPT one must not have the Anthropic forwarding change under them

**Alternatives considered**:

- One flat list of models across all providers. Rejected, because declaring a ChatGPT scope would then silently stop the bearer reaching an Anthropic target, which is a behavior change to a shipped flow that is out of scope
- The scope keyed by provider but stored per deployment. Rejected, same reason as Decision 1, plus it multiplies the operator's configuration

## Decision 5: the scope matches on the selected deployment's model group, with alias and wildcard handling

**Decision**: A target is in scope when the selected deployment's **model group** matches one of the models the operator listed. A listed entry that is a router model-group alias resolves to its target group before the comparison, and a listed entry that is a wildcard matches under the proxy's existing wildcard rule

**Rationale**: The closest existing precedent is `ModelGroupSettings.forward_client_headers_to_llm_api` at `litellm/types/router.py:1296-1297`, a list of model names consumed at `litellm/proxy/litellm_pre_call_utils.py:1719-1743` through `check_model_access_helper`. That helper resolves an access group, a team model alias, and a wildcard. The scope needs the wildcard rule and the router's own alias resolution

The match key is the deployment's model group, `deployment["model_name"]`, which is the operator-facing name they write in `model_list`. A probe at the enforcement point confirmed that this holds even when the caller requested an alias:

```
=== request via alias 'codex-alias' ===
  deployment['model_name'] = codex-plan
  litellm_params.model     = openai/gpt-4o
=== request directly for 'codex-plan' ===
  deployment['model_name'] = codex-plan
  litellm_params.model     = openai/gpt-4o
```

So one scope entry covers both spellings of a request, and the operator does not have to repeat the alias in the scope

Two corrections to the earlier draft of this decision, both established by reading the code rather than inferring it

The alias handling that matters is the **router's** `model_group_alias`, not the proxy's team alias. `check_model_access_helper` at `litellm/proxy/auth/auth_checks.py:4823` resolves access groups and team model aliases, but not the router's `model_group_alias`. The router resolves its own aliases at `litellm/router.py:12024-12030` through `resolve_model_group_alias` at `litellm/router_utils/common_utils.py:96-114`, and the probe confirmed the resolution:

```
get_model_from_alias('codex-alias') = codex-plan
get_model_from_alias('codex-plan')  = None
routable_model_group('codex-alias') = codex-plan
```

The wildcard rule is the one at `litellm/proxy/auth/auth_checks.py:7753` and `:7772`, `is_model_allowed_by_pattern` and `model_matches_any_wildcard_pattern_in_list`. The router core does not depend on the proxy layer, so those primitives move to the shared core location `litellm/litellm_core_utils/get_provider_specific_headers.py`, which already holds the provider-scoped header helpers, and the proxy's `auth_checks.py` delegates to them. One implementation, two callers

**Alternatives considered**:

- Reuse `check_model_access_helper` directly. Rejected as a call, because it lives under `litellm/proxy/auth/` and the router core does not depend on the proxy layer, and because it resolves access groups and team aliases rather than the router's alias map, which is the alias that matters here. Its wildcard primitive is reused instead
- Exact string equality against the model group. Rejected, because an operator who writes `openai/*` in one list and expects it to work in another would be surprised, and the spec's clarification settled on the existing alias and wildcard handling
- Matching against the provider-prefixed model (`chatgpt/gpt-5.3-codex`). Rejected, because the operator's config vocabulary is the model group name
- Matching against the requested model rather than the deployment's group. Rejected, because the requested name changes between fallback hops, and the scope must be decided against the target that is actually serving the attempt

## Decision 6: the operator-facing setting is a router setting, not a proxy setting

**Decision**: The scope is declared in `router_settings`, reaches `Router.__init__` as a constructor argument, and is held on the router

**Rationale**: The proxy already forwards any `router_settings` key that `Router.__init__` accepts, at `litellm/proxy/proxy_server.py:7300-7311`, using `Router.get_valid_args()` at `litellm/router.py:1680-1688`. A router setting therefore reaches the enforcement point with no new proxy plumbing

```python
available_args: Final = [
    k for k in litellm.Router.get_valid_args() if k not in ROUTER_SETTINGS_MANAGED_OUTSIDE_CONFIG
]
for k, v in router_settings.items():
    if k in available_args:
        router_params[k] = v
```

The alternative, a `litellm_settings.model_group_settings` field, would work for the proxy but not for a bare `Router` used from the SDK, and the enforcement point is the router in both cases

**Alternatives considered**:

- A `litellm_settings.model_group_settings` field, mirroring `forward_client_headers_to_llm_api`. Rejected, because it is a proxy-global with no router-level equivalent, so the same feature would work in the proxy and not in a bare router
- A per-deployment `litellm_params` flag. Rejected, for the reasons in Decision 1

## Decision 7: the credential attribution in the log reuses the existing `used_client_oauth_token` flag

**Decision**: The router records which credential served the request, and the proxy stamps it onto the request metadata so it lands in the spend log and the request log

**Rationale**: The proxy already stamps this flag. At `litellm/proxy/litellm_pre_call_utils.py:2658`:

```python
data[_metadata_variable_name]["used_client_oauth_token"] = add_provider_specific_headers_to_request(
    data=data, headers=_headers
)
```

`add_provider_specific_headers_to_request` returns whether a client OAuth token was found, and the flag is carried through to the spend log at `litellm/proxy/spend_tracking/spend_tracking_utils.py:814-816` via `resolve_used_client_oauth_token`. The flag is typed at `litellm/types/utils.py:3374` and stored on spend logs at `litellm/proxy/_types.py:3770`

That flag is currently proxy-stamped, from the inbound request, before routing. It answers "did the caller send a subscription credential", not "which credential served this request". The router's decision is the per-hop answer, so the router writes the per-hop value and the proxy's stamp becomes the fallback for requests the router did not route

**Alternatives considered**:

- A new dedicated metadata field. Rejected, because an existing field already means "a client subscription credential served this request" and two fields for one fact is worse
- Recording the credential class only in the router's own logs. Rejected, because the operator needs it on the request record, which is where the spend log and the request log both read from

## Decision 8: the ChatGPT provider's own credential precedence is left alone

**Decision**: The change does not touch the ChatGPT provider's credential precedence at `litellm/llms/chatgpt/responses/transformation.py:58-92` or `litellm/llms/chatgpt/chat/transformation.py:81-107`

**Rationale**: The precedence is client credential, then configured key, then the proxy's stored subscription login. When the gate removes the caller's bearer from the outbound request, the provider's existing precedence already falls through to the target's own credential. The probe confirmed this: with the bearer stripped, the upstream received `sk-deployment-own-key` and rejected it with "API keys are not supported by this endpoint", which is the ChatGPT endpoint refusing an API key. That is the expected outcome for an out-of-scope target whose own credential is an API key, and it confirms the fall-through works without a provider change

**Alternatives considered**:

- Adding an explicit "use the deployment's key, not the caller's" flag to the provider. Rejected, because the absence of the caller's bearer already produces exactly that behavior, and a new provider flag would be a second place to keep in sync

## Decision 9: the Codex-native passthrough route is not a routing surface

**Decision**: The Codex-native passthrough route stays out of scope

**Rationale**: `litellm/proxy/pass_through_endpoints/codex_passthrough_endpoints.py` forwards verbatim to `https://chatgpt.com/backend-api/codex/{endpoint}` and never consults the router, so it has no selected deployment to scope against. It also requires the caller to send a ChatGPT bearer in `Authorization` and a separate LiteLLM key in `x-litellm-api-key`, and refuses when the two are the same token

## Decision 10: the spec's clarifications hold up against the tree

**Decision**: All seven clarifications in the spec's `## Clarifications` section are consistent with the code as it stands

**Rationale**: Each was checked against the tree. The plan credential is the caller's own forwarded bearer, because the shipped flow at `litellm/proxy/litellm_pre_call_utils.py:4345-4394` puts the caller's bearer into a provider-scoped `ProviderSpecificHeader` and `litellm/llms/chatgpt/common_utils.py:352-363` reads it back for the chatgpt provider. The proxy-held per-deployment login is a separate concern, at `litellm/llms/chatgpt/authenticator.py`. The scope attaches to models or model groups, per the existing model-access vocabulary. Declaring a scope narrows forwarding for that provider, per Decision 4. Both outbound paths are gated, per Decision 2. The fallback-on-400 setting needs no change, because the router's default at `litellm/router.py:1233` is `fallback_on_unsupported_params: bool = True` and the 400-to-fallback gate at `litellm/router_utils/fallback_event_handlers.py:259-266` already lets a 400 fall through when that flag is on. Spend labelling stays out of scope, because every `chatgpt/` row in `litellm/model_prices_and_context_window_backup.json` carries no rates, 20 rows in total. The exhaustion policy stays an operator opt-in

## Decision 11: the fallback chain is keyed on the requested name, so the operator-facing name and the scope entry are different strings

**Decision**: The operator-facing name and the scope entry name different things, and the operator-facing guide says so explicitly

**Rationale**: The router's fallback chain is looked up by the **requested** model name, while the scope is matched against the **selected deployment's model group**. A probe with a `model_group_alias` confirmed the difference. The request asked for `codex-alias`, and:

```
=== fallback keyed on the ALIAS (the requested name) ===
keyed on alias : attempted = ['openai/gpt-4o', 'openai/gpt-4o-mini']
=== fallback keyed on the ALIAS TARGET (the group) ===
keyed on target: attempted = ['openai/gpt-4o']
```

Keying the fallback on the alias reached the second deployment. Keying it on the target did not, because the lookup key is the name the caller asked for

The scope is the other way round, because it is matched against the deployment the router selected, and the deployment's `model_name` is always the group, as Decision 5's probe showed

So an operator exposing one client-facing name over two model groups writes three different names: the client-facing name in `model_group_alias`, the fallback key using that same client-facing name, and the scope entry using the model group name

**Alternatives considered**:

- Key the fallback on the model group and have the operator write the group in both places. Rejected, because the probe shows the fallback chain would not resolve under an alias, and the failure is silent in the sense that the request simply does not fall back
- Introduce one name for all three roles. Rejected, because the router's fallback lookup and the deployment's group name are different namespaces and forcing them together means changing router behavior well outside this feature's scope

## Decision 12: the plan-covered target carries no credential of its own

**Decision**: The proof configuration gives the plan-covered target no `api_key` and no `chatgpt_auth_file`

**Rationale**: It makes the two cases legible. If the caller's bearer reaches the target, the request succeeds under the caller's subscription. If the bearer is stripped, the target has nothing left to authenticate with, so the request fails loudly rather than succeeding on some other credential. That is the difference the operator needs to see, and a target carrying its own key would hide a failed strip behind a success

The provider's own precedence already does the right thing. At `litellm/llms/chatgpt/responses/transformation.py:65-92`, a client credential in the headers wins, otherwise the configured key wins, otherwise the proxy's stored subscription login is used. Removing the caller's bearer leaves the provider to fall through to whatever the target owns

**Alternatives considered**:

- Give the plan-covered target a `chatgpt_auth_file` holding the proxy's own stored login. Rejected for the proof, because a stripped bearer would then silently authenticate as the proxy's login, which is the opposite of what the operator wants to see
- Give the plan-covered target an `api_key`. Rejected for the same reason, and it would also make the ChatGPT upstream reject the request with `api_key_not_supported`, which muddies the signal

## Open items carried into implementation

- The exact configuration key name for the scope is a plan-level naming decision, recorded in the plan's contract rather than settled here
- Whether the scope also accepts the `chatgpt/` provider-prefixed spelling of a model name, or only the model group name, is an implementation detail that the contract fixes as the model group name
- The `forward_client_headers_by_model_group` literal at `litellm/types/router.py:181` is a declared-but-unimplemented check name. It is not enforced anywhere in the tree, and this feature does not adopt it
