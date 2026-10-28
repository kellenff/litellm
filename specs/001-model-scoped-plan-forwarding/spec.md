# Feature Specification: Model-scoped token-plan forwarding

**Feature Branch**: `001-model-scoped-plan-forwarding`

**Created**: 2026-10-28

**Status**: Draft

**Input**: User description: "An operator who fronts ChatGPT-subscription Codex models and ordinary models behind one LiteLLM proxy cannot expose a single client-facing entry point whose upstream credential follows the model the router actually selected. The operator declares, per model or model group, that the client's forwarded ChatGPT bearer is the credential for that target. The router forwards the bearer only when the selected deployment matches a declared scope. A target outside the scope uses its own configured credential. When a plan-backed target rejects a request with a 400, the router's existing fallback path takes the request to the configured fallback model, which is out of scope and therefore authenticates normally."

## Clarifications

### Session 2026-10-28

- Q: Is the plan credential the caller's own forwarded ChatGPT bearer, as the shipped single-model subscription flow already forwards, or a credential the proxy holds per deployment through a stored subscription login? → A: The caller's own forwarded ChatGPT bearer. The chosen approach names it directly, and per-deployment subscription logins are a separate concern this change does not touch. The proxy-held login stays the target's own configured credential
- Q: Does the scope attach to a model group, to an individual deployment, or to both? → A: The operator declares a scope over models or model groups, which is the vocabulary the operator already maintains. Matching follows the existing model-access check, which already handles aliases and wildcards, so an operator's existing list of model names keeps working
- Q: Does declaring a scope for one target narrow forwarding for every target of that provider, or does forwarding stay provider-wide until the whole provider is opted in? → A: A scope is an allowlist. Once an operator declares any scope for a provider, that provider's forwarding is narrowed to declared targets and an undeclared target of that provider uses its own configured credential. A provider with no declared scope keeps today's provider-wide forwarding, so an operator who opts in nothing sees no change
- Q: How does the scope gate both outbound paths the bearer travels? → A: It gates both. The bearer must not reach an out-of-scope target as the target's credential or as a merged request header, since gating one path leaves the other open
- Q: Does the operator's fallback-on-400 setting need to change? → A: No. The ordinary fallback path already exists and the router's own default falls back on a 400. An operator who has turned that off sees the 400 stop the chain, which is their configuration working as configured
- Q: What is the spend and labeling rule for plan-covered traffic? → A: Out of scope, as separate work. This change makes plan-covered traffic identifiable in the log and prices nothing, because the cost map carries no rates for the subscription model rows
- Q: May an exhausted plan silently substitute a metered target? → A: No. That stays an explicit operator opt-in and out of scope here, and a 429 keeps the existing retry and cooldown path

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One client-facing name over plan-covered and ordinary targets, composed from configuration alone (Priority: P1)

An operator fronts a ChatGPT-subscription Codex model group and an ordinary metered model group behind the same client-facing name. The operator keeps one group per credential-bearing target, points the name at both groups, and configures the fallback relationship between them. A caller's request that lands on the subscription group is authenticated by the caller's own ChatGPT login, and a request that lands on the ordinary group is authenticated by the ordinary group's own configured credential. The operator maintains one name for the caller instead of one name per credential plus a separate fallback arrangement

**Why this priority**: This is the arrangement the operator can adopt today with configuration and documentation only. It delivers the visible outcome the operator asked for, needs no new proxy behavior, and it is the shape against which the model-scoped forwarding in Story 2 is designed and tested

**Independent Test**: Can be fully tested by configuring two groups with different credentials, exposing one name over both, sending a request that resolves to each group, and observing which credential served each. Delivers the one-name arrangement with no code change

**Acceptance Scenarios**:

1. **Given** a ChatGPT-subscription group and an ordinary group, **When** an operator points one client-facing name at both and configures them as each other's fallback, **Then** the operator maintains a single name for the caller
2. **Given** that arrangement, **When** a request resolves to the subscription group, **Then** the request is authenticated by the caller's own ChatGPT login
3. **Given** that arrangement, **When** a request resolves to the ordinary group, **Then** the request is authenticated by the ordinary group's own configured credential
4. **Given** that arrangement, **When** the subscription group rejects a request with a 400, **Then** the request is served by the ordinary fallback group under the ordinary group's own credential

---

### User Story 2 - The caller's subscription credential is forwarded only to targets the operator declared in scope (Priority: P2)

