# Implementation Plan: Model-scoped token-plan forwarding

**Branch**: `001-model-scoped-plan-forwarding` | **Date**: 2026-10-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-model-scoped-plan-forwarding/spec.md`

## Summary

An operator fronting ChatGPT-subscription Codex models and ordinary models behind one LiteLLM proxy cannot expose a single client-facing entry point whose upstream credential follows the model the router actually selected. The proxy holds no representation of which models a plan covers, and it binds credentials to deployments rather than to selections

The change makes the forwarded credential follow the routing decision. The operator declares, per provider, the model groups whose deployments authenticate with the caller's forwarded ChatGPT bearer. The router makes that decision per routing attempt, at the point where it already binds a credential to the selected deployment, and expresses it by rewriting the request-scoped scoped header for that attempt so the caller's bearer is absent from the outbound request to an out-of-scope target. A target outside the scope authenticates with its own configured credential. A 400 from a plan-backed target stays on the existing fallback path, so the request reaches the configured fallback model, which authenticates normally

The first story needs no code. An operator composes the same one-name arrangement from configuration alone, one model group per credential-bearing target, with the fallback relationship configured between them

## Technical Context

**Language/Version**: Python 3.11 (the package supports `>=3.10, <3.16` per `pyproject.toml`)

**Primary Dependencies**: pydantic 2.x, httpx, fastapi (proxy), openai SDK. No new dependency is introduced

**Storage**: N/A for the routing decision. The credential attribution reuses the existing spend-log `metadata` JSON, which carries `used_client_oauth_token` today at `litellm/proxy/_types.py:3770`. No migration

**Testing**: pytest, pytest-asyncio, respx for HTTP mocking

**Target Platform**: Linux server (the proxy), macOS and Linux for development

**Project Type**: web-service (the LiteLLM proxy and its router library)

**Performance Goals**: The scope decision runs once per routing attempt and is a provider-keyed dict lookup plus a model-name match. No measurable latency target; the work is on the order of the existing deployment-resolution cost per attempt

**Constraints**: Python max line length is 120, not 88. The five lint gates at `scripts/` compare each rule's codebase count against the merge-base, so a branch may not grow a rule's count. `reportAny` and `reportExplicitAny` share a fixed cap in `ANY_CAPS` at `scripts/type_check_gate.py`

**Scale/Scope**: One router-level setting, one shared matching helper, one enforcement point in the router, one metadata stamp. The change touches the router core, the proxy's config path, the shared core helper module, the proxy's auth module, and the docs

## Constitution Check

The project constitution at `.specify/memory/constitution.md` is an unfilled template, with every principle still a placeholder. There is no ratified principle to check against, which the assessment also recorded. The binding gates are therefore the repository's `AGENTS.md`, and this plan is checked against those

| Gate | Requirement | How this plan satisfies it |
|------|-------------|---------------------------|
| Composition over inheritance | Prefer composition | The scope is a plain value on the router, matched by a shared helper function. No new class hierarchy, no base class, no mixin |
| Never-nester, early returns | Flat control flow | The enforcement is a single early-return-shaped decision at the top of the binding method, before the existing credential work |
| No mutation | Immutable values, `Final` annotations, no rebinding | The matching helper is a pure function returning a decision. The rewrite of the scoped header builds a new value rather than mutating the existing one. Every new local is `Final` |
| Fully typed, no `Any` | Strong types everywhere | The scope is a typed mapping. The matching helper takes and returns concrete types. If the shared helper needs a pydantic-validated value, the validation happens in the caller and the typed value is passed in |
| Tagged unions plus `match` | Model states as unions | The credential attribution is a two-valued enum rather than a loose string, matched exhaustively |
| Standard over hand-rolled | Use the existing library | The model matching reuses the proxy's existing alias and wildcard primitives rather than writing a new matcher. The setting reuses the existing `router_settings` to `Router.__init__` path rather than new proxy plumbing |
| API-fragmentation-aware | One shared helper, not per-surface parsing | The scope decision is made once in the router binding method, which every surface already calls. It is not reimplemented per provider surface |
| No monster files, no file sprawl | Deliberate structure | The shared matching helper goes in the existing `litellm/litellm_core_utils/` area alongside the other provider-agnostic helpers. The new test file sits at the mirrored path |
| Comments only when necessary | No AI slop comments | The plan calls for a comment only on the non-obvious part, which is why the rewrite must happen on the attempt's own kwargs and not on shared state |
| No new failure class | A request must not fail only because of the routing step | The gate never raises on a request path. A misconfigured scope is rejected at construction, not per request |
| Tests that fail when the behavior breaks | Meaningful tests | The test plan below names the mutation each test must catch |

**Complexity Tracking**: no violations. The design adds one setting, one shared helper, one enforcement point, and one metadata stamp. No new project, no new repository pattern, no new credential field

**Post-design re-check**: re-evaluated after Phase 1, and the gate still passes. The design did not grow a second enforcement point when the alias and fallback-key findings came back, it sharpened the one enforcement point's match key. The wildcard primitives moved rather than being duplicated, so the "standard over hand-rolled" row still holds. The test plan grew two cases, one for an alias scope entry and one for a direct group entry, because the probes showed both spellings must reach the same decision. No row needs to be revisited

## Project Structure

### Documentation (this feature)

```text
specs/001-model-scoped-plan-forwarding/
├── plan.md              # This file (/speckit-plan command output)
├── spec.md              # The feature specification
├── research.md          # Phase 0 output: the verified findings and the decisions they drove
├── data-model.md        # Phase 1 output: entities, fields, validation rules
├── quickstart.md        # Phase 1 output: runnable validation scenarios
├── contracts/
│   ├── plan-scope-config.md       # The operator-facing configuration contract
│   └── credential-attribution.md  # The log-record contract
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
litellm/
├── types/
│   └── router.py                  # the scope setting's typed surface, next to ModelGroupSettings
├── router.py                      # the Router constructor argument and the enforcement point
├── litellm_core_utils/
│   └── get_provider_specific_headers.py   # the shared provider-scoped header helpers
└── proxy/
    ├── auth/
    │   └── auth_checks.py         # delegates model matching to the shared helper
    ├── litellm_pre_call_utils.py  # the proxy-side stamp, unchanged in behavior
    └── spend_tracking/
        └── spend_tracking_utils.py # reads the attribution, unchanged in behavior

