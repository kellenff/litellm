# Problem Definition: ChatGPT plan entitlement behind a routed model name

- **Slug**: codex-token-plan-auto-router
- **Created**: 2026-10-27
- **Inputs used**: intake.md yes | research.md yes | user input (the original one-liner)

## Problem Statement

An operator who fronts ChatGPT-subscription (token plan) Codex models and ordinary models behind one LiteLLM proxy cannot expose a single client-facing entry point whose upstream credential follows the model the router actually selected, because the proxy holds no representation of which models a plan covers and it binds credentials to deployments rather than to selections. The outcomes the operator cannot currently tell apart are a request rejected upstream because the selected model is outside the caller's plan, a request that quietly ran on the wrong credential, and a plan-covered request that reports no spend at all

## Affected Users & Stakeholders

- **Users**: the proxy operator or admin who fronts a ChatGPT subscription for a team. The shipped ChatGPT subscription passthrough guide shows the operator-facing shape today, and issue #23777 (45 `+1`, 7 comments, open) is the strongest observed demand for per-account ChatGPT OAuth handling in this repo
- **Users**: the developer or team whose Codex client holds the ChatGPT login and expects that subscription to be the credential that pays for their traffic
- **Users**: the end users of the models served through the proxy, who are the ones who meet the upstream rejection when a selected model is outside the plan
- **Stakeholders**: OpenAI, the only authority on which models a plan covers, whose policy moves without notice. The proxy operator, who pays ordinary-model invoices and needs the split visible in accounting. The maintainers who own credential-ownership rules, who must keep a client-supplied credential from becoming a way to select upstream accounts

## Goals

- One client-facing name can cover both plan-eligible and ordinary targets, with the credential for each request determined by the selected target rather than by static per-target configuration
- A plan credential never reaches a target the caller's plan does not cover
- Plan ineligibility, plan exhaustion, and ordinary upstream failure are distinguishable in the proxy's own behavior and its logs, rather than all surfacing as one generic 400
- Spend and credential attribution for a plan-covered request are visible in the proxy's accounting instead of reading as zero
- The behavior holds for Codex clients on the Responses contract without those clients changing how they authenticate

## Non-Goals

- Not building an authoritative local copy of OpenAI's plan-to-model policy, since the upstream is the only authority and its policy changes without notice
- Not making the upstream credential a client-selectable request parameter, and not weakening the existing isolation that limits forwarded client credentials to the chatgpt and anthropic providers
- Not changing the credential precedence that shipped for the existing single-model ChatGPT subscription flow, which callers already depend on
- Not covering the Anthropic subscription provider, which has its own open request
- Not building subscription account management UI, which is separate open work
- Not changing the current behavior of the Codex-native passthrough route for the clients that use it today, whichever surface the feature ends up on

## Success Metrics

- The number of distinct model names an operator maintains to expose both plan-eligible and ordinary models (baseline: one per credential plus separate fallback configuration, target: one name covers the mix)
- Share of selected-but-ineligible requests the proxy classifies as plan ineligibility rather than leaving as a generic provider 400 (baseline: no plan-specific classification exists, target: classified)
- Share of plan-covered requests reporting a nonzero or explicitly labeled spend in the proxy's accounting (baseline: zero, every chatgpt row in the cost map carries no rates, target: labeled or priced)
- Incidents in which a plan credential was sent to a non-chatgpt upstream target (baseline: none observed, target: none, with the existing provider credential isolation as the guard)
- Requests per second through the new path failing only because of the routing step, counted separately from upstream failures (baseline: unknown, target: no new failure class)
- Qualitative: an operator can tell from the proxy's logs which credential a given request used, without reading the model list (baseline: not available, target: available)

## Cost of Inaction

Operators keep hand-maintaining the model list and the per-target fallback wiring, and when OpenAI's plan policy moves, as the public evidence shows it does without notice, the stale configuration silently routes requests the upstream will reject. The proxy has no way to tell an operator that a model is outside the caller's plan before the request, so the user-facing failure is the upstream 400, which community reports show users cannot diagnose on their own. A configuration-only approximation of the wanted behavior, separate model groups plus configured fallbacks, duplicates configuration per target, carries no shared notion of a plan, prices nothing, and steers operators away from mixing subscription traffic with fallback traffic because cross-provider fallbacks incur separate charges per the shipped guide. The subscription passthrough work that did ship is still in flux, with per-model auth files, subscription management UI, and cooldown isolation for forwarded subscription bearers all open, so the gap widens as each of those lands

## Open Questions

- [NEEDS CLARIFICATION: which credential is "the token plan oauth", the proxy's own stored ChatGPT OAuth from a device-code login, or the client's bearer forwarded through the request. Existing precedence is client-first and `chatgpt_auth_file` is per-deployment and server-owned, so the two readings lead to materially different designs]
- [NEEDS CLARIFICATION: whether "a different model that isn't a part of the token plan" means a ChatGPT Codex model outside the caller's plan tier, or a non-ChatGPT model entirely such as a pay-per-token API deployment. The first reading needs entitlement logic, the second needs only credential isolation, which already exists]
- [NEEDS CLARIFICATION: which surface the feature lives on. The Codex-native passthrough forwards verbatim and never consults the router, so an auto-router in front of it is a different feature from one that resolves to a `chatgpt/` deployment through the ordinary `/v1/responses` path]
- [NEEDS CLARIFICATION: which router is meant. This codebase names both the semantic `auto_router/` deployment and `auto_router/complexity_router` "auto_router", and only the complexity router carries per-tier `litellm_params` today]
- [NEEDS CLARIFICATION: what "normal proxy auth" means concretely on the path in question, the selected deployment's own `api_key`, the inbound virtual key, or the master key, and whether a Responses-shaped request can be served by a non-ChatGPT target at all given chatgpt is Responses-only]
- [NEEDS CLARIFICATION: how a model is judged "part of the token plan". Upstream enforces entitlement server-side and exposes no per-account entitlement list, so the candidates are a static configured list, the plan tier read from the id_token, or attempt-then-classify-on-error, each with a different failure mode]
- [NEEDS CLARIFICATION: what happens when the plan's usage allowance is exhausted, retry the same model, fall back to ordinary auth, or fail the request. The upstream shape is a 429 with a rate-limit payload, which the router currently retries and cools down generically]
- [NEEDS CLARIFICATION: how spend is attributed for a plan-covered route, given the chatgpt rows carry no rates. Without a pricing rule, plan-covered traffic reads as zero cost in logs and savings]
- [NEEDS CLARIFICATION: whether the swapped model is reflected in the response envelope and in the Codex streaming shape the client expects, and whether the per-request routing embedding cost is acceptable]
- [NEEDS CLARIFICATION: whether an operator-configured list of plan-eligible models is acceptable given the public evidence that OpenAI's entitlement changes without notice, since a stale list silently routes requests the server will reject]
- [NEEDS CLARIFICATION: what the trigger was. No issue in this repo describes the auto-router-plus-plan combination, so the demand signal for that exact shape is assumed rather than observed]
- [NEEDS CLARIFICATION: whether the goal is a single name covering a mixed pool at all, given that a configuration-only approximation already exists. If it is, what the operator-facing configuration is allowed to assume about plan scope, and how an operator learns the plan scope of a given caller]