An operator declares, per model or model group, that the caller's forwarded ChatGPT bearer is the credential for that target. A request whose selected target falls inside a declared scope carries the caller's bearer upstream. A request whose selected target falls outside every declared scope carries no part of the caller's bearer upstream and is authenticated by the target's own configured credential. The operator no longer has to keep a per-group arrangement in step with the routing decision, because the credential follows the decision the router actually made

**Why this priority**: This is the increment over Story 1. Story 1 still makes the operator hand-maintain which target implies which credential, and that mapping goes stale whenever the plan's coverage moves. Story 2 makes the credential follow the routing decision rather than the static target

**Independent Test**: Can be fully tested by declaring a scope covering one model group, configuring a second same-provider target outside that scope, routing requests to each, and observing that the caller's bearer appears upstream only for the in-scope target

**Acceptance Scenarios**:

1. **Given** a declared scope covering a model group, **When** the router selects a target in that group, **Then** the caller's forwarded ChatGPT bearer is the credential sent upstream
2. **Given** a target outside every declared scope, **When** the router selects it, **Then** the request is authenticated by that target's own configured credential
3. **Given** a target outside every declared scope, **When** the request is sent upstream, **Then** no part of the caller's forwarded bearer is present in the outbound request
4. **Given** a scope covering a model group, **When** the caller supplies no ChatGPT bearer on the request, **Then** the target's own configured credential is used and the request is not failed for the missing bearer
5. **Given** a scope that covers a model group holding targets from more than one provider, **When** the router selects the non-subscription target in that group, **Then** the caller's bearer is not forwarded to it
6. **Given** an operator who has declared no scope for a provider, **When** a request resolves to a target of that provider, **Then** the caller's bearer is forwarded exactly as it is today
7. **Given** a scope declaration, **When** the proxy chooses the credential for a request, **Then** it does not consult a local list of plan coverage first, and the request is attempted against the selected target
8. **Given** a caller that wants a particular upstream credential, **When** the caller sends a request, **Then** no request parameter selects the upstream credential and the scope stays the operator's configuration
9. **Given** a single-model subscription target with no scope declared, **When** the caller supplies its own ChatGPT bearer, **Then** the credential precedence is the one that already ships, unchanged
10. **Given** a scope declaration naming a target, **When** the target's provider is one that does not accept a forwarded client credential, **Then** the caller's bearer is not forwarded to it and the set of providers accepting a forwarded credential is unchanged

---

### User Story 3 - A fallback target never inherits the plan credential (Priority: P2)

A plan-covered target rejects a request with a 400. The request falls through to the configured fallback model. The fallback target is out of scope, so it authenticates with its own configured credential and the caller's bearer never reaches it. When the router moves to a new target, the scope decision is made again for that target rather than carried over from the attempt that failed

**Why this priority**: The scope decision has to be re-made per routing attempt. If it is made once per request instead, a fallback target inherits a credential it was never scoped for, which is the exact failure the operator is trying to prevent. This story is what makes the guarantee hold under fallback

**Independent Test**: Can be fully tested by routing a request to a plan-covered target that rejects with a 400, and observing that the fallback attempt is authenticated by the fallback target's own credential and that the caller's bearer appears upstream only on the first attempt

**Acceptance Scenarios**:

1. **Given** a plan-covered target that rejects with a 400, **When** the router falls back to the configured fallback model, **Then** the fallback attempt is authenticated by the fallback target's own configured credential
2. **Given** the same failure, **When** the fallback attempt is sent upstream, **Then** the caller's forwarded bearer is not present in that request
3. **Given** a fallback chain where a later target is also inside a declared scope, **When** the router reaches that target, **Then** the caller's bearer is forwarded for that attempt because the scope covers it
4. **Given** a plan-covered target that rejects with a 429, **When** the router handles the rejection, **Then** the request stays on the existing retry and cooldown path and is not served by a substituted metered target
5. **Given** a plan-covered target that rejects with a 400, **When** the rejection reaches the caller, **Then** the caller receives the upstream 400 itself, with no plan-rejection classification added by the proxy

---

### User Story 4 - The operator can tell from the logs which credential served a request (Priority: P3)

An operator reads the proxy's log for a request and sees whether the caller's forwarded ChatGPT credential served it or the target's own configured credential did. The operator can answer that question without reading the model list and without reconstructing the routing decision

**Why this priority**: Three outcomes the operator currently cannot tell apart are a request rejected upstream because the selected model was outside the caller's plan, a request that quietly ran on the wrong credential, and a plan-covered request that reports no spend. The credential attribution in the log is the part this feature can deliver, and it is what lets an operator notice a stale scope declaration

