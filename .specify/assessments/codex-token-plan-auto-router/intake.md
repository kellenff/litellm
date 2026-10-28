# Idea Intake: Auto-router passthrough for ChatGPT Codex models on a token plan

- **Slug**: codex-token-plan-auto-router
- **Created**: 2026-10-27
- **Source**: pasted text, this repository (LiteLLM proxy)
- **Type**: new-capability

## Idea (as captured)

> "add the ability to use an auto_router to pass-through available chatgpt codex models using token plan oauth, while using the normal proxy auth when the auto_router picks a different model that isn't a part of the token plan"

No secrets, tokens or URLs were present in the original text, so nothing was redacted.

## Restated

An auto-router deployment should be able to send a request to a ChatGPT Codex model that the account's plan covers, authenticating that request with the plan's OAuth credential, and should fall back to the proxy's ordinary authentication when the router selects a model the plan does not cover.

## Origin & Context

- **Raised by**: Kellen, in this LiteLLM checkout
- **Trigger**: [NEEDS CLARIFICATION: what prompted this, for example a Codex CLI client that needs a router in front of the subscription, an operator wanting plan-covered and pay-per-token models behind one alias, or a cost goal]
- **Where it lands in this repo**:
  - `litellm/router_strategy/auto_router/auto_router.py` is the semantic auto-router. Its `async_pre_routing_hook` returns a `PreRoutingHookResponse` whose `model` is the selected model name, and the router then resolves that name to a deployment
  - `litellm/router.py:10527` (`init_auto_router_deployment`) wires an `auto_router/` deployment up, `litellm/router.py:16008` dispatches the hook, and `litellm/router.py:562` / `litellm/router.py:566` decide which alias-level params are never forwarded (`api_key`, `api_base`, `api_version`, `responses_api_version`) and which providers isolate forwarded credentials (`chatgpt`, `anthropic`)
  - `litellm/llms/chatgpt/authenticator.py` owns the ChatGPT device-code OAuth login, the auth file and token refresh. `litellm/llms/chatgpt/common_utils.py` holds `CHATGPT_API_BASE`, `is_chatgpt_oauth_key` and `get_chatgpt_request_credential`
  - `litellm/llms/chatgpt/responses/transformation.py:58` (`validate_environment`) sets the precedence for a chatgpt call today, a client OAuth credential first, then a configured `api_key`, then the authenticator's stored access token
  - `litellm/proxy/pass_through_endpoints/codex_passthrough_endpoints.py` is the Codex-native passthrough route. It forwards verbatim to `https://chatgpt.com/backend-api/codex/{endpoint}`, requires a ChatGPT bearer in `Authorization` plus a separate LiteLLM key in `x-litellm-api-key`, rejects the two when they are the same token, and never consults the router
  - `litellm/proxy/litellm_pre_call_utils.py:4346` (`add_provider_specific_headers_to_request`) scopes a client's ChatGPT OAuth bearer to the `chatgpt` provider only
  - `litellm/proxy/common_utils/codex_model_catalog.py` builds the Codex `/v1/models` catalog from the proxy's own model list
  - `litellm/types/litellm_params.py:94` carries `chatgpt_auth_file`, so a chatgpt deployment can already hold its own OAuth auth file (added in #41522, per-model auth files for multiple ChatGPT accounts)
  - `litellm/model_prices_and_context_window_backup.json` lists `chatgpt/gpt-5.3-codex`, `chatgpt/gpt-5.2-codex` and siblings as `chatgpt` rows with no per-token rates

## First-Glance Unknowns

- [NEEDS CLARIFICATION: which credential is "the token plan oauth", the proxy's own stored ChatGPT OAuth from a device-code login, or the client's bearer forwarded through the request]
- [NEEDS CLARIFICATION: which surface the feature lives on, a model-list auto-router deployment that resolves to chatgpt deployments, or the Codex-native passthrough route, which today always targets chatgpt.com and never asks the router]
- [NEEDS CLARIFICATION: which router is meant, the semantic `auto_router/` deployment or the complexity router under `auto_router/complexity_router`, since "auto_router" names both surfaces in this codebase]
- [NEEDS CLARIFICATION: how a model is judged "part of the token plan", a static configured list, the plan's own entitlements, or the model catalog the plan exposes]
- [NEEDS CLARIFICATION: what "normal proxy auth" means concretely on the path in question, the client's own key, the selected deployment's `api_key`, or the master key, and whether a Codex-shaped responses request can be served by a non-Codex model at all]
- [NEEDS CLARIFICATION: how the plan credential attaches to the routing decision, given the alias never forwards `api_key` and `chatgpt_auth_file` lives on the deployment the hook selects]
- [NEEDS CLARIFICATION: how spend is attributed for a plan-covered route compared to a normal-auth route, given chatgpt subscription rows carry no rates]
- [NEEDS CLARIFICATION: what happens when the plan's usage allowance is exhausted, retry elsewhere, fall back to normal auth, or fail the request]
- [NEEDS CLARIFICATION: whether the swapped model is reflected in the response envelope and in the Codex streaming shape the client expects]
