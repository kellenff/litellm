---
title: Router strategies
type: component
sources: [S030, S031, S032, S033, S033, S035, S036, S037, S038, S039]
updated: 2026-09-26
---

The router in this repo (`litellm/router_strategy/`) ships a collection of independent strategies a deployment can pick from. Each one is a `CustomLogger` that scores the eligible deployments and returns one. They share `BaseRoutingStrategy` for cache plumbing (S039), and they cooperate with helpers under `litellm/router_utils/` for cooldown, retry-policy resolution, affinity, and pre-call checks (S039).

**Metric-based pickers.** `lowest_tpm_rpm.py` counts tokens-per-minute and requests-per-minute per minute-bucket and routes to the least-loaded group (S030). `lowest_tpm_rpm_v2.py` keeps the same surface but subclasses `BaseRoutingStrategy`, batches Redis writes, and is meant to work across instances; it caches per model, not per model-group, and uses `redis.mget` plus `redis.incr` (S030). `lowest_latency.py` scores on response time, or time-to-first-token for streaming, with optional percentile and buffer knobs (S031). `lowest_cost.py` routes by `input_cost_per_token + output_cost_per_token` from `model_info`, refreshed from `model_prices_and_context_window.json` (S032). `least_busy.py` tracks in-flight requests per deployment with a 1-hour TTL and prefers the idle one (S033). These are stateless scorers: they need only the deployment table and a working cache.

**Distribution strategies.** `simple_shuffle.py` is the default fallback: weighted random over per-deployment weights, then global metric ties, respecting scoped `_router_weights` per request (S033). `tag_based_routing.py` filters deployments by metadata tags; subset, default-tags, `!tag` excludes, `&tag` requires; so teams and tiers can be carved out declaratively (S033).

**Cost gates.** `budget_limiter.py` is a post-filter, not a scorer: it accepts whatever scorer upstream picked and rejects deployments that have burned through their configured `$ budget_limit` over the `time_period` (S035). `savings_baseline.py` defines the counterfactual a complexity router is measured against: the priciest model in the hardest configured tier, ranked against a fixed reference request, not against live traffic (S036).

**Agent-confidence routing.** `lar1_routing.py` routes by LAR-1 agent confidence metadata on the request, with configurable `low`/`medium`/`high` thresholds (default `0.3 / 0.5 / 0.7`) (S037). Pick it when an upstream agent publishes a confidence score and you want a separate model tier per confidence level.

**LLM-driven routers.** `complexity_router.py` runs a local-or-LLM classifier over the request (regex/keyword by default under 1ms; optionally an LLM or capability classifier), scores complexity across dimensions, and routes to a tier (S038). `adaptive_router.py` per-request Thompson-samples a Beta posterior per `(request_type, model)`, then updates the posterior from post-call signals; quality and cost are combined in a weighted linear sum (S038). `auto_router.py` is the legacy semantic embedder: encode the request, find the nearest configured route, hand it off to `default_model` (S038). `quality_router.py` reuses the complexity classification and routes to a deployment whose declared `quality_tier` matches the requested tier, with optional keyword short-circuit (S038). All four are model-driven and need at least one extra model in the deployment table to act as classifier, embedder, or evaluator (S038).

**Trade-off in one line each.** TPM/RPM pickers (S030) optimize availability, latency (S031) optimizes user-perceived speed, cost (S032) optimizes dollars, least-busy (S033) optimizes throughput under bursty traffic, tag (S033) gives operator control, budget (S035) enforces dollars, complexity/adaptive/quality (S038) optimize for "right model for this request" but pay an extra inference or classification cost on the hot path. When in doubt start on `simple_shuffle` and upgrade only when a metric forces it.

Related: [Routing decisions](./routing-decisions.md), [Proxy server](./proxy-server.md).