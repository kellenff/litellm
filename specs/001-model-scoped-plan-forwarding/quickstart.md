# Quickstart: Validating model-scoped token-plan forwarding

**Feature**: `specs/001-model-scoped-plan-forwarding`
**Date**: 2026-10-28

This guide proves the feature end to end against a running proxy. It follows the repository's rule that a feature is proven with a live proxy and real upstream calls, not with a test script

## What is being proved

Three things, in order of how badly a mistake would hurt

1. An in-scope target receives the caller's own ChatGPT bearer upstream
2. An out-of-scope target receives **no part of** the caller's bearer upstream, and authenticates with its own configured credential
3. A fallback hop re-decides the scope, so a fallback target never inherits the plan credential, and a fallback back into scope does forward the bearer again

The full configuration contract is in [contracts/plan-scope-config.md](./contracts/plan-scope-config.md). The credential attribution contract is in [contracts/credential-attribution.md](./contracts/credential-attribution.md)

## Prerequisites

- A proxy checkout with the change applied
- A ChatGPT subscription credential for the caller, exported as `CHATGPT_BEARER`. This is the caller's own login, the credential the shipped subscription flow already forwards
- An upstream that shows the credential it received. The `chatgpt.com` backend rejects an API key with `api_key_not_supported`, which is itself a usable signal: a request that authenticates with the caller's bearer never produces that error, and a request that falls back to an API-key deployment does
- A second, ordinary model group for the out-of-scope target, carrying its own `api_key`
- The `curl` binary and `jq` for reading the responses

## The proxy configuration

Two model groups and one client-facing name. The `codex-plan` group is the plan-covered target, the `ordinary` group is out of scope, and `codex-alias` is the name callers request

```yaml
model_list:
  - model_name: codex-plan
    litellm_params:
      model: chatgpt/gpt-5.3-codex
    model_info:
      mode: responses

  - model_name: ordinary
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY
    model_info:
      mode: chat

router_settings:
  model_group_alias:
    codex-alias: codex-plan

  forward_client_credentials_to_model_groups:
    chatgpt:
      - codex-plan

  fallbacks:
    - codex-alias: ["ordinary"]
```

Three details matter for the proof

`codex-plan` carries no `api_key` and no `chatgpt_auth_file` of its own. It is the deployment whose credential comes from the caller. That is what makes the difference between the two requests legible: if the bearer were stripped, this target would have nothing left to authenticate with, and the request would fail rather than silently succeed on the wrong credential

The three names are not interchangeable. `codex-alias` is the name callers request and the key the fallback chain is looked up by, so the fallback is keyed on `codex-alias`. The scope is matched against the deployment the router selected, whose model group is always `codex-plan`, so the scope names `codex-plan`

`codex-alias` is the single client-facing name. It reaches the plan-covered group, and the fallback relationship carries it to the ordinary group when the plan-covered group cannot serve the request

## Start the proxy

```bash
cd /Users/kellen/Projects/litellm
export CHATGPT_BEARER="$(cat ~/.chatgpt-bearer)"
litellm --config ./plan_scope_config.yml --port 4000 --detailed_debug 2>&1 | tee litellm.log
```

Wait for the proxy to report that it is listening on port 4000

## Step 1: an in-scope target receives the caller's bearer

The caller's ChatGPT bearer and the caller's LiteLLM key cannot both ride the same `Authorization` header. Send the LiteLLM key as `x-litellm-api-key`, which is the separate-key convention the shipped guide already documents, and the ChatGPT bearer as `Authorization`

```bash
curl -sS http://localhost:4000/v1/responses \
  -H "x-litellm-api-key: $LITELLM_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHATGPT_BEARER" \
  -d '{
    "model": "codex-alias",
    "input": "reply with the single word: plan-covered",
    "stream": false
  }' | jq -r '.output[0].content[0].text'
```

**Expected**: the caller's subscription serves the request. The response is a normal completion and the upstream never returns `api_key_not_supported`, which is the signal that the caller's bearer, not the deployment's `api_key`, was used

**Expected in the proxy log**: the request's record names the forwarded credential

```bash
grep -o '"used_client_oauth_token":[a-z]*' litellm.log | tail -1
```

**Expected**: `"used_client_oauth_token":true`

## Step 2: an out-of-scope target receives no part of the caller's bearer

Request the ordinary group directly, under the same client-facing name's scope rules