**Independent Test**: Can be fully tested by sending a request that resolves to an in-scope target and one that resolves to an out-of-scope target, then reading the two log records and seeing a different credential attribution on each

**Acceptance Scenarios**:

1. **Given** a request served by the caller's forwarded ChatGPT bearer, **When** the operator reads the request's log record, **Then** the record states that the forwarded credential served it
2. **Given** a request served by a target's own configured credential, **When** the operator reads the request's log record, **Then** the record states that the target's own credential served it
3. **Given** a request served under a plan-covered target, **When** the operator reads the request's log record, **Then** the request is identifiable as plan-covered even though it reports no spend

### Edge Cases

- The router selects an in-scope target but the caller supplied no ChatGPT bearer. The target's own configured credential applies, and the missing bearer does not fail the request on its own
- The router selects an out-of-scope target that is itself a ChatGPT-subscription target with its own stored subscription login. That target authenticates from its own stored login and the caller's bearer does not reach it
- The caller's bearer reaches an out-of-scope target. It does not, through any outbound path, whether it arrives as the target's credential or as a merged request header. Gating one path and not the other leaves the leak open
- A declared scope covers a model group whose deployments span more than one provider. Only the provider that accepts a forwarded subscription credential is eligible to receive it
- The scope declaration names a target that the plan does not actually cover. The proxy does not detect this and does not predict eligibility. The request is attempted, upstream rejects it with a 400, and the ordinary fallback path carries the request onward
- The operator's fallback model is a target inside a declared scope. The fallback attempt forwards the caller's bearer, because the scope covers that target
- The upstream rejects a plan-covered target with a 429 rather than a 400. The request stays on the existing retry and cooldown path. An exhausted plan does not silently substitute a metered target
- The operator declares no scope for the provider at all. The proxy keeps today's provider-wide forwarding behavior rather than narrowing it silently
- The operator declares a scope for one ChatGPT target and runs a second ChatGPT target outside that scope. The second target stops receiving the caller's bearer and authenticates with its own configured credential, which is a change from the provider-wide behavior that target had before the scope was declared
- The caller supplies a bearer that is not a ChatGPT subscription credential. It is not forwarded under any scope

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The operator MUST be able to declare that the caller's forwarded ChatGPT bearer is the credential for the targets in a named scope, expressed as a set of models or model groups. The scope is an allowlist over the model vocabulary the operator already maintains, and a declared target matches through the same alias and wildcard handling the proxy applies to model access checks
- **FR-002**: The proxy MUST forward the caller's forwarded ChatGPT bearer upstream only when the selected target matches a declared scope. The plan credential is the caller's own forwarded bearer, so the proxy holds no plan credential of its own
- **FR-003**: A target outside every declared scope MUST be authenticated by that target's own configured credential
- **FR-004**: The caller's forwarded ChatGPT bearer MUST NOT be present in the outbound request to a target outside every declared scope, through any outbound path, including both the path that supplies the target's credential and the path that merges request headers
- **FR-005**: The scope decision MUST be re-evaluated for every routing attempt, so that a target reached later in the chain is evaluated on its own and not on the outcome of the attempt that preceded it
- **FR-006**: When no scope is declared for the provider in question, the proxy MUST preserve the existing provider-wide forwarding behavior. Once an operator declares any scope for a provider, that provider's forwarding is narrowed to declared targets, and an undeclared target of the same provider authenticates with its own configured credential
- **FR-007**: The proxy MUST handle a 400 from a plan-covered target on the existing fallback path, so that the request reaches the configured fallback model
- **FR-008**: The proxy MUST NOT classify a plan rejection separately from any other 400. The rejection reaches the caller as the upstream 400 it is
- **FR-009**: The proxy MUST NOT attempt to determine whether a target is covered by a caller's plan before the request is attempted
- **FR-010**: The proxy MUST NOT hold a local copy of the provider's plan-to-model coverage policy. A scope declaration is the operator's assertion, and the provider is the sole authority on actual coverage
- **FR-011**: The proxy MUST keep 429 handling on the existing retry and cooldown path, and MUST NOT substitute a metered target for an exhausted plan
- **FR-012**: Every request's log record MUST state which credential served it, distinguishing the caller's forwarded ChatGPT bearer from the target's own configured credential
- **FR-013**: A request served by a caller's forwarded ChatGPT bearer MUST be identifiable in the log as plan-covered
- **FR-014**: The upstream credential MUST NOT become a client-selectable request parameter. A caller may supply its own credential and nothing else, and the scope remains operator-configured
- **FR-015**: The proxy MUST NOT change the credential precedence that the shipped single-model ChatGPT subscription flow already uses, where the client's own credential is preferred over the configured key, which is preferred over the proxy's stored subscription login
- **FR-016**: The proxy MUST NOT widen the set of providers that accept a forwarded client credential
- **FR-017**: The operator MUST be able to compose the one-name arrangement of Story 1 from configuration alone, without any new proxy behavior being required for it to work

