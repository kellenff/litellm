---
description: "Task list for model-scoped token-plan forwarding"
---

# Tasks: Model-scoped token-plan forwarding

**Input**: Design documents from `/specs/001-model-scoped-plan-forwarding/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Test tasks are included. The specification's requirements and the repository's `AGENTS.md` both require meaningful regression tests for every behavior change, and this feature changes a security-relevant path (a credential must not reach an out-of-scope target).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g. US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `litellm/` at repository root, `tests/` at repository root
- Unit tests mirror `litellm/` in a parallel path under `tests/unit/`
- Python max line length is 120

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: The shared matching helper and the typed setting surface that every later phase depends on

- [ ] T001 [P] Move `is_model_allowed_by_pattern` and `model_matches_any_wildcard_pattern_in_list` from `litellm/proxy/auth/auth_checks.py` into `litellm/litellm_core_utils/get_provider_specific_headers.py` unchanged, so the router core can reach them without depending on the proxy layer
- [ ] T002 Make `litellm/proxy/auth/auth_checks.py` delegate to the relocated wildcard primitives so its existing callers keep the same behavior, and keep its own `_is_wildcard_pattern` helper next to them
- [ ] T003 [P] Add the `forward_client_credentials_to_model_groups` setting to `litellm/types/router.py` as a typed mapping from provider to a sequence of model group names, placed next to `ModelGroupSettings` at `litellm/types/router.py:1296`
- [ ] T004 Add the scope's validation to `litellm/types/router.py`: a provider key MUST be in `_FORWARDED_CREDENTIAL_ISOLATION_PROVIDERS` at `litellm/router.py:566`, currently `{"chatgpt", "anthropic"}`, and a provider's model list MUST be non-empty, because an empty list is ambiguous between "nothing is covered" and "no scope declared"

**Checkpoint**: The shared primitives and the typed setting exist, so the scope decision can be written and unit-tested on its own

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The scope decision itself, before any story consumes it

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 [P] Create `litellm/router_utils/forwarded_credential_scope.py` with a pure function that decides whether a selected deployment is in scope, taking the provider, the deployment's model group, the declared scope, and the router's model-group alias map, and returning a boolean
- [ ] T006 [P] Create `litellm/router_utils/forwarded_credential_scope.py`'s match function so a listed entry that is a router model-group alias resolves to its target group through `resolve_model_group_alias` at `litellm/router_utils/common_utils.py:96` before the comparison
- [ ] T007 [P] Create `litellm/router_utils/forwarded_credential_scope.py`'s match function so a listed entry that is a wildcard matches through the relocated `model_matches_any_wildcard_pattern_in_list`
- [ ] T008 [P] Create `tests/unit/router_utils/test_forwarded_credential_scope.py` covering the decision function: an in-scope group is in scope, an out-of-scope group is not, a provider with no declared scope leaves its targets in scope under today's provider-wide forwarding, one provider's scope does not affect another provider's forwarding, a listed alias resolves to the group it names, a listed group matches directly, a listed wildcard matches, and a scope for a provider outside `_FORWARDED_CREDENTIAL_ISOLATION_PROVIDERS` is rejected
- [ ] T009 Add the `forward_client_credentials_to_model_groups` constructor argument to `Router.__init__` at `litellm/router.py:1185`, store it on the router, and validate it at construction so a misconfiguration surfaces at boot rather than at the first request that would have leaked a credential, in `litellm/router.py`

**Checkpoint**: The scope decision exists, is validated, and is unit-tested, so the stories can wire it in independently

---

## Phase 3: User Story 1 - One client-facing name over plan-covered and ordinary targets, composed from configuration alone (Priority: P1) 🎯 MVP

**Goal**: The operator maintains one client-facing name for the caller instead of one name per credential plus a separate fallback arrangement, using configuration only

**Independent Test**: Configure two groups with different credentials, expose one name over both, send a request that resolves to each, and observe which credential served each. No code change required.

### Tests for User Story 1 (OPTIONAL - only if tests requested) ⚠️

> **NOTE**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] T010 [P] [US1] Add a test in `tests/unit/test_router/test_router.py` that a request routed through a `model_group_alias` to a fallback chain reaches the fallback deployment when the first deployment raises a 400, asserting the fallback attempt happened, in `tests/unit/test_router/test_router.py`

### Implementation for User Story 1

- [ ] T011 [US1] Extend `cookbook/ai_coding_tool_guides/chatgpt_subscription_passthrough.md` with the one-name arrangement composed from configuration alone, showing one model group per credential-bearing target, the client-facing name in `model_group_alias`, and the fallback relationship between the groups
- [ ] T012 [US1] In `cookbook/ai_coding_tool_guides/chatgpt_subscription_passthrough.md`, state explicitly that the fallback chain is keyed on the **requested** model name while the scope is matched against the **selected deployment's model group**, so an operator writes the client-facing name in both `model_group_alias` and the fallback key, and explain that keying the fallback on the group makes the fallback silently never fire
- [ ] T013 [US1] In `cookbook/ai_coding_tool_guides/chatgpt_subscription_passthrough.md`, state that the plan-covered target carries no `api_key` and no `chatgpt_auth_file` of its own, so a stripped bearer fails loudly instead of silently authenticating as some other credential

**Checkpoint**: User Story 1 is fully functional and testable independently, and ships on its own

---

## Phase 4: User Story 2 - The caller's subscription credential is forwarded only to targets the operator declared in scope (Priority: P2)

**Goal**: The credential follows the routing decision rather than the static target, so the operator no longer keeps a per-group arrangement in step with the router

**Independent Test**: Declare a scope covering one model group, configure a second same-provider target outside that scope, route requests to each, and observe that the caller's bearer appears upstream only for the in-scope target.

### Tests for User Story 2 (OPTIONAL - only if tests requested) ⚠️

> **NOTE**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] T014 [P] [US2] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a request resolved to an in-scope target carries the caller's bearer upstream, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T015 [P] [US2] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a request resolved to an out-of-scope target carries no part of the caller's bearer upstream on **both** routes, the router's credential substitution and the outbound header merge, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T016 [P] [US2] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that an out-of-scope target authenticates with its own configured credential rather than failing, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T017 [P] [US2] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a provider with no declared scope keeps today's provider-wide forwarding, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T018 [P] [US2] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a request naming a model-group alias is scoped against the deployment's group, so the alias and the group reach the same decision, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T019 [P] [US2] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a model group holding deployments from more than one provider forwards the caller's bearer only to the provider that accepts a forwarded credential, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T020 [P] [US2] Add a test in `tests/unit/litellm_core_utils/test_provider_specific_headers.py` that the relocated wildcard primitives keep their current behavior, in `tests/unit/litellm_core_utils/test_provider_specific_headers.py`

### Implementation for User Story 2

- [ ] T021 [US2] Implement the scope decision in `litellm/router.py`'s `Router._update_kwargs_with_deployment` at `litellm/router.py:4783`, placed before the existing credential work at `litellm/router.py:4826-4844`, so the decision is made for every routing attempt on every surface
- [ ] T022 [US2] In `litellm/router.py`'s `Router._update_kwargs_with_deployment` at `litellm/router.py:4783`, leave the request's scoped header untouched for an in-scope target, so the caller's bearer is forwarded exactly as it is today
- [ ] T023 [US2] In `litellm/router.py`'s `Router._update_kwargs_with_deployment` at `litellm/router.py:4783`, replace the attempt's scoped header with one carrying no authorization for the provider when the target is out of scope, so the provider's existing credential precedence falls through to the target's own configured credential, and so neither the credential-substitution route nor the outbound-header-merge route carries the caller's bearer
- [ ] T024 [US2] Rewrite the attempt's own request kwargs rather than shared request state in `litellm/router.py`, so the rewrite does not reach the next attempt
- [ ] T025 [US2] Add `forward_client_credentials_to_model_groups` to the `router_settings` path that reaches `Router.__init__` in `litellm/proxy/proxy_server.py`, confirming the existing plumbing at `litellm/proxy/proxy_server.py:7300-7311` needs no change

**Checkpoint**: User Story 2 is fully functional and testable independently

---

## Phase 5: User Story 3 - A fallback target never inherits the plan credential (Priority: P2)

**Goal**: The scope decision is re-made per routing attempt, so a target reached later in the chain is evaluated on its own

**Independent Test**: Route a request to a plan-covered target that rejects with a 400, and observe that the fallback attempt is authenticated by the fallback target's own credential and that the caller's bearer appears upstream only on the first attempt.

### Tests for User Story 3 (OPTIONAL - only if tests requested) ⚠️

> **NOTE**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] T026 [P] [US3] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a request falling back from an in-scope target to an out-of-scope one carries no bearer on the fallback attempt and that the fallback attempt is authenticated by the fallback target's own credential, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T027 [P] [US3] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a request falling back from an out-of-scope target to an in-scope one **does** forward the bearer on the fallback attempt, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T028 [P] [US3] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a 429 from a plan-covered target stays on the existing retry and cooldown path and is not served by a substituted metered target, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T029 [P] [US3] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a 400 from a plan-covered target reaches the caller as the upstream 400 itself, with no plan-rejection classification added, in `tests/unit/test_router/test_forwarded_credential_scope.py`

### Implementation for User Story 3

- [ ] T030 [US3] Confirm in `litellm/router.py` that the scope decision made in T021 runs on each attempt rather than once per request, and that each attempt receives a fresh kwargs dict, from the `**kwargs` unpacking at the hop boundary `litellm/router_utils/fallback_event_handlers.py:894` and the `input_kwargs` copy at `litellm/router.py:8552-8557`, which keeps the rewrite hop-local
- [ ] T031 [US3] Confirm in `litellm/router_utils/fallback_event_handlers.py` that the 400-to-fallback gate at `litellm/router_utils/fallback_event_handlers.py:259-266` needs no change, since the router's own `fallback_on_unsupported_params` default is on at `litellm/router.py:1233` and an operator who has turned it off sees the 400 stop the chain, which is their configuration working as configured
- [ ] T032 [US3] Add the e2e scenario in `tests/e2e/router/` that drives a live proxy through the shared transport with one client-facing name over a plan-covered group and an ordinary group, asserting that the fallback attempt is authenticated by the fallback target's own credential, following the conventions in `tests/e2e/AGENTS.md`

**Checkpoint**: User Stories 1, 2, and 3 are all independently functional

---

## Phase 6: User Story 4 - The operator can tell from the logs which credential served a request (Priority: P3)

**Goal**: The operator can answer which credential served a request without reading the model list and reconstructing the routing decision

**Independent Test**: Send a request that resolves to an in-scope target and one that resolves to an out-of-scope target, then read the two log records and see a different credential attribution on each.

### Tests for User Story 4 (OPTIONAL - only if tests requested) ⚠️

> **NOTE**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] T033 [P] [US4] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that the attempt that served the request is the one whose credential attribution is recorded, in `tests/unit/test_router/test_forwarded_credential_scope.py`
- [ ] T034 [P] [US4] Add a test in `tests/unit/test_router/test_forwarded_credential_scope.py` that a request served by the caller's forwarded bearer records `used_client_oauth_token` as true and a request served by the target's own credential records it as false, in `tests/unit/test_router/test_forwarded_credential_scope.py`

### Implementation for User Story 4

- [ ] T035 [US4] Write the per-attempt credential attribution onto the request metadata in `litellm/router.py`'s `Router._update_kwargs_with_deployment`, reusing the existing `used_client_oauth_token` flag typed at `litellm/types/utils.py:3374` and stored on spend logs at `litellm/proxy/_types.py:3770`, so no new column and no new field are needed
- [ ] T036 [US4] Confirm in `litellm/proxy/spend_tracking/spend_tracking_utils.py` that the flag reaches the spend log through the existing `resolve_used_client_oauth_token` at `litellm/proxy/spend_tracking/spend_tracking_utils.py:814-816` with no change, and that the router's per-attempt value takes precedence over the proxy's pre-routing stamp at `litellm/proxy/litellm_pre_call_utils.py:2658` for a request the router served
- [ ] T037 [US4] Confirm in `litellm/proxy/spend_tracking/spend_management_endpoints.py` at `litellm/proxy/spend_tracking/spend_management_endpoints.py:2559` that the flag stays filterable from the spend-logs endpoint with no new filter
- [ ] T038 [US4] Extend `cookbook/ai_coding_tool_guides/chatgpt_subscription_passthrough.md` with how the operator reads the attribution, noting that a plan-covered request reports no spend because every `chatgpt/` row in `litellm/model_prices_and_context_window_backup.json` carries no rates, so the flag is what makes such a request identifiable

**Checkpoint**: All four user stories are independently functional

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T039 [P] Run the mutation harness over the changed lines in `litellm/router.py`, `litellm/router_utils/forwarded_credential_scope.py`, and `litellm/types/router.py`, and confirm a kill rate above 90 percent, so each test fails when the behavior it names is broken
- [ ] T040 [P] Run the quickstart validation in `specs/001-model-scoped-plan-forwarding/quickstart.md` against a live proxy on `localhost:4000` with a real ChatGPT subscription credential, showing the in-scope target receiving the caller's bearer, the out-of-scope target receiving none, the fallback attempt authenticated by the fallback target's own credential, and the log naming the credential that served each request
- [ ] T041 [P] Run `make check` from the repository root and confirm the five lint gates pass with no rule's count grown on this branch
- [ ] T042 [P] Run the wiki ingest for the feature's research and plan decisions, per the `after_implement` hook registered in `.specify/extensions.yml`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies, can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion, BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 -> P2 -> P2 -> P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2), no dependencies on other stories. It is a documentation change and ships independently
- **User Story 2 (P2)**: Can start after Foundational (Phase 2), no dependencies on other stories
- **User Story 3 (P2)**: Can start after Foundational (Phase 2). It exercises the same enforcement point as US2 and its tests are most meaningful once US2's implementation lands, but it is a distinct guarantee and its own checkpoint
- **User Story 4 (P3)**: Can start after Foundational (Phase 2). It reads the attempt that US2 and US3 decide, so its tests are most meaningful once those land

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- The shared helper before the enforcement that uses it
- The enforcement before the attribution that reads it
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 2

```bash
# Launch all tests for User Story 2 together:
Task: "Add a test in tests/unit/test_router/test_forwarded_credential_scope.py that a request resolved to an in-scope target carries the caller's bearer upstream"
Task: "Add a test in tests/unit/test_router/test_forwarded_credential_scope.py that a request resolved to an out-of-scope target carries no part of the caller's bearer upstream on both routes"
Task: "Add a test in tests/unit/test_router/test_forwarded_credential_scope.py that an out-of-scope target authenticates with its own configured credential rather than failing"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL, blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational, foundation ready
2. Add User Story 1, test independently, deploy/demo (MVP)
3. Add User Story 2, test independently, deploy/demo
4. Add User Story 3, test independently, deploy/demo
5. Add User Story 4, test independently, deploy/demo
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 2 (the enforcement)
   - Developer B: User Story 1 (the operator guide)
   - Developer C: User Story 3 (the fallback guarantee)
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- The repository's `AGENTS.md` requires that a bug fix or a behavior change carry a regression test that fails when the behavior is broken, and that no test pin a fact the code does not own
- The repository's `AGENTS.md` asks for proof of a fix against a live proxy with real upstream calls rather than a pytest script, which is what T040 does