```bash
curl -sS http://localhost:4000/v1/responses \
  -H "x-litellm-api-key: $LITELLM_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHATGPT_BEARER" \
  -d '{
    "model": "ordinary",
    "input": "reply with the single word: ordinary",
    "stream": false
  }' | jq -r '.output[0].content[0].text'
```

**Expected**: the request is served by the ordinary group under its own `api_key`. The caller's bearer is absent from the outbound request

**Expected in the proxy log**:

```bash
grep -o '"used_client_oauth_token":[a-z]*' litellm.log | tail -1
```

**Expected**: `"used_client_oauth_token":false`

If the bearer had leaked, the upstream would have authenticated as the caller's subscription instead, and the flag would read `true`

To see the outbound credential directly, point the ordinary group at a host that echoes the `Authorization` header it received. Add a deployment whose `api_base` is that echo host and reissue the request. The echo must show the ordinary group's own key, never the caller's bearer

## Step 3: a fallback hop re-decides the scope

Make the in-scope target fail with a 400, so the request falls back to the ordinary group

The cleanest way to produce a plan-shaped 400 is to point the in-scope group at a model the caller's plan does not cover. Set `codex-plan`'s model to one the subscription does not include, then request it

```bash
curl -sS http://localhost:4000/v1/responses \
  -H "x-litellm-api-key: $LITELLM_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CHATGPT_BEARER" \
  -d '{
    "model": "codex-alias",
    "input": "reply with the single word: fallback",
    "stream": false
  }' | jq -r '.output[0].content[0].text'
```

**Expected**: the in-scope attempt is rejected upstream with a 400, the existing fallback path carries the request to the ordinary group, and the ordinary group serves it under its own credential. The caller sees a normal completion

**Expected in the proxy log**: the request's record reads `"used_client_oauth_token":false`, because the attempt that served the request was the fallback attempt and it used the ordinary group's own credential

This is the case the whole feature exists for. A scope decision made once per request would have handed the ordinary group the caller's bearer, and the flag would have read `true`

## Step 4: the reverse fallback still forwards the bearer

Change the scope so the fallback target is the in-scope one, and make the first group the one that fails

```yaml
router_settings:
  forward_client_credentials_to_model_groups:
    chatgpt:
      - ordinary

  fallbacks:
    - codex-alias: ["codex-plan"]
```

**Expected**: the first attempt on `ordinary` fails, the fallback lands on `codex-plan`, and because `codex-plan` is now in scope the caller's bearer **is** forwarded on that attempt

**Expected in the proxy log**: `"used_client_oauth_token":true`

This proves the rewrite is per attempt rather than permanent for the request. A strip that stuck for the whole request would read `false` here and the fallback would have had no credential to use

## Step 5: no scope declared preserves today's behavior

Remove the `forward_client_credentials_to_model_groups` block entirely and reissue step 1's request

**Expected**: the caller's bearer reaches the `chatgpt` group even though the scope no longer names it, because a provider with no scope declared keeps the existing provider-wide forwarding. An operator who opts in nothing sees no change

## Step 6: a scope for a provider outside the forwarded-credential set is rejected

```yaml
router_settings:
  forward_client_credentials_to_model_groups:
    openai:
      - ordinary
```

**Expected**: the proxy refuses to start and names the allowed providers. The scope narrows forwarding, it never widens it to a provider that does not accept a forwarded client credential

## Running the automated suites

```bash
# The scope decision's unit tests
pytest tests/unit/router_utils/test_forwarded_credential_scope.py -v

# The enforcement point's unit tests
pytest tests/unit/test_router/test_forwarded_credential_scope.py -v

# The shared helper's unit tests
pytest tests/unit/litellm_core_utils/test_get_provider_specific_headers.py -v

# The lint and type gates
make check
```

## What each step would catch

| Step | The mistake it catches |
|------|------------------------|
| 1 | A gate that always strips, so no plan-covered target ever receives the caller's bearer |
| 2 | A gate that closes the router's credential substitution but leaves the outbound header merge open, so the bearer still reaches an out-of-scope target |
| 3 | A scope decision made once per request, so the fallback target inherits the plan credential |
| 4 | A strip that sticks for the whole request, so a later in-scope attempt has no bearer to forward |
| 5 | A scope that narrows forwarding even when the operator declared nothing |
| 6 | A scope that widens the set of providers accepting a forwarded client credential |