### Key Entities *(include if feature involves data)*

- **Plan scope**: the operator's declaration that the caller's forwarded ChatGPT credential is the credential for the targets it names. Holds the set of models or model groups in scope
- **Forwarded client credential**: the caller's own ChatGPT subscription bearer, carried on the inbound request, that the operator has declared to be the credential for in-scope targets
- **Configured target credential**: the credential a target carries on its own, whether a configured key or a stored subscription login. It authenticates every request to a target outside every declared scope
- **Selected target**: the deployment the router resolved for the current routing attempt, and the thing a scope is matched against
- **Routing attempt**: one attempt of a request against one selected target. A request makes a new attempt each time it falls back, and each attempt makes its own scope decision
- **Credential attribution record**: the per-request log entry naming which of the two credentials served the request, and marking the request as plan-covered when the forwarded one did

### Out of Scope

- A local copy of the provider's plan-to-model entitlement policy, and any attempt to predict eligibility before a request is attempted
- Distinguishing a plan rejection from an ordinary upstream 400 in the proxy's own behavior or in its logs
- Any change to 429 handling, which stays on the existing retry and cooldown path
- The Codex-native passthrough route as a routing surface, since it forwards verbatim and never consults the router
- Any change to the credential precedence that shipped for the existing single-model ChatGPT subscription flow
- Making the upstream credential a client-selectable request parameter
- The Anthropic subscription provider
- Subscription account management in the dashboard
- Per-token pricing for subscription models, beyond making plan-covered traffic identifiable in the log
- Deciding the exhaustion substitution policy on the operator's behalf, which stays an explicit opt-in

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator exposes one client-facing name that covers both plan-covered and ordinary targets, replacing the baseline of one name per credential plus separate fallback configuration
- **SC-002**: Zero requests send the caller's forwarded ChatGPT bearer to a target outside every declared scope, across every routing attempt including fallback hops
- **SC-003**: Zero requests fail only because of the scope decision. The scope decision introduces no failure class of its own
- **SC-004**: Every request's log record names the credential that served it, so an operator can answer the question from the log alone
- **SC-005**: A 400 from a plan-covered target reaches the configured fallback model, and the fallback attempt is served under the fallback target's own credential
- **SC-006**: The number of distinct client-facing model names an operator maintains to serve both plan-covered and ordinary targets falls from one per credential plus separate fallback configuration to one

The plan-ineligibility classification metric and the nonzero-spend metric from the problem definition are deliberately not carried. The operator traded both away in favor of the ordinary fallback path, and the cost map still carries no rates for the subscription model rows, so a plan-covered request continues to report no spend

## Assumptions

- The caller's own forwarded ChatGPT bearer is the plan credential, matching the shipped single-model subscription flow and the operator's own proposal. A credential the proxy holds per deployment is a separate concern that this scope does not change
- The operator's router configuration falls back on a 400, which is the router's own default. An operator who has turned that off sees a 400 stop the fallback chain instead of reaching the fallback model
- The operator's fallback model is one the operator is willing to bill, since the ordinary fallback path treats a plan rejection as any other rejection
- An operator who runs more than one ChatGPT target today relies on the current provider-wide forwarding, so declaring a scope changes the behavior of their other ChatGPT targets. Declaring nothing leaves their current behavior untouched
- The operator accepts that a plan rejection and an ordinary bad request are close enough in effect to treat alike, since the request still reaches the fallback model either way and the operator reads the upstream message when they need the reason
- The operator accepts that an exhausted plan does not silently substitute a metered target, since a 429 stays on the existing retry and cooldown path
- The operator is willing to give up a labeled spend for a plan-covered request, since the cost map carries no rates for those model rows and that work is separate from the routing change
- The one-name arrangement of Story 1 is composed from configuration alone and ships independently of the model-scoped forwarding in Story 2
- The scope declaration names models or model groups, and the operator maintains it as the list of targets the plan is believed to cover. A stale entry causes one failed round trip and a fallback, which is the ordinary behavior of any other upstream rejection