tests/unit/
├── litellm_core_utils/
│   └── test_get_provider_specific_headers.py   # the shared helper's unit tests
├── router_utils/
│   └── test_forwarded_credential_scope.py     # the scope decision's unit tests
└── test_router/
    └── test_forwarded_credential_scope.py      # the enforcement point's unit tests

cookbook/ai_coding_tool_guides/
└── chatgpt_subscription_passthrough.md         # the operator guide, extended
```

**Structure Decision**: single project, the existing LiteLLM layout. The enforcement point is the router, so the router's constructor and the router's binding method are the two source files that change. The shared matching helper sits in `litellm/litellm_core_utils/` because both the router core and the proxy's auth module need it, and `litellm/litellm_core_utils/` is where the repository keeps helpers that both layers share. No new package

## Phase 0 Research

Complete. See [research.md](./research.md)

The load-bearing findings, all verified against commit `180f030292`:

- The caller's forwarded bearer reaches the upstream by **two independent routes**, the router's credential substitution at `litellm/router.py:4826-4841` and the outbound header merge at `litellm/main.py:5743` and `litellm/responses/utils.py:243`. A probe instrumenting both confirmed the bearer arrives on both. Gating one leaves the other open
- **Both routes read the same request-scoped value**, `kwargs["provider_specific_header"]`. One rewrite of that value closes both routes at once
- The rewrite is **hop-local**. A probe capturing the value at the entry of each attempt across a two-hop chain confirmed every attempt starts from the request's own value and none inherits the previous attempt's rewrite
- When the bearer is stripped, the ChatGPT provider's **existing precedence already falls through** to the target's own configured credential, with no provider change. The probe confirmed the upstream then received the deployment's own `api_key`
- The `forward_client_headers_by_model_group` literal at `litellm/types/router.py:181` is **declared but not enforced anywhere**. This feature does not adopt it
- The router's `fallback_on_unsupported_params` default is `True` at `litellm/router.py:1233`, so the ordinary fallback on a 400 needs no change
- The selected deployment's `model_name` is the **model group**, even when the caller requested an alias. The scope therefore matches on the group, and one scope entry covers both spellings
- The fallback chain is keyed on the **requested** name, not the group. Keying the fallback on the group silently never fires, which the operator guide has to say out loud
- The alias that matters is the **router's** `model_group_alias`, not the proxy's team alias, and the proxy's `check_model_access_helper` resolves only the latter. The scope matcher uses the router's own resolution and the proxy's wildcard primitive

## Phase 1 Design

Complete. See [data-model.md](./data-model.md) and [contracts/](./contracts/)

### The enforcement point

The scope decision is made in `Router._update_kwargs_with_deployment`, before the existing credential work at `litellm/router.py:4826-4841`. That method already runs on every routing attempt for every surface, and it already holds the selected deployment, so it is the only point where the routing decision and the credential binding meet

The decision has two outcomes

For an **in-scope** target, the request's scoped header is left as it is, and the existing behavior runs unchanged. The caller's bearer is forwarded, exactly as it is today

For an **out-of-scope** target, the attempt's scoped header is replaced with one that carries no authorization for the provider, and the existing credential precedence falls through to the target's own configured credential. No new provider path, no new flag, no new credential field

The rewrite targets the attempt's own request kwargs. The fallback chain copies the request kwargs per attempt at `litellm/router_utils/fallback_event_handlers.py:8552-8557`, and the probe confirmed the rewrite does not reach the next attempt. That is what makes the per-hop re-evaluation work: each attempt decides against its own selected target

### The matching helper

The scope matches against the selected deployment's model group, `deployment["model_name"]`, which is the operator-facing name. A probe at the enforcement point confirmed this holds even when the caller requested an alias, so one scope entry covers both spellings of a request

Two matching behaviors are needed. An entry that is a router model-group alias resolves to its target group first, using the router's own alias map at `litellm/router.py:12024-12030` and `litellm/router_utils/common_utils.py:96-114`. An entry that is a wildcard matches under the proxy's existing wildcard rule at `litellm/proxy/auth/auth_checks.py:7753` and `:7772`, `is_model_allowed_by_pattern` and `model_matches_any_wildcard_pattern_in_list`

Those wildcard primitives live under `litellm/proxy/auth/`, and the router core does not depend on the proxy layer. The primitives therefore move to the shared core location `litellm/litellm_core_utils/get_provider_specific_headers.py`, which already holds the provider-scoped header helpers, and the proxy's `auth_checks.py` delegates to them. One implementation, two callers

### The names in an operator's configuration are not interchangeable

The fallback chain is looked up by the **requested** model name, while the scope is matched against the **selected deployment's model group**. A probe with a `model_group_alias` confirmed the difference, because the lookup key is the name the caller asked for:

```
=== fallback keyed on the ALIAS (the requested name) ===
keyed on alias : attempted = ['openai/gpt-4o', 'openai/gpt-4o-mini']
=== fallback keyed on the ALIAS TARGET (the group) ===
keyed on target: attempted = ['openai/gpt-4o']
```

Keying the fallback on the alias reached the second deployment. Keying it on the target did not, and the request simply does not fall back

An operator exposing one client-facing name over two model groups therefore writes three different names: the client-facing name in `model_group_alias`, the fallback key using that same client-facing name, and the scope entry using the model group name. The operator guide and the quickstart say so explicitly, because getting it wrong fails silently as a missing fallback rather than as an error

### The configuration surface

The scope is a router setting, reaching `Router.__init__` through the existing path at `litellm/proxy/proxy_server.py:7300-7311`. The full contract is in [contracts/plan-scope-config.md](./contracts/plan-scope-config.md)

### The credential attribution

The router records which credential served the request onto the request metadata, reusing the existing `used_client_oauth_token` flag. The full contract is in [contracts/credential-attribution.md](./contracts/credential-attribution.md)

### The story that needs no code

The operator-facing guide at `cookbook/ai_coding_tool_guides/chatgpt_subscription_passthrough.md` gains the one-name arrangement composed from configuration alone. That story is a documentation change and is independently valuable

## Test Plan

Tests follow the repository conventions in `tests/AGENTS.md` and `tests/unit/AGENTS.md`. A test must fail when the behavior it names is broken, and must not pin a fact the code does not own

**The scope decision, in `tests/unit/router_utils/test_forwarded_credential_scope.py`**

- A target whose model group is in the scope is in scope. Mutation caught: an inverted comparison
- A target whose model group is not in the scope is out of scope. Mutation caught: a scope that always matches
- A provider with no scope declared leaves its targets in scope under today's provider-wide forwarding. Mutation caught: a missing-scope case that narrows instead
- One provider's scope does not affect another provider's forwarding. Mutation caught: a scope lookup that ignores the provider key
- A scope entry naming a router model-group alias matches the deployment whose group the alias resolves to. Mutation caught: a matcher that skips alias resolution
- A scope entry naming the deployment's own group matches that deployment. Mutation caught: a matcher that only resolves aliases and never compares the group directly
- A wildcard entry matches a model group under the wildcard. Mutation caught: a matcher that drops the wildcard branch
- A scope for a provider outside the forwarded-credential set is rejected. Mutation caught: validation that accepts any provider name

**The enforcement, in `tests/unit/test_router/test_forwarded_credential_scope.py`**

- A request resolved to an in-scope target carries the caller's bearer upstream. Mutation caught: a gate that always strips
- A request resolved to an out-of-scope target carries no part of the caller's bearer upstream, on **both** routes, the router's credential substitution and the outbound header merge. Mutation caught: a gate that rewrites one route only, which is the specific leak this feature exists to prevent
- An out-of-scope target authenticates with its own configured credential. Mutation caught: a request that fails because the bearer was removed and the fall-through broke
- A request that falls back from an in-scope target to an out-of-scope one carries no bearer on the fallback attempt, and the fallback attempt is authenticated by the fallback target's own credential. Mutation caught: a scope decision made once per request instead of per attempt
- A request that falls back from an out-of-scope target to an in-scope one **does** forward the bearer on the fallback attempt. Mutation caught: a strip that is permanent for the request rather than per attempt
- A request that names a model-group alias is scoped against the deployment's group, so the alias and the group reach the same decision. Mutation caught: a matcher that keys on the requested name
- The attempt that served the request is the one whose credential attribution is recorded. Mutation caught: an attribution stamped on the first attempt

**The shared helper, in `tests/unit/litellm_core_utils/test_get_provider_specific_headers.py`**

- The provider-scoped header helpers keep their current behavior for a provider that accepts a forwarded credential. Mutation caught: a refactor of the shared module that changes the existing precedence

**Mutation testing**: run the repository's mutation harness over the changed lines and confirm a kill rate above 90 percent. The tests above are written so that each one fails when its named behavior is broken

**End-to-end**: the e2e suite proves the feature against a live proxy with a scripted upstream, per `tests/e2e/AGENTS.md`. The scenario is one client-facing name over a plan-covered group and an ordinary group, a request that resolves to each, and an assertion on which credential reached the upstream. The e2e suite has no unit tests of a product feature and no mock upstream of our own code, so this scenario belongs in `tests/e2e/router/` alongside the other routing-behavior suites, and it drives the proxy through the shared transport

## Proof of fix

The repository's `AGENTS.md` asks for a live proxy and real upstream calls, not a pytest script as proof. The proof is a proxy running on `localhost:4000` from a config that declares the scope, driven with `curl` against a real ChatGPT subscription credential, showing:

- a request to the in-scope model returns the caller's own subscription response, with the upstream seeing the caller's bearer
- a request to the out-of-scope model does not carry the caller's bearer upstream, shown in the upstream's received request
- a request that falls back shows the fallback attempt authenticated by the fallback target's own credential
- the proxy's log for each request names the credential that served it

The commands and the expected upstream observations are written out in [quickstart.md](./quickstart.md)

## Risks

| Risk | Mitigation |
|------|------------|
| Gating only one of the two outbound routes leaves the leak open | The rewrite targets the single request-scoped value both routes read. The test asserts both routes are closed, and the second route is the one a naive implementation misses |
| The rewrite is applied to shared request state and leaks into the next attempt | The rewrite targets the attempt's own kwargs. The probe confirmed hop-locality, and a test asserts a fallback into an in-scope target still forwards the bearer |
| The shared helper's move breaks the proxy's existing model matching | The primitives move unchanged and the proxy delegates to them. The proxy's existing callers keep working, and a test asserts the shared module's current behavior |
| The scope narrows a provider the operator did not mean to narrow | The scope is keyed by provider. A provider absent from the mapping keeps today's forwarding, and a test asserts one provider's scope does not affect another's |
| An existing operator's Anthropic forwarding changes | Only providers with a declared scope are narrowed, and the Anthropic subscription provider is out of scope for this feature |
| The credential attribution leaks a secret into a log | The flag is a boolean. No credential value is recorded |
| The operator keys the fallback on the model group instead of the client-facing name, and the fallback silently never fires | The fallback lookup key is the requested name, which the probe confirmed. The operator guide and the quickstart name the two keys separately and say why they differ, and the e2e scenario asserts the fallback attempt actually reaches the second target |
| The operator scopes by the alias and the match is made against the group, so the scope never matches | The matcher resolves an alias entry to its target group before comparing, and the group is the match key. The unit tests cover both an alias entry and a direct group entry |
