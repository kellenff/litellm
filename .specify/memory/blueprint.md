# litellm Blueprint

**Status**: Living document — the authoritative backlog + architecture map for this project.

<!--
  HOW THIS DOCUMENT WORKS
  =======================
  Decreasing-detail map. Sections are DETAILED (backlog: design pending), SETTLED
  (digest + pointer; owner is a feature spec specs/<slug> or the CODE itself —
  brownfield), or CONTEXT (framing; never backlog). Ground truth is the filesystem;
  the machine-readable provenance markers under each heading are what the oracle
  reads — banners and prose are cosmetic. To change a code-owned slice:
  /speckit.specify it as usual; distill collapses its section when the spec ships.
  STRUCTURE IS COMPUTED (blueprint-slice.sh scaffold), never improvised: to change
  the cut, edit blueprint-config.yml and re-derive; the check gate validates
  structural conformance.
-->

## Table of Contents

- `backend` — The UI backend component is a control-plane FastAPI app that reuses the shared proxy application and trims its route table down to the management and admin surface the dashboard consumes, leaving every LLM data-plane path to the gateway component; **code-owned**
- `ci_cd` — This section holds the pull-request guard scripts and the standards documents that gate changes to the repository, enforcing cost-map consistency, spend-log schema ownership, safe migration generation, and secret-scanning conventions; **code-owned**
- `cookbook` — Example notebooks and scripts that show how to drive LiteLLM as an SDK, as a router and as a proxy, kept as user-facing sample code rather than part of the shipped package; **code-owned**
- `db_scripts` — This section collects the operator-run SQL and Python scripts for one-off Postgres maintenance against the proxy database, such as converting the spend-log table to a range-partitioned table, rebuilding lifetime key spend from spend logs, and creating the proxy's reporting views; **code-owned**
- `docker` — This section defines the container images and compose stacks that ship LiteLLM, covering the rootless all-in-one proxy image with its embedded admin UI, the migration-qualification image variant, and the quickstart and tracing compose stacks used for local evaluation; **code-owned**
- `enterprise` — The commercially licensed LiteLLM Enterprise add-on, shipped as the separate litellm-enterprise distribution; **code-owned**
- `examples` — This section holds the example proxy configuration that demonstrates the LAR-1 router strategy, registering several local Ollama models behind one model name and letting the router pick between them by confidence; **code-owned**
- `gateway` — The gateway component is the LLM data-plane process: it reuses the shared proxy application but keeps only the completion, embedding, media, passthrough and realtime paths, and it supervises an in-container PgBouncer so a single pooler fronts the writer database for all workers; **code-owned**
- `helm` — This section holds the two Helm charts that deploy LiteLLM on Kubernetes: the componentized chart that runs gateway, UI backend, UI and a migration Job as separate workloads, and the older single-service chart that also bundles Postgres and Redis; **code-owned**
- `litellm-proxy-extras/dist` — Build output, not source: the published wheels and source tarballs of the litellm-proxy-extras package, one pair per released version from 0.1.0 through 0.4.60, kept in the repository so every released artifact stays on record; **code-owned**
- `litellm-proxy-extras/litellm_proxy_extras` — The importable litellm_proxy_extras package: the proxy's Prisma schema and its SQL migration history, plus the Python machinery that applies them under a lock and refuses changes the existing rows would reject; **code-owned**
- `litellm-proxy-extras` (remainder) — Packaging, licensing and operator runbooks for the separately published litellm-proxy-extras distribution, sitting outside the importable package directory that holds the code; **code-owned**
- `litellm-rust` — The Rust port of the gateway, a Cargo workspace of crates that reimplements provider translation, routing, caching, auth and the HTTP gateway in Rust and exposes it back to Python through a PyO3 bridge; **code-owned**
- `litellm/_v2` — The experimental v2 surface: today only a cache facade that builds a native Rust cache handle and injects it behind the existing BaseCache interface, deliberately kept out of the documented SDK; **code-owned**
- `litellm/a2a_protocol` — The Agent-to-Agent protocol client, wrapping the upstream a2a SDK so callers can resolve an agent card and send or stream messages to a remote agent, with LiteLLM logging, cost attribution and provider-specific adapters; **code-owned**
- `litellm/anthropic_interface` — The Anthropic-native surface of the SDK, exposing Anthropic-shaped message creation plus the Anthropic error taxonomy that the proxy, the provider layer and the integrations all share; **code-owned**
- `litellm/batches` — The batch job API, covering provider batch creation, retrieval, listing and cancellation and settling the cost and per-request usage of a batch once its results land; **code-owned**
- `litellm/caching` — The SDK's cache tier: a pluggable cache facade over Redis, S3, GCS, Azure Blob, disk, in-memory and semantic-vector backends, together with the request-level handler that decides what may be cached and how a hit is replayed; **code-owned**
- `litellm/completion_extras` — The completion-only extras: the bridge that turns a chat-completions request into a Responses API request and maps the answer back, kept apart from the Responses implementation itself; **code-owned**
- `litellm/compression` — Context compression for long conversations: it scores the messages, keeps the protected ones, replaces the rest with retrievable stubs, and hands the model a retrieval tool that can pull the dropped content back; **code-owned**
- `litellm/containers` — The container API: creating, listing, retrieving and deleting provider containers and their files, with the file-level operations generated from a JSON endpoint description rather than written by hand; **code-owned**
- `litellm/decisions` — The Decisions API client: it validates a decision request against the target provider's supported fields, inlines images and other assets, and issues the call through the SDK's shared handler; **code-owned**
- `litellm/files` — The provider files API, covering upload, retrieval, listing, deletion and content download across providers, including the streaming download response that turns a file fetch into a logged operation; **code-owned**
- `litellm/google_genai` — The Google GenAI native surface, exposing generate_content in Google's own request and response shape and adapting that shape onto LiteLLM's OpenAI-style completion model; **code-owned**
- `litellm/harness` — The agent harness runtime: it runs Claude Code, Codex, OpenCode, pi, Deep Agents or a plain tool loop against any LiteLLM model, driving each CLI through a per-session local model endpoint and reporting what happens as a typed event stream; **code-owned**
- `litellm/images` — The image API for the SDK, covering generation, editing and variation across providers with the shared request-shaping rules and per-provider dispatch; **code-owned**
- `litellm/integrations` — The callback and integration layer of the SDK, defining the CustomLogger and CustomGuardrail extension contracts that observability, alerting, guardrail and gateway hooks plug into; **code-owned**
- `litellm/interactions` — The Interactions API, covering creation, retrieval, deletion and cancellation of provider interactions and managed agents, plus the background cost settlement that bills long-running interactions; **code-owned**
- `litellm/litellm_core_utils` — The SDK's shared internal helper layer: provider resolution, token counting, the request and response logging object, prompt templating, redaction and error normalization, imported by nearly every other package rather than reimplemented in it; **code-owned**
- `litellm/llms` — The provider translation layer of the SDK, holding one package per LLM provider with the request and response transformations and handlers that turn OpenAI-shaped calls into that provider's wire format; **code-owned**
- `litellm/mcp_client` — The Model Context Protocol client, connecting to MCP servers, listing and calling their tools, and mapping MCP tool schemas onto OpenAI and Anthropic tool definitions; **code-owned**
- `litellm/models` — The canonical Pydantic models for every persisted LiteLLM entity: API keys, teams, users, budgets, models, tags, access groups, managed files and MCP servers, so the gateway and the SDK agree on one row shape; **code-owned**
- `litellm/passthrough` — The provider passthrough route for the SDK, forwarding a raw request to a provider endpoint with merged headers and query parameters and returning the provider response, streamed or buffered, with spend still captured; **code-owned**
- `litellm/proxy/_experimental` — Packaged Admin UI assets and legacy proxy import shims; **code-owned**
- `litellm/proxy/a2a` — The A2A protocol support for agent registration; **code-owned**
- `litellm/proxy/agent_endpoints` — The agent registry of the proxy; **code-owned**
- `litellm/proxy/anthropic_endpoints` — The Anthropic-shaped surface of the proxy; **code-owned**
- `litellm/proxy/auth` — Authentication and authorization for every proxy request: it resolves the caller into a UserAPIKeyAuth and then decides which routes, models and budgets that caller may reach; **code-owned**
- `litellm/proxy/batches_endpoints` — The OpenAI Batch API surface; **code-owned**
- `litellm/proxy/client` — The Python client and CLI for a running proxy: typed management clients for keys, teams, models and credentials, plus the command line that drives the same operations; **code-owned**
- `litellm/proxy/common_utils` — Shared proxy support code: configuration loading, credential encryption, callback registration, caching, and the small helpers that many other proxy sections import rather than reimplement; **code-owned**
- `litellm/proxy/config_resolvers` — Settings reconciliation for the proxy: it decides whether a setting comes from the config file, the database or the environment, and reports which source won; **code-owned**
- `litellm/proxy/container_endpoints` — The containers surface of the proxy; **code-owned**
- `litellm/proxy/db` — The proxy's Postgres access layer: the Prisma client wrapper, the queued spend and window-spend writers, and the transaction machinery that keeps the database current; **code-owned**
- `litellm/proxy/discovery_endpoints` — The public discovery documents of the proxy; **code-owned**
- `litellm/proxy/example_config_yaml` — Reference proxy configurations and the custom auth, callback, guardrail and validator modules they point at, kept as working examples of how to extend the gateway; **code-owned**
- `litellm/proxy/guardrails` — The guardrail plugin subsystem; **code-owned**
- `litellm/proxy/hooks` — The proxy's callback layer: the CustomLogger subclasses the gateway runs around each request for rate limiting, budget enforcement, cache-control validation and cost attribution; **code-owned**
- `litellm/proxy/lens` — The Lens tracing integration: it forwards a request to a Lens collector under a delegated identity and bounds what may be buffered while it does; **code-owned**
- `litellm/proxy/list_api` — The shared contract for LiteLLM's collection endpoints: it turns query parameters into a filter and sort plan and renders the same problem responses on every list route; **code-owned**
- `litellm/proxy/management` — Shared team and user authorization primitives for the management plane; **code-owned**
- `litellm/proxy/management_endpoints` — The proxy's admin control-plane HTTP surface; **code-owned**
- `litellm/proxy/management_helpers` — Write-path helpers shared by the management routes; **code-owned**
- `litellm/proxy/mcp_server` — The gateway's Model Context Protocol implementation; **code-owned**
- `litellm/proxy/middleware` — The ASGI middleware ring around the proxy app: it caps request size, decompresses bodies, compresses responses, adds security headers and gates the metrics endpoint; **code-owned**
- `litellm/proxy/openai_files_endpoints` — The OpenAI Files API surface; **code-owned**
- `litellm/proxy/pass_through_endpoints` — The provider-direct passthrough surface; **code-owned**
- `litellm/proxy/policy_engine` — The policy engine; **code-owned**
- `litellm/proxy/prompts` — Prompt management for the gateway: a versioned prompt registry, the endpoints that serve stored prompts, and the initializer that loads prompts from the config file; **code-owned**
- `litellm/proxy/public_endpoints` — The gateway's unauthenticated public surface: the model hub, the provider and agent creation schemas, and the release and preset catalogs the dashboard renders; **code-owned**
- `litellm/proxy/rag_endpoints` — The RAG surface of the proxy; **code-owned**
- `litellm/proxy/response_polling` — The polling mode of the Responses API; **code-owned**
- `litellm/proxy/roi_calculator` — The ROI calculator engine; **code-owned**
- `litellm/proxy/search_endpoints` — The web-search surface of the proxy; **code-owned**
- `litellm/proxy/shutdown` — Graceful termination for the proxy: it drains in-flight requests, lets scheduled jobs finish, and gives the server worker a bounded window to exit; **code-owned**
- `litellm/proxy/spend_tracking` — Cost attribution for the gateway: it turns a completed request into spend records, keeps the budget counters the auth section reads, and exposes the spend reporting endpoints; **code-owned**
- `litellm/proxy/swagger` — The vendored Swagger UI assets the proxy serves for its OpenAPI page, so the documentation renders without a CDN fetch; **code-owned**
- `litellm/proxy/telemetry` — Telemetry for the proxy itself: it records per-request timings and provider attempts, stores them, and exports them only under the configured consent; **code-owned**
- `litellm/proxy/ui_crud_endpoints` — The Admin UI settings surface; **code-owned**
- `litellm/proxy/vector_store_endpoints` — The vector store surface of the proxy; **code-owned**
- `litellm/proxy/video_endpoints` — The video surface of the proxy; **code-owned**
- `litellm/proxy` (remainder) — The proxy server itself: it composes the FastAPI application, runs the request pipeline that every route shares, and owns the shared type and schema surface the other proxy sections build on; **code-owned**
- `litellm/rag` — The retrieval-augmented generation pipeline, covering document ingestion through upload, OCR, chunking, embedding and storage, and query-time retrieval, reranking and context assembly; **code-owned**
- `litellm/repositories` — The data-access layer over Prisma: typed protocols for the generated client, a generic CRUD repository, per-entity repositories with their own queries and writes, and unit-of-work helpers that batch one logical operation into a single transaction; **code-owned**
- `litellm/responses` — The OpenAI Responses API surface: request and response transformation for the /v1/responses shape, the streaming iterator, MCP tool execution and the bridge that lets a chat-completions provider serve a Responses request; **code-owned**
- `litellm/router_strategy` — The routing algorithms behind the Router: the least-busy, lowest-cost, lowest-latency, TPM and RPM, tag-based and shuffle deployment pickers, plus the adaptive, complexity, quality and auto routers that choose a model group before a deployment; **code-owned**
- `litellm/router_utils` — The Router's supporting machinery: the cooldown and health-state caches, the optional pre-call deployment checks, fallback bookkeeping, capability lookups and the access-window rules that decide which deployment may serve a request; **code-owned**
- `litellm/rust_bridge` — The Python side of the Rust migration: it loads the packaged native extension, decides per request whether Rust or Python should handle the call, and projects Python call arguments into the shape the native code reads; **code-owned**
- `litellm/sandbox` — The sandbox surface for code execution: provider code-interpreter containers plus a registry that resolves a configured sandbox tool name to its provider and credentials, and lazy re-exports of the harness sandboxes; **code-owned**
- `litellm/search` — The search API for the SDK, running a provider web or document search and pricing the query that produced it; **code-owned**
- `litellm/secret_managers` — Credential resolution for the whole product: one get_secret and get_secret_str entry point over pluggable backends, covering AWS Secrets Manager, Google Secret Manager and KMS, HashiCorp Vault and CyberArk, plus a loader for operator-supplied Python managers; **code-owned**
- `litellm/telemetry` — The privacy-scoped usage and stability telemetry core for the gateway, holding the record shapes, consent gating, aggregation and export primitives that the proxy telemetry runtime plugs into; **code-owned**
- `litellm/tracing` — The Lens trace gateway client for the SDK, owning the remote-only HTTP reads against the BerriAI/lens trace service, the query and storage layer over it, and the asynchronous spend exporter that feeds the same sink; **code-owned**
- `litellm/types` — The typed contract layer of the SDK: the request, response, provider, routing and proxy-endpoint models, plus the enums and TypedDicts every other package builds its own types on; **code-owned**
- `litellm/vector_store_files` — The vector store file API, covering creation, listing, retrieval, update, deletion and content download of the files held inside a provider vector store; **code-owned**
- `litellm/vector_stores` — The vector store API and registry, covering creation, search, listing, update and deletion of provider vector stores together with the managed-store registry that decides which store a request should hit and which credentials it should use; **code-owned**
- `litellm/videos` — The video API for the SDK, covering generation, status polling, listing, retrieval, remixing, extension and editing of video jobs plus the reusable character assets they can reference; **code-owned**
- `litellm` (remainder) — The public LiteLLM SDK surface and the shared runtime behind it: the package facade, the completion and embedding entry points, the Router that fans a request across deployments, cost calculation, and the error taxonomy every layer raises into; **code-owned**
- `litellm_cli` — This section holds the console entry points for the lite and litellm-proxy commands, which boot the CLI against an uninitialized SDK package so startup does not pay for the full SDK import before any command needs it; **code-owned**
- `migrations` — This section is the standalone Prisma migrations Job, a minimal image and entrypoint that applies schema migrations to the writer database with the proxy's recovery logic and then builds the request-log indexes the migrations do not create; **code-owned**
- `packaging/litellm-core` — This section holds the build metadata for the standalone litellm-core distribution, a Rust-extension build of the SDK that ships without the proxy extras; **code-owned**
- `packaging` (remainder) — This section holds the Homebrew tap formula and its release runbook for the thin lite command, which installs the published SDK sdist with its CLI extra into a dedicated virtualenv rather than shipping a pinned resource tree; **code-owned**
- `scripts` — This section is the repository's developer tooling: the delta-versus-base lint and type gates, the code generators, the benchmark and health-check harnesses, the Lens fixture corpus and the GitHub issue automations that no runtime path imports; **code-owned**
- `terraform/litellm` — This section holds the reference cloud stacks that stand up the componentized deployment, one module set for AWS ECS and Fargate with Aurora and ElastiCache, and one for GCP Cloud Run with Cloud SQL and Memorystore; **code-owned**
- `terraform/provider` — This section holds the Go Terraform provider that manages LiteLLM control-plane objects through the proxy's management REST API, with one resource and one data source per object kind and a static audit that keeps the provider from drifting from the API; **code-owned**
- `tests` — The repository's test suite, split into tiers by what stands on the other side of the call: in-process unit tests that mirror the source tree, integration tests against a proxy the suite boots itself, end-to-end tests against real providers, and tests of the harness itself; **code-owned**
- `ui` — The Next.js admin dashboard that ships next to the proxy, an app-router project under ui/litellm-dashboard that is built as a static export and served either by the proxy at /ui or by the standalone nginx image in this directory; **code-owned**
- `vscode-extension` — This section holds the VS Code extension that registers LiteLLM as a language-model chat provider, reading the gateway's model groups to populate the picker and streaming completions through the configured gateway; **code-owned**

---

## backend
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `backend/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=backend sha=ecfbca9ec82d6d28346dbfa35d5ab7125b9a7161 -->

The UI backend component is a control-plane FastAPI app that reuses the shared proxy application and trims its route table down to the management and admin surface the dashboard consumes, leaving every LLM data-plane path to the gateway component. It runs as its own non-root container on port 4001 with the database URL assembled from discrete environment variables before the proxy app is imported. At a glance:

- **Entry point** — backend/main.py imports the proxy app and swaps its lifespan so route trimming happens after startup hooks register their routes, not at module load.
- **Route allowlist** — backend/routes/allowlist.py enumerates the management path prefixes, exact paths and mounts kept on the backend, so data-plane LLM endpoints never reach this process.
- **Database wiring** — DatabaseURLSettings.from_env().apply_to_env() runs before the proxy app import so Prisma connects when only the discrete DATABASE_* variables are set.
- **Container image** — The backend image is built on the pinned Wolfi base, runs as the nonroot user and starts uvicorn backend.main:app on port 4001.

For exact behavior, read the code under `backend/`. Do not restate it here.
---

## ci_cd
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `ci_cd/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=ci_cd sha=c03eb170062b3fcc595a42ef9f0fd2c7c75bc24b -->

This section holds the pull-request guard scripts and the standards documents that gate changes to the repository, enforcing cost-map consistency, spend-log schema ownership, safe migration generation, and secret-scanning conventions. At a glance:

- **Cost map guard** — cost_map_guard.py compares the root cost map against the copy kept under the SDK package, refuses to let it drift, and holds bot branches to a narrower add-or-update-only contract.
- **Spend log gate** — spend_logs_guard.py reads the diff rather than path rules, so a change naming LiteLLM_SpendLogs in any watched schema copy or migration file only passes with an approving review from the spend-log owner.
- **Migration generation** — run_migration.py diffs a temporary Postgres against the schema, refuses to write DROP COLUMN, DROP TABLE or DROP INDEX statements without an explicit override, and refuses to run from a branch that is behind the default branch.
- **Baseline creation** — baseline_db.py writes a from-empty baseline migration set into deploy/migrations for the root Prisma schema.
- **Standards docs** — security_scans_readme.md lists the Trivy and Grype scans that run, and TEST_KEY_PATTERNS.md documents the low-entropy key shapes that keep test credentials out of GitGuardian findings.

For exact behavior, read the code under `ci_cd/`. Do not restate it here.
---

## cookbook
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `cookbook/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=cookbook sha=0c1d8a42df9e2b0a0e621fa95ebd7f25d4b40084 -->

Example notebooks and scripts that show how to drive LiteLLM as an SDK, as a router and as a proxy, kept as user-facing sample code rather than part of the shipped package. At a glance:

- **Notebooks and scripts** — The tree mixes 41 Jupyter notebooks with 34 Python scripts and a handful of configs; the notebooks walk through provider setups and observability integrations while the scripts are the runnable recipes.
- **Router load harnesses** — cookbook/litellm_router and cookbook/litellm_router_load_test build a litellm.Router over Azure deployments and fire concurrent completions from question files, with one variant wiring an S3-backed cache into the run.
- **Secret manager extension** — The proxy recipe includes a custom secret manager that subclasses litellm.integrations.custom_secret_manager.CustomSecretManager, showing the extension point a user implements for their own key store.
- **Agent SDK gateways** — The anthropic_agent_sdk and livekit_agent_sdk examples point third-party agent SDKs at a LiteLLM gateway through setup_litellm_env and a config.example.yaml, so the agent talks to the gateway rather than to a provider.
- **Local mock servers** — cookbook/mock_guardrail_server and cookbook/mock_prompt_management_server stand up FastAPI doubles of the Bedrock Guardrail API and the generic prompt management API so a local proxy can be exercised without those services.
- **Coding-tool guide index** — cookbook/ai_coding_tool_guides/index.json is a machine-readable catalogue of the Claude Code and MCP guides, each entry carrying title, description, url, date, version and tags.

For exact behavior, read the code under `cookbook/`. Do not restate it here.
---

## db_scripts
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `db_scripts/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=db_scripts sha=dabac51f28544a570dc76bd0b45a26c64b95a211 -->

This section collects the operator-run SQL and Python scripts for one-off Postgres maintenance against the proxy database, such as converting the spend-log table to a range-partitioned table, rebuilding lifetime key spend from spend logs, and creating the proxy's reporting views. At a glance:

- **Spend log partitioning** — partition_spend_logs.sql converts the spend-log table into a range-partitioned table keyed on startTime, keeps a default partition for safety, and documents that the default schema is not partitioned.
- **Spend backfills** — backfill_key_total_spend_from_spend_logs.sql reconstructs lifetime spend for keys whose spend resets each budget period, joining spend logs back to tokens and their hashed digests, and never lowering an already-correct total.
- **View creation** — create_views.py creates the reporting views the proxy reads, including the verification-token view that joins team limits onto keys and the rolling 30-day spend views.
- **Key import** — migrate_keys.py imports verification tokens from a CSV export, coercing each column to the type its Prisma model expects and skipping tokens that already exist.
- **Vector store cleanup** — strip_vector_store_internal_metadata.py lists or deletes the metadata keys the proxy itself writes into provider vector stores, and defaults to a dry run.

litellm/proxy/db/create_views.py documents itself as a copy of litellm/db_scripts/create_views.py, but that path does not exist in the tree; the tracked copy is db_scripts/create_views.py.

For exact behavior, read the code under `db_scripts/`. Do not restate it here.
---

## docker
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `docker/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=docker sha=b1948e9d2dc0596890980e3ca5032eaf3c25ed32 -->

This section defines the container images and compose stacks that ship LiteLLM, covering the rootless all-in-one proxy image with its embedded admin UI, the migration-qualification image variant, and the quickstart and tracing compose stacks used for local evaluation. At a glance:

- **Rootless image** — Dockerfile.non_root builds the shipped image on the pinned Wolfi base, compiles PgBouncer from source, replaces the committed UI bundle with one built from the same source, and finishes as uid 65534.
- **Shared entrypoint** — component_entrypoint.sh clears stale Prometheus multiprocess sample files before exec and wraps the process in ddtrace-run when USE_DDTRACE is set.
- **Quickstart stack** — docker-compose.quickstart.yml runs the gateway with a Postgres 16 service and keeps the salt key in a local .env file because rotating it would invalidate stored credentials.
- **Admin UI build** — build_admin_ui.sh is a no-op for the default UI and only rebuilds a custom admin UI when the enterprise UI palette files are present.
- **Migration image** — Dockerfile.database is the variant CircleCI builds as the migration-qualification image, so it runs the admin UI build script inline, bakes the Prisma CLI and engines at a fixed path, and keeps root as its runtime user.

For exact behavior, read the code under `docker/`. Do not restate it here.
---

## enterprise
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `enterprise/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=enterprise sha=dce5c95cb4b2183c3369b71785d37aad255aa072 -->

The commercially licensed LiteLLM Enterprise add-on, shipped as the separate litellm-enterprise distribution. It contributes extra proxy routers, hook classes, guardrail callbacks and management endpoints that the open-source proxy mounts only when the enterprise package is installed. At a glance:

- **Route surface** — proxy/enterprise_routes.py aggregates the e-mail events, audit logging, LiteAdmin and management routers into one APIRouter that litellm/proxy includes at startup when litellm_enterprise is importable
- **Hook registry** — enterprise_hooks/__init__.py maps hook names to CustomLogger subclasses, managed_files and managed_vector_stores today, and litellm/proxy/hooks merges that registry into its own PROXY_HOOKS table
- **Managed resources** — proxy/hooks/managed_vector_stores.py and managed_files.py rewrite request-body file and vector-store references into provider-native ids, on top of the managed-resource contract in litellm/llms
- **Audit trail** — proxy/audit_logging_endpoints.py serves /audit and /audit/{id} over the shared AuditLogRepository, filtering JSON columns with Prisma JSON-path conditions
- **Guardrail callbacks** — enterprise_callbacks carries secret detection with 94 detect-secrets plugins, llama_guard, llm_guard, pagerduty and the send_emails providers; secret_detection is a CustomGuardrail named hide_secrets
- **Proprietary package** — pyproject.toml publishes the tree as the litellm-enterprise distribution under a proprietary licence with its own version series, while the built wheels and source tarballs are kept in enterprise/dist

The proxy treats the whole tree as optional: litellm/proxy imports litellm_enterprise inside try/except ImportError and skips the enterprise router when it is absent.

For exact behavior, read the code under `enterprise/`. Do not restate it here.
---

## examples
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `examples/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=examples sha=35839eb61c39b79250102359e1e8326527a29ba3 -->

This section holds the example proxy configuration that demonstrates the LAR-1 router strategy, registering several local Ollama models behind one model name and letting the router pick between them by confidence. At a glance:

- **Model list** — The config registers four Ollama deployments that share the single model name agent-router and are told apart only by their model_info identifiers and types.
- **Router settings** — router_settings selects the lar1 routing strategy and sets the low, medium and high confidence thresholds that drive its escalation.
- **General settings** — general_settings carries a redacted master key placeholder and litellm_settings turns on verbose output, showing the shape of a full proxy config file.

For exact behavior, read the code under `examples/`. Do not restate it here.
---

## gateway
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `gateway/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=gateway sha=3693a80bebb5726fac30fa20e30a365e04631b70 -->

The gateway component is the LLM data-plane process: it reuses the shared proxy application but keeps only the completion, embedding, media, passthrough and realtime paths, and it supervises an in-container PgBouncer so a single pooler fronts the writer database for all workers. At a glance:

- **Route trimming** — gateway/main.py replaces the proxy lifespan so the route table is filtered inside the lifespan, after startup hooks have registered their own routes.
- **Data plane allowlist** — gateway/routes/allowlist.py enumerates the versioned completion, embedding, audio, image, responses, rerank, video and provider-passthrough prefixes that stay on the gateway.
- **Pooler supervisor** — launch.py starts the in-container PgBouncer once per pod before uvicorn forks, exports the pooled loopback URL so every worker picks it up, and exits non-zero if the pooler cannot start.
- **Container image** — The gateway image compiles PgBouncer from a pinned source tarball with a checked SHA-256 and starts python -m gateway.launch on port 4000.

ARCHITECTURE.md documents only the SDK and a single AI Gateway under litellm/proxy; it never mentions the gateway, backend and UI components, the Helm charts, the Terraform stacks or the CLI. The code wins.

For exact behavior, read the code under `gateway/`. Do not restate it here.
---

## helm
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `helm/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=helm sha=c1d3b423dee64e8493b27b806cb2b0098ac61cec -->

This section holds the two Helm charts that deploy LiteLLM on Kubernetes: the componentized chart that runs gateway, UI backend, UI and a migration Job as separate workloads, and the older single-service chart that also bundles Postgres and Redis. At a glance:

- **Componentized chart** — The litellm chart is described as componentized, with separate gateway, backend and UI templates and a Lens subchart dependency.
- **Per component images** — values.yaml pins a distinct image repository per component, including the dedicated migrations image, so each component can be versioned and rolled back on its own.
- **Migration job** — The componentized chart's migration Job runs as a Helm pre-install and pre-upgrade hook, and can be switched to an ArgoCD PreSync hook, so schema changes land before the serving workloads roll.
- **Template tests** — The helm unittest suites assert on rendered templates such as probe timeouts, autoscaling behaviour, ingress path types and pod hardening.
- **Legacy chart** — The litellm-helm chart is the older single-deployment chart and pulls Postgres, Redis and Lens as bundled dependencies.

For exact behavior, read the code under `helm/`. Do not restate it here.
---

## litellm-proxy-extras/dist
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm-proxy-extras/dist/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm-proxy-extras/dist sha=004db1e17122970ca318576b255ce78aebff1663 -->

Build output, not source: the published wheels and source tarballs of the litellm-proxy-extras package, one pair per released version from 0.1.0 through 0.4.60, kept in the repository so every released artifact stays on record. At a glance:

- **Artifact inventory** — The directory holds 179 tracked files, 90 py3-none-any wheels and 89 source tarballs of the same distribution, with no source of its own
- **Release span** — The earliest archived release is 0.1.0 and the newest is 0.4.60, which is behind the 0.4.111 the litellm-proxy-extras packaging section declares
- **Generated output** — Every file here is produced by the uv build step the litellm-proxy-extras packaging section runs, so nothing in this directory is edited by hand and edits belong in the package source
- **Uneven pairing** — 0.2.28 was published as a wheel without a matching source tarball, so the wheel and tarball series are not perfectly parallel

For exact behavior, read the code under `litellm-proxy-extras/dist/`. Do not restate it here.
---

## litellm-proxy-extras/litellm_proxy_extras
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm-proxy-extras/litellm_proxy_extras/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm-proxy-extras/litellm_proxy_extras sha=8642d34073dfff52f14c0adc1bef78f5c6791e05 -->

The importable litellm_proxy_extras package: the proxy's Prisma schema and its SQL migration history, plus the Python machinery that applies them under a lock and refuses changes the existing rows would reject. At a glance:

- **Schema source** — schema.prisma declares 101 Postgres models for the proxy database and is the file migrations are generated from; it is byte-identical to the copy in litellm/proxy
- **Migration history** — migrations/ carries 222 timestamped directories, each with exactly one migration.sql, applied in order by prisma migrate deploy starting from the 20250326162113_baseline
- **Migration entry point** — ProxyExtrasDBManager.setup_database is what litellm/proxy/db calls to bring a database up to date: it ensures the Prisma toolchain, refuses changes the existing rows would block, runs the migrations, repairs invalid indexes and can re-assert REPLICA IDENTITY FULL
- **Boot lock** — migration_lock.py takes a Postgres advisory lock so only one resolver migrates a given database at a time, and derives a direct non-pooler URL for Prisma
- **Pre-flight row checks** — migration_data_checks.py reads the pending statements and counts rows that would violate a new unique, not-null, foreign-key or check constraint, refusing the migration before anything is applied
- **Toolchain supervision** — prisma_toolchain.py installs and supervises the private Node runtime and Prisma CLI with separate timeouts for bootstrap versus migrate deploy, killing the whole process group on timeout so a killed schema engine cannot keep mutating the database

The packaged schema.prisma is a byte-identical copy of the repository-root schema.prisma and of litellm/proxy/schema.prisma; the sync step in the litellm-proxy-extras runbook is what keeps the three identical.

For exact behavior, read the code under `litellm-proxy-extras/litellm_proxy_extras/`. Do not restate it here.
---

## litellm-proxy-extras (remainder)
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm-proxy-extras/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm-proxy-extras/tests sha=5186088c612bb51344a4db5376eada493c340372 -->
<!-- blueprint:code path=litellm-proxy-extras/LICENSE sha=3bfef5bae9b48c334acf426d5b7f21bc1913aab9 -->
<!-- blueprint:code path=litellm-proxy-extras/README.md sha=94fba0b5c654e8e01076b78166ab92008c44b090 -->
<!-- blueprint:code path=litellm-proxy-extras/build_and_publish.md sha=6808d800258c20492faf33df91454fb079ceec54 -->
<!-- blueprint:code path=litellm-proxy-extras/migration_runbook.md sha=b1e9236e520d9b2e47bd20df75672c935707becd -->
<!-- blueprint:code path=litellm-proxy-extras/pyproject.toml sha=6de44be0c12ab95a4ec8bb29adfff45eed91ab64 -->

Packaging, licensing and operator runbooks for the separately published litellm-proxy-extras distribution, sitting outside the importable package directory that holds the code. At a glance:

- **Package manifest** — pyproject.toml defines the litellm-proxy-extras distribution, version 0.4.111, built by uv_build with the module root at the package directory, and commitizen version files keep it in lockstep with the pin in the repository-root pyproject.toml
- **Install path** — README tells operators to add the package with uv add litellm-proxy-extras, or to install litellm[proxy] which pulls it in, and to drive migrations from the litellm/proxy CLI
- **Migration runbook** — migration_runbook.md is the operator procedure for a schema change: sync the three schema.prisma copies, refuse generated SQL containing DROP COLUMN, DROP TABLE or DROP INDEX, verify the branch is fresh, then generate the migration with ci_cd/run_migration.py
- **Publish runbook** — build_and_publish.md documents the release flow: bump the version with commitizen, clean old artifacts, build with uv build and upload with twine
- **Licence split** — LICENSE puts everything under enterprise/ under the enterprise licence and the remainder of the repository under MIT
- **Own tests** — tests/ holds the distribution's own regression test for the v2 migration resolver, asserting that a Prisma P3018 permission failure surfaces as a RuntimeError instead of a silent success

README's litellm --use_prisma_migrate has no counterpart in the CLI at HEAD, where the implemented flags are --use_v2_migration_resolver and --check_migrations_against_existing_data.

For exact behavior, read the code under `litellm-proxy-extras/`. Do not restate it here.
---

## litellm-rust
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm-rust/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm-rust sha=d86f2e445079c1c689c5459efe4b3c1657751f94 -->

The Rust port of the gateway, a Cargo workspace of crates that reimplements provider translation, routing, caching, auth and the HTTP gateway in Rust and exposes it back to Python through a PyO3 bridge. At a glance:

- **Crate taxonomy** — Cargo.toml declares a workspace of crates/* and 69 crates are checked in, split by role: domain crates (llms, llms-types, inference-chat/messages/responses/ocr/transcription, config, router, cost, model-catalog), service crates (cache-*, auth-*, secrets-*, db, redis-client, token-counter-*), runtime crates (host, host-http, host-native, host-python, coroutine, framer) and the Python bridge (python-bridge, python-compat, callbacks-legacy-python).
- **PyO3 boundary** — crates/python-bridge is the product-side PyO3 consumer: it defines a single pymodule named _native with one exported function per public route (completion, messages, responses, embedding, transcription, ocr, token counter) and surfaces Rust failures as the RustBridgeDeclined and RustUpstreamError exception types.
- **Runtime-neutral host contract** — crates/host defines the call contract every driver speaks, with typed Protocol request, response, stream head, chunk and error values plus interceptors, hooks and a resumable machine, so the HTTP and Python drivers interpret the same suspension protocol in their own runtimes.
- **Rust gateway server** — crates/gateway is an axum server that assembles config, auth, secrets, Redis clients and layered HTTP settings into a Router, and it ships as its own image with a Dockerfile and an mcp_config.yaml.
- **Legacy callback dispatch** — crates/callbacks-legacy-python keeps the Python callback surface alive from Rust by mapping each dispatch key to the Python module that owns those hooks, covering proxy utils, router utils, logging and per-provider handlers.
- **Pinned to the Python calculator** — The cost crate holds itself to the Python implementation: a generator script calls generic_cost_per_token from litellm.litellm_core_utils with a litellm.types Usage, writes the results to python_reference.tsv, and the Rust test reads that table back.

ARCHITECTURE.md has no section for this workspace; the Rust port, its crate taxonomy and its parity rules are documented only by the workspace AGENTS.md and the crate-level AGENTS.md files.

For exact behavior, read the code under `litellm-rust/`. Do not restate it here.
---

## litellm/_v2
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/_v2/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/_v2 sha=837bfb2523d1c7beab77a91bb4946dc624389348 -->

The experimental v2 surface: today only a cache facade that builds a native Rust cache handle and injects it behind the existing BaseCache interface, deliberately kept out of the documented SDK. At a glance:

- **Native backend** — cache/__init__.py's NativeBackend adapts a native cache handle to the BaseCache interface, forwarding TTL and preserving both the sync and async cache operations.
- **Facade reuse** — The same module returns the ordinary litellm/caching Cache facade with the native backend injected, so callers keep one cache API and only the storage moves.
- **Boundary rules** — cache/AGENTS.md fixes the contract: keep litellm._v2.cache.Cache import-compatible, keep storage in the Rust crates and keep the native extension import lazy.
- **Experimental status** — _v2/AGENTS.md marks everything under it experimental and undocumented, usable by the gateway only behind the v2 flag so SDK users are not broken.

For exact behavior, read the code under `litellm/_v2/`. Do not restate it here.
---

## litellm/a2a_protocol
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/a2a_protocol/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/a2a_protocol sha=5c2b4166c3b1829e96eee5ab4992b93eebc762c1 -->

The Agent-to-Agent protocol client, wrapping the upstream a2a SDK so callers can resolve an agent card and send or stream messages to a remote agent, with LiteLLM logging, cost attribution and provider-specific adapters. At a glance:

- **Public surface** — The package exports A2AClient alongside standalone send_message, asend_message, asend_message_streaming, create_a2a_client and aget_agent_card, mirroring the upstream a2a SDK's shape for drop-in use.
- **Card resolution** — card_resolver.py's LiteLLMA2ACardResolver discovers the agent card, normalizes its advertised interfaces for the negotiated protocol version and refuses localhost and internal URLs.
- **Cost attribution** — cost_calculator.py's A2ACostCalculator prices a send_message from an explicit response cost, then a flat cost per query, then per-token rates, in that priority order.
- **Provider adapters** — providers holds per-vendor backends (Bedrock AgentCore, Watsonx Orchestrate, Pydantic AI agents) selected through a config manager, each with its own handler and transformation.
- **Completion bridge** — litellm_completion_bridge/handler.py's A2ACompletionBridgeHandler answers an A2A request by running an ordinary LiteLLM completion instead of calling a remote agent, which lets any model serve the protocol.

For exact behavior, read the code under `litellm/a2a_protocol/`. Do not restate it here.
---

## litellm/anthropic_interface
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/anthropic_interface/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/anthropic_interface sha=734a1a88de711b6dd345a0f6e302cca44beb9ec9 -->

The Anthropic-native surface of the SDK, exposing Anthropic-shaped message creation plus the Anthropic error taxonomy that the proxy, the provider layer and the integrations all share. At a glance:

- **Messages wrapper** — messages/__init__.py exposes create and acreate over the Anthropic request and response shapes, delegating to the litellm.messages handlers so callers can talk Anthropic format without changing models.
- **Error taxonomy** — exceptions/exceptions.py defines AnthropicErrorResponse and AnthropicErrorDetail, the body shape Anthropic clients expect when a call fails.
- **Exception mapping** — exception_mapping_utils.py maps internal failures onto Anthropic error types, and anthropic_error_sse_frame renders the matching error frame for streaming responses so a mid-stream failure looks like a provider failure.

For exact behavior, read the code under `litellm/anthropic_interface/`. Do not restate it here.
---

## litellm/batches
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/batches/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/batches sha=108c3536a4ab01147d6ccee3f06dbc00d2b1a492 -->

The batch job API, covering provider batch creation, retrieval, listing and cancellation and settling the cost and per-request usage of a batch once its results land. At a glance:

- **Job lifecycle** — main.py exposes acreate_batch, aretrieve_batch, alist_batches and acancel_batch over one shared HTTP handler, dispatching to per-provider handlers for OpenAI, Azure, Vertex AI, Anthropic, Bedrock and xAI.
- **Cost settlement** — batch_utils.py's calculate_batch_cost_and_usage prices a completed batch from its output file and aggregates usage across lines, with a separate path for Vertex AI's native batch output.
- **Line items** — batch_line_items.py splits provider output into per-request line items and hands them to the callback loggers, dropping request and response bodies when redaction is requested.
- **Output file access** — Cost settlement fetches the provider's result file through litellm/files rather than reimplementing file download, so batch accounting follows the same file path as everything else.

For exact behavior, read the code under `litellm/batches/`. Do not restate it here.
---

## litellm/caching
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/caching/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/caching sha=a2baffc439b7cf6e4f18998f0b59c8b4f1c3bd86 -->

The SDK's cache tier: a pluggable cache facade over Redis, S3, GCS, Azure Blob, disk, in-memory and semantic-vector backends, together with the request-level handler that decides what may be cached and how a hit is replayed. At a glance:

- **Cache facade** — caching.py's Cache selects a backend by LiteLLMCacheType and owns key generation, namespaces and TTLs for every backend.
- **Request handler** — caching_handler.py's LLMCachingHandler decides per call type whether a response is cacheable and converts a stored payload back into the response shape the caller expects.
- **Backend contract** — base_cache.py's BaseCache defines the get, set, disconnect and test-connection surface that every backend implements.
- **Dual cache** — dual_cache.py's DualCache layers an in-process cache over Redis, so rate-limit counters, cooldowns and client caches survive a Redis restart.
- **Redis resilience** — redis_cache.py's RedisCircuitBreaker opens after repeated Redis failures, so a cache outage degrades the call instead of failing it.
- **Semantic cache** — qdrant_semantic_cache.py matches on embedding similarity rather than exact key equality, and resolves its embedding route through the shared embedding router.

The embedding router in this section is dependency-injected on purpose: _embedding_router.py takes the proxy llm_router and llm_model_list as arguments so the decision logic never imports litellm.proxy.proxy_server.

For exact behavior, read the code under `litellm/caching/`. Do not restate it here.
---

## litellm/completion_extras
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/completion_extras/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/completion_extras sha=5aea261d1eed2008469022dc1a877c4b6a4067a6 -->

The completion-only extras: the bridge that turns a chat-completions request into a Responses API request and maps the answer back, kept apart from the Responses implementation itself. At a glance:

- **Single purpose** — The package README states it holds logic specific for litellm.completion, and __init__.py exports exactly one name, responses_api_bridge.
- **Bridge handler** — handler.py's ResponsesToCompletionBridgeHandler validates the completion kwargs, issues the Responses call and converts the result back into a chat completion.
- **Transformation** — transformation.py rewrites messages, tools and reasoning between the two API shapes and strips the prompt-cache breakpoints that cannot cross the boundary.

This section and litellm/responses form a cycle at runtime: the Responses entry points call responses_api_bridge from here, and the bridge calls back into the Responses transformation helpers.

For exact behavior, read the code under `litellm/completion_extras/`. Do not restate it here.
---

## litellm/compression
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/compression/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/compression sha=7c814d46f4c3d9ce3c6e44ef4abf9b7e68d8e0f8 -->

Context compression for long conversations: it scores the messages, keeps the protected ones, replaces the rest with retrievable stubs, and hands the model a retrieval tool that can pull the dropped content back. At a glance:

- **Entry point** — compress.py's compress normalizes the messages, scores them and returns the compressed request with the retrieval tool attached.
- **Protected content** — get_protected_indices keeps the system messages, the last user and assistant turns, and everything up to the last cache-control breakpoint out of compression.
- **Scoring** — scoring/ combines a BM25 lexical score with an embedding similarity score, each min-max normalized and then blended by weight.
- **Stubbing** — message_stubbing.py replaces a dropped message with a compact stub and extracts the key a retrieval call will use to fetch it.
- **Retrieval tool** — retrieval_tool.py builds the tool definition that lets the model ask for a stubbed message back.
- **Content detection** — content_detection.py classifies a message's content type so stubbing and scoring treat images and text differently.

For exact behavior, read the code under `litellm/compression/`. Do not restate it here.
---

## litellm/containers
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/containers/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/containers sha=0a5b66cf96c00017d60f45dfa5eeeb259b30030c -->

The container API: creating, listing, retrieving and deleting provider containers and their files, with the file-level operations generated from a JSON endpoint description rather than written by hand. At a glance:

- **Lifecycle** — main.py implements create, list, retrieve and delete for containers across providers, with sync and async variants of each.
- **Generated endpoints** — endpoint_factory.py reads endpoints.json and generates the container-file functions from that description.
- **Managed ids** — utils.py encodes a provider's container id into a LiteLLM-managed id and decodes it back for a later request.
- **Endpoint description** — endpoints.json is the single source of truth for the generated container-file operations, naming path, method, parameters and response type.

For exact behavior, read the code under `litellm/containers/`. Do not restate it here.
---

## litellm/decisions
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/decisions/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/decisions sha=6eebe26bd76c41f5a75e5210aeea05acc792fed4 -->

The Decisions API client: it validates a decision request against the target provider's supported fields, inlines images and other assets, and issues the call through the SDK's shared handler. At a glance:

- **Entry point** — main.py exposes decisions() and adecisions(), which validate the request fields per provider before dispatching.
- **Request assembly** — call.py's DecisionsCall builds the provider request, inlining image URLs as data and rejecting malformed ones.
- **Provider dialects** — The same module keeps a SystemOne field set and an OpenAI field set and converts between them and the shared intermediate representation.

For exact behavior, read the code under `litellm/decisions/`. Do not restate it here.
---

## litellm/files
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/files/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/files sha=f31930e362a167269087ad17020572c8e3c394e9 -->

The provider files API, covering upload, retrieval, listing, deletion and content download across providers, including the streaming download response that turns a file fetch into a logged operation. At a glance:

- **Surface** — main.py exposes acreate_file, file_retrieve, file_list, file_delete and file_content plus their async twins, dispatching per provider over the shared HTTP handler.
- **Streaming download** — streaming.py's FileContentStreamingResponse is a sync and async byte iterator that yields the file body and still emits the standard success or failure logging events as it drains.
- **Request validation** — utils.py's FilesAPIUtils decides whether an upload is a batch JSONL file and whether its content type is acceptable, which is what keeps malformed uploads off the provider.
- **Typed kwargs** — types.py carries the per-call TypedDicts and the provider literals that main.py validates each operation against, so an unsupported provider fails fast.

The dependency with litellm/llms runs both ways: provider file transformations import the shared file types from here, while this section instantiates those provider handlers.

For exact behavior, read the code under `litellm/files/`. Do not restate it here.
---

## litellm/google_genai
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/google_genai/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/google_genai sha=8152744216cd2c137879217e6f9891a851f70798 -->

The Google GenAI native surface, exposing generate_content in Google's own request and response shape and adapting that shape onto LiteLLM's OpenAI-style completion model. At a glance:

- **Native entry points** — main.py exports agenerate_content, generate_content and their streaming variants over the GenerateContent contract, with a shared helper that prepares the call and can mock the response.
- **Request adapter** — adapters/transformation.py's GoogleGenAIAdapter converts a native generateContent request into a chat-completion request and back, including system instruction, tool and tool-config mapping.
- **Stream wrapper** — GoogleGenAIStreamWrapper holds back the finish chunk until usage arrives, so the final chunk of a native stream still carries token counts.
- **Shared handler** — The native surface runs on the same BaseLLMHTTPHandler as the chat path, so timeouts, retries and logging behave identically across surfaces.

For exact behavior, read the code under `litellm/google_genai/`. Do not restate it here.
---

## litellm/harness
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/harness/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/harness sha=43456c0746ed26c88b3d8a7926e3f66910df938b -->

The agent harness runtime: it runs Claude Code, Codex, OpenCode, pi, Deep Agents or a plain tool loop against any LiteLLM model, driving each CLI through a per-session local model endpoint and reporting what happens as a typed event stream. At a glance:

- **Public surface** — __init__.py exports the Harness enum, the per-harness option classes, the event types and the sync and async session entry points.
- **Local endpoint** — endpoint.py serves the per-session endpoint the harness inside the sandbox points its base URL at, in either gateway mode or SDK mode, and counts usage and cost.
- **Runtime** — runtime.py owns the session lifecycle: config validation, model-route resolution, turn control and the approval handshake with the caller.
- **Handlers** — handlers/base.py defines the BaseHarnessHandler contract each CLI adapter implements, with one adapter per supported harness.
- **Sandboxes** — sandbox/base.py defines the Sandbox protocol, with local and Docker implementations beside it and a snapshot diff of the files a run changed.
- **Sync facade** — sync.py wraps the async runtime in a blocking Session and EventStream for callers that are not asyncio-native.

ARCHITECTURE.md does not mention this package, so the harness and its sandbox abstractions are absent from the documented SDK flow.

For exact behavior, read the code under `litellm/harness/`. Do not restate it here.
---

## litellm/images
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/images/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/images sha=e33059afa24ca665e57d3dca62f9d7e66715146e -->

The image API for the SDK, covering generation, editing and variation across providers with the shared request-shaping rules and per-provider dispatch. At a glance:

- **Surface** — main.py exposes image_generation, image_edit and image_variation plus their async twins, resolving the provider and dispatching to that provider's image handlers.
- **Edit parameters** — utils.py's ImageEditRequestUtils maps an edit request onto the optional params and content type the target provider actually accepts, which is what keeps one API across many providers.
- **ChatGPT image path** — main.py carries a separate params and headers path for the ChatGPT image backend rather than folding it into the generic image flow, since that backend takes different inputs.

For exact behavior, read the code under `litellm/images/`. Do not restate it here.
---

## litellm/integrations
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/integrations/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/integrations sha=b48722242a83b8940c741a64e2b067d612f88f1c -->

The callback and integration layer of the SDK, defining the CustomLogger and CustomGuardrail extension contracts that observability, alerting, guardrail and gateway hooks plug into. It also ships the vendor-specific integrations built on those contracts. At a glance:

- **Callback contract** — custom_logger.py defines CustomLogger, the base class of the entire extension surface, covering request, success, failure, streaming, deployment, dataset and agentic-loop hooks. Proxy hooks and every vendor integration subclass it.
- **Guardrail contract** — custom_guardrail.py adds CustomGuardrail on top of CustomLogger, with hooks for pre-call, post-call and streaming scope, sensitive-data routing and structured-message support. It is the shared base of the gateway's guardrail handlers and of the provider guardrail_translation packages under litellm/llms.
- **Vendor breadth** — 37 vendor sub-packages plus 50 top-level modules cover Langfuse, Datadog, OpenTelemetry, Prometheus, ClickHouse, S3, Slack alerting and the rest. 24 modules define a class that derives from CustomLogger.
- **Metrics surface** — prometheus.py is the largest file in the section at over 5200 lines and pulls spend, usage and budget rows out of the proxy database into Prometheus series, which makes it a reporting layer rather than a plain callback.
- **Batch payload** — batch_line_item_objects.py renders the standard per-line batch payload as NDJSON, and that is the format litellm/batches dispatches to callbacks for every request in a batch job.

This section and litellm/llms depend on each other: provider guardrail translations import CustomGuardrail from here, while 56 files here import provider code from litellm/llms. The cycle is real and worth keeping visible rather than resolving.

For exact behavior, read the code under `litellm/integrations/`. Do not restate it here.
---

## litellm/interactions
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/interactions/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/interactions sha=bb439eb21701f8e1825c877a3b71aea38e4d708f -->

The Interactions API, covering creation, retrieval, deletion and cancellation of provider interactions and managed agents, plus the background cost settlement that bills long-running interactions. At a glance:

- **Interaction lifecycle** — main.py exposes create, get, delete and cancel plus their async twins over the provider's interaction contract, and the agents sub-package creates provider-side managed agents.
- **Background settlement** — background_cost_polling.py owns billing for background creates: the create call schedules a poll until a terminal status and logs one success event, because GET polls are deliberately never billed.
- **Managed agents** — agents/ creates provider-side managed agents over its own HTTP handler and the shared llms agent transformation base.
- **Responses bridge** — litellm_responses_transformation reuses the litellm/responses streaming iterator so interaction output can be served in the Responses shape without a second streaming implementation.
- **Parameter filtering** — utils.py's InteractionsAPIRequestUtils narrows the requested optional params to what the target provider accepts.

For exact behavior, read the code under `litellm/interactions/`. Do not restate it here.
---

## litellm/litellm_core_utils
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/litellm_core_utils/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/litellm_core_utils sha=8e13bdc3b00ff0ea86c077e0dc09b6a2a58d5e44 -->

The SDK's shared internal helper layer: provider resolution, token counting, the request and response logging object, prompt templating, redaction and error normalization, imported by nearly every other package rather than reimplemented in it. At a glance:

- **Logging object** — litellm_logging.py owns the Logging class, the per-request object that carries the call's state, computes the response cost and emits the standard logging payload that callbacks receive.
- **Provider resolution** — get_llm_provider_logic.py turns a model string plus an api_base into a provider, a credential source and a routing generalization. It is the one place that decision is made.
- **Token counting** — token_counter.py counts tokens per provider and model, including image tiling and tool-call accounting, and is what budget and context-window checks read.
- **Redaction** — redact_messages.py strips message content and provider-specific fields out of a payload before it reaches a logging callback.
- **Error taxonomy** — error_normalization.py maps provider error bodies and exception classes onto LiteLLM's own status and message vocabulary, which is what the gateway then renders.
- **Prompt templates** — prompt_templates/factory.py renders the provider-specific message formats, such as the Anthropic and HF chat templates, for providers that do not accept OpenAI-shaped messages.

This is the map's widest hub by import count, and it is a true platform layer rather than a grab-bag: every other section imports it for one of a small number of named facilities (logging, provider resolution, token counting, redaction, error normalization).

For exact behavior, read the code under `litellm/litellm_core_utils/`. Do not restate it here.
---

## litellm/llms
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/llms/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/llms sha=b7a73999d7c0d07f3a8a36d64ebc8f45cf8b711f -->

The provider translation layer of the SDK, holding one package per LLM provider with the request and response transformations and handlers that turn OpenAI-shaped calls into that provider's wire format. Every outbound model call in LiteLLM is funnelled through its shared HTTP handler here. At a glance:

- **Translation contract** — BaseConfig in base_llm/chat/transformation.py declares the abstract transform_request and transform_response pair every provider must implement. Only 16 of the 86 chat/transformation.py files define a class that derives from BaseConfig. 46 build on OpenAIGPTConfig and 22 on OpenAILikeChatConfig, so most providers inherit an OpenAI-compatible shape rather than write their own.
- **HTTP driver** — BaseLLMHTTPHandler in custom_httpx/llm_http_handler.py is the single execution path for provider calls, spanning roughly 14300 lines and over 220 methods covering chat, embeddings, rerank, files, batches, search, audio and decisions.
- **Surface split** — base_llm holds 34 sub-packages, one per API surface (chat, embedding, files, batches, images, videos, responses, rerank, search, ocr, realtime, vector_store, guardrail_translation and so on), so each surface has its own base config and guardrail contract instead of one oversized base class.
- **Guardrail discovery** — llms/__init__.py walks the llms tree at import time to find provider guardrail_translation packages (17 of them) and map them to call types, so adding a provider's guardrail translation needs no central registry edit.
- **Cost routing** — Per-provider pricing lives beside the provider (27 cost_calculator modules) and is reached through dispatchers on llms/__init__.py such as get_cost_for_web_search_request, which branches on custom_llm_provider and model key.
- **SDK-to-gateway reach-back** — 42 import statements in this section point back into litellm/proxy, so the SDK layer is not independent of the gateway: proxy_server, pass_through_endpoints, policy_engine, hooks, guardrails and auth are all imported from provider code.

ARCHITECTURE.md section 3 describes this section as the translation layer and its BaseConfig and llm_http_handler pointers match the code, but two of its specifics do not: the worked example imports BedrockConverseConfig, a name that exists nowhere in the tree (the class is AmazonConverseConfig), and it says every provider Config inherits BaseConfig when only 16 of the 86 chat transformation files define a class deriving from it. Its test path tests/llm_translation is empty at HEAD, and provider translation tests live under tests/unit/llms/<provider>.
This is the map's widest hub: 150 provider directories, 1115 files, and the target of hundreds of imports from litellm, litellm/proxy/guardrails and litellm/proxy/pass_through_endpoints. Treat it as a platform layer, but note that 42 of its own import statements, spread over 20 files, point back into litellm/proxy, so the dependency runs in both directions.

For exact behavior, read the code under `litellm/llms/`. Do not restate it here.
---

## litellm/mcp_client
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/mcp_client/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/mcp_client sha=8cf0cb72c62ced2f651634447ad16aea9b070276 -->

The Model Context Protocol client, connecting to MCP servers, listing and calling their tools, and mapping MCP tool schemas onto OpenAI and Anthropic tool definitions. At a glance:

- **Tool translation** — tools.py converts MCP tool schemas into OpenAI and Anthropic tool parameters and back, and lists tools with cursor pagination so a large server catalogue is not truncated.
- **Session client** — client.py's MCPClient owns the httpx2 session, the transport and protocol settings, the session callback map and the route that keeps a server's session callbacks isolated.
- **Optional dependency** — __init__.py converts a missing mcp or httpx2 extra into a pointed ImportError, so the core package imports cleanly without the MCP extras installed.
- **Gateway coupling** — The client imports the proxy's MCP context, debug capture and result conversion rather than reimplementing them, which means SDK-side MCP calls and gateway-side MCP calls share one contract.

For exact behavior, read the code under `litellm/mcp_client/`. Do not restate it here.
---

## litellm/models
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/models/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/models sha=e596919e3e08e1a3f75681c322a2a2758c440f8a -->

The canonical Pydantic models for every persisted LiteLLM entity: API keys, teams, users, budgets, models, tags, access groups, managed files and MCP servers, so the gateway and the SDK agree on one row shape. At a glance:

- **Table models** — Each module defines one table's model, for example LiteLLM_VerificationToken for API keys and LiteLLM_UserTable for end users, and the archived twin of each key table.
- **Base model** — base.py's DomainModel gives every table the shared from_attributes parsing plus id and timestamp fields.
- **Re-export surface** — models/__init__.py re-exports every table, and litellm/proxy/_types.py re-exports them again so existing proxy imports keep working.
- **Managed and permission tables** — managed_files.py models the managed file and vector-store objects, and object_permission.py models the per-object permissions that authorize them.
- **MCP servers** — mcp_server.py models a registered MCP server with its env-var scope and its static headers, which are stored encrypted.

ARCHITECTURE.md says litellm/models and litellm/repositories exist so the gateway and the SDK can use them without importing proxy internals, but models/mcp_server.py imports litellm.proxy.common_utils.encrypt_decrypt_utils inside a field validator to decrypt stored headers, so the models layer is not fully proxy-free.

For exact behavior, read the code under `litellm/models/`. Do not restate it here.
---

## litellm/passthrough
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/passthrough/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/passthrough sha=79916cbecd679c6824b67fe146418ed7fabc6ed2 -->

The provider passthrough route for the SDK, forwarding a raw request to a provider endpoint with merged headers and query parameters and returning the provider response, streamed or buffered, with spend still captured. At a glance:

- **Route entry** — main.py exposes llm_passthrough_route and allm_passthrough_route, which send the caller's body to an arbitrary provider endpoint and stream the response back without translating it.
- **Header and query merge** — utils.py's BasePassthroughUtils merges the caller's query parameters and forwards the inbound headers to the upstream request.
- **Timeout policy** — timeout_utils.py resolves the passthrough request timeout separately from the normal completion timeout, so a slow provider endpoint can be given its own budget.
- **Spend on stream** — main.py's _SpendCollection accumulates streamed bytes so spend is still flushed when the client disconnects mid-stream rather than being lost with the response.

For exact behavior, read the code under `litellm/passthrough/`. Do not restate it here.
---

## litellm/proxy/_experimental
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/_experimental/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/_experimental sha=f557bd354a9a1334b98a99efb9f86b18ea5211d2 -->

Packaged Admin UI assets and legacy proxy import shims. The section holds the compiled Next.js dashboard export that litellm/proxy mounts as its packaged UI path, plus a deprecated-import alias for the MCP server package and a sample custom post-call rule module. At a glance:

- **UI bundle** — out/ is the built Next.js dashboard export, one pre-rendered HTML page per admin route plus hashed JS and CSS chunks, images and logos; the ui section's build script copies it in here and the tree ships inside the wheel
- **MCP alias** — mcp_server/__init__.py re-points the old litellm.proxy._experimental.mcp_server import path at litellm.proxy.mcp_server through alias_deprecated_package, so deep imports of the retired path still resolve but warn
- **Sample rule** — post_call_rules.py is the two-line example of the callable a config-supplied post_call_rules entry must expose, the shape litellm/proxy loads by file path from the config
- **Asset catalog** — out/assets/logos holds per-provider logos and agent artwork that the built dashboard serves and that the MCP server registry entries reference by icon URL

812 of this section's 814 tracked files are the compiled dashboard bundle under out/, so the section is build output rather than in-progress proxy code; the only Python is the MCP import alias and the sample rule module.

For exact behavior, read the code under `litellm/proxy/_experimental/`. Do not restate it here.
---

## litellm/proxy/a2a
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/a2a/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/a2a sha=7317a8a30eebc3e84b2f8c35cd4ac53bf6de63b1 -->

The A2A protocol support for agent registration. It fetches an upstream agent's well-known card, merges it into the card the proxy fronts, and converts payloads between the A2A protocol versions the proxy can serve. At a glance:

- **Card discovery** — discovery.py fetches the upstream card and dispatches on the discovery mode, because pure A2A agents publish the card at one of the standard well-known paths while LangGraph Platform publishes a single card endpoint keyed by an assistant id.
- **Card merge** — agent_card.py merges the upstream card with the values an admin set in the UI, replacing the fields that would send traffic straight to the upstream so it flows through the proxy with LiteLLM auth, and it normalizes the served protocol version to a supported one.
- **Version conversion** — version_convert.py converts responses, stream events, forwarded requests and extended cards between the 0.3 and 1.0 wire shapes, inferring the incoming shape rather than trusting a stored one and falling back to the input unchanged so a conversion bug cannot break a valid response.
- **Discover route** — endpoints.py serves the single discovery route the UI calls when an admin registers an agent, returning the raw upstream card so the UI can pick which skills to expose.

For exact behavior, read the code under `litellm/proxy/a2a/`. Do not restate it here.
---

## litellm/proxy/agent_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/agent_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/agent_endpoints sha=11d71067ba83ea9ad83325fc648a2e4a94ec734e -->

The agent registry of the proxy. It registers, discovers, updates and retires upstream agents, tracks the managed identity behind each one, and relays A2A message traffic to the registered agent. At a glance:

- **Agent routes** — endpoints.py serves the agent list, create, retrieve, update, patch and delete routes plus the make-public and kill-switch routes.
- **Registry** — agent_registry.py persists agents through the shared agent repository, redacts sensitive fields on read, and owns the restore path for a kill-switched agent.
- **Identity** — identity_store.py binds verified human subjects to managed agent identities and keeps the retired identity and retired agent rows so a retired agent's identity cannot be reused.
- **Kill switch** — kill_switch.py calls the upstream agent's own kill switch with a timeout and a bounded response body, and records the outcome as an audit log.
- **Permission model** — auth/agent_permission_handler.py resolves which agents a caller may reach by intersecting key-level and team-level agent access, defaulting to deny when access cannot be established.
- **A2A routing** — a2a_routing.py merges the agent's parameters with the caller's and decides what to forward, while a2a_endpoints.py serves the agent card and the message-send route for a registered agent.

For exact behavior, read the code under `litellm/proxy/agent_endpoints/`. Do not restate it here.
---

## litellm/proxy/anthropic_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/anthropic_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/anthropic_endpoints sha=ea412e3aaa37c378e57fbeb82c543eb6c64eb4e6 -->

The Anthropic-shaped surface of the proxy. It serves the native Messages and count-tokens routes, the Claude Code gateway protocol that Claude Code clients sign in against, the Anthropic Skills API, and the Claude Code plugin marketplace. At a glance:

- **Messages and token counting** — endpoints.py serves the Anthropic Messages route and the token-count route, translating provider-specific Anthropic error detail into the Anthropic error body shape.
- **Claude Code gateway protocol** — gateway_endpoints.py implements the wire contract Claude Code expects from a gateway: OAuth 2.0 device authorization with a rotating refresh token, revocation for sign-out, managed settings, and OTLP metrics, logs and traces ingestion, all under a single base path.
- **Skills API** — skills_endpoints.py serves the Anthropic Skills API over the hosted skill search index, with upload, list, retrieve and delete routes.
- **Plugin marketplace** — claude_code_marketplace.py serves the marketplace document and the plugin enable, disable and delete lifecycle, and claude_code_skill_access.py decides which plugins a caller may see based on proxy admin status, object permissions and access-group grants.
- **Stream restamping** — streaming_model_restamp.py rewrites the model on the message_start event so a streamed response reports the requested model the way the non-streaming path already does.

ARCHITECTURE.md maps /v1/messages to this directory, but the route's own docstring marks it a beta surface and points callers at the passthrough route instead.

For exact behavior, read the code under `litellm/proxy/anthropic_endpoints/`. Do not restate it here.
---

## litellm/proxy/auth
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/auth/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/auth sha=f2655b3a32e9cc194407ecac7f5e6dfe758ab438 -->

Authentication and authorization for every proxy request: it resolves the caller into a UserAPIKeyAuth and then decides which routes, models and budgets that caller may reach. At a glance:

- **Entry point** — user_api_key_auth.py owns user_api_key_auth, the dependency every protected route calls to turn an API key, JWT or session into a UserAPIKeyAuth
- **Key and team resolution** — auth_checks.py looks up the key, team and org rows behind a request and enforces the per-model budget the key carries
- **Route authorization** — route_checks.py decides whether the resolved key may call the route it asked for, including enterprise route restrictions
- **Model access** — model_checks.py resolves the model list a key, team or access group is allowed to call
- **Fallback budget** — fallback_budget.py enforces the per-model and per-router budget ceilings that stand in for the key-level limit
- **Network identity** — network.py resolves the real client IP behind proxies and trusted_proxy_utils.py decides which forwarded headers are believed
- **Boot and password safety** — master_key_boot_check.py refuses to start on an unsafe master key and password_policy.py screens user passwords at creation

For exact behavior, read the code under `litellm/proxy/auth/`. Do not restate it here.
---

## litellm/proxy/batches_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/batches_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/batches_endpoints sha=1ec88b827fcfef9f92617a175988736f87f0ae62 -->

The OpenAI Batch API surface. It accepts batch jobs against a named provider or the generic route, tracks them, and can either hand them to the provider or execute them inside the proxy itself. At a glance:

- **Route aliases** — endpoints.py mounts the same batch handlers under a provider-scoped path, the versioned path and the bare path, so a client can pick whichever form it already speaks.
- **Proxy-executed batches** — litellm_executed_batches.py holds the runner that executes a batch inside the proxy, with bounded concurrency, a managed batch store and per-record error accounting, for providers that cannot run batches themselves.
- **List limit validation** — common_utils.py rejects a batch list limit outside the supported range using the OpenAI error shape, keeping the list contract identical to the provider's.
- **Batch attribution** — The batch surface imports the passthrough provider handlers' batch attribution helper, so a batch submitted through a provider is attributed the same way a direct call would be.

For exact behavior, read the code under `litellm/proxy/batches_endpoints/`. Do not restate it here.
---

## litellm/proxy/client
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/client/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/client sha=68a875bc9e7d0480a9230416168a670da04f9574 -->

The Python client and CLI for a running proxy: typed management clients for keys, teams, models and credentials, plus the command line that drives the same operations. At a glance:

- **Client facade** — client.py owns Client, which assembles the per-resource clients over one base URL and key
- **Chat client** — chat.py holds ChatClient, the streaming client for chat completions against the proxy
- **CLI entry point** — cli/main.py builds the click group and its command table, including the operator-hidden commands
- **Credential storage** — cli/commands/auth.py owns CliTokenData, the token and keychain-backed credential context the CLI reuses
- **PKCE login** — cli/commands/pkce_login.py implements the browser-based PKCE flow, including client registration and the loopback callback server
- **Agent configuration** — cli/commands/configure.py writes the Codex and Claude Code settings that point a native agent at the proxy

For exact behavior, read the code under `litellm/proxy/client/`. Do not restate it here.
---

## litellm/proxy/common_utils
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/common_utils/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/common_utils sha=21e7a3881177ec07a320224311065e45d71eece6 -->

Shared proxy support code: configuration loading, credential encryption, callback registration, caching, and the small helpers that many other proxy sections import rather than reimplement. At a glance:

- **Config loading** — load_config_utils.py fetches the proxy config from disk or from S3, GCS or Azure, and config_includes.py resolves include directives inside it
- **Callback registration** — callback_utils.py owns initialize_callbacks_on_proxy, which turns the configured custom callbacks and guardrails into live handlers at startup
- **Credential encryption** — encrypt_decrypt_utils.py encrypts and decrypts stored provider credentials against the proxy salt key
- **Key object cache** — user_api_key_cache.py holds UserApiKeyCache, the dual-cache wrapper that keeps resolved auth objects in memory and in Redis
- **Error and tag mapping** — openai_error_payload.py builds the OpenAI-shaped error body and request_tag_mappings.py maps request tags onto routes and models
- **Budget reset job** — reset_budget_job.py implements the scheduled job that clears per-window spend for keys, users and teams

For exact behavior, read the code under `litellm/proxy/common_utils/`. Do not restate it here.
---

## litellm/proxy/config_resolvers
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/config_resolvers/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/config_resolvers sha=78c6273e6a2841e55148458f9d9bb9c47dbf0caa -->

Settings reconciliation for the proxy: it decides whether a setting comes from the config file, the database or the environment, and reports which source won. At a glance:

- **Field descriptors** — _descriptors.py owns resolve_fields, which reconciles a stored database row against the environment with a fixed precedence and returns per-field provenance
- **Settings store** — settings_store.py owns SettingsStore, the merged view over config, database and runtime values that refuses to overwrite a config-owned key
- **Section rules** — settings_rules.py maps each settings section to the database row that owns it and the precedence that applies
- **SSO resolution** — sso.py owns resolve_sso_config, the single place that maps SSO fields onto their environment variables for both read and save
- **Change detection** — changed_section_keys.py compares old and new settings so only the sections that actually changed are reloaded

For exact behavior, read the code under `litellm/proxy/config_resolvers/`. Do not restate it here.
---

## litellm/proxy/container_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/container_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/container_endpoints sha=7fc92fca33dd637c90264bfc9ac9506f7be5df79 -->

The containers surface of the proxy. It creates, lists, retrieves and deletes provider-side containers, and it keeps track of which caller owns each container so a container is not visible to anyone else. At a glance:

- **Route aliases** — endpoints.py mounts the container routes under both a versioned and a bare path for create, list, retrieve and delete.
- **Ownership** — ownership.py records the owning caller against the managed object repository and answers the access assertion that every read and delete goes through, backed by a short-lived in-memory cache so the check does not hit the database each time.
- **Config-driven file endpoints** — handler_factory.py reads the container endpoints config and generates the FastAPI handlers for the provider's container file paths, so a new provider file route does not need hand-written plumbing.
- **Forwarding parameters** — The ownership module also produces the forwarding parameters a request needs to reach the right provider deployment.

For exact behavior, read the code under `litellm/proxy/container_endpoints/`. Do not restate it here.
---

## litellm/proxy/db
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/db/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/db sha=85e7fb1ac232e13585aea61ff1d2fe0f08ad9e81 -->

The proxy's Postgres access layer: the Prisma client wrapper, the queued spend and window-spend writers, and the transaction machinery that keeps the database current. At a glance:

- **Client wrapper** — prisma_client.py owns PrismaWrapper, which keeps the generated Prisma client alive, refreshes IAM and Entra database tokens, and can route reads to a replica
- **Spend writer** — db_spend_update_writer.py owns DBSpendUpdateWriter, which batches spend log and daily spend upserts instead of writing per request
- **Transaction queues** — db_transaction_queue holds the Redis-backed update queues, the pod lock that elects one writer, and the spend log cleanup
- **Lookup gate** — db_lookup_gate.py bounds concurrent database lookups so a slow database cannot exhaust the request path
- **Master key migration** — master_key_migration.py re-encrypts the stored secret columns when the master key is rotated
- **Failure handling** — exception_handler.py classifies Prisma and connection failures so callers can retry instead of surfacing a raw driver error

For exact behavior, read the code under `litellm/proxy/db/`. Do not restate it here.
---

## litellm/proxy/discovery_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/discovery_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/discovery_endpoints sha=56edcc35f6cdb48baae2d6ae5018fe2aed4b9d09 -->

The public discovery documents of the proxy. It publishes the Agent Skills well-known index and the skill archives it points at, plus the UI configuration document that tells a browser where the dashboard lives. At a glance:

- **Skills index** — agent_skills_endpoints.py serves the well-known agent-skills index and the per-skill archive download; both routes are unauthenticated and stay off until public_skills_index is enabled, because publishing them exposes every stored skill to anyone who can reach the proxy.
- **Archive repack** — agent_skills_archive.py rebuilds a stored skill upload into the archive shape clients install from, stripping the upload's top-level folder and fixing entry timestamps so the SHA-256 published in the index is reproducible for identical uploads.
- **Index limits** — The index caps how many skills it lists and how many archives it caches, and it bounds the cached archive bytes.
- **UI discovery** — ui_discovery_endpoints.py serves the well-known UI configuration describing SSO setup, whether the admin UI is disabled and whether default credentials should be hinted.

For exact behavior, read the code under `litellm/proxy/discovery_endpoints/`. Do not restate it here.
---

## litellm/proxy/example_config_yaml
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/example_config_yaml/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/example_config_yaml sha=08bd2efa9b11fdae6d7f3dddb9a6eadf4fed3432 -->

Reference proxy configurations and the custom auth, callback, guardrail and validator modules they point at, kept as working examples of how to extend the gateway. At a glance:

- **Custom auth** — custom_auth.py shows the user_api_key_auth and generate_key_fn pair a deployment implements to take over authentication
- **Custom callbacks** — custom_callbacks.py shows a MyCustomHandler logger registered through the config's custom_callbacks list
- **Custom guardrail** — custom_guardrail.py shows a myCustomGuardrail implementation wired into a config
- **Team metadata validation** — custom_team_metadata_validate.py shows the validate_team_metadata hook the proxy calls for team-level checks
- **Config template** — simple_config.yaml is the minimal working proxy config the examples build on

For exact behavior, read the code under `litellm/proxy/example_config_yaml/`. Do not restate it here.
---

## litellm/proxy/guardrails
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/guardrails/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/guardrails sha=9480361f95f060c830220fa4cf781abdb8c63862 -->

The guardrail plugin subsystem. It keeps a registry of initialized guardrails, ships roughly sixty vendor-specific guardrail adapters, carries the built-in content-filter rule data, and serves the CRUD and usage-reporting routes that let operators manage guardrails from the Admin UI. At a glance:

- **Registry** — guardrail_registry.py owns GuardrailRegistry, which resolves a guardrail name to its initialized callback and derives a stable guardrail id from the name so repeated config loads do not create duplicate identities.
- **Vendor adapters** — The guardrail_hooks directory holds about sixty provider packages, from Bedrock and Azure through Cisco, PANW and Presidio, each a CustomGuardrail subclass with its own request and response translation.
- **Built-in content filter** — litellm_content_filter compiles the YAML category and policy-template packs under content_filter_data into the built-in ContentFilterGuardrail, so policy-as-data ships with the proxy rather than being configured per deployment.
- **Management routes** — guardrail_endpoints.py serves list, create, update, delete and register routes plus a submission review flow where a submitted guardrail is approved or rejected, and it also derives the provider-specific parameter schema for the UI form.
- **Usage metering** — usage_tracking.py upserts daily guardrail and policy metrics and writes the spend-log guardrail index alongside spend logs, while usage_endpoints.py exposes the overview, detail and log views over that data.
- **Tool scoping** — tool_name_extraction.py extracts tool names from chat, messages and MCP request bodies so a guardrail can be scoped to the tools a request actually invokes.

ARCHITECTURE.md has no guardrail section at all, so this subsystem, its vendor adapters and its usage dashboards are undocumented in the repo-level map even though it is one of the larger pieces of the proxy.

For exact behavior, read the code under `litellm/proxy/guardrails/`. Do not restate it here.
---

## litellm/proxy/hooks
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/hooks/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/hooks sha=883d45e00b89190cb73293347388680332f95da3 -->

The proxy's callback layer: the CustomLogger subclasses the gateway runs around each request for rate limiting, budget enforcement, cache-control validation and cost attribution. At a glance:

- **Hook registry** — __init__.py holds PROXY_HOOKS, the name to class registry that the proxy resolves hooks from, extended at import time with the enterprise hook set
- **Parallel request limiting** — parallel_request_limiter_v3.py owns the default limiter, which enforces per-key and per-user TPM, RPM and parallel request ceilings
- **Cost tracking** — proxy_track_cost_callback.py owns _ProxyDBLogger, the success callback that computes response cost and queues the spend write
- **Cache control validation** — cache_control_check.py rejects provider cache-control blocks that the target model cannot honor
- **Response id security** — responses_id_security.py signs and re-keys Responses API ids so a client cannot replay another call's id
- **Model budget ceiling** — model_max_budget_limiter.py resolves and enforces the per-model spend ceiling for a key

For exact behavior, read the code under `litellm/proxy/hooks/`. Do not restate it here.
---

## litellm/proxy/lens
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/lens/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/lens sha=c2ec16d0860f4d704e8c02987209f68db624ce4a -->

The Lens tracing integration: it forwards a request to a Lens collector under a delegated identity and bounds what may be buffered while it does. At a glance:

- **Adapter** — adapter.py owns the /lens router and lens_request, which forwards a proxied request to the collector
- **Delegated identity** — adapter.py builds the delegated identity that authorizes the forwarded call
- **Buffer budget** — buffering.py owns BufferBudget, which caps the bytes in flight against the downstream response
- **Internal auth** — internal.py owns LensInternalMiddleware, which verifies the signed internal claim on the loopback path

For exact behavior, read the code under `litellm/proxy/lens/`. Do not restate it here.
---

## litellm/proxy/list_api
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/list_api/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/list_api sha=f8e10c2168ad3db65aaa24544ca44914741e668b -->

The shared contract for LiteLLM's collection endpoints: it turns query parameters into a filter and sort plan and renders the same problem responses on every list route. At a glance:

- **List framework** — list_framework.py owns build_query_plan, which turns query parameters into a QueryPlan without touching a database
- **Route spec** — list_framework.py defines ListSpec, the per-route declaration of columns, filters, sorts and scope
- **Problem responses** — common.py owns ManagementProblem and the RFC 9457 problem rendering every list route returns
- **In-memory executor** — in_memory.py holds InMemoryListExecutor, the executor for list resources whose rows are computed rather than queried
- **SQL rendering** — list_framework.py owns where_sql, which renders a plan's predicates with every value bound to a placeholder

For exact behavior, read the code under `litellm/proxy/list_api/`. Do not restate it here.
---

## litellm/proxy/management
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/management/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/management sha=d56e88f247eaf1fbfc51a8e08597346dd1ad5b4f -->

Shared team and user authorization primitives for the management plane. It holds the frozen TeamAccess role checker, the org-admin lookup it needs, and the current-user endpoint the Admin UI calls to identify itself. At a glance:

- **Team role checker** — teams/authz.py defines TeamAccess with allows and strongest_role, checking proxy admin first, then team admin, then org admin, so a caller holding several roles keeps the strongest edit rights and only off-roster callers pay for the org lookup.
- **Frozen role sets** — The module exports TEAM_ADMIN_ONLY and TEAM_OR_ORG_ADMIN as frozensets so callers state which roles a route accepts rather than hand-rolling role comparisons.
- **Compatibility shim** — teams/access.py re-exports the authz symbols purely because the published litellm-enterprise 0.1.73 wheel imports is_team_admin from that path, and it is marked for deletion once the enterprise pin moves.
- **Org role lookup** — users/service.py holds PrismaOrgRoles, which answers is_org_admin by reading the user's organization_memberships through the shared user-object cache.
- **Current user route** — users/endpoints.py serves a single GET under the management v1 prefix that returns the caller's id, role and email, and raises a 404 ProblemDetail when the key is not bound to a user.

For exact behavior, read the code under `litellm/proxy/management/`. Do not restate it here.
---

## litellm/proxy/management_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/management_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/management_endpoints sha=44d96f728e57b240491ab4a1f5501835410b1427 -->

The proxy's admin control-plane HTTP surface. It serves key, team, user, budget, model, tag, callback, access-group, organization, policy, ROI and SSO/SCIM administration routes, and it is where the admin side resolves a caller's team and key context. At a glance:

- **Route families** — Key administration lives in key_management_endpoints.py, the largest file in the section at over 8400 lines, and owns the generate, update, delete, list, info, bulk-update and regenerate key routes plus the generation-policy checks that gate who may mint a key for a team.
- **Versioned control plane** — The management_v1 subpackage aggregates budgets, spend-logs, teams and users routers behind the MANAGEMENT_V1_PREFIX constant, giving the newer control-plane routes a single shared prefix and a single list-contract implementation.
- **Shared validation** — common_utils.py rejects non-finite spend values before they reach the database or the spend counter, because a NaN spend silently defeats the max_budget comparison, and it also validates budget duration strings.
- **Privilege model** — types.py defines LITELLM_USER_ROLE_HIERARCHY and highest_privilege_role, picking the most privileged role out of a multi-valued IdP role claim instead of trusting claim order.
- **Enterprise identity** — The sso subpackage holds SAML, Microsoft and ID-JAG sign-in flows and the scim subpackage implements SCIM v2 user provisioning, both gated behind a premium license.
- **Policy and ROI admin** — The policy_endpoints subpackage exposes policy validation and listing for the Admin UI, and roi_calculator_endpoints.py defines the ROI router with an APScheduler-driven refresh plus the observed-report router it pulls in, over the analytics the ROI calculator section supplies.

ARCHITECTURE.md's "LLM-specific proxy endpoints" table lists only inference-shaped routes and does not mention this directory, the guardrails subsystem, the MCP gateway, the policy engine, the agent registry or the ROI calculator; the code, not the doc, is the map for those.

For exact behavior, read the code under `litellm/proxy/management_endpoints/`. Do not restate it here.
---

## litellm/proxy/management_helpers
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/management_helpers/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/management_helpers sha=58739cd9c636a9514d0a9666a835f38095db562d -->

Write-path helpers shared by the management routes. It holds the bulk user and team operations, the roster and access-group mirroring, the object-permission upserts and the audit-log writes that keep the admin surface out of the route handlers. At a glance:

- **Bulk user creation** — bulk_user_creation.py validates a batch of new users with set queries, inserts them in a single create_many, and writes each referenced team once under its advisory lock instead of once per user.
- **Roster sync** — team_roster_sync.py computes the added and removed member sets, applies both in one transaction and settles the cached team and membership state afterwards.
- **Access-group reverse sync** — access_group_team_sync.py mirrors an access-group edit made on the team side back into the access-group table, and it lives outside the access-group endpoints on purpose so importing it cannot eagerly pull in a lazily registered feature router and drop its routes from the OpenAPI schema.
- **Object permissions** — object_permission_utils.py normalizes and upserts the per-object permission rows for organizations, teams and keys and evicts the cached copies when they change.
- **Audit trail** — audit_logs.py writes LiteLLM_AuditLogs rows for admin mutations and resolves the changed-by actor from the request header.

For exact behavior, read the code under `litellm/proxy/management_helpers/`. Do not restate it here.
---

## litellm/proxy/mcp_server
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/mcp_server/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/mcp_server sha=83633ed39e26ef2f44bee76eae1b8dc50515ebea -->

The gateway's Model Context Protocol implementation. It manages upstream MCP servers, aggregates their tools into a paginated gateway catalog, resolves outbound credentials per server, and exposes the MCP transport, a REST mirror and the OAuth discovery, registration and BYOK flows that clients negotiate against. At a glance:

- **Upstream manager** — mcp_server_manager.py owns the client sessions for the configured upstream MCP servers across SSE and streamable-HTTP transports, and it is the only place that knows how to talk to an upstream server.
- **Catalog and pagination** — catalog.py aggregates tools, prompts and resources across servers behind a global manager, and the accompanying README specifies that pagination state is encrypted with purpose-separated keys derived from the salt key and that cursors expire ten minutes after the first page.
- **Tool registry** — tool_registry.py holds the live tool registry that in-flight requests resolve against, and tool_search.py layers keyword ranking plus JSON-schema argument validation on top of it for the virtual search tools.
- **Outbound credentials** — The outbound_credentials package holds twenty-seven modules behind a single resolver that dispatches on the server's typed auth config, so each credential mode gets a fully typed arm and an unimplemented mode fails loudly instead of returning nothing.
- **OAuth and discovery** — discoverable_endpoints.py and byok_oauth_endpoints.py serve the authorization-server metadata, dynamic client registration, authorize, token, revoke and JWKS routes that MCP clients and BYOK users negotiate against.
- **Persistence** — db.py persists MCP server rows, per-user credentials and OAuth tokens with expiry buffers and rejects stale auth fields on update.

For exact behavior, read the code under `litellm/proxy/mcp_server/`. Do not restate it here.
---

## litellm/proxy/middleware
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/middleware/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/middleware sha=13a70b1175844471c349d17512d045014163e232 -->

The ASGI middleware ring around the proxy app: it caps request size, decompresses bodies, compresses responses, adds security headers and gates the metrics endpoint. At a glance:

- **Request size limit** — request_size_limit_middleware.py rejects oversized bodies before downstream auth or routes parse them
- **Body decompression** — request_body_decompression_middleware.py expands compressed request bodies under a decompression ratio and size ceiling
- **Response compression** — gzip_middleware.py buffers and compresses responses above a minimum size
- **Security headers** — security_headers_middleware.py sets anti-framing, nosniff and optional HSTS headers on every response
- **Admission control** — admission_control_middleware.py bounds concurrent work with a lease, exempting the health paths
- **Metrics authentication** — prometheus_auth_middleware.py guards the Prometheus scrape path with the same key auth the API uses

For exact behavior, read the code under `litellm/proxy/middleware/`. Do not restate it here.
---

## litellm/proxy/openai_files_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/openai_files_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/openai_files_endpoints sha=8d2c2844b340df24512fe6a9352ba9c5d8e8c11c -->

The OpenAI Files API surface. It uploads, lists, retrieves, deletes and streams back files, routes each upload to the right storage backend, and screens batch input files before they are accepted. At a glance:

- **Route aliases** — files_endpoints.py mounts the file routes under a provider-scoped path, the versioned path and the bare path, and route_create_file decides whether the upload goes to a provider, to the proxy's own storage or into a proxy-executed batch.
- **Storage backends** — storage_backend_service.py wraps the shared storage backend abstraction so a file can be uploaded to a custom backend such as Azure Blob while the managed-file metadata is kept in step.
- **Upload validation** — general_upload_validation.py enforces size ceilings, an extension allow list, a blocked-extension list and filename safety before a file is accepted.
- **Batch guardrail scan** — batch_guardrails.py runs the configured pre-call guardrails over every record of a batch input file, on the understanding that the batch file validation has already proved each line is a JSON object with the expected fields.
- **Content streaming** — file_content_streaming_handler.py streams file content back to the client rather than buffering it, and it also carries the usage caps applied to file reads.
- **Credential handling** — common_utils.py resolves explicit per-request and per-team provider credentials and the shared managed-file records that back them.

For exact behavior, read the code under `litellm/proxy/openai_files_endpoints/`. Do not restate it here.
---

## litellm/proxy/pass_through_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/pass_through_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/pass_through_endpoints sha=6550123d49c4b01350d42321561d78e9af1b7156 -->

The provider-direct passthrough surface. It forwards a client request body unchanged to an upstream provider after rewriting the URL and swapping the credential, and it parses the provider's response so the call can still be costed and logged. At a glance:

- **Own architecture note** — The architecture.md in this directory is the authoritative statement of the contract: the body is unchanged, but URL construction, auth-header replacement, x-pass-* header stripping, tag extraction, guardrails and cost injection all still happen.
- **Generic handler** — pass_through_endpoints.py implements the shared pass_through_request path and the route factory that creates one route per configured passthrough endpoint, and it also carries the admin routes that manage those configurations.
- **Provider logging handlers** — llm_provider_handlers holds a base handler plus one subclass per provider family, which is how a provider-specific response gets turned into cost and usage without special-casing the generic path.
- **Managed id rewriting** — managed_id_rewriter.py rewrites provider-native file and object ids into LiteLLM managed ids in both buffered and streamed responses, so a passthrough result can be referenced later through the proxy's own storage.
- **Guardrails** — passthrough_guardrails.py runs the configured guardrails on passthrough traffic, which is opt-in because the body is otherwise untouched.
- **Credential resolution** — passthrough_endpoint_router.py picks the deployment and the provider credential for a passthrough path and resolves secret references, refusing to continue when a reference cannot be resolved.

For exact behavior, read the code under `litellm/proxy/pass_through_endpoints/`. Do not restate it here.
---

## litellm/proxy/policy_engine
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/policy_engine/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/policy_engine sha=c874c01d05556d5475c649353ed0bda3f70d03d7 -->

The policy engine. It defines named policies that combine guardrails with inheritance and conditions, attaches those policies to teams, keys and models, and resolves and runs the resulting guardrail pipeline for a request. At a glance:

- **Registry** — policy_registry.py owns PolicyRegistry, which keeps policies in memory and persists them and their version rows through the shared policy repository.
- **Attachment registry** — attachment_registry.py owns the separate AttachmentRegistry, holding where policies apply and ordering attachments by specificity so the most specific attachment wins.
- **Resolution** — policy_resolver.py resolves the inheritance chain with add and remove operations, and condition_evaluator.py evaluates the model condition on a policy, supporting exact matches, regular expressions and lists.
- **Matching** — policy_matcher.py matches an incoming request's team alias, key alias and model against the attachment scopes using the shared wildcard pattern helper.
- **Pipeline execution** — pipeline_executor.py runs the resolved guardrail steps in order, distinguishes detect-only steps, and raises UndeliverableStreamRewrite when a guardrail rewrote a stream that can no longer be written back.
- **Startup load** — init_policies.py loads the policies and attachments from config at startup, validates them and prints what was loaded.

ARCHITECTURE.md has no policy-engine entry; the doc's proxy section covers inference routes and hooks only, so this engine and the guardrail subsystem it orchestrates are both outside the repo-level map.

For exact behavior, read the code under `litellm/proxy/policy_engine/`. Do not restate it here.
---

## litellm/proxy/prompts
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/prompts/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/prompts sha=87232d8b0d63dc46063f5f85efadcda9dc9a89b6 -->

Prompt management for the gateway: a versioned prompt registry, the endpoints that serve stored prompts, and the initializer that loads prompts from the config file. At a glance:

- **Registry** — prompt_registry.py owns IN_MEMORY_PROMPT_REGISTRY, the in-memory registry of the prompts the proxy serves
- **Versioning** — prompt_registry.py owns get_base_prompt_id and the version parsing that lets a prompt id carry a version suffix
- **Environment precedence** — prompt_registry.py defines the order in which production, staging and development environments are consulted when serving a prompt
- **Endpoints** — prompt_endpoints.py owns the router that serves and edits stored prompts
- **Initialization** — init_prompts.py owns init_prompts, which loads the prompts declared in the config file into the registry

For exact behavior, read the code under `litellm/proxy/prompts/`. Do not restate it here.
---

## litellm/proxy/public_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/public_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/public_endpoints sha=cc0595c3c560f4b896e46b927d0da0796ba58cdf -->

The gateway's unauthenticated public surface: the model hub, the provider and agent creation schemas, and the release and preset catalogs the dashboard renders. At a glance:

- **Model hub** — public_v1/model_hub.py builds the public model listing, enriching each row with live health and feature data
- **Provider fields** — provider_create_fields.json declares the credential fields each provider needs when a key is created
- **Agent fields** — agent_create_fields.json declares the same for agent types, including their litellm params template
- **Release feed** — whats_new.json carries the launch entries the dashboard's what's new panel renders
- **Endpoint catalog** — public_endpoints.py serves the supported provider and endpoint list from the bundled file

For exact behavior, read the code under `litellm/proxy/public_endpoints/`. Do not restate it here.
---

## litellm/proxy/rag_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/rag_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/rag_endpoints sha=a860d6a9e82c8aae2358e316f4f82ea077247d35 -->

The RAG surface of the proxy. It exposes an all-in-one ingestion pipeline that uploads, chunks, embeds and stores a document, and a query pipeline that searches, reranks and completes. At a glance:

- **Route aliases** — endpoints.py mounts the ingest and query pipelines under both a versioned and a bare path so a client can call either form.
- **Upload security** — upload_security.py classifies content by inspecting its actual bytes and a strict UTF-8 decode rather than trusting the filename or content type, rejects archives and executables by magic signature, caps the size and passes the file through a dependency-injected malware scanner before it is accepted.
- **Vector store hand-off** — The ingest pipeline builds the managed vector store request through the vector store section's request builder rather than duplicating the vector store payload contract.
- **Managed naming** — Accepted uploads are given a server-generated filename so the client-controlled name never reaches storage.

For exact behavior, read the code under `litellm/proxy/rag_endpoints/`. Do not restate it here.
---

## litellm/proxy/response_polling
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/response_polling/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/response_polling sha=b1f8d8cb6b1f70da251c79155874359fdbb5b268 -->

The polling mode of the Responses API. It hands the client a polling id, keeps the in-flight response in Redis, and streams partial provider output into that cache so a background request can be collected later. At a glance:

- **Polling handler** — polling_handler.py owns the litellm_poll_ id format and the Redis cache key for a polling entry, and it creates and updates the cached ResponsesAPIResponse as the request progresses.
- **Background streaming** — background_streaming.py runs the provider stream as a background task and writes partial responses into the polling cache, so a polling client can watch a background request advance.
- **Public surface** — The package init exports the handler, the background task and the request predicate that decides whether a request should be polled rather than awaited.
- **Redis backing** — The handler holds a Redis cache and a time to live, so a polled response expires from the cache on its own rather than needing a janitor.

For exact behavior, read the code under `litellm/proxy/response_polling/`. Do not restate it here.
---

## litellm/proxy/roi_calculator
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/roi_calculator/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/roi_calculator sha=0bad478dc89524079c2f064913434f0b52cafcdb -->

The ROI calculator engine. It collects pull-request evidence from GitHub or GitLab, estimates the developer time a pull request saved, and attributes proxy spend to those pull requests so a team can be told what its LLM usage bought. At a glance:

- **Retired dashboard** — The section README states the integrated ROI calculator is retired and that its dashboard page, API endpoints, OAuth callbacks and scheduled refresh are no longer available, while the backend implementation and the stored configuration are retained so reverting the retirement restores the feature.
- **Observed reporting** — The observed_* modules and github_observed.py implement the second, observed reporting path that measures issue and pull activity directly instead of estimating it, and observed_workspace.py merges several sources into one report.
- **Source abstraction** — source.py defines the RepositorySource protocol and selects the GitHub or GitLab implementation from the saved settings, so the sync and estimate code does not branch on provider.
- **Estimator** — estimator.py asks a model to turn the collected diff and commit evidence into an estimate, with a versioned response contract and a bounded evidence size.
- **Spend sync** — sync.py reads proxy spend and repository pull requests and joins them into per-pull records, falling back to an unlinked estimate when a record cannot be produced.
- **Analytics and settings** — analytics.py and observed_analytics.py summarise reports per person by matching identities, while settings.py stores the source connections with encrypted tokens in the config repository.

The engine's HTTP surface is defined in litellm/proxy/management_endpoints/roi_calculator_endpoints.py, and no application in the proxy mounts that router, so the ROI endpoints are reachable only from tests.

For exact behavior, read the code under `litellm/proxy/roi_calculator/`. Do not restate it here.
---

## litellm/proxy/search_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/search_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/search_endpoints sha=42d9fca492c5c9309cc58c54db8852adf93746ee -->

The web-search surface of the proxy. It runs a search query against a configured search tool and manages the stored search-tool configurations, including their encrypted provider credentials. At a glance:

- **Route aliases** — endpoints.py mounts the search route under a versioned path, a bare path, and a form that names the search tool explicitly.
- **Registry** — search_tool_registry.py stores search tool configurations through the shared table repositories and encrypts provider credentials with the proxy's salt key.
- **Management routes** — search_tool_management.py serves the list, create, update, delete and get routes for search tools plus a connection test and the available-provider list the UI needs to populate its form.
- **Per-team scoping** — The management routes read the caller's team and role so a search tool's visibility is decided by team rather than by key alone.

For exact behavior, read the code under `litellm/proxy/search_endpoints/`. Do not restate it here.
---

## litellm/proxy/shutdown
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/shutdown/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/shutdown sha=f1eee56c10343c9630c92aad53e8a44fc8e9020f -->

Graceful termination for the proxy: it drains in-flight requests, lets scheduled jobs finish, and gives the server worker a bounded window to exit. At a glance:

- **Drain manager** — graceful_shutdown_manager.py owns GracefulShutdownManager, which blocks until the in-flight request count reaches zero or the timeout elapses
- **Scheduled jobs** — scheduled_jobs.py owns stop_in_flight_scheduler_jobs, which lets running jobs finish before the database is disconnected
- **Worker** — graceful_uvicorn_worker.py builds the uvicorn worker that applies the graceful shutdown timeout

For exact behavior, read the code under `litellm/proxy/shutdown/`. Do not restate it here.
---

## litellm/proxy/spend_tracking
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/spend_tracking/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/spend_tracking sha=dcf46d2c9320195fbf191707bda8fe5e0dcae26d -->

Cost attribution for the gateway: it turns a completed request into spend records, keeps the budget counters the auth section reads, and exposes the spend reporting endpoints. At a glance:

- **Spend event** — spend_event.py defines SpendEvent, the compact typed success event handed from the inference worker to the collector
- **Event producer** — spend_event_producer.py builds the fire-and-forget producer that pushes serialized spend events to the pod-local collector sidecar
- **Counter batching** — spend_counter_batch.py reads the spend counters with one Redis MGET per phase rather than one GET each
- **Budget reservation** — budget_reservation.py reserves budget before the call and settles or releases it afterwards
- **Capture rate** — spend_capture_rate.py compares what the proxy billed against what the provider actually charged
- **Spend reporting** — spend_management_endpoints.py serves the per-key and per-team spend and activity reports

For exact behavior, read the code under `litellm/proxy/spend_tracking/`. Do not restate it here.
---

## litellm/proxy/swagger
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/swagger/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/swagger sha=7be021e3386987578607b3962e81df3c95299596 -->

The vendored Swagger UI assets the proxy serves for its OpenAPI page, so the documentation renders without a CDN fetch. At a glance:

- **UI bundle** — swagger-ui-bundle.js is the pinned Swagger UI distribution the docs page loads
- **Stylesheet** — swagger-ui.css is the matching theme for that bundle
- **Favicon** — favicon.png is the icon the docs page requests

For exact behavior, read the code under `litellm/proxy/swagger/`. Do not restate it here.
---

## litellm/proxy/telemetry
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/telemetry/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/telemetry sha=892d8939aed2584e40005e1f0538cc8fa781f3df -->

Telemetry for the proxy itself: it records per-request timings and provider attempts, stores them, and exports them only under the configured consent. At a glance:

- **Request middleware** — middleware.py owns TelemetryMiddleware, the ASGI layer that measures request timing and classifies the response
- **Attempt logger** — attempt_logger.py holds TelemetryAttemptLogger, which turns each provider attempt into a telemetry attempt record
- **Consent and settings** — settings.py owns env_policy and TelemetrySettings, the policy that decides whether telemetry may leave the process
- **Runtime** — runtime.py owns TelemetryRuntime, which assembles the sink, the exporter and the deployment hashing secret
- **Storage** — store.py holds TelemetryStore, which persists reports and the deployment hash secret in the proxy's own database
- **Block counting** — blocks.py owns count_blocks, which classifies message content into the block types the reports count

For exact behavior, read the code under `litellm/proxy/telemetry/`. Do not restate it here.
---

## litellm/proxy/ui_crud_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/ui_crud_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/ui_crud_endpoints sha=91f939013ec5f926874ef72d8271175fa02bd1d7 -->

The Admin UI settings surface. It exposes the get and update pairs for proxy-wide settings, the release-notes lookup the dashboard shows, and the dashboard banner. At a glance:

- **Settings pairs** — proxy_setting_endpoints.py serves the matching get and update pairs for allowed IPs, internal-user settings, default team settings, SSO settings, UI theme, MCP semantic filtering, websearch interception and MCP tool search, and it refuses to write settings that the config file owns.
- **Config ownership resolution** — The settings routes route every field through the shared config resolvers, which report the source of a setting and refuse a database write for a config-owned key.
- **Release notes** — latest_release_endpoints.py pulls the changelog feed and the GitHub release feed, parses release bullets and first contributions, and caches the result, including a short negative cache when the lookup fails.
- **Banner** — user_banner_endpoints.py stores a single dashboard-wide banner with an enabled flag, a severity and a bounded message, visible to every authenticated dashboard user.

For exact behavior, read the code under `litellm/proxy/ui_crud_endpoints/`. Do not restate it here.
---

## litellm/proxy/vector_store_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/vector_store_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/vector_store_endpoints sha=0b04cc1d9750f57f2e2b40ff65ef955dd3f83364 -->

The vector store surface of the proxy. It serves the OpenAI-compatible vector store routes for creating, listing, retrieving, updating, deleting and searching stores, and it registers LiteLLM-managed vector stores and their indexes. At a glance:

- **OpenAI-compatible routes** — endpoints.py mounts the vector store and search routes under both a versioned and a bare path, and it also serves the index routes.
- **Managed store registration** — management_endpoints.py serves the new, list, delete, info and update routes for LiteLLM-managed vector stores through the managed store repository.
- **Access checks** — utils.py asserts that a caller may reach a store and filters the listable set, with proxy admin bypassing the ownership check and UI session credentials contributing their team scope.
- **Server-side embedding config** — endpoints.py rejects caller-supplied embedding selection parameters, because the embedding configuration belongs to the store's server-side registration and must not be overridden per request.
- **Index management** — Index routes are restricted to proxy admins, separating who may create an index from who may use a store.

For exact behavior, read the code under `litellm/proxy/vector_store_endpoints/`. Do not restate it here.
---

## litellm/proxy/video_endpoints
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/video_endpoints/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/video_endpoints sha=79e507b6edb8e70eea6e8047f2d2ae07821bd4a3 -->

The video surface of the proxy. It creates, lists, retrieves and serves video content, and it supports remixing, characters, edits and extensions. At a glance:

- **Route aliases** — endpoints.py mounts the video routes under both a versioned and a bare path, covering create, list, retrieve, content, remix, characters, edits and extensions.
- **Provider-scoped ids** — utils.py encodes and decodes video and character ids with the provider name folded in, so a later request routes back to the provider that produced the video.
- **Request shaping** — utils.py validates the requested model and target model names and derives the routable model name, so a video request is dispatched the same way a chat request is.
- **Binary responses** — endpoints.py reuses the image surface's byte-conversion helper for the content route rather than reimplementing a second binary response path.

For exact behavior, read the code under `litellm/proxy/video_endpoints/`. Do not restate it here.
---

## litellm/proxy (remainder)
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/proxy/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/proxy/analytics_endpoints sha=a36c2bf9741352fa64be74973d948fdbda4124a6 -->
<!-- blueprint:code path=litellm/proxy/config_management_endpoints sha=321a6a86770f1a5f612cdb62db5084373e44689e -->
<!-- blueprint:code path=litellm/proxy/credential_endpoints sha=e1eac3ba04e8536578d59b0f355ffa66885f8ab7 -->
<!-- blueprint:code path=litellm/proxy/custom_hooks sha=5b515db1c8d9bd5af200fa6656ec0ff54275e6fa -->
<!-- blueprint:code path=litellm/proxy/decisions_endpoints sha=7c346d1f9f682169401db738e8b9edf3e3c1f135 -->
<!-- blueprint:code path=litellm/proxy/enterprise_billing sha=739688861e0011c046ebd4f8788880776a2d4c1b -->
<!-- blueprint:code path=litellm/proxy/fine_tuning_endpoints sha=ddcd4917947e58f4ea2ea8c9f151ba66f219bd9f -->
<!-- blueprint:code path=litellm/proxy/google_endpoints sha=28d0162d82f259b9a048ae24a425441f55581e3b -->
<!-- blueprint:code path=litellm/proxy/health_check_utils sha=20acd0ef405c1278a5b54aa7a61cf4e9daff8230 -->
<!-- blueprint:code path=litellm/proxy/health_endpoints sha=b8466143892d94ea13a03b5993fc82f2a95b52bb -->
<!-- blueprint:code path=litellm/proxy/image_endpoints sha=b2fa4b63ab72a55bef1f8a0f5d58bc4d2470063b -->
<!-- blueprint:code path=litellm/proxy/logging_endpoints sha=51a16be10fce57d8f84314471bc668020b123779 -->
<!-- blueprint:code path=litellm/proxy/memory sha=3273a43803e47d24c65d86365d5c83d5d9081743 -->
<!-- blueprint:code path=litellm/proxy/ocr_endpoints sha=19c7e589a25fc5f36bbeafae4d20c46aa1f74e8c -->
<!-- blueprint:code path=litellm/proxy/openai_evals_endpoints sha=b4a696c35dc5b2ca4beb9c372b3ace57681bf2f1 -->
<!-- blueprint:code path=litellm/proxy/realtime_endpoints sha=48ccdec08c08bc301beb24843d140f41ce91b108 -->
<!-- blueprint:code path=litellm/proxy/rerank_endpoints sha=5e778f928e9b8d422d1df44226588a181247c830 -->
<!-- blueprint:code path=litellm/proxy/response_api_endpoints sha=708e4a757cbf618da32b7f6d6a30a409f89d94c9 -->
<!-- blueprint:code path=litellm/proxy/test_prompts sha=d1ca5c28f135ba6688f5f9e74ffe6cf4de0088f9 -->
<!-- blueprint:code path=litellm/proxy/types_utils sha=9c742297d147401c99d32f20c0b0479037a3c96c -->
<!-- blueprint:code path=litellm/proxy/vector_store_files_endpoints sha=9466985311b02855c2a4b4b7c2162c8d685dc1e2 -->
<!-- blueprint:code path=litellm/proxy/vertex_ai_endpoints sha=1938df23f43e9608586680ee6a4e6ee3dcd8aad3 -->
<!-- blueprint:code path=litellm/proxy/workflows sha=87877910f9e9165bc4a100e5aabfbc24af3a8c27 -->
<!-- blueprint:code path=litellm/proxy/.gitignore sha=caa4783d9074da6624aae24c2ed0fd95c7111449 -->
<!-- blueprint:code path=litellm/proxy/README.md sha=900dea5ea29eff1a14ba36c7933ab91b1425edb7 -->
<!-- blueprint:code path=litellm/proxy/__init__.py sha=addeeadc9f82880be58ac006a9510da9ff91a633 -->
<!-- blueprint:code path=litellm/proxy/_lazy_features.py sha=db01475154be8e48d0437468a5381c5d60f590fa -->
<!-- blueprint:code path=litellm/proxy/_lazy_openapi_snapshot.json sha=166072e9613b88330bc94dea0a7875674e700854 -->
<!-- blueprint:code path=litellm/proxy/_lazy_openapi_snapshot.py sha=c5a63b0f990e60e6e7f9af642e10033b36e012cf -->
<!-- blueprint:code path=litellm/proxy/_new_new_secret_config.yaml sha=7932cc20fe94b12c7401a7923c8463986d233bd7 -->
<!-- blueprint:code path=litellm/proxy/_new_secret_config.yaml sha=235d64f29add3959cef2e95439fb936ed88f1edd -->
<!-- blueprint:code path=litellm/proxy/_super_secret_config.yaml sha=b993b9cdfefe9790ab1b7285331b484a45f8f201 -->
<!-- blueprint:code path=litellm/proxy/_types.py sha=dd91bb6eef38c479d7c7baa4a5165f3054a9664e -->
<!-- blueprint:code path=litellm/proxy/admin_mcp.py sha=6371863f45c439660b25b91cbe634fc1007b961c -->
<!-- blueprint:code path=litellm/proxy/bug_report_config.py sha=d7b920de4d56e90ee298a8317dc3868ac0dbd1bc -->
<!-- blueprint:code path=litellm/proxy/cached_logo.jpg sha=a10a1d249690c6148a6ba40893e7c0ada44adec0 -->
<!-- blueprint:code path=litellm/proxy/caching_routes.py sha=775d00ed53e9b9e1b5128f4551ee7cb5fcf54454 -->
<!-- blueprint:code path=litellm/proxy/collector.py sha=3ff2a83860b36aa707b4d9f11537702f11068139 -->
<!-- blueprint:code path=litellm/proxy/common_request_processing.py sha=3b9c17baa02461947f7f1d61a1ac52047ecf7516 -->
<!-- blueprint:code path=litellm/proxy/compliance_checks.py sha=9d2f2dc7c6944c8f63d1e3bacddd34f422bbdefc -->
<!-- blueprint:code path=litellm/proxy/custom_auth_auto.py sha=8ac8443adf661fb415de394bce66459414eff2d5 -->
<!-- blueprint:code path=litellm/proxy/custom_prompt_management.py sha=e213e741e4fc55eff22a6ac3154536fa1633432c -->
<!-- blueprint:code path=litellm/proxy/custom_sso.py sha=99cb3bc6c176cde702811a780c57e68a40304ab5 -->
<!-- blueprint:code path=litellm/proxy/custom_validate.py sha=c80ffa4fe957b06d4e29f4cffbdf3ed04d3fd8e3 -->
<!-- blueprint:code path=litellm/proxy/dd_span_tagger.py sha=08a99e363cdf21b902e75a458cc5a627d2bdf433 -->
<!-- blueprint:code path=litellm/proxy/dev_config.yaml sha=1fc9e09b8979161a4c627d3bcf37ac47741211e3 -->
<!-- blueprint:code path=litellm/proxy/enterprise sha=6ee73080d0aad3d40dc65fea19ce18a33d995577 -->
<!-- blueprint:code path=litellm/proxy/health_check.py sha=0d2f8dc9a0cf6f0b416baecb976e8e858b0ba0c1 -->
<!-- blueprint:code path=litellm/proxy/lambda.py sha=4845c00dfe7e1f1759b1fc24d9313df742976a7a -->
<!-- blueprint:code path=litellm/proxy/litellm_pre_call_utils.py sha=1e7cdc44c709bc743533a91fe648accd3ce117c8 -->
<!-- blueprint:code path=litellm/proxy/llamaguard_prompt.txt sha=25cd8bce26cce6b0a44f0c8b14a4cf9579888669 -->
<!-- blueprint:code path=litellm/proxy/logo.png sha=4e47364ce693fb1eff2e709f2f202783b0b2c9cf -->
<!-- blueprint:code path=litellm/proxy/logo_dark.png sha=c7f45c18f19f99522fc787fb6e14ab6ef43c8125 -->
<!-- blueprint:code path=litellm/proxy/logo_monogram.png sha=5a2816197ab18df3da97856bb74535c5d58f3ba2 -->
<!-- blueprint:code path=litellm/proxy/logo_monogram_dark.png sha=6e44c798a6390d5a9b61ea180c63cf6127a35454 -->
<!-- blueprint:code path=litellm/proxy/mcp_registry.json sha=70e81f127c9b5f918f9d14474968fde8a8d813ac -->
<!-- blueprint:code path=litellm/proxy/mcp_tools.py sha=239bb4b2fcfcfcc3e191404c8434da920ae43d86 -->
<!-- blueprint:code path=litellm/proxy/model_config.yaml sha=a0399c0952c8aadc42eaa44c251a06e90989a3a5 -->
<!-- blueprint:code path=litellm/proxy/model_insights_tasks.json sha=17f9dabd24e8589797dc037418a5c578c967517e -->
<!-- blueprint:code path=litellm/proxy/moyai_endpoints.py sha=45f4502ec4e4e4e67defd7327efe2289cf4093f3 -->
<!-- blueprint:code path=litellm/proxy/native_compaction.py sha=fd27e7fbbdcc91a526f75769ad0e6f91d733647b -->
<!-- blueprint:code path=litellm/proxy/openapi.json sha=95517182667f6032704045cb8b353ca010434479 -->
<!-- blueprint:code path=litellm/proxy/openapi_registry.json sha=19f46908855aa1f2c7844ae033778f10c7feb061 -->
<!-- blueprint:code path=litellm/proxy/plugin_routes.py sha=1dfe5cbc6bb0b4a7a004e5a5cf94c0ca75a39d69 -->
<!-- blueprint:code path=litellm/proxy/post_call_rules.py sha=6200bee4d7b16f2214c81364c2a1b97c00d893bf -->
<!-- blueprint:code path=litellm/proxy/prisma_migration.py sha=3561f190808276bb8ddf980be0fa89e8dca2eca2 -->
<!-- blueprint:code path=litellm/proxy/prometheus_cleanup.py sha=52aa20cea5a629a42c57e6a48ae6d6f4f0f8a090 -->
<!-- blueprint:code path=litellm/proxy/prometheus_metrics_server.py sha=053accaf65029a677ad9eb71381520cf435a2c3a -->
<!-- blueprint:code path=litellm/proxy/proxy_cli.py sha=fc33ab1bd0b61366f71e0d7cb5db1c4ee3546046 -->
<!-- blueprint:code path=litellm/proxy/proxy_config.yaml sha=50e5ae15b99d206d2a038b00b31b6586ff0b724d -->
<!-- blueprint:code path=litellm/proxy/proxy_server.py sha=bc79becf7bb0935c7bf5233a5f4f55d3d6f910fc -->
<!-- blueprint:code path=litellm/proxy/read_model_list.py sha=92bfa8657cb78cfe685655518ac8cc800b0078b2 -->
<!-- blueprint:code path=litellm/proxy/route_llm_request.py sha=cb2269291676250e632b6aa4fadeb765e17c953e -->
<!-- blueprint:code path=litellm/proxy/route_priority.py sha=e2f7759785d61215d7e40810cdfd80f8da0509cd -->
<!-- blueprint:code path=litellm/proxy/schema.prisma sha=83a0e6f9e056838f1234beb9def9a728109384f5 -->
<!-- blueprint:code path=litellm/proxy/start.sh sha=44df50aaabfbf3cf0fa38e50d1b2ecc34a5ddecc -->
<!-- blueprint:code path=litellm/proxy/tracing_endpoints.py sha=95894e9c3b1b26d375bd480f9386ece50984651a -->
<!-- blueprint:code path=litellm/proxy/tracing_runtime.py sha=0ac05216a30921c8291af543448a5907b37bc758 -->
<!-- blueprint:code path=litellm/proxy/utils.py sha=d3202368d7689ce3c4b7bc8eeb9689ca05aa5539 -->
<!-- blueprint:code path=litellm/proxy/wildcard_config.yaml sha=dc0206388c337f0f5008feaec8c0651632d146ec -->

The proxy server itself: it composes the FastAPI application, runs the request pipeline that every route shares, and owns the shared type and schema surface the other proxy sections build on. At a glance:

- **App composition** — litellm/proxy/proxy_server.py builds the FastAPI app, installs the middleware stack, and includes every route module as a router, so the app object is the single composition point for the whole gateway
- **Request pipeline** — common_request_processing.py turns a provider response into the client-facing response and stamps the x-litellm-response-cost header family that carries the cost breakdown
- **Model routing** — route_llm_request.py owns route_request, the single point where the requested model is mapped onto a concrete deployment before the provider call
- **Pre-call shaping** — litellm_pre_call_utils.py holds LiteLLMProxyRequestSetup, which strips client-supplied metadata and normalizes the request body before it reaches the router
- **Shared type surface** — _types.py re-exports the SDK model and proxy types under one import path and defines ProxyException, so proxy modules share one type vocabulary
- **Owned data** — schema.prisma is the proxy's own Postgres schema, holding the spend log, verification token, budget and daily-aggregate tables
- **Legacy utility module** — utils.py still holds the PrismaClient wrapper class and ProxyLogging that newer litellm/proxy/db modules call into, so it is a compatibility surface rather than a leaf

ARCHITECTURE.md lists litellm/proxy/utils.py as the home of PrismaClient and the Postgres access layer; at HEAD PrismaClient still lives there but the token-refreshing PrismaWrapper and the batched spend writer moved into litellm/proxy/db, and litellm/proxy/utils.py re-exports them.
ARCHITECTURE.md shows route_request living in router.py; at HEAD route_request lives in litellm/proxy/route_llm_request.py and router.py only owns load balancing.

For exact behavior, read the code under `litellm/proxy/`. Do not restate it here.
---

## litellm/rag
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/rag/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/rag sha=915039354583c75d95cfdb99261dcd37a4737caf -->

The retrieval-augmented generation pipeline, covering document ingestion through upload, OCR, chunking, embedding and storage, and query-time retrieval, reranking and context assembly. At a glance:

- **Ingest pipeline** — main.py's aingest runs upload, OCR, chunk, embed and store through a provider-specific ingestion class, with the provider chosen from the ingest options.
- **Query pipeline** — main.py's aquery searches the vector store, reranks the hits and assembles the retrieved chunks into the answer, and reports search cost through the shared cost calculator.
- **Ingestion contract** — ingestion/base_ingestion.py's BaseRAGIngestion defines the upload, OCR, chunk, embed and store steps every provider ingestion implements, with credentials loaded from config.
- **Chunking** — text_splitters supplies the default recursive character splitter that the ingestion steps chunk documents with.
- **Context assembly** — rag_query.py's RAGQuery extracts the query from the messages, builds the context message from the retrieved chunks and folds the search and rerank results back into the response.

For exact behavior, read the code under `litellm/rag/`. Do not restate it here.
---

## litellm/repositories
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/repositories/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/repositories sha=c3e73eab9e59a2212a92b30b4c2962ce9366c351 -->

The data-access layer over Prisma: typed protocols for the generated client, a generic CRUD repository, per-entity repositories with their own queries and writes, and unit-of-work helpers that batch one logical operation into a single transaction. At a glance:

- **Protocol seam** — prisma_protocols.py declares the DatabaseClient and TableActions protocols, so a repository can be written and tested against an interface instead of the generated Prisma client.
- **Generic CRUD** — base_repository.py's BaseRepository implements find_by_id, find_many, create, update, delete, count and exists over a single table with a typed model class.
- **Units of work** — unit_of_work.py batches the writes of one logical operation, such as a spend reset or a budget-window advance, into a single transaction.
- **Table repositories** — table_repositories.py declares one thin repository per Prisma table, and the entity-specific repositories add encryption, archiving or atomic array updates on top.
- **Encrypted columns** — model_repository.py encrypts and decrypts a deployment's litellm_params on the way into and out of the database.

The dependency on litellm/proxy/db and litellm/proxy/common_utils runs the other way from the doc's stated intent: these two gateway imports are function-local, which keeps the gateway import out of module load but does not remove the coupling.

For exact behavior, read the code under `litellm/repositories/`. Do not restate it here.
---

## litellm/responses
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/responses/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/responses sha=44ab3cc09e05a80b386e99d19786c62a6de31d5a -->

The OpenAI Responses API surface: request and response transformation for the /v1/responses shape, the streaming iterator, MCP tool execution and the bridge that lets a chat-completions provider serve a Responses request. At a glance:

- **Public entry** — main.py's responses() and aresponses() are the SDK's Responses entry points, and dispatch.py binds them to a native route when the catalog admits one.
- **Request shaping** — utils.py's ResponsesAPIRequestUtils normalizes Responses input items, applies prompt management and builds the provider-specific parameters.
- **Streaming** — streaming_iterator.py's BaseResponsesAPIStreamingIterator rebuilds provider SSE frames into the Responses event stream, including the usage accounting.
- **Chat bridge** — litellm_completion_transformation/handler.py converts a Responses request into a chat-completions call and back for providers with no Responses support.
- **MCP tools** — mcp/litellm_proxy_mcp_handler.py runs the gateway's MCP tools in the middle of a Responses turn and merges their usage back into the response.
- **Bridge gating** — bridge_check.py decides per deployment whether the Responses API is served natively or has to be bridged, based on the deployment's registered mode.

This section and litellm/completion_extras depend on each other: the Responses entry points call the bridge handler that lives in completion_extras, and that handler in turn calls back into the Responses transformation helpers. The cycle is real and is worth keeping visible.

For exact behavior, read the code under `litellm/responses/`. Do not restate it here.
---

## litellm/router_strategy
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/router_strategy/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/router_strategy sha=41be29612609607383169443a29194514f3c6961 -->

The routing algorithms behind the Router: the least-busy, lowest-cost, lowest-latency, TPM and RPM, tag-based and shuffle deployment pickers, plus the adaptive, complexity, quality and auto routers that choose a model group before a deployment. At a glance:

- **Strategy base** — base_routing_strategy.py's BaseRoutingStrategy owns the shared Redis increment queue and the periodic sync that flushes in-memory counters to Redis.
- **Load and cost** — least_busy.py picks by in-flight request count and lowest_cost.py by cost-map rates; each is a logging handler that records its own decision.
- **Latency** — lowest_latency.py ranks deployments by observed latency and time-to-first-token, keeping the samples per deployment.
- **Tag routing** — tag_based_routing.py filters deployments by request, key, team and project tags and supports an exclusion syntax for negated tags.
- **Adaptive router** — adaptive_router/ keeps a bandit-style score per model and request type and persists that state through the repositories.
- **Complexity and quality routers** — complexity_router/ classifies a prompt's complexity and routes by tier, and quality_router/ scores candidate deployments against a quality tier.

The strategies and litellm/router_utils form a cycle: strategies import the shared router helpers, and the auto-router naming helper in router_utils imports the complexity router's configuration back.

For exact behavior, read the code under `litellm/router_strategy/`. Do not restate it here.
---

## litellm/router_utils
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/router_utils/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/router_utils sha=9815d360ff3a211f091d4f3e0cdbba8fd8af3db5 -->

The Router's supporting machinery: the cooldown and health-state caches, the optional pre-call deployment checks, fallback bookkeeping, capability lookups and the access-window rules that decide which deployment may serve a request. At a glance:

- **Cooldown cache** — cooldown_cache.py stores per-deployment cooldowns in the router cache and reports the ones currently active.
- **Health state** — health_state_cache.py tracks which deployments the background health checks have marked unhealthy so the Router stops selecting them.
- **Pre-call checks** — pre_call_checks/ holds the optional filters a deployment set can enable before dispatch, such as the model rate-limit check and the prompt-caching affinity check.
- **Fallback bookkeeping** — fallback_event_handlers.py records which fallback targets were already attempted or skipped, so a retry never re-picks a deployment that just failed.
- **Access windows** — access_windows.py parses the configured maintenance windows and filters out the deployments they reserve.
- **Routing groups** — routing_groups.py validates a routing strategy name and applies per-model priorities inside a group.

This section and litellm/router_strategy depend on each other; both edges are recorded because both are real runtime imports.

For exact behavior, read the code under `litellm/router_utils/`. Do not restate it here.
---

## litellm/rust_bridge
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/rust_bridge/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/rust_bridge sha=cf574d5b9e685b0c208137ba9dd7885433db149a -->

The Python side of the Rust migration: it loads the packaged native extension, decides per request whether Rust or Python should handle the call, and projects Python call arguments into the shape the native code reads. At a glance:

- **Loader** — loader.py imports the packaged native extension lazily and caches it, so a missing extension degrades to the Python path instead of failing at import time.
- **Route catalog** — catalog.py holds the Route, Target and Feature enums and the ordered RULES table. The first matching rule wins and a context no rule matches stays on Python.
- **Detectors** — detectors.py and the per-route detectors describe a request, for example whether it streams, carries a mock response or a caller-supplied client, so the catalog and the fallback agree.
- **Dispatch** — dispatch.py's PublicDispatch applies the catalog decision and runs either the native call or the Python fallback. A detector that raises keeps the call on Python rather than failing it.
- **Host modules** — host/ holds the modules Rust imports by name to read Python-owned state, such as the cache, the secret manager and the legacy callbacks.
- **Public call shape** — public_call.py's NativeCall resolves arguments the same way whether they arrived by position, by keyword or as a signature default.

ARCHITECTURE.md never mentions this package, so the documented SDK flow predates the Rust migration and does not show the native dispatch layer that the public entry points now go through.

For exact behavior, read the code under `litellm/rust_bridge/`. Do not restate it here.
---

## litellm/sandbox
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/sandbox/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/sandbox sha=fde40f682989a0fefc0c1077ca0f6f444fbb936c -->

The sandbox surface for code execution: provider code-interpreter containers plus a registry that resolves a configured sandbox tool name to its provider and credentials, and lazy re-exports of the harness sandboxes. At a glance:

- **Provider sandboxes** — main.py exposes create, run and delete for provider code-interpreter sandboxes plus a one-shot code-interpreter tool.
- **Tool registry** — sandbox_tools.py maps a configured sandbox tool name to its provider and credentials, resolving os.environ/ references through the secret managers.
- **Harness re-export** — __init__.py lazily re-exports the harness's local and Docker sandboxes, so importing litellm does not pull in litellm.harness.

For exact behavior, read the code under `litellm/sandbox/`. Do not restate it here.
---

## litellm/search
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/search/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/search sha=5dbb333a1799ede7a262da1cd645b77e74ea154a -->

The search API for the SDK, running a provider web or document search and pricing the query that produced it. At a glance:

- **Search surface** — main.py exposes asearch and search over the base search config, translating the caller arguments (max results, domain filter, country, per-page token cap) into provider optional params.
- **Per-query pricing** — cost_calculator.py's search_provider_cost_per_query prices one query from the model cost map and treats providers registered at runtime separately, so unpriced providers fall through rather than costing zero silently.
- **Price clearing** — main.py's _search_pricing_params always carries the price key, which is what clears the price a failed fallback attempt left behind on the shared logging object.

For exact behavior, read the code under `litellm/search/`. Do not restate it here.
---

## litellm/secret_managers
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/secret_managers/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/secret_managers sha=e0f065c1cdc9d79abdee8963f4e688860aa75b76 -->

Credential resolution for the whole product: one get_secret and get_secret_str entry point over pluggable backends, covering AWS Secrets Manager, Google Secret Manager and KMS, HashiCorp Vault and CyberArk, plus a loader for operator-supplied Python managers. At a glance:

- **Entry point** — main.py's get_secret_str resolves a secret reference to its value, with an environment-variable fast path and local OIDC file references handled separately.
- **Backend contract** — base_secret_manager.py's BaseSecretManager defines the async read, write, delete and rotate surface every backend implements, and refuses secret names that look unsafe.
- **AWS backends** — aws_secret_manager.py reads AWS Secrets Manager values and decrypts KMS-wrapped environment values, while aws_secret_manager_v2.py is the newer typed implementation of the same contract.
- **Enterprise backends** — hashicorp_secret_manager.py speaks the Vault KV v2 API over AppRole or TLS-certificate auth, and cyberark_secret_manager.py implements the same contract against CyberArk's REST API.
- **Custom managers** — custom_secret_manager_loader.py imports an operator's own manager class from a Python file and instantiates it, so a private vault can be plugged in without changing the SDK.
- **Handler** — secret_manager_handler.py adapts the SDK's sync and async managers and the cloud KMS clients into one read path for the callers above.

The AWS v2 manager extends the Bedrock AWS credential base in litellm/llms, so this package depends on the provider layer for its AWS session handling; that edge is noted here rather than drawn, because the coupling is incidental to the credential contract.

For exact behavior, read the code under `litellm/secret_managers/`. Do not restate it here.
---

## litellm/telemetry
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/telemetry/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/telemetry sha=ebcec56810046126219ba4ebdecd670f05275342 -->

The privacy-scoped usage and stability telemetry core for the gateway, holding the record shapes, consent gating, aggregation and export primitives that the proxy telemetry runtime plugs into. At a glance:

- **Import isolation** — The package must not import anything else from litellm so it stays auditable on its own, and tests/code_coverage_tests/check_telemetry_imports.py enforces that by walking every module in the package.
- **Consent gating** — consent.py models the telemetry groups and their prerequisites, and ConsentGatedSink drops or requires groups according to the operator's consent setting before anything is recorded.
- **Sink protocol** — sink.py defines the TelemetrySink and Exporter protocols plus the export outcome enum, which is the seam the proxy runtime implements against.
- **Aggregation and export** — aggregate.py's AggregatingSink folds request, attempt and UI-event records into per-window rows bounded by a max row count, and http_exporter.py ships the report out, retrying on 408, 409 and 429 or any 5xx.
- **Record shapes** — records.py holds the frozen request, attempt and UI-event records together with the status, block-type and UI-action enums that the whole pipeline agrees on.

This section has no outgoing dependency on the rest of the codebase by design, so its only edge is inbound from litellm/proxy/telemetry, which consumes the sink, consent and record contracts.

For exact behavior, read the code under `litellm/telemetry/`. Do not restate it here.
---

## litellm/tracing
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/tracing/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/tracing sha=6f4236beeea0a207a23c60685927050d61ab29bb -->

The Lens trace gateway client for the SDK, owning the remote-only HTTP reads against the BerriAI/lens trace service, the query and storage layer over it, and the asynchronous spend exporter that feeds the same sink. At a glance:

- **Remote-only boundary** — The package's own AGENTS.md fixes the split: it owns the HTTP client, gateway response validation and asynchronous spend export, and keeps the trace reader remote-only while Lens owns normalization, schemas, storage and graph assembly.
- **Read surface** — receiver.py's TraceReceiver is the only public export and storage.py's LensTraceStorage validates every gateway response against generated schemas before returning it.
- **Generated contracts** — The generated package holds Pydantic models regenerated from the pinned Lens schemas by scripts/generate_trace_types.py, and AGENTS.md forbids hand-editing them.
- **Spend exporter** — exporter.py's LensExporter subclasses CustomLogger, batches spend-log records and ships them to the sink off the request path, which is the only writer this package owns.
- **OTLP is guidance only** — otlp_http.py only encodes setup-guidance error frames for OTLP upload routes. The package implements no OTLP ingestion of its own.

For exact behavior, read the code under `litellm/tracing/`. Do not restate it here.
---

## litellm/types
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/types/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/types sha=eb3d2c85648b163d9ec10c1a47258a16f729737a -->

The typed contract layer of the SDK: the request, response, provider, routing and proxy-endpoint models, plus the enums and TypedDicts every other package builds its own types on. At a glance:

- **Call types** — types/utils.py holds the CallTypes enum, which names every API surface the SDK can dispatch, and the ModelInfo map describing each model's context window and pricing metadata.
- **Router contracts** — types/router.py declares RouterConfig and DeploymentTypedDict, the shape of a router's deployments, routing groups and retry policy.
- **LiteLLM params** — types/litellm_params.py declares the request kwargs LiteLLM owns on top of a provider's schema and merges them with the callback and pricing models into all_litellm_params.
- **OpenAI-shaped payloads** — types/llms/openai.py mirrors the OpenAI request and response objects the SDK emits, including the Responses API payload types.
- **Base model** — types/llms/base_model.py defines LiteLLMBaseModel, the pydantic base nearly every LiteLLM model in the repository inherits.
- **Proxy contracts** — types/proxy/ holds the management-endpoint request and response schemas the gateway validates its admin routes against, such as the team-permission endpoints.

Two of this section's outbound edges are type-only and were demoted: types/litellm_params.py imports litellm.router_strategy.complexity_router.context_compaction and types/completion.py imports litellm.llms.base_llm, but both sit under TYPE_CHECKING, so they are not runtime dependencies.

For exact behavior, read the code under `litellm/types/`. Do not restate it here.
---

## litellm/vector_store_files
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/vector_store_files/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/vector_store_files sha=dcae9ef51de839269b66afdb78e0590fbe352ffe -->

The vector store file API, covering creation, listing, retrieval, update, deletion and content download of the files held inside a provider vector store. At a glance:

- **File surface** — main.py exposes create, list, retrieve, update, delete and retrieve_content plus their async twins, dispatching per provider over the shared HTTP handler.
- **Registry credentials** — main.py's _prepare_registry_credentials pulls the managed store's credentials out of the vector store registry before the call, which is how a LiteLLM-managed store authenticates without the caller passing keys.
- **Parameter filtering** — utils.py's VectorStoreFileRequestUtils strips params the provider's request model does not accept, so one call signature stays valid across providers.

For exact behavior, read the code under `litellm/vector_store_files/`. Do not restate it here.
---

## litellm/vector_stores
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/vector_stores/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/vector_stores sha=043cdf9e875c62405ab41e343ca058a6b5c6d921 -->

The vector store API and registry, covering creation, search, listing, update and deletion of provider vector stores together with the managed-store registry that decides which store a request should hit and which credentials it should use. At a glance:

- **Store surface** — main.py exposes create, search, retrieve, list, update and delete plus their async twins, with mocked responses for providers that lack native vector store support.
- **Managed store registry** — vector_store_registry.py's VectorStoreRegistry holds config-backed and database-backed managed stores, resolves which store a tool call should run against, pops it once used, and hands back its credentials.
- **Index registry** — VectorStoreIndexRegistry tracks the LiteLLM-managed vector store indexes separately from the stores themselves, and can load them back from the database.
- **Metadata ownership** — utils.py's is_litellm_written_metadata_key separates caller metadata from metadata LiteLLM wrote, so a proxy round trip does not clobber the user's own keys.

For exact behavior, read the code under `litellm/vector_stores/`. Do not restate it here.
---

## litellm/videos
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/videos/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/videos sha=71ff4947499eb3c490213c452e06d3e8132324bb -->

The video API for the SDK, covering generation, status polling, listing, retrieval, remixing, extension and editing of video jobs plus the reusable character assets they can reference. At a glance:

- **Job surface** — main.py exposes video_generation, video_status, video_content, video_list, video_remix, video_edit and video_extension plus their async twins, dispatching per provider over the shared HTTP handler.
- **Character assets** — avideo_create_character and avideo_get_character manage the reusable character identities a provider can attach to a video request, which are separate resources from the jobs themselves.
- **Parameter mapping** — utils.py's VideoGenerationRequestUtils maps the requested generation params onto the optional params the target provider accepts.

For exact behavior, read the code under `litellm/videos/`. Do not restate it here.
---

## litellm (remainder)
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm/assistants sha=5614cf42e1b87c35ac15472304d6dccb555d2b7c -->
<!-- blueprint:code path=litellm/batch_completion sha=bf66ecd895042a93bb409e51db199a6089da5240 -->
<!-- blueprint:code path=litellm/chat_completions sha=24115822085f8efa443da53145ab917585cccdac -->
<!-- blueprint:code path=litellm/embeddings sha=65d1c32f545b97a32b1e57306752ebf633d4ff01 -->
<!-- blueprint:code path=litellm/endpoints sha=fb3b5df3f3db62686e5f0e21ecbc39acbe9b22c5 -->
<!-- blueprint:code path=litellm/evals sha=3bd840e2b6d5559bdc7d8dd71f53661e02bd1f15 -->
<!-- blueprint:code path=litellm/experimental_mcp_client sha=a0f022c1c691ee5d84e9744df9838b715369f901 -->
<!-- blueprint:code path=litellm/extraction sha=ef7b98599cad208b55a8cd6b67d2338e1255d3e8 -->
<!-- blueprint:code path=litellm/fine_tuning sha=7fbd800def95a598a59abc1cf51f9dd495e01c3f -->
<!-- blueprint:code path=litellm/messages sha=b32dedf12c528a56f09cb2ed38c8a042eb324d3a -->
<!-- blueprint:code path=litellm/ocr sha=40bbd2ca7797e211b5a95bf97be752cb12fb7430 -->
<!-- blueprint:code path=litellm/proxy_auth sha=2fa994c6e406b435de8842f562dd43589045fa2a -->
<!-- blueprint:code path=litellm/realtime_api sha=15d755d432821d35088efa94bd0815118f2bfea4 -->
<!-- blueprint:code path=litellm/rerank_api sha=6844f992b11c560e2d5f226e7f263c6f67483e9b -->
<!-- blueprint:code path=litellm/skills sha=d28700083db471f8dfb82af33288ba61a8a9eb51 -->
<!-- blueprint:code path=litellm/systemone sha=e3d8ab5914292b085bc29b50565450954f85a356 -->
<!-- blueprint:code path=litellm/text_completions sha=5175f46e6fca56b372ae7623c27055ede34cf237 -->
<!-- blueprint:code path=litellm/__init__.py sha=41e3fa34323be02905076f5e7dae6521529e970c -->
<!-- blueprint:code path=litellm/_internal_context.py sha=244efc8047b334a77274492c47673e703d243dd7 -->
<!-- blueprint:code path=litellm/_lazy_imports.py sha=1a7dc3437459f2d0ae79420077311debc7ff6b56 -->
<!-- blueprint:code path=litellm/_lazy_imports_registry.py sha=f43e369e092583f62a2a46aff12b72e6ae0c8eeb -->
<!-- blueprint:code path=litellm/_logging.py sha=d08254db3fdc2b8042349f0eaacc7a0434aecdf4 -->
<!-- blueprint:code path=litellm/_process_defaults.py sha=7501215f1080d217125f3527c27c9cfd04890651 -->
<!-- blueprint:code path=litellm/_redis.py sha=96777887c74360c7bcf9f7656fe157b27679ba54 -->
<!-- blueprint:code path=litellm/_redis_credential_provider.py sha=8b20b9b7d4b360639d5d08e3b75d2862cc06cbf4 -->
<!-- blueprint:code path=litellm/_service_logger.py sha=060b4fb878e0000ce0ada2f0c216f67f8418e4a6 -->
<!-- blueprint:code path=litellm/_uuid.py sha=55df233b5531deb44e71aa45144a3f2ab9c7af4c -->
<!-- blueprint:code path=litellm/_version.py sha=140adcb66cfe89317a761da8a052413885aa224a -->
<!-- blueprint:code path=litellm/anthropic_beta_headers_config.json sha=d68de6c9d4dd4292bea25a1554494c7600c1cb02 -->
<!-- blueprint:code path=litellm/anthropic_beta_headers_manager.py sha=fec1d8e44657491d978223eddda2209704ff100d -->
<!-- blueprint:code path=litellm/blog_posts.json sha=fa768b3ec5704c136fbe4b2119f779f565056715 -->
<!-- blueprint:code path=litellm/budget_manager.py sha=0f8ec4be036d3f8229b3fca519a14d0258ead643 -->
<!-- blueprint:code path=litellm/constants.py sha=2901b7d8948390e1dbb3ae778edc54300d83a362 -->
<!-- blueprint:code path=litellm/cost.json sha=360f981e455d09ef175b351215fe5500fc96309b -->
<!-- blueprint:code path=litellm/cost_calculator.py sha=86b22069a39eae704b41a681cc247aaa7b79809c -->
<!-- blueprint:code path=litellm/exceptions.py sha=b8e933bf04653b6619b1067034d38d3b278f82c8 -->
<!-- blueprint:code path=litellm/main.py sha=7775922ea442c43ca56a589e35eca5db98cff590 -->
<!-- blueprint:code path=litellm/model_prices_and_context_window_backup.json sha=39500330096b8a88363750e62e0efe4a7db2af3d -->
<!-- blueprint:code path=litellm/policy_templates_backup.json sha=0798f345bb5f5f8df7510cc9763c82751fe06cf5 -->
<!-- blueprint:code path=litellm/provider_endpoints_support_backup.json sha=9ba6ed342eacfa1018475a8c0259f9c9c4b61cb4 -->
<!-- blueprint:code path=litellm/py.typed sha=5686005abc55960810b5120dda9c320fe602d7ef -->
<!-- blueprint:code path=litellm/router.py sha=0d4045e6ca84abbff62b507972992d3125ba67e9 -->
<!-- blueprint:code path=litellm/scheduler.py sha=73196d24e4dac76f0ef864475c902a4e3950bcfe -->
<!-- blueprint:code path=litellm/setup_wizard.py sha=390e8c8d568f99d07880368212f379e7a304820f -->
<!-- blueprint:code path=litellm/timeout.py sha=33d1ce92e53b8f14d5492d159b9a80a7bc1fe10c -->
<!-- blueprint:code path=litellm/tool_loop.py sha=aaa0d62eea7db43a6002723de42ee47ed0fbcc75 -->
<!-- blueprint:code path=litellm/utils.py sha=6f0b1ca2e3efa6a75e105873c44603fb8359ef3c -->

The public LiteLLM SDK surface and the shared runtime behind it: the package facade, the completion and embedding entry points, the Router that fans a request across deployments, cost calculation, and the error taxonomy every layer raises into. At a glance:

- **Package facade** — litellm/__init__.py is the SDK's front door. It applies process defaults at import time, then re-exports the request entry points, the callback registries and the provider constants that callers configure.
- **Request entry point** — litellm/main.py owns completion() and acompletion() plus the per-provider dispatch branches, and the module-level base_llm_http_handler is the single HTTP driver every provider call goes through.
- **Router** — litellm/router.py holds the Router class, which selects a deployment per model group, drives the fallback chain and the retries, and records cooldowns. The selection policy itself lives in litellm/router_strategy.
- **Cost and errors** — litellm/cost_calculator.py prices a finished response from its token counts while litellm/exceptions.py defines the OpenAI-shaped error classes every layer raises, so provider failures surface in one shape.
- **Internal context** — litellm/_internal_context.py holds ContextVar-scoped internal signals such as is_internal_call, billing_time and service_target. They are set by the SDK itself and cannot be injected through a request body.
- **Client-side helpers** — litellm/tool_loop.py runs the client-side tool-calling loop, litellm/budget_manager.py tracks spend for the hosted API, litellm/scheduler.py drains a Redis-backed priority queue, and litellm/timeout.py supplies the sync and async timeout decorator.

ARCHITECTURE.md section 2 lists utils.py as where get_llm_provider() resolves model to provider, but at HEAD that function is defined in litellm/litellm_core_utils/get_llm_provider_logic.py and utils.py only imports it inside a function body, so the doc points at the wrong file.

For exact behavior, read the code under `litellm/`. Do not restate it here.
---

## litellm_cli
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `litellm_cli/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=litellm_cli sha=1b6778681e202dc3a8f726af1952f33eee138fab -->

This section holds the console entry points for the lite and litellm-proxy commands, which boot the CLI against an uninitialized SDK package so startup does not pay for the full SDK import before any command needs it. At a glance:

- **Lazy SDK module** — The litellm package is replaced in sys.modules by a module object that runs the real SDK init on its first non-dunder attribute read, and an init that raises leaves the package uninitialized so the next use retries and raises the same error.
- **CLI wiring** — The entry points import the Click command group from the proxy client package, so the command implementations stay with the rest of the proxy client code.
- **Process defaults** — Process-level defaults are applied at CLI start so command behaviour matches the SDK's own defaults.

For exact behavior, read the code under `litellm_cli/`. Do not restate it here.
---

## migrations
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `migrations/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=migrations sha=307b4c1750d5606fb19faad6f8fc0f404ecae869 -->

This section is the standalone Prisma migrations Job, a minimal image and entrypoint that applies schema migrations to the writer database with the proxy's recovery logic and then builds the request-log indexes the migrations do not create. At a glance:

- **Job entrypoint** — run.py delegates to the proxy-extras database manager's migration job, which applies the migrations with the v2 resolver and then waits for the request-log index build, failing the job when an index cannot be built.
- **Resolver switch** — USE_V2_MIGRATION_RESOLVER selects the v2 resolver, the default that avoids the schema thrashing two LiteLLM versions see during a rolling deploy, and can be turned off to fall back to the v1 diff-and-force recovery.
- **Minimal image** — The image installs only the proxy extra, runs prisma generate at build time to pre-warm the engine binaries, and runs the CLI in offline Prisma mode so the Job pod never reaches the internet.

For exact behavior, read the code under `migrations/`. Do not restate it here.
---

## packaging/litellm-core
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `packaging/litellm-core/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=packaging/litellm-core sha=af7fe55366b8f887297f5560be072403e2e81de6 -->

This section holds the build metadata for the standalone litellm-core distribution, a Rust-extension build of the SDK that ships without the proxy extras. At a glance:

- **Maturin build** — The build backend is maturin and the manifest points at the Rust python-bridge crate, with the compiled extension installed as the litellm.rust_bridge native module.
- **Python support** — The distribution supports Python 3.10 through 3.15 and pins separate pydantic and tiktoken floors per interpreter version.
- **Source archive contents** — The include and exclude lists decide which router artifacts, proxy task files and bundled model catalogues travel in the sdist.

For exact behavior, read the code under `packaging/litellm-core/`. Do not restate it here.
---

## packaging (remainder)
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `packaging/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=packaging/homebrew sha=cd88800f962460d657ab6c20e63629fdfa7f87d6 -->

This section holds the Homebrew tap formula and its release runbook for the thin lite command, which installs the published SDK sdist with its CLI extra into a dedicated virtualenv rather than shipping a pinned resource tree. At a glance:

- **Formula** — lite.rb builds a dedicated virtualenv, installs the published sdist with the cli extra, and symlinks the lite binary out of it.
- **Release placeholders** — The formula's url and sha256 are placeholders that must be pointed at the first published sdist that ships the cli extra, and the version is parsed from that url.
- **Tap runbook** — README.md documents the publish steps into the BerriAI/homebrew-litellm tap, the reason homebrew-core is unsuitable for a fast-moving Python CLI, and the rule that the in-repo formula stays the source of truth.

For exact behavior, read the code under `packaging/`. Do not restate it here.
---

## scripts
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `scripts/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=scripts sha=6f17870b27a0268170fcdf8da53485957d1e07b7 -->

This section is the repository's developer tooling: the delta-versus-base lint and type gates, the code generators, the benchmark and health-check harnesses, the Lens fixture corpus and the GitHub issue automations that no runtime path imports. At a glance:

- **Lint gates** — The ruff strict gate counts violations per rule across the whole tree at HEAD and at the merge base with the default branch, so a rule fails only when a change grows it, and the base counts are shared with the other gates through lint_base_counts.
- **Local lint driver** — pre_commit_lint.sh picks the files in scope, runs only the matching CI checks, and holds one of the machine-wide slots through gate_slot_lock so parallel worktrees do not thrash the machine.
- **Code generation** — generate_trace_types.py regenerates the tracing types from the pinned Lens JSON schemas with datamodel-code-generator and jinja templates under trace_codegen.
- **Fixture corpus** — lens_assets/source.json pins the Lens schema and fixture files by sha256 against a recorded upstream revision, so schema drift fails the generator instead of silently changing the generated types.
- **Issue automation** — The bun scripts implement the issue labelling, classification and duplicate-closing flows that run from GitHub workflows.

For exact behavior, read the code under `scripts/`. Do not restate it here.
---

## terraform/litellm
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `terraform/litellm/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=terraform/litellm sha=2e973421ed2007a6cf856ac9d8ac72b6866667de -->

This section holds the reference cloud stacks that stand up the componentized deployment, one module set for AWS ECS and Fargate with Aurora and ElastiCache, and one for GCP Cloud Run with Cloud SQL and Memorystore. At a glance:

- **AWS workload** — The ECS module defines a cluster with separate gateway, backend and UI task definitions and services behind an application load balancer.
- **GCP workload** — The GCP module defines three Cloud Run v2 services plus a migrations job, all sharing one service account and one VPC connector for private egress.
- **Migration task** — The AWS migration task definition deliberately sets no entrypoint override so the dedicated migrations image's own entrypoint runs, and a terraform_data resource triggers it on every apply.
- **Database contract** — The stacks pass discrete DATABASE_HOST, PORT, USER and NAME variables so the proxy assembles the URL at pod startup and no database password has to live in a task definition.
- **Module tests** — The terraform test files assert on the rendered plan for the collector sidecar, connection pool, image wiring and workload autoscaling.

The README describes the migration task as running python litellm/proxy/prisma_migration.py against the backend image, but aws/migrations.tf and gcp/cloudrun.tf actually run the dedicated litellm-migrations image with no command override. The code wins.
The AWS stack's IAM-auth comment names litellm/proxy/auth/rds_iam_token.py::init_iam_db_url_from_env and the GCP README names the same function, but no such symbol exists. The code mints the token through generate_iam_auth_token in litellm/proxy/auth/rds_iam_token.py, called from litellm/proxy/db/token_auth.py and litellm/proxy/db/db_url_settings.py.

For exact behavior, read the code under `terraform/litellm/`. Do not restate it here.
---

## terraform/provider
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `terraform/provider/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=terraform/provider sha=a6925122698a650125d2beb00609b916a8ebeedc -->

This section holds the Go Terraform provider that manages LiteLLM control-plane objects through the proxy's management REST API, with one resource and one data source per object kind and a static audit that keeps the provider from drifting from the API. At a glance:

- **Resource registry** — The provider registers resources for models, teams, keys, organizations, budgets, tags, projects, users, guardrails, prompts, agents, search tools, access groups, MCP servers, credentials and vector stores, each with a matching data source.
- **API client** — client.go is a thin HTTP client over the management API, with one method per management operation such as key generation and organization membership.
- **Endpoint audit** — The endpointaudit tool parses the provider's Go sources for request call sites and checks each one against the proxy's OpenAPI paths, and in reverse requires every management endpoint to be covered by a resource or data source or carry an allowlist entry.
- **Schema dump** — dump_openapi.py imports the proxy application and writes its OpenAPI schema, which is the input to that audit.

For exact behavior, read the code under `terraform/provider/`. Do not restate it here.
---

## tests
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `tests/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=tests sha=5335ee77e4c29840ff82125054b687b4bac88713 -->

The repository's test suite, split into tiers by what stands on the other side of the call: in-process unit tests that mirror the source tree, integration tests against a proxy the suite boots itself, end-to-end tests against real providers, and tests of the harness itself. At a glance:

- **Tiered by dependency** — tests/AGENTS.md fixes the split: tests/unit talks to nothing on the other side, tests/integration drives a proxy the suite starts with a scripted upstream, tests/e2e needs someone else's service with real credentials, and tests/e2e_harness tests the harness alone with no proxy at all. The dashboard's browser tier sits apart again, a self-contained Playwright package under tests/e2e/ui with its own lockfile that boots postgres, a mock upstream and the proxy on port 4000.
- **Unit tree mirrors source** — tests/unit/<path> mirrors litellm/<path>, so a changed source file selects its tests by path rather than through a mapping file. 3397 of the 5555 tracked files sit under tests/unit, and 156 provider folders live under tests/unit/llms.
- **Shared e2e transport** — The e2e suite routes every call through one Transport protocol with a frozen ProxyClient dataclass holding the transport plus poll config, so suites add their own client methods instead of re-implementing HTTP.
- **Coverage registry** — Behaviour coverage is a checked-in registry of cells under tests/e2e/coverage_registry, loaded from YAML and validated by a pydantic TypeAdapter that rejects duplicate cell ids, with each e2e test claiming a cell through a covers marker.
- **Rust parity harness** — tests/rust-python-harness runs strategies that drive the same contract through the Python implementation and the native Rust one and compare the results; unit_tests_parity runs each scope with LITELLM_RUST=0 and =1 in separate processes and demands matching outcomes.
- **Repo policy gates** — tests/code_coverage_tests holds the tree-wide structural checks rather than product tests, such as the migration rule that forbids data rewrites in Prisma migrations unless a statement is explicitly bounded with the data-migration-ok marker.

ARCHITECTURE.md still tells contributors to add provider tests in tests/llm_translation/test_{provider}.py and lists test paths under that prefix, but no tests/llm_translation directory exists at HEAD; provider translation tests live under tests/unit/llms/<provider>/, tests/integration/translation/ and tests/e2e/llm_translation/.

For exact behavior, read the code under `tests/`. Do not restate it here.
---

## ui
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `ui/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=ui sha=9f9738d10aa816c738fefb340c2908218ec8a439 -->

The Next.js admin dashboard that ships next to the proxy, an app-router project under ui/litellm-dashboard that is built as a static export and served either by the proxy at /ui or by the standalone nginx image in this directory. At a glance:

- **App router layout** — The dashboard is a Next.js app-router project: 1109 tracked files live under src/app, and the whole authenticated surface sits in the (dashboard) route group, which the README pins to a folder-per-page convention of page.tsx plus components/ and hooks/ subfolders.
- **Generated API types** — src/lib/http/schema.d.ts is generated from the proxy's own OpenAPI spec, and scripts/gen-api-types.mjs reads the spec straight off the FastAPI app object so it can run in CI with no database and no proxy boot; the generated file is never hand-edited.
- **One typed HTTP client** — All backend calls funnel through src/lib/http/api.ts, an openapi-fetch client over the generated paths whose middleware attaches the auth token, rejects non-JSON success bodies and turns error responses into a typed ApiError.
- **Four test projects** — vitest.config.ts declares four projects with distinct scopes: unit over .test.ts in a node environment, component over .test.tsx in jsdom, integration over .integration.test.tsx, and a types project that typechecks .test-d.ts files.
- **Lint budgets** — eslint-budgets.json caps the codebase-wide count of individual rules with a max and a lower target for each, for example no-explicit-any at 2040 heading to 1500, so the lint gate ratchets down instead of only blocking growth.
- **Container and static serving** — ui/Dockerfile builds the export with npm run build and hands /app/out to an nginx image, while ui/nginx.conf resolves /ui/<page> to the exported HTML, keeps the App Router flight payload .txt files reachable, and serves a runtime-config.json the entrypoint writes from LITELLM_BACKEND_URL.

ARCHITECTURE.md documents only the Python SDK and proxy request flow; it never mentions the dashboard, the Next.js project or how the UI is packaged.

For exact behavior, read the code under `ui/`. Do not restate it here.
---

## vscode-extension
<!-- blueprint:section state=code -->
> **Distilled — owned by code at `vscode-extension/`.** (no spec yet) The implementation
> is the source of truth; this section maps it. To change it, `/speckit.specify`
> the area as usual and `distill` it when the spec ships.
<!-- blueprint:code path=vscode-extension sha=c17093224040ad051b1dc831e18d90ad436a9c79 -->

This section holds the VS Code extension that registers LiteLLM as a language-model chat provider, reading the gateway's model groups to populate the picker and streaming completions through the configured gateway. At a glance:

- **Manifest contribution** — package.json contributes the litellm vendor with a gateway base URL and API key setting and a refresh-models command, and bundles to a single CommonJS extension file.
- **Gateway client** — gateway.ts fetches the gateway's model group list, then streams chat completions through the OpenAI SDK against the same origin with a versioned user agent.
- **Model descriptors** — models.ts turns the model group payload into descriptors carrying context limits, pricing and the reasoning efforts each model supports.
- **Provider registration** — extension.ts registers the chat provider and the refresh command with VS Code's language model API.

On the componentized deployment the model-group endpoint is kept by the backend's allowlist while the OpenAI-compatible paths are kept by the gateway's, so a componentized install needs the extension pointed at whichever origin serves both.

For exact behavior, read the code under `vscode-extension/`. Do not restate it here.
---

## Architecture — subsystem relations
<!-- blueprint:section state=context -->

Rendered from the recovery facts; every edge below is machine-validated by
the check gate (endpoints on the map, evidence tracked in git).

| from | kind | to | why |
|---|---|---|---|
| backend | uses | docker | The backend image copies the shared container entrypoint script and runs it as its process entrypoint. |
| backend | uses | litellm/proxy | The backend serves a trimmed view of the shared proxy application, keeping only management routes. |
| backend | uses | litellm/proxy/db | The backend assembles its database URL through the proxy's shared database URL settings before the proxy app starts. |
| ci_cd | uses | litellm | The cost map guard requires the SDK package's backup copy of the cost map to stay byte-identical to the root file. |
| ci_cd | uses | litellm-proxy-extras/litellm_proxy_extras | The migration generator applies and diffs against the proxy-extras migration tree rather than a separate copy. |
| ci_cd | uses | litellm/proxy | The spend-log gate watches the proxy's schema copy for changes that touch the spend-log table. |
| ci_cd | uses | scripts | The migration generator shells out to the shared default-branch resolver to discover origin's current default branch. |
| cookbook | uses | litellm | the scripts call the SDK surface directly, from litellm.completion and litellm.Router to the gateway token helpers |
| cookbook | uses | litellm/caching | the load-test recipe configures the SDK's cache object directly, with S3 as the backing store |
| cookbook | uses | litellm/integrations | the custom secret manager example extends the integrations package's CustomSecretManager base class |
| cookbook | uses | litellm/proxy/management_endpoints | the config migration script reads a proxy config.yaml and posts each model_list entry to the proxy's model creation route |
| db_scripts | uses | litellm/proxy/db | The partitioning script must agree with the proxy's spend-log partition manager on the partition interval contract. |
| db_scripts | uses | litellm/vector_stores | The vector-store cleanup reuses the SDK's predicate for identifying proxy-written metadata keys. |
| docker | uses | enterprise | The admin UI build step keys off the enterprise UI palette files to decide whether to ship a custom dashboard. |
| docker | uses | litellm/proxy | The image entrypoint runs the proxy's own Prisma migration script before the server starts. |
| docker | uses | ui | The image builder copies the dashboard source and compiles its static export into the image. |
| enterprise | uses | litellm/integrations | the enterprise callbacks are CustomLogger and CustomGuardrail subclasses from litellm/integrations, which is how the proxy discovers them |
| enterprise | uses | litellm/proxy | enterprise code reaches into the host proxy for prisma_client, proxy_config and the premium_user gate, and the proxy in turn imports litellm_enterprise optionally, so the two import each other |
| enterprise | uses | litellm/proxy/auth | the enterprise route checks and custom SSO handler extend the proxy auth contracts, reusing its auth_checks and user_api_key_auth surface |
| enterprise | uses | litellm/repositories | the enterprise endpoints read and write through the shared repository layer rather than through Prisma models directly |
| enterprise | uses | litellm/secret_managers | enterprise-only behaviour is gated on secret-manager flags such as DISABLE_ADMIN_ENDPOINTS, read through litellm/secret_managers |
| examples | uses | litellm/proxy | The file is a proxy config.yaml, so its keys are the proxy's configuration contract. |
| examples | uses | litellm/router_strategy | The example's routing_strategy value is the name the LAR-1 routing strategy registers itself under. |
| gateway | uses | docker | The gateway image copies the shared container entrypoint script and runs it before the supervisor. |
| gateway | uses | litellm/proxy | The gateway serves a trimmed view of the shared proxy application, keeping only data-plane routes. |
| gateway | uses | litellm/proxy/db | The gateway assembles the database URL and drives the proxy's in-container PgBouncer helper for pooled connections. |
| helm | uses | litellm/proxy | The legacy chart's migration Job runs the proxy's Prisma migration script, and the componentized gateway runs the proxy's Prometheus metrics server as a sidecar. |
| helm | uses | migrations | The componentized chart deploys the dedicated migrations image for its schema Job instead of the backend image. |
| litellm | uses | litellm/litellm_core_utils | Provider resolution, token counting, logging and the cost helpers come from the core utilities instead of being reimplemented here. |
| litellm | uses | litellm/llms | Every provider call is transformed and executed by the provider layer; main.py imports the provider configs and the shared HTTP handler from it. |
| litellm | uses | litellm/router_strategy | The Router instantiates one routing strategy per configured name and hands it the deployment list to pick from. |
| litellm | uses | litellm/rust_bridge | The public endpoint packages bind each entry point to a native route when the catalog admits it, and fall back to the Python path otherwise. |
| litellm | uses | litellm/types | The request, response and model-info contracts the entry points validate against are declared once in the shared type package. |
| litellm-proxy-extras | uses | ci_cd | the runbook's generation step delegates to ci_cd/run_migration.py, which creates the migration directories the package ships |
| litellm-proxy-extras | uses | litellm-proxy-extras/litellm_proxy_extras | the runbook and the packaged test both drive the packaged ProxyExtrasDBManager and its migration directory |
| litellm-proxy-extras | uses | litellm/proxy | step zero of the runbook requires litellm/proxy/schema.prisma to stay byte-identical to the packaged schema, so the proxy's Prisma client and the published migrations agree |
| litellm-proxy-extras/dist | uses | litellm-proxy-extras/litellm_proxy_extras | the archived artifacts are published builds of this package's module tree and migration SQL, which is why every file name carries the litellm_proxy_extras module name |
| litellm-proxy-extras/litellm_proxy_extras | uses | litellm | the package keeps no hard dependency on litellm, psycopg is its only runtime requirement, and borrows litellm's secret redaction only opportunistically when litellm happens to be importable |
| litellm-rust | uses | litellm/litellm_core_utils | the Rust cost calculator is pinned against the Python generic_cost_per_token implementation it must agree with |
| litellm-rust | uses | litellm/llms | the Rust port still routes provider-specific legacy hooks into the Python provider packages by module path |
| litellm-rust | uses | litellm/proxy | legacy Python callbacks dispatched from Rust are resolved by module path into the proxy package, including its utils and cold-storage spend handler |
| litellm-rust | uses | litellm/rust_bridge | the Rust crates import the Python-side bridge host modules at runtime, including the settings, logger and cache hosts under litellm.rust_bridge.host |
| litellm-rust | uses | litellm/types | the parity generator constructs the Python Usage type to feed the reference calculator |
| litellm/_v2 | uses | litellm/caching | The v2 factory implements the existing BaseCache interface and returns the existing Cache facade. |
| litellm/_v2 | uses | litellm/rust_bridge | The native cache handle comes from the packaged Rust extension the bridge loads. |
| litellm/_v2 | uses | litellm/types | The cache type enum the facade is configured with comes from the shared type package. |
| litellm/a2a_protocol | uses | litellm/interactions | The completion bridge borrows the interactions agent utilities to resolve agent configuration, which is what couples the two surfaces. |
| litellm/a2a_protocol | uses | litellm/litellm_core_utils | The logging object that carries usage, agent id and cost parameters comes from the core utilities, so A2A calls land in the same logging pipeline as chat calls. |
| litellm/a2a_protocol | uses | litellm/llms | Agent card and message calls go out over the SDK's shared HTTP handler, which is why the client inherits LiteLLM's timeout, retry and logging behaviour for free. |
| litellm/a2a_protocol | uses | litellm/types | Agent, message and response types are shared from litellm/types rather than redefined here. |
| litellm/anthropic_interface | crosscuts | litellm/proxy | The Anthropic error body and SSE frame are what the gateway renders failures with, so this taxonomy threads through the proxy's whole error path. |
| litellm/anthropic_interface | crosscuts | litellm/proxy/anthropic_endpoints | The Anthropic endpoints build their error responses from this taxonomy, including the provider_specific_fields and call_id enrichment. |
| litellm/anthropic_interface | uses | litellm | The messages wrapper is a thin adapter that delegates to the root package's litellm.messages handlers. |
| litellm/anthropic_interface | uses | litellm/litellm_core_utils | Upstream error bodies are parsed with the shared safe JSON loader rather than a local one. |
| litellm/anthropic_interface | uses | litellm/types | The Anthropic response type is shared from litellm/types so the Anthropic surface and the OpenAI surface agree on model objects. |
| litellm/batches | uses | litellm/files | The result file that batch cost is computed from is read through the files API. |
| litellm/batches | uses | litellm/integrations | Per-line results are dispatched to a CustomLogger callback, using the standard batch line-item payload shape defined in that section. |
| litellm/batches | uses | litellm/llms | Provider batch handlers and the shared HTTP handler live in the provider layer, which is where batch request shaping is implemented. |
| litellm/batches | uses | litellm/types | Batch request, response and provider-list constants are typed in litellm/types, including the set of providers that support batch listing. |
| litellm/caching | uses | litellm/litellm_core_utils | Model parameters and hidden parameters are normalized before they enter a cache key. |
| litellm/caching | uses | litellm/llms | The Anthropic native response cache is reused for provider-specific caching semantics instead of being reimplemented. |
| litellm/caching | uses | litellm/responses | The Responses streaming iterator is reused so a cached streaming response can be replayed in the same event shape. |
| litellm/caching | uses | litellm/secret_managers | Backend credentials, such as the Qdrant API key, are resolved through the secret managers. |
| litellm/caching | uses | litellm/types | Cache types, TTLs and the cache-control options the handler honours are typed in the shared type package. |
| litellm/completion_extras | uses | litellm/litellm_core_utils | The streaming handler assembles the bridged response into a completion stream. |
| litellm/completion_extras | uses | litellm/llms | The provider bridge and base-model iterator are what carry a bridged call back into a normal completion. |
| litellm/completion_extras | uses | litellm/responses | The bridge reuses the Responses transformation helpers, including tool search, rather than reimplementing them. |
| litellm/completion_extras | uses | litellm/types | The OpenAI request and response models the bridge produces come from the shared type package. |
| litellm/compression | uses | litellm/caching | The stubbed content and its retrieval keys are parked in the dual cache so a later retrieval can find them. |
| litellm/compression | uses | litellm/litellm_core_utils | Token counting against the target budget comes from the core utilities. |
| litellm/compression | uses | litellm/types | The compressed request and result models and the supported call types come from the shared type package. |
| litellm/containers | uses | litellm/litellm_core_utils | Every generated container-file call runs through the shared logging object. |
| litellm/containers | uses | litellm/llms | The provider container configs and the generic container handler live in the provider layer. |
| litellm/containers | uses | litellm/responses | The managed container id is decoded with the same helper the Responses API uses. |
| litellm/containers | uses | litellm/types | The container request and response models are declared in the shared type package. |
| litellm/decisions | uses | litellm | The Decisions client prices its calls with the root package's cost calculator. |
| litellm/decisions | uses | litellm/litellm_core_utils | Metadata handling and the drop-params normalization the call applies come from the core utilities. |
| litellm/decisions | uses | litellm/llms | The provider decisions transformations and the shared HTTP handler carry the call to the provider. |
| litellm/decisions | uses | litellm/types | The Decisions request and response models are declared in the shared type package. |
| litellm/files | uses | litellm/litellm_core_utils | Provider resolution and the logging object come from the core utilities, so a file call is logged like any other call. |
| litellm/files | uses | litellm/llms | The Azure, Bedrock, Vertex and OpenAI file handlers, and the shared HTTP handler they run on, are all defined in the provider layer. |
| litellm/files | uses | litellm/types | The OpenAI file request and response models are shared from litellm/types rather than redeclared here. |
| litellm/google_genai | uses | litellm/llms | The Google GenAI base config and the shared HTTP handler are owned by the provider layer. This section is the public native wrapper over them. |
| litellm/google_genai | uses | litellm/proxy/pass_through_endpoints | The native streaming iterator reuses the proxy's passthrough streaming and success handlers, the same reuse pattern the Anthropic native path uses. |
| litellm/google_genai | uses | litellm/types | Google GenAI request and response models come from litellm/types, including the adapter-specific type adapters. |
| litellm/harness | uses | litellm | The harness reads the SDK's process constants and public client to start its endpoint. |
| litellm/harness | uses | litellm/llms | The local model endpoint calls models through the SDK's shared HTTP handler rather than opening a separate client. |
| litellm/harness | uses | litellm/types | The request parameters and the stream-usage injection field the endpoint forwards come from the shared type package. |
| litellm/images | uses | litellm/litellm_core_utils | Provider resolution and the logging object come from the core utilities. |
| litellm/images | uses | litellm/llms | The image base configs and the provider image handlers are defined in the provider layer, which is where generation and edit requests are actually shaped for each vendor. |
| litellm/images | uses | litellm/types | Image request and response models are shared from litellm/types. |
| litellm/integrations | crosscuts | litellm/proxy/guardrails | The CustomGuardrail base class is what every gateway guardrail extends, so the guardrail contract threads through the proxy's guardrail registry. |
| litellm/integrations | crosscuts | litellm/proxy/hooks | The CustomLogger base class is what every gateway hook extends, so the callback contract threads through the entire proxy hook layer. |
| litellm/integrations | uses | litellm/litellm_core_utils | Masking, metadata sanitisation and prompt-template helpers are shared from the core utilities instead of being reimplemented per integration. |
| litellm/integrations | uses | litellm/llms | Integrations that talk to a provider make their own outbound calls through the SDK's shared HTTP handler rather than opening a separate client. |
| litellm/integrations | uses | litellm/types | Every callback payload, settings object and provider literal is typed in litellm/types, which is this section's largest import dependency. |
| litellm/interactions | uses | litellm/llms | The agent transformation base and the shared HTTP handler live in the provider layer, and the agent handler calls straight into them. |
| litellm/interactions | uses | litellm/proxy/spend_tracking | Background cost polling reserves and settles budget through the proxy's spend-tracking module, which is how an unbilled poll still cannot overspend. |
| litellm/interactions | uses | litellm/responses | The Responses API streaming iterator is reused rather than reimplemented, which is what keeps the two surfaces' event shapes aligned. |
| litellm/interactions | uses | litellm/types | Interaction, agent and request types are shared from litellm/types, including the agent model and router parameter types. |
| litellm/litellm_core_utils | crosscuts | litellm/llms | Provider transformations resolve the provider, count tokens and log through the same helpers, so the provider layer is built on this package. |
| litellm/litellm_core_utils | crosscuts | litellm/proxy | The shared logging, redaction, token-counting and error-normalization helpers thread through the whole gateway, which runs its request path on this package. |
| litellm/litellm_core_utils | uses | litellm/caching | The logging object reads a cached response back through the cache tier before deciding what to log. |
| litellm/litellm_core_utils | uses | litellm/integrations | The agentic loop and the callback registry dispatch into the CustomLogger contract that the integrations package defines. |
| litellm/litellm_core_utils | uses | litellm/llms | The agentic loop drives the provider base model iterator and the shared HTTP handler for the tool calls it issues. |
| litellm/litellm_core_utils | uses | litellm/secret_managers | Provider resolution fetches provider credentials through the secret managers rather than reading the environment directly. |
| litellm/litellm_core_utils | uses | litellm/types | The CallTypes enum and the request and response models this layer keys off are declared in the shared type package. |
| litellm/llms | uses | litellm/integrations | Provider guardrail translation handlers implement the CustomGuardrail contract, which is the seam between a provider's wire events and the gateway's guardrail pipeline. |
| litellm/llms | uses | litellm/litellm_core_utils | Shared helpers, prompt templates, masking utilities and the logging object come from the core utilities package rather than being duplicated per provider. |
| litellm/llms | uses | litellm/proxy/pass_through_endpoints | The Anthropic native streaming iterator reaches back into the proxy's passthrough streaming and success handlers, an inversion that ties the SDK to the gateway's streaming path. |
| litellm/llms | uses | litellm/secret_managers | Provider credentials are resolved through the secret manager, which keeps key lookup out of the transformation code. |
| litellm/llms | uses | litellm/types | Typed request, response and provider contracts are the densest dependency of the whole layer, with well over a thousand import sites across provider transformations. |
| litellm/mcp_client | uses | litellm/litellm_core_utils | Tool call arguments are rendered through the shared prompt-template helpers. |
| litellm/mcp_client | uses | litellm/proxy/mcp_server | The MCP request context, debug capture, result conversion and outbound credential contracts are all taken from the proxy's MCP server package. |
| litellm/mcp_client | uses | litellm/types | MCP tool, transport and session types are shared from litellm/types. |
| litellm/models | uses | litellm/proxy/common_utils | The MCP server table encrypts its stored static headers with the gateway's encrypt and decrypt helper. |
| litellm/models | uses | litellm/types | Every table inherits LiteLLM's shared pydantic base model. |
| litellm/passthrough | uses | litellm/litellm_core_utils | Provider resolution and the logging object come from the core utilities. |
| litellm/passthrough | uses | litellm/llms | The shared HTTP handler and the base passthrough transformation are owned by the provider layer, which is what makes passthrough calls log like ordinary calls. |
| litellm/passthrough | uses | litellm/types | Request, response and router parameter types are shared from litellm/types. |
| litellm/proxy | uses | litellm/proxy/auth | every route depends on the shared key and JWT resolution |
| litellm/proxy | uses | litellm/proxy/common_utils | config loading, callback initialization and the shared key cache come from here |
| litellm/proxy | uses | litellm/proxy/config_resolvers | persisted settings are reconciled against the config file through the resolvers |
| litellm/proxy | uses | litellm/proxy/db | the app drives Prisma access and the batched spend writer |
| litellm/proxy | uses | litellm/proxy/hooks | the cost-tracking and rate-limit callbacks run inside the request path |
| litellm/proxy | uses | litellm/proxy/lens | the Lens tracing adapter route and its internal middleware are mounted |
| litellm/proxy | uses | litellm/proxy/list_api | list routes share the problem-response contract for rejected query parameters |
| litellm/proxy | uses | litellm/proxy/middleware | the ASGI stack wraps every request and every response |
| litellm/proxy | uses | litellm/proxy/prompts | prompts declared in config are initialized into the registry at startup |
| litellm/proxy | uses | litellm/proxy/public_endpoints | the public model hub and provider catalog are mounted as routers |
| litellm/proxy | uses | litellm/proxy/shutdown | graceful termination is coordinated for this worker |
| litellm/proxy | uses | litellm/proxy/spend_tracking | request outcomes become spend events and budget counter increments |
| litellm/proxy | uses | litellm/proxy/swagger | the OpenAPI docs page serves the vendored Swagger UI assets |
| litellm/proxy | uses | litellm/proxy/telemetry | request telemetry is captured per call and exposed through admin endpoints |
| litellm/proxy/_experimental | uses | litellm/litellm_core_utils | the alias machinery that makes the retired import path resolve is the deprecated_package helper in litellm_core_utils |
| litellm/proxy/_experimental | uses | litellm/proxy/mcp_server | the shim's whole purpose is to forward the retired litellm.proxy._experimental.mcp_server path to the canonical MCP server package |
| litellm/proxy/a2a | uses | litellm/litellm_core_utils | Card fetching goes through the shared URL helpers that guard against SSRF. |
| litellm/proxy/a2a | uses | litellm/llms | The upstream card is fetched with the shared HTTP client. |
| litellm/proxy/a2a | uses | litellm/proxy/auth | The discovery route is admin-authenticated through the proxy auth layer. |
| litellm/proxy/a2a | uses | litellm/types | Card and protocol shapes come from the shared type definitions. |
| litellm/proxy/agent_endpoints | uses | litellm/a2a_protocol | Agent cards and messages use the shared A2A protocol types. |
| litellm/proxy/agent_endpoints | uses | litellm/proxy/a2a | A2A payloads are version-normalized by the a2a section's conversion helpers. |
| litellm/proxy/agent_endpoints | uses | litellm/proxy/auth | Agent routes authenticate and resolve access through the proxy auth layer. |
| litellm/proxy/agent_endpoints | uses | litellm/proxy/management_helpers | Agent object permissions are prepared and upserted through the shared object-permission helpers. |
| litellm/proxy/agent_endpoints | uses | litellm/proxy/mcp_server | Effective agent and MCP auth contexts are resolved together. |
| litellm/proxy/agent_endpoints | uses | litellm/repositories | Agents, identities and object permissions are persisted through the shared table repositories. |
| litellm/proxy/anthropic_endpoints | uses | litellm/anthropic_interface | Anthropic error responses are shaped by the shared Anthropic interface exception types. |
| litellm/proxy/anthropic_endpoints | uses | litellm/llms | Context management and message handling come from the Anthropic message modules. |
| litellm/proxy/anthropic_endpoints | uses | litellm/proxy/auth | Marketplace and gateway routes authenticate through the proxy auth layer. |
| litellm/proxy/anthropic_endpoints | uses | litellm/proxy/management_endpoints | The Claude Code gateway reuses the management endpoints' SSO helpers for the browser leg of device sign-in. |
| litellm/proxy/anthropic_endpoints | uses | litellm/proxy/mcp_server | The gateway's refresh token is the MCP gateway's sealed session refresh token and it shares that flow's dynamic client registration record. |
| litellm/proxy/auth | crosscuts | litellm/proxy/hooks | the post-call hooks re-check the key's team and budget after the provider returns |
| litellm/proxy/auth | crosscuts | litellm/proxy/management_endpoints | the admin API threads every authenticated call through this resolver |
| litellm/proxy/auth | crosscuts | litellm/proxy/mcp_server | the MCP bridge authenticates through the same key resolution |
| litellm/proxy/auth | crosscuts | litellm/proxy/pass_through_endpoints | passthrough routes resolve the caller the same way |
| litellm/proxy/auth | uses | litellm/caching | the dual in-memory plus Redis cache backs key object lookups |
| litellm/proxy/auth | uses | litellm/proxy/common_utils | the resolved key objects are cached in the shared user API key cache |
| litellm/proxy/auth | uses | litellm/proxy/db | key, team and org lookups go through the bounded database lookup gate |
| litellm/proxy/auth | uses | litellm/proxy/spend_tracking | budget ceilings are read against the live spend counters |
| litellm/proxy/auth | uses | litellm/repositories | team, org and user rows are read through the typed repositories |
| litellm/proxy/auth | uses | litellm/types | the auth contract types are shared SDK types |
| litellm/proxy/batches_endpoints | uses | litellm/llms | Provider workload identity for batch submissions is resolved through the provider modules. |
| litellm/proxy/batches_endpoints | uses | litellm/proxy/auth | Batch routes authenticate through the proxy auth layer. |
| litellm/proxy/batches_endpoints | uses | litellm/proxy/openai_files_endpoints | Batch input files are read through the shared files surface and its managed-file helpers. |
| litellm/proxy/batches_endpoints | uses | litellm/proxy/pass_through_endpoints | Provider-side batch submission and attribution reuse the passthrough provider handlers. |
| litellm/proxy/batches_endpoints | uses | litellm/repositories | Managed batch state is persisted through the shared table repositories. |
| litellm/proxy/client | uses | litellm/litellm_core_utils | the client resolves the stored gateway API key from the shared CLI token helper |
| litellm/proxy/client | uses | litellm/proxy/common_utils | the CLI prints the shared proxy banner |
| litellm/proxy/client | uses | litellm/types | the PKCE flow uses the shared SDK base model |
| litellm/proxy/common_utils | crosscuts | litellm/proxy/guardrails | guardrail endpoints reuse the shared callback and config plumbing |
| litellm/proxy/common_utils | crosscuts | litellm/proxy/management_endpoints | the admin API reuses these config, encryption and cache helpers |
| litellm/proxy/common_utils | uses | litellm/caching | the key object cache is built on the shared dual cache |
| litellm/proxy/common_utils | uses | litellm/proxy/auth | request tag mappings resolve route permissions through the auth section |
| litellm/proxy/common_utils | uses | litellm/proxy/db | the budget reset job writes its spend-window updates through the database layer |
| litellm/proxy/common_utils | uses | litellm/proxy/hooks | callback registration reaches into the proxy hook implementations |
| litellm/proxy/common_utils | uses | litellm/types | request tag mappings use the shared SDK type definitions |
| litellm/proxy/config_resolvers | crosscuts | litellm/proxy/management_endpoints | the router settings endpoints resolve their values the same way |
| litellm/proxy/config_resolvers | crosscuts | litellm/proxy/ui_crud_endpoints | the admin settings UI reads and writes through these resolvers |
| litellm/proxy/config_resolvers | uses | litellm/proxy/common_utils | stored secrets are decrypted with the shared crypto helper |
| litellm/proxy/config_resolvers | uses | litellm/types | the resolved SSO shape is a shared SDK type |
| litellm/proxy/container_endpoints | uses | litellm/llms | The provider container transformation supplies the request and response contract. |
| litellm/proxy/container_endpoints | uses | litellm/proxy/auth | Container routes authenticate through the proxy auth layer. |
| litellm/proxy/container_endpoints | uses | litellm/proxy/common_utils | Request parsing and ownership helpers use the shared proxy utilities. |
| litellm/proxy/container_endpoints | uses | litellm/repositories | Container ownership rows are persisted through the shared table repositories. |
| litellm/proxy/db | crosscuts | litellm/proxy/management_endpoints | admin CRUD endpoints reach the database through this layer |
| litellm/proxy/db | crosscuts | litellm/proxy/mcp_server | the MCP bridge uses the database exception handler and lookup gate |
| litellm/proxy/db | uses | litellm/proxy/auth | master key migration depends on the auth section's key and salt handling |
| litellm/proxy/db | uses | litellm/proxy/common_utils | the writer refreshes cached auth objects through the shared key cache |
| litellm/proxy/db | uses | litellm/proxy/spend_tracking | counter reseeding and window spend share the spend tracking key space |
| litellm/proxy/db | uses | litellm/repositories | table rows are read and written through the typed repositories |
| litellm/proxy/db | uses | litellm/secret_managers | the database URL and its credentials come from the secret managers |
| litellm/proxy/discovery_endpoints | uses | litellm/caching | Archive caching uses the shared in-memory cache. |
| litellm/proxy/discovery_endpoints | uses | litellm/llms | Skill archives are built with the shared proxy skills handler. |
| litellm/proxy/discovery_endpoints | uses | litellm/models | Stored skill rows come from the shared skill models. |
| litellm/proxy/discovery_endpoints | uses | litellm/proxy/common_utils | The default-credentials hint uses the shared HTML form helper. |
| litellm/proxy/discovery_endpoints | uses | litellm/proxy/mcp_server | The UI configuration reports whether the MCP stdio server is enabled. |
| litellm/proxy/example_config_yaml | uses | litellm/integrations | the example callbacks subclass the SDK CustomLogger |
| litellm/proxy/example_config_yaml | uses | litellm/proxy | the example auth module uses the proxy's shared request and response types |
| litellm/proxy/example_config_yaml | uses | litellm/proxy/management_helpers | the end-to-end validator example drives the management helpers |
| litellm/proxy/guardrails | crosscuts | litellm/proxy/auth | Guardrail tool-name extraction threads through key authorization, so every authenticated call can see which tools a request would invoke. |
| litellm/proxy/guardrails | crosscuts | litellm/proxy/common_utils | The shared registry read-through utilities resolve guardrails by name on behalf of every callback-bearing request path. |
| litellm/proxy/guardrails | uses | litellm/integrations | Every vendor adapter derives from the shared CustomGuardrail base contract. |
| litellm/proxy/guardrails | uses | litellm/repositories | Guardrail and usage rows are persisted through the shared table repositories. |
| litellm/proxy/guardrails | uses | litellm/secret_managers | Guardrail litellm_params are encrypted and decrypted through the shared secret manager helpers. |
| litellm/proxy/hooks | crosscuts | litellm/litellm_core_utils | the SDK logger registry resolves the proxy's dynamic rate limiter |
| litellm/proxy/hooks | crosscuts | litellm/proxy/management_endpoints | key and team management fire the key management event hooks |
| litellm/proxy/hooks | uses | litellm/integrations | the hooks are CustomLogger subclasses |
| litellm/proxy/hooks | uses | litellm/proxy/auth | the cost callback re-reads the key and team to settle the right budget |
| litellm/proxy/hooks | uses | litellm/proxy/common_utils | limiters raise the shared proxy rate limit error |
| litellm/proxy/hooks | uses | litellm/proxy/db | the cost callback hands queued spend rows to the database writer |
| litellm/proxy/hooks | uses | litellm/proxy/spend_tracking | the cost callback batches its counter increments through the spend tracker |
| litellm/proxy/lens | uses | litellm/proxy | the adapter uses the proxy's shared user and role types |
| litellm/proxy/lens | uses | litellm/proxy/auth | the forwarded call authenticates the caller and resolves trace read scope |
| litellm/proxy/lens | uses | litellm/tracing | the collector connection and bounded response reader come from the SDK tracing layer |
| litellm/proxy/list_api | crosscuts | litellm/proxy/management_endpoints | the management list routes are built on this framework |
| litellm/proxy/list_api | uses | litellm/proxy | the framework takes the caller's auth object from the proxy's shared types |
| litellm/proxy/list_api | uses | litellm/proxy/common_utils | validation errors are rendered through the shared validation error body |
| litellm/proxy/list_api | uses | litellm/types | the list and problem response shapes are shared SDK types |
| litellm/proxy/management | uses | litellm/proxy/auth | The current-user route authenticates through the proxy auth layer and reads UserAPIKeyAuth. |
| litellm/proxy/management | uses | litellm/proxy/list_api | The current-user route reports failures through the shared list-API problem contract rather than raising a bare HTTPException. |
| litellm/proxy/management | uses | litellm/proxy/management_endpoints | The current-user route takes its path prefix from the management v1 constants that the management endpoints section owns. |
| litellm/proxy/management_endpoints | uses | litellm/proxy/auth | Key and team routes resolve the caller's auth context through the proxy auth layer before any admin mutation is applied. |
| litellm/proxy/management_endpoints | uses | litellm/proxy/management | Team-scoped admin routes borrow the shared team role checker rather than duplicating the role comparison. |
| litellm/proxy/management_endpoints | uses | litellm/proxy/management_helpers | Access-group and key administration call the shared reverse-sync and roster helpers instead of reimplementing the two-column relationship. |
| litellm/proxy/management_endpoints | uses | litellm/proxy/policy_engine | Policy validation and listing under policy_endpoints delegate to the policy engine's registry and validator. |
| litellm/proxy/management_endpoints | uses | litellm/proxy/roi_calculator | The ROI admin router reads spend and repository data through the ROI calculator's analytics and sync functions. |
| litellm/proxy/management_helpers | crosscuts | litellm/proxy/hooks | Audit logging is a cross-cutting facility the proxy hooks call into whenever they change keys or users. |
| litellm/proxy/management_helpers | uses | litellm/proxy/auth | Roster and permission helpers evict auth caches through the proxy auth layer when membership changes. |
| litellm/proxy/management_helpers | uses | litellm/proxy/common_utils | Cache eviction for roster changes goes through the shared cache-invalidation pubsub helpers. |
| litellm/proxy/management_helpers | uses | litellm/proxy/management | Bulk team helpers ask the shared team access checker whether the caller may write the team roster. |
| litellm/proxy/management_helpers | uses | litellm/proxy/management_endpoints | Bulk helpers reuse the management endpoints' shared request utilities for the management write contract. |
| litellm/proxy/management_helpers | uses | litellm/repositories | Sync and permission helpers read and write through the shared table repositories. |
| litellm/proxy/mcp_server | crosscuts | litellm/proxy/agent_endpoints | Managed agent access and MCP request handling resolve each other's identity context, so agent identity and MCP auth are one loop rather than two. |
| litellm/proxy/mcp_server | crosscuts | litellm/proxy/management_endpoints | The MCP management routes in the admin surface drive the same server and credential registry this section owns. |
| litellm/proxy/mcp_server | uses | litellm/mcp_client | Upstream MCP servers are reached through the shared MCP client. |
| litellm/proxy/mcp_server | uses | litellm/proxy/auth | The REST mirror authenticates MCP calls through the proxy auth layer. |
| litellm/proxy/mcp_server | uses | litellm/repositories | Server rows, credentials and token stores are persisted through the shared table repositories. |
| litellm/proxy/middleware | uses | litellm/caching | the request-scoped Redis batch scope lets every in-request read share one pipeline |
| litellm/proxy/middleware | uses | litellm/proxy | the per-request root path middleware resolves the served prefix from the proxy's own helpers |
| litellm/proxy/middleware | uses | litellm/proxy/auth | the metrics endpoint authenticates with the shared key resolver |
| litellm/proxy/openai_files_endpoints | uses | litellm/llms | File storage backends come from the shared file and storage backend modules. |
| litellm/proxy/openai_files_endpoints | uses | litellm/proxy/auth | File routes authenticate through the proxy auth layer. |
| litellm/proxy/openai_files_endpoints | uses | litellm/proxy/batches_endpoints | Batch input files are linked to the batch runner in the batches section. |
| litellm/proxy/openai_files_endpoints | uses | litellm/proxy/common_utils | Request parsing and credential helpers are shared with the rest of the proxy. |
| litellm/proxy/openai_files_endpoints | uses | litellm/repositories | Managed file records are read and written through the shared table repositories. |
| litellm/proxy/pass_through_endpoints | uses | litellm/integrations | Passthrough guardrails build on the shared custom guardrail contract. |
| litellm/proxy/pass_through_endpoints | uses | litellm/llms | Provider-specific passthrough behaviour, such as the ChatGPT codex routes, reuses the provider transformation and utility modules. |
| litellm/proxy/pass_through_endpoints | uses | litellm/passthrough | The shared passthrough client performs the actual upstream request. |
| litellm/proxy/pass_through_endpoints | uses | litellm/proxy/auth | Passthrough routes authenticate the caller through the proxy auth layer before the upstream call. |
| litellm/proxy/pass_through_endpoints | uses | litellm/secret_managers | Provider credentials and secret references are resolved through the shared secret manager. |
| litellm/proxy/policy_engine | uses | litellm/integrations | The executor drives guardrails through the shared custom guardrail contract and records guardrail information on the standard logging payload. |
| litellm/proxy/policy_engine | uses | litellm/proxy/auth | Policy management routes authenticate and authorize through the proxy auth layer. |
| litellm/proxy/policy_engine | uses | litellm/proxy/common_utils | Applied-guardrail bookkeeping uses the shared callback utilities. |
| litellm/proxy/policy_engine | uses | litellm/proxy/guardrails | The executor runs the unified guardrail callback that the guardrails section owns. |
| litellm/proxy/policy_engine | uses | litellm/repositories | Policies, versions and attachments are persisted through the shared table repositories. |
| litellm/proxy/policy_engine | uses | litellm/types | Policy, condition and pipeline shapes come from the shared proxy policy types. |
| litellm/proxy/prompts | uses | litellm/integrations | a custom prompt management integration supplies its own initializer |
| litellm/proxy/prompts | uses | litellm/proxy/auth | the prompt endpoints authenticate the caller |
| litellm/proxy/prompts | uses | litellm/repositories | stored prompts are persisted through the prompt repository |
| litellm/proxy/prompts | uses | litellm/types | prompt specs and responses are shared SDK types |
| litellm/proxy/public_endpoints | uses | litellm/proxy/auth | the v1 model hub authenticates the caller before publishing |
| litellm/proxy/public_endpoints | uses | litellm/proxy/db | published health and plugin rows are read from the database |
| litellm/proxy/public_endpoints | uses | litellm/proxy/list_api | the model hub lists through the shared list framework |
| litellm/proxy/public_endpoints | uses | litellm/router_strategy | the published routing presets come from the complexity router |
| litellm/proxy/rag_endpoints | uses | litellm/proxy/auth | RAG routes authenticate and authorize the caller through the proxy auth layer. |
| litellm/proxy/rag_endpoints | uses | litellm/proxy/openai_files_endpoints | Upload credential handling and file parsing are shared with the files surface. |
| litellm/proxy/rag_endpoints | uses | litellm/proxy/vector_store_endpoints | The ingest pipeline stores into managed vector stores through the vector store endpoints. |
| litellm/proxy/rag_endpoints | uses | litellm/rag | Chunking, embedding and reranking are performed by the shared RAG library. |
| litellm/proxy/response_polling | uses | litellm/caching | The polling entry is stored in the shared Redis cache. |
| litellm/proxy/response_polling | uses | litellm/proxy | The background task drives the request through the shared proxy request-processing base class. |
| litellm/proxy/response_polling | uses | litellm/proxy/auth | The background task resolves the caller's auth context so the streamed request is attributed correctly. |
| litellm/proxy/response_polling | uses | litellm/types | The cached response uses the shared Responses API response and status types. |
| litellm/proxy/roi_calculator | uses | litellm/llms | The estimator calls a model through the shared HTTP client. |
| litellm/proxy/roi_calculator | uses | litellm/proxy/auth | The settings helpers authenticate through the proxy auth layer. |
| litellm/proxy/roi_calculator | uses | litellm/proxy/common_utils | Connection tokens are encrypted and decrypted through the shared encryption helpers. |
| litellm/proxy/roi_calculator | uses | litellm/repositories | ROI connections and configuration are persisted through the shared config repository. |
| litellm/proxy/roi_calculator | uses | litellm/types | Report, pull and settings shapes come from the shared ROI types. |
| litellm/proxy/search_endpoints | uses | litellm/proxy/auth | Search routes authenticate through the proxy auth layer. |
| litellm/proxy/search_endpoints | uses | litellm/proxy/common_utils | Credential encryption and decryption use the shared encryption helpers. |
| litellm/proxy/search_endpoints | uses | litellm/repositories | Search tool rows are persisted through the shared table repositories. |
| litellm/proxy/search_endpoints | uses | litellm/types | Search tool configuration uses the shared search types. |
| litellm/proxy/shutdown | uses | litellm | the shutdown timeouts come from the shared constants |
| litellm/proxy/shutdown | uses | litellm/proxy/middleware | the drain reads the in-flight counter the middleware layer maintains |
| litellm/proxy/spend_tracking | crosscuts | litellm/proxy/management_endpoints | the admin spend-log endpoints read the same spend records |
| litellm/proxy/spend_tracking | uses | litellm/caching | the counter batch rides the shared Redis batch cache |
| litellm/proxy/spend_tracking | uses | litellm/proxy/auth | the spend reporting endpoints resolve the caller through the auth section |
| litellm/proxy/spend_tracking | uses | litellm/proxy/common_utils | counter keys come from the shared key cache helpers |
| litellm/proxy/spend_tracking | uses | litellm/proxy/db | spend rows and key metadata recovery go through the database layer |
| litellm/proxy/spend_tracking | uses | litellm/repositories | spend and team rows are read through the typed repositories |
| litellm/proxy/telemetry | uses | litellm/proxy/auth | the telemetry endpoints require an authenticated admin |
| litellm/proxy/telemetry | uses | litellm/proxy/common_utils | the deployment hash secret is derived from the shared salt key |
| litellm/proxy/telemetry | uses | litellm/proxy/middleware | the telemetry middleware reuses the billable-request classification |
| litellm/proxy/telemetry | uses | litellm/telemetry | the proxy telemetry layer is built on the SDK's telemetry records, sinks and report types |
| litellm/proxy/telemetry | uses | litellm/types | the telemetry HTTP exporter uses the shared custom http types |
| litellm/proxy/ui_crud_endpoints | uses | litellm/proxy/auth | Settings, release and banner routes authenticate through the proxy auth layer. |
| litellm/proxy/ui_crud_endpoints | uses | litellm/proxy/config_resolvers | Setting ownership and validation come from the shared config resolvers. |
| litellm/proxy/ui_crud_endpoints | uses | litellm/proxy/management_endpoints | The team admin field permissions that constrain which settings a team admin may change come from the management endpoints. |
| litellm/proxy/ui_crud_endpoints | uses | litellm/repositories | Settings and SSO configuration rows are stored through the shared table repositories. |
| litellm/proxy/vector_store_endpoints | uses | litellm/proxy/auth | Vector store routes authenticate through the proxy auth layer. |
| litellm/proxy/vector_store_endpoints | uses | litellm/proxy/mcp_server | Access checks resolve UI session credentials through the MCP server's session helpers. |
| litellm/proxy/vector_store_endpoints | uses | litellm/repositories | Managed vector store rows are read and written through the shared table repositories. |
| litellm/proxy/vector_store_endpoints | uses | litellm/vector_stores | The vector store registry and write body come from the shared vector store library. |
| litellm/proxy/video_endpoints | uses | litellm/proxy | Binary content responses reuse the image endpoints' byte conversion. |
| litellm/proxy/video_endpoints | uses | litellm/proxy/auth | Video routes authenticate through the proxy auth layer. |
| litellm/proxy/video_endpoints | uses | litellm/proxy/common_utils | Request parsing and provider detection use the shared proxy utilities. |
| litellm/proxy/video_endpoints | uses | litellm/types | Video request and response shapes come from the shared video types. |
| litellm/rag | uses | litellm/llms | Provider ingestion classes issue their own provider calls through the SDK's shared HTTP handler, and the Bedrock ingestion subclasses the provider's AWS base client. |
| litellm/rag | uses | litellm/types | RAG request and response types, including the ingestion and query option models, are shared from litellm/types. |
| litellm/rag | uses | litellm/vector_store_files | The same ingestion path attaches the source files to the store through the vector store file API. |
| litellm/rag | uses | litellm/vector_stores | The OpenAI ingestion path stores embedded chunks into a provider vector store through the vector store API rather than talking to the provider directly. |
| litellm/repositories | uses | litellm/litellm_core_utils | Rows are converted with the shared core helpers so every repository maps them the same way. |
| litellm/repositories | uses | litellm/models | Repositories read and write the canonical table models rather than a row shape of their own. |
| litellm/repositories | uses | litellm/proxy/common_utils | Credential writes publish through the gateway's config-sync pub/sub so every worker observes the change. |
| litellm/repositories | uses | litellm/proxy/db | The daily-activity repository joins the gateway's spend-span tables to build its projections. |
| litellm/repositories | uses | litellm/types | Row shapes that are not tables, such as the daily-activity projection, are typed in the shared type package. |
| litellm/responses | uses | litellm/completion_extras | The completion-to-Responses bridge handler is shared with litellm/completion_extras rather than duplicated. |
| litellm/responses | uses | litellm/litellm_core_utils | Provider resolution, prompt templates and the logging object come from the core utilities. |
| litellm/responses | uses | litellm/llms | The bridge check consults the provider configurations to learn whether a deployment can serve the Responses API. |
| litellm/responses | uses | litellm/rust_bridge | The public entry points dispatch to the native Responses route through the Rust bridge catalog. |
| litellm/responses | uses | litellm/types | The Responses request and response models are declared in the shared type package. |
| litellm/router_strategy | uses | litellm/caching | The Redis counters, cooldowns and per-deployment usage the strategies read and write live in the cache tier. |
| litellm/router_strategy | uses | litellm/litellm_core_utils | Prompt templates and the metadata helpers are shared from the core utilities instead of being copied per strategy. |
| litellm/router_strategy | uses | litellm/repositories | The adaptive router persists its learned scores through the repository layer. |
| litellm/router_strategy | uses | litellm/router_utils | Batch detection and fallback bookkeeping are shared router utilities rather than per-strategy code. |
| litellm/router_strategy | uses | litellm/types | The deployment, ModelInfo and routing-group types the strategies read are declared in the shared type package. |
| litellm/router_utils | uses | litellm/caching | The cooldown and health state live in the router cache so every worker sees them. |
| litellm/router_utils | uses | litellm/litellm_core_utils | Hidden-parameter handling when building retry and fallback headers comes from the core utilities. |
| litellm/router_utils | uses | litellm/responses | The deployment-affinity pre-call check reads the Responses request utilities to resolve an existing response id. |
| litellm/router_utils | uses | litellm/router_strategy | The auto-router naming helper reads the complexity router's configuration to derive model names. |
| litellm/router_utils | uses | litellm/types | The deployment and routing types these helpers read are declared in the shared type package. |
| litellm/rust_bridge | uses | litellm/litellm_core_utils | The detectors resolve the provider through the same core helper the Python path uses, so both agree on what a request needs. |
| litellm/rust_bridge | uses | litellm/llms | The legacy Python callbacks the host modules bridge to reach the provider streaming iterators. |
| litellm/rust_bridge | uses | litellm/responses | The Responses route has its own detectors and entry points inside the bridge. |
| litellm/rust_bridge | uses | litellm/secret_managers | The host secret-manager module reads credentials through the SDK's secret managers. |
| litellm/rust_bridge | uses | litellm/types | The request and response shapes the detectors read are declared in the shared type package. |
| litellm/sandbox | uses | litellm/harness | The local and Docker sandbox implementations exposed here are the harness package's, re-exported for the top-level sandbox namespace. |
| litellm/sandbox | uses | litellm/llms | The provider sandbox configuration and the code-execution result types come from the provider layer. |
| litellm/sandbox | uses | litellm/secret_managers | A configured sandbox tool's credentials are resolved through the secret managers. |
| litellm/sandbox | uses | litellm/types | The provider literals and call types the sandbox configuration uses come from the shared type package. |
| litellm/search | uses | litellm/litellm_core_utils | Pricing reads the shared model cost map through the core utilities. |
| litellm/search | uses | litellm/llms | The base search config and the per-provider search cost calculators live in the provider layer, and this section dispatches to them. |
| litellm/search | uses | litellm/types | Search request and response types and the supported-provider enum come from litellm/types. |
| litellm/secret_managers | crosscuts | litellm/proxy | Credential resolution for provider keys is the gateway's auth facility, so every proxy path that needs a provider secret comes through here. |
| litellm/secret_managers | uses | litellm/caching | The OIDC token and the CyberArk client hold their state in the cache tier so a token is not fetched on every call. |
| litellm/secret_managers | uses | litellm/integrations | A custom manager must satisfy the CustomSecretManager base that the integrations package defines. |
| litellm/secret_managers | uses | litellm/litellm_core_utils | The AWS backend resolves the partition to talk to and reuses the shared optional-import helpers. |
| litellm/secret_managers | uses | litellm/types | The key-management settings that select and configure a backend are typed in the shared type package. |
| litellm/tracing | uses | litellm/integrations | The exporter subclasses CustomLogger and reuses the ClickHouse spend logger, which is how trace spend reaches the same pipeline as ordinary call spend. |
| litellm/tracing | uses | litellm/llms | The Lens HTTP client is driven through the SDK's shared async handler rather than a bespoke transport. |
| litellm/tracing | uses | litellm/rust_bridge | The OTLP error encoder loads the native bridge for the encoding of its guidance frames. |
| litellm/tracing | uses | litellm/types | Trace and spend payload models are built on the shared litellm/types base models, which is what keeps the generated schemas consistent with the rest of the SDK. |
| litellm/types | uses | litellm/litellm_core_utils | Router typing reaches into the core utilities for the completion-timeout and provider-affinity helpers its config fields carry. |
| litellm/types | uses | litellm/models | The proxy-scoped auth and management types import the persisted entity models rather than restating their shape. |
| litellm/types | uses | litellm/proxy/common_utils | The team-endpoint contracts use the gateway's timezone helper to validate budget durations. |
| litellm/vector_store_files | uses | litellm/litellm_core_utils | The logging object for a file operation comes from the core utilities. |
| litellm/vector_store_files | uses | litellm/llms | The shared HTTP handler that runs every vector store file operation lives in the provider layer. |
| litellm/vector_store_files | uses | litellm/types | Vector store file request and response models are shared from litellm/types. |
| litellm/vector_store_files | uses | litellm/vector_stores | The managed-store registry that supplies credentials is owned by the vector stores section. This file reaches it through the root package's litellm.vector_store_registry handle rather than importing the module directly. |
| litellm/vector_stores | uses | litellm/litellm_core_utils | Provider resolution and the logging object come from the core utilities. |
| litellm/vector_stores | uses | litellm/llms | The shared HTTP handler and the provider vector store configs live in the provider layer. |
| litellm/vector_stores | uses | litellm/repositories | The registry loads managed stores from the database through the table repositories, which is where the persisted store list actually comes from. |
| litellm/vector_stores | uses | litellm/types | Vector store request and response models are shared from litellm/types. |
| litellm/videos | uses | litellm/litellm_core_utils | Provider resolution and the logging object come from the core utilities. |
| litellm/videos | uses | litellm/llms | The base video transformation and the shared HTTP handler are owned by the provider layer, and the video request shaping lives with them. |
| litellm/videos | uses | litellm/types | Video request, response and router parameter types are shared from litellm/types. |
| litellm_cli | uses | litellm | The CLI initializes the SDK package in place and applies its process defaults before running a command. |
| litellm_cli | uses | litellm/proxy/client | The console scripts call the Click CLI defined in the proxy client package. |
| migrations | uses | litellm-proxy-extras/litellm_proxy_extras | The Job's migration and index-build logic comes from the proxy-extras database manager. |
| migrations | uses | litellm/proxy/db | The Job assembles its database URL through the proxy's shared database URL settings. |
| packaging | uses | litellm_cli | The formula's value is the lite console script, whose implementation lives in the CLI section's entry points. |
| packaging/litellm-core | uses | litellm-rust | The maturin manifest is the Rust crate that provides the native extension. |
| packaging/litellm-core | uses | litellm/rust_bridge | The compiled extension is installed into the SDK's rust_bridge package namespace. |
| scripts | uses | litellm/proxy | The OpenAPI documentation gate computes its findings from the proxy application's own OpenAPI schema. |
| scripts | uses | litellm/proxy/mcp_server | The MCP SDK install gate imports the proxy's MCP server modules and asserts the negotiated protocol versions. |
| scripts | uses | litellm/rust_bridge | The tracing fixture seeder takes its ClickHouse spend storage configuration from the native bridge's Python shim. |
| scripts | uses | litellm/tracing | The tracing fixture seeder writes spend logs and traces through the tracing package's remote store and storage types. |
| scripts | uses | packaging/litellm-core | The core distribution builder reuses the core pyproject as the staged project's metadata when it assembles a standalone distribution. |
| terraform/litellm | uses | litellm/proxy/auth | The AWS stack's IAM-auth branch depends on the proxy's RDS IAM token helper to mint the database URL. |
| terraform/litellm | uses | litellm/proxy/db | The stacks feed the proxy's database URL settings the discrete variables they assemble the connection string from. |
| terraform/litellm | uses | migrations | The AWS migration task runs the dedicated migrations image as its container. |
| terraform/provider | uses | litellm/proxy | The provider audits itself against the proxy application's generated OpenAPI schema. |
| terraform/provider | uses | litellm/proxy/management_endpoints | The provider's client calls the proxy's management endpoints, for example key generation. |
| tests | uses | litellm-rust | the parity harness shells into cargo inside the Rust workspace to collect and run the native test targets it compares against |
| tests | uses | litellm/llms | the unit tree imports provider transformation and handler classes directly, one mirrored folder per provider |
| tests | uses | litellm/proxy/auth | route-level RBAC and model checks are asserted through the auth package's public helpers |
| tests | uses | litellm/proxy/db | the proxy data layer has its own mirrored unit folder, and its token-auth module is imported and exercised there |
| tests | uses | litellm/rust_bridge | the native-path suite drives the Rust bridge through the Python public API, selecting routes via the bridge catalog and its rollout rules |
| tests | uses | litellm/types | the shared request and response models are the contract most unit assertions are written against |
| ui | uses | litellm/proxy | the dashboard's typed client is generated from the proxy's OpenAPI schema and every request targets the proxy, so the proxy app object is the contract the UI compiles against |
| ui | uses | litellm/proxy/auth | the dashboard mirrors the server's role-level route RBAC for model writes, naming the auth package's route check that forbids view-only sessions |
| ui | uses | litellm/proxy/management_endpoints | key, model and team management screens drive the proxy's management routes directly, for example the key creation endpoint |
| ui | uses | litellm/proxy/spend_tracking | cost tracking and log drawers read the proxy's spend log endpoints, including the per-log detail route |
| vscode-extension | uses | litellm/proxy | The extension consumes the proxy's model-group endpoint and its OpenAI-compatible chat completions surface. |

<!-- blueprint:relation from=backend to=docker kind=uses evidence=backend/Dockerfile#component_entrypoint.sh -->
<!-- blueprint:relation from=backend to=litellm/proxy kind=uses evidence=backend/main.py#litellm.proxy.proxy_server -->
<!-- blueprint:relation from=backend to=litellm/proxy/db kind=uses evidence=backend/main.py#litellm.proxy.db.db_url_settings -->
<!-- blueprint:relation from=ci_cd to=litellm kind=uses evidence=ci_cd/cost_map_guard.py#model_prices_and_context_window_backup.json -->
<!-- blueprint:relation from=ci_cd to=litellm-proxy-extras/litellm_proxy_extras kind=uses evidence=ci_cd/run_migration.py#litellm_proxy_extras -->
<!-- blueprint:relation from=ci_cd to=litellm/proxy kind=uses evidence=ci_cd/spend_logs_guard.py#litellm/proxy/schema.prisma -->
<!-- blueprint:relation from=ci_cd to=scripts kind=uses evidence=ci_cd/run_migration.py#default_branch.py -->
<!-- blueprint:relation from=cookbook to=litellm kind=uses evidence=cookbook/litellm_proxy_server/cli_token_usage.py#litellm.completion -->
<!-- blueprint:relation from=cookbook to=litellm/caching kind=uses evidence=cookbook/litellm_router_load_test/test_loadtest_router_withs3_cache.py#litellm.caching.caching -->
<!-- blueprint:relation from=cookbook to=litellm/integrations kind=uses evidence=cookbook/litellm_proxy_server/secret_manager/my_secret_manager.py#litellm.integrations.custom_secret_manager -->
<!-- blueprint:relation from=cookbook to=litellm/proxy/management_endpoints kind=uses evidence=cookbook/misc/migrate_proxy_config.py#/model/new -->
<!-- blueprint:relation from=db_scripts to=litellm/proxy/db kind=uses evidence=db_scripts/partition_spend_logs.sql#SPEND_LOG_PARTITION_INTERVAL -->
<!-- blueprint:relation from=db_scripts to=litellm/vector_stores kind=uses evidence=db_scripts/strip_vector_store_internal_metadata.py#is_litellm_written_metadata_key -->
<!-- blueprint:relation from=docker to=enterprise kind=uses evidence=docker/build_admin_ui.sh#enterprise/enterprise_ui -->
<!-- blueprint:relation from=docker to=litellm/proxy kind=uses evidence=docker/entrypoint.sh#prisma_migration.py -->
<!-- blueprint:relation from=docker to=ui kind=uses evidence=docker/Dockerfile.non_root#ui/litellm-dashboard -->
<!-- blueprint:relation from=enterprise to=litellm/integrations kind=uses evidence=enterprise/litellm_enterprise/enterprise_callbacks/secret_detection.py#CustomGuardrail -->
<!-- blueprint:relation from=enterprise to=litellm/proxy kind=uses evidence=enterprise/litellm_enterprise/proxy/proxy_server.py#premium_user -->
<!-- blueprint:relation from=enterprise to=litellm/proxy/auth kind=uses evidence=enterprise/litellm_enterprise/proxy/management_endpoints/project_endpoints.py#delete_cached_project_object -->
<!-- blueprint:relation from=enterprise to=litellm/repositories kind=uses evidence=enterprise/litellm_enterprise/proxy/management_endpoints/project_endpoints.py#ProjectRepository -->
<!-- blueprint:relation from=enterprise to=litellm/secret_managers kind=uses evidence=enterprise/litellm_enterprise/proxy/auth/route_checks.py#get_secret_bool -->
<!-- blueprint:relation from=examples to=litellm/proxy kind=uses evidence=examples/lar1_ollama_config.yaml#general_settings -->
<!-- blueprint:relation from=examples to=litellm/router_strategy kind=uses evidence=examples/lar1_ollama_config.yaml#routing_strategy -->
<!-- blueprint:relation from=gateway to=docker kind=uses evidence=gateway/Dockerfile#component_entrypoint.sh -->
<!-- blueprint:relation from=gateway to=litellm/proxy kind=uses evidence=gateway/main.py#litellm.proxy.proxy_server -->
<!-- blueprint:relation from=gateway to=litellm/proxy/db kind=uses evidence=gateway/launch.py#litellm.proxy.db.pgbouncer -->
<!-- blueprint:relation from=helm to=litellm/proxy kind=uses evidence=helm/litellm-helm/templates/migrations-job.yaml#prisma_migration.py -->
<!-- blueprint:relation from=helm to=migrations kind=uses evidence=helm/litellm/values.yaml#ghcr.io/berriai/litellm-migrations -->
<!-- blueprint:relation from=litellm to=litellm/litellm_core_utils kind=uses evidence=litellm/utils.py#litellm.litellm_core_utils.core_helpers -->
<!-- blueprint:relation from=litellm to=litellm/llms kind=uses evidence=litellm/main.py#litellm.llms.base_llm -->
<!-- blueprint:relation from=litellm to=litellm/router_strategy kind=uses evidence=litellm/router.py#litellm.router_strategy.base_routing_strategy -->
<!-- blueprint:relation from=litellm to=litellm/rust_bridge kind=uses evidence=litellm/chat_completions/dispatch.py#litellm.rust_bridge.dispatch -->
<!-- blueprint:relation from=litellm to=litellm/types kind=uses evidence=litellm/main.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm-proxy-extras to=ci_cd kind=uses evidence=litellm-proxy-extras/migration_runbook.md#ci_cd/run_migration.py -->
<!-- blueprint:relation from=litellm-proxy-extras to=litellm-proxy-extras/litellm_proxy_extras kind=uses evidence=litellm-proxy-extras/tests/test_setup_database_fail_fast.py#ProxyExtrasDBManager -->
<!-- blueprint:relation from=litellm-proxy-extras to=litellm/proxy kind=uses evidence=litellm-proxy-extras/migration_runbook.md#litellm/proxy/schema.prisma -->
<!-- blueprint:relation from=litellm-proxy-extras/dist to=litellm-proxy-extras/litellm_proxy_extras kind=uses evidence=litellm-proxy-extras/dist#litellm_proxy_extras-0.4.60-py3-none-any.whl -->
<!-- blueprint:relation from=litellm-proxy-extras/litellm_proxy_extras to=litellm kind=uses evidence=litellm-proxy-extras/litellm_proxy_extras/_redaction.py#redact_secrets -->
<!-- blueprint:relation from=litellm-rust to=litellm/litellm_core_utils kind=uses evidence=litellm-rust/crates/cost/tests/generate_python_reference.py#generic_cost_per_token -->
<!-- blueprint:relation from=litellm-rust to=litellm/llms kind=uses evidence=litellm-rust/crates/callbacks-legacy-python/src/mapping.rs#litellm.llms.openai.openai -->
<!-- blueprint:relation from=litellm-rust to=litellm/proxy kind=uses evidence=litellm-rust/crates/callbacks-legacy-python/src/mapping.rs#litellm.proxy.spend_tracking.cold_storage_handler -->
<!-- blueprint:relation from=litellm-rust to=litellm/rust_bridge kind=uses evidence=litellm-rust/crates/python-bridge/src/python_settings.rs#litellm.rust_bridge.host.settings -->
<!-- blueprint:relation from=litellm-rust to=litellm/types kind=uses evidence=litellm-rust/crates/cost/tests/generate_python_reference.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm/_v2 to=litellm/caching kind=uses evidence=litellm/_v2/cache/__init__.py#litellm.caching.base_cache -->
<!-- blueprint:relation from=litellm/_v2 to=litellm/rust_bridge kind=uses evidence=litellm/_v2/cache/__init__.py#litellm.rust_bridge._native -->
<!-- blueprint:relation from=litellm/_v2 to=litellm/types kind=uses evidence=litellm/_v2/cache/__init__.py#litellm.types.caching -->
<!-- blueprint:relation from=litellm/a2a_protocol to=litellm/interactions kind=uses evidence=litellm/a2a_protocol/litellm_completion_bridge/handler.py#litellm.interactions.agents.utils -->
<!-- blueprint:relation from=litellm/a2a_protocol to=litellm/litellm_core_utils kind=uses evidence=litellm/a2a_protocol/cost_calculator.py#litellm.litellm_core_utils.litellm_logging -->
<!-- blueprint:relation from=litellm/a2a_protocol to=litellm/llms kind=uses evidence=litellm/a2a_protocol/main.py#litellm.llms.custom_httpx.http_handler -->
<!-- blueprint:relation from=litellm/a2a_protocol to=litellm/types kind=uses evidence=litellm/a2a_protocol/client.py#litellm.types.agents -->
<!-- blueprint:relation from=litellm/anthropic_interface to=litellm/proxy kind=crosscuts evidence=litellm/proxy/common_request_processing.py#anthropic_error_sse_frame -->
<!-- blueprint:relation from=litellm/anthropic_interface to=litellm/proxy/anthropic_endpoints kind=crosscuts evidence=litellm/proxy/anthropic_endpoints/endpoints.py#AnthropicErrorResponse -->
<!-- blueprint:relation from=litellm/anthropic_interface to=litellm kind=uses evidence=litellm/anthropic_interface/messages/__init__.py#litellm.messages -->
<!-- blueprint:relation from=litellm/anthropic_interface to=litellm/litellm_core_utils kind=uses evidence=litellm/anthropic_interface/exceptions/exception_mapping_utils.py#litellm.litellm_core_utils.safe_json_loads -->
<!-- blueprint:relation from=litellm/anthropic_interface to=litellm/types kind=uses evidence=litellm/anthropic_interface/messages/__init__.py#litellm.types.llms.anthropic_messages.anthropic_response -->
<!-- blueprint:relation from=litellm/batches to=litellm/files kind=uses evidence=litellm/batches/batch_utils.py#litellm.files.main -->
<!-- blueprint:relation from=litellm/batches to=litellm/integrations kind=uses evidence=litellm/batches/batch_line_items.py#litellm.integrations.custom_logger -->
<!-- blueprint:relation from=litellm/batches to=litellm/llms kind=uses evidence=litellm/batches/main.py#litellm.llms.custom_httpx.llm_http_handler -->
<!-- blueprint:relation from=litellm/batches to=litellm/types kind=uses evidence=litellm/batches/main.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm/caching to=litellm/litellm_core_utils kind=uses evidence=litellm/caching/caching.py#litellm.litellm_core_utils.model_param_helper -->
<!-- blueprint:relation from=litellm/caching to=litellm/llms kind=uses evidence=litellm/caching/caching_handler.py#litellm.llms.anthropic.messages.native.response_cache -->
<!-- blueprint:relation from=litellm/caching to=litellm/responses kind=uses evidence=litellm/caching/caching_handler.py#litellm.responses.streaming_iterator -->
<!-- blueprint:relation from=litellm/caching to=litellm/secret_managers kind=uses evidence=litellm/caching/qdrant_semantic_cache.py#litellm.secret_managers.main -->
<!-- blueprint:relation from=litellm/caching to=litellm/types kind=uses evidence=litellm/caching/caching.py#litellm.types.caching -->
<!-- blueprint:relation from=litellm/completion_extras to=litellm/litellm_core_utils kind=uses evidence=litellm/completion_extras/litellm_responses_transformation/handler.py#litellm.litellm_core_utils.streaming_handler -->
<!-- blueprint:relation from=litellm/completion_extras to=litellm/llms kind=uses evidence=litellm/completion_extras/litellm_responses_transformation/transformation.py#litellm.llms.base_llm.bridges.completion_transformation -->
<!-- blueprint:relation from=litellm/completion_extras to=litellm/responses kind=uses evidence=litellm/completion_extras/litellm_responses_transformation/transformation.py#litellm.responses.litellm_completion_transformation.tool_search -->
<!-- blueprint:relation from=litellm/completion_extras to=litellm/types kind=uses evidence=litellm/completion_extras/litellm_responses_transformation/handler.py#litellm.types.llms.openai -->
<!-- blueprint:relation from=litellm/compression to=litellm/caching kind=uses evidence=litellm/compression/compress.py#litellm.caching.dual_cache -->
<!-- blueprint:relation from=litellm/compression to=litellm/litellm_core_utils kind=uses evidence=litellm/compression/compress.py#litellm.litellm_core_utils.token_counter -->
<!-- blueprint:relation from=litellm/compression to=litellm/types kind=uses evidence=litellm/compression/compress.py#litellm.types.compression -->
<!-- blueprint:relation from=litellm/containers to=litellm/litellm_core_utils kind=uses evidence=litellm/containers/endpoint_factory.py#litellm.litellm_core_utils.litellm_logging -->
<!-- blueprint:relation from=litellm/containers to=litellm/llms kind=uses evidence=litellm/containers/endpoint_factory.py#litellm.llms.base_llm.containers.transformation -->
<!-- blueprint:relation from=litellm/containers to=litellm/responses kind=uses evidence=litellm/containers/utils.py#litellm.responses.utils -->
<!-- blueprint:relation from=litellm/containers to=litellm/types kind=uses evidence=litellm/containers/endpoint_factory.py#litellm.types.containers.main -->
<!-- blueprint:relation from=litellm/decisions to=litellm kind=uses evidence=litellm/decisions/call.py#litellm.cost_calculator -->
<!-- blueprint:relation from=litellm/decisions to=litellm/litellm_core_utils kind=uses evidence=litellm/decisions/call.py#litellm.litellm_core_utils.core_helpers -->
<!-- blueprint:relation from=litellm/decisions to=litellm/llms kind=uses evidence=litellm/decisions/call.py#litellm.llms.custom_httpx.llm_http_handler -->
<!-- blueprint:relation from=litellm/decisions to=litellm/types kind=uses evidence=litellm/decisions/main.py#litellm.types.decisions -->
<!-- blueprint:relation from=litellm/files to=litellm/litellm_core_utils kind=uses evidence=litellm/files/main.py#litellm.litellm_core_utils.get_llm_provider_logic -->
<!-- blueprint:relation from=litellm/files to=litellm/llms kind=uses evidence=litellm/files/main.py#litellm.llms.azure.files.handler -->
<!-- blueprint:relation from=litellm/files to=litellm/types kind=uses evidence=litellm/files/main.py#litellm.types.llms.openai -->
<!-- blueprint:relation from=litellm/google_genai to=litellm/llms kind=uses evidence=litellm/google_genai/main.py#litellm.llms.custom_httpx.llm_http_handler -->
<!-- blueprint:relation from=litellm/google_genai to=litellm/proxy/pass_through_endpoints kind=uses evidence=litellm/google_genai/streaming_iterator.py#litellm.proxy.pass_through_endpoints.streaming_handler -->
<!-- blueprint:relation from=litellm/google_genai to=litellm/types kind=uses evidence=litellm/google_genai/adapters/handler.py#litellm.types.google_genai.adapters -->
<!-- blueprint:relation from=litellm/harness to=litellm kind=uses evidence=litellm/harness/runtime.py#litellm.constants -->
<!-- blueprint:relation from=litellm/harness to=litellm/llms kind=uses evidence=litellm/harness/endpoint.py#litellm.llms.custom_httpx.http_handler -->
<!-- blueprint:relation from=litellm/harness to=litellm/types kind=uses evidence=litellm/harness/endpoint.py#litellm.types.litellm_params -->
<!-- blueprint:relation from=litellm/images to=litellm/litellm_core_utils kind=uses evidence=litellm/images/main.py#litellm.litellm_core_utils.get_llm_provider_logic -->
<!-- blueprint:relation from=litellm/images to=litellm/llms kind=uses evidence=litellm/images/main.py#litellm.llms.base_llm -->
<!-- blueprint:relation from=litellm/images to=litellm/types kind=uses evidence=litellm/images/main.py#litellm.types.images.main -->
<!-- blueprint:relation from=litellm/integrations to=litellm/proxy/guardrails kind=crosscuts evidence=litellm/proxy/guardrails/guardrail_endpoints.py#CustomGuardrail -->
<!-- blueprint:relation from=litellm/integrations to=litellm/proxy/hooks kind=crosscuts evidence=litellm/proxy/hooks/parallel_request_limiter_v3.py#CustomLogger -->
<!-- blueprint:relation from=litellm/integrations to=litellm/litellm_core_utils kind=uses evidence=litellm/integrations/shadow_eval_logger.py#litellm.litellm_core_utils.core_helpers -->
<!-- blueprint:relation from=litellm/integrations to=litellm/llms kind=uses evidence=litellm/integrations/SlackAlerting/slack_alerting.py#litellm.llms.custom_httpx.http_handler -->
<!-- blueprint:relation from=litellm/integrations to=litellm/types kind=uses evidence=litellm/integrations/batch_line_item_objects.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm/interactions to=litellm/llms kind=uses evidence=litellm/interactions/agents/http_handler.py#litellm.llms.custom_httpx.http_handler -->
<!-- blueprint:relation from=litellm/interactions to=litellm/proxy/spend_tracking kind=uses evidence=litellm/interactions/background_cost_polling.py#litellm.proxy.spend_tracking.budget_reservation -->
<!-- blueprint:relation from=litellm/interactions to=litellm/responses kind=uses evidence=litellm/interactions/litellm_responses_transformation/handler.py#litellm.responses.streaming_iterator -->
<!-- blueprint:relation from=litellm/interactions to=litellm/types kind=uses evidence=litellm/interactions/agents/http_handler.py#litellm.types.agents -->
<!-- blueprint:relation from=litellm/litellm_core_utils to=litellm/llms kind=crosscuts evidence=litellm/llms/anthropic/chat/transformation.py#litellm.litellm_core_utils.core_helpers -->
<!-- blueprint:relation from=litellm/litellm_core_utils to=litellm/proxy kind=crosscuts evidence=litellm/proxy/proxy_server.py#litellm.litellm_core_utils -->
<!-- blueprint:relation from=litellm/litellm_core_utils to=litellm/caching kind=uses evidence=litellm/litellm_core_utils/litellm_logging.py#litellm.caching.caching -->
<!-- blueprint:relation from=litellm/litellm_core_utils to=litellm/integrations kind=uses evidence=litellm/litellm_core_utils/chat_completion_agentic_loop.py#litellm.integrations.custom_logger -->
<!-- blueprint:relation from=litellm/litellm_core_utils to=litellm/llms kind=uses evidence=litellm/litellm_core_utils/chat_completion_agentic_loop.py#litellm.llms.base_llm.base_model_iterator -->
<!-- blueprint:relation from=litellm/litellm_core_utils to=litellm/secret_managers kind=uses evidence=litellm/litellm_core_utils/get_llm_provider_logic.py#litellm.secret_managers.main -->
<!-- blueprint:relation from=litellm/litellm_core_utils to=litellm/types kind=uses evidence=litellm/litellm_core_utils/api_route_to_call_types.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm/llms to=litellm/integrations kind=uses evidence=litellm/llms/anthropic/chat/guardrail_translation/handler.py#litellm.integrations.custom_guardrail -->
<!-- blueprint:relation from=litellm/llms to=litellm/litellm_core_utils kind=uses evidence=litellm/llms/anthropic/chat/transformation.py#litellm.litellm_core_utils.core_helpers -->
<!-- blueprint:relation from=litellm/llms to=litellm/proxy/pass_through_endpoints kind=uses evidence=litellm/llms/anthropic/messages/native/streaming_iterator.py#litellm.proxy.pass_through_endpoints.success_handler -->
<!-- blueprint:relation from=litellm/llms to=litellm/secret_managers kind=uses evidence=litellm/llms/aiml/chat/transformation.py#litellm.secret_managers.main -->
<!-- blueprint:relation from=litellm/llms to=litellm/types kind=uses evidence=litellm/llms/anthropic/chat/transformation.py#litellm.types.llms.anthropic -->
<!-- blueprint:relation from=litellm/mcp_client to=litellm/litellm_core_utils kind=uses evidence=litellm/mcp_client/tools.py#litellm.litellm_core_utils.prompt_templates.common_utils -->
<!-- blueprint:relation from=litellm/mcp_client to=litellm/proxy/mcp_server kind=uses evidence=litellm/mcp_client/client.py#litellm.proxy.mcp_server.mcp_context -->
<!-- blueprint:relation from=litellm/mcp_client to=litellm/types kind=uses evidence=litellm/mcp_client/client.py#litellm.types.mcp -->
<!-- blueprint:relation from=litellm/models to=litellm/proxy/common_utils kind=uses evidence=litellm/models/mcp_server.py#litellm.proxy.common_utils.encrypt_decrypt_utils -->
<!-- blueprint:relation from=litellm/models to=litellm/types kind=uses evidence=litellm/models/access_group.py#litellm.types.llms.base -->
<!-- blueprint:relation from=litellm/passthrough to=litellm/litellm_core_utils kind=uses evidence=litellm/passthrough/main.py#litellm.litellm_core_utils.get_llm_provider_logic -->
<!-- blueprint:relation from=litellm/passthrough to=litellm/llms kind=uses evidence=litellm/passthrough/main.py#litellm.llms.custom_httpx.http_handler -->
<!-- blueprint:relation from=litellm/passthrough to=litellm/types kind=uses evidence=litellm/passthrough/main.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/auth kind=uses evidence=litellm/proxy/proxy_server.py#user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/proxy_server.py#initialize_callbacks_on_proxy -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/config_resolvers kind=uses evidence=litellm/proxy/proxy_server.py#changed_section_keys -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/db kind=uses evidence=litellm/proxy/proxy_server.py#PodLockManager -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/hooks kind=uses evidence=litellm/proxy/proxy_server.py#proxy_track_cost_callback -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/lens kind=uses evidence=litellm/proxy/proxy_server.py#lens_router -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/list_api kind=uses evidence=litellm/proxy/proxy_server.py#litellm.proxy.list_api.common -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/middleware kind=uses evidence=litellm/proxy/proxy_server.py#PrometheusAuthMiddleware -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/prompts kind=uses evidence=litellm/proxy/proxy_server.py#init_prompts -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/public_endpoints kind=uses evidence=litellm/proxy/proxy_server.py#public_endpoints_router -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/shutdown kind=uses evidence=litellm/proxy/proxy_server.py#GracefulShutdownManager -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/spend_tracking kind=uses evidence=litellm/proxy/proxy_server.py#build_spend_event_producer -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/swagger kind=uses evidence=litellm/proxy/proxy_server.py#mount_swagger_ui -->
<!-- blueprint:relation from=litellm/proxy to=litellm/proxy/telemetry kind=uses evidence=litellm/proxy/proxy_server.py#TelemetryMiddleware -->
<!-- blueprint:relation from=litellm/proxy/_experimental to=litellm/litellm_core_utils kind=uses evidence=litellm/proxy/_experimental/mcp_server/__init__.py#litellm.litellm_core_utils.deprecated_package -->
<!-- blueprint:relation from=litellm/proxy/_experimental to=litellm/proxy/mcp_server kind=uses evidence=litellm/proxy/_experimental/mcp_server/__init__.py#litellm.proxy.mcp_server -->
<!-- blueprint:relation from=litellm/proxy/a2a to=litellm/litellm_core_utils kind=uses evidence=litellm/proxy/a2a/discovery.py#litellm.litellm_core_utils.url_utils -->
<!-- blueprint:relation from=litellm/proxy/a2a to=litellm/llms kind=uses evidence=litellm/proxy/a2a/discovery.py#litellm.llms.custom_httpx.http_handler -->
<!-- blueprint:relation from=litellm/proxy/a2a to=litellm/proxy/auth kind=uses evidence=litellm/proxy/a2a/endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/a2a to=litellm/types kind=uses evidence=litellm/proxy/a2a/discovery.py#litellm.types.llms.custom_http -->
<!-- blueprint:relation from=litellm/proxy/agent_endpoints to=litellm/a2a_protocol kind=uses evidence=litellm/proxy/agent_endpoints/a2a_endpoints.py#litellm.a2a_protocol -->
<!-- blueprint:relation from=litellm/proxy/agent_endpoints to=litellm/proxy/a2a kind=uses evidence=litellm/proxy/agent_endpoints/a2a_endpoints.py#litellm.proxy.a2a.version_convert -->
<!-- blueprint:relation from=litellm/proxy/agent_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/agent_endpoints/a2a_endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/agent_endpoints to=litellm/proxy/management_helpers kind=uses evidence=litellm/proxy/agent_endpoints/agent_registry.py#litellm.proxy.management_helpers.object_permission_utils -->
<!-- blueprint:relation from=litellm/proxy/agent_endpoints to=litellm/proxy/mcp_server kind=uses evidence=litellm/proxy/agent_endpoints/auth/agent_permission_handler.py#litellm.proxy.mcp_server -->
<!-- blueprint:relation from=litellm/proxy/agent_endpoints to=litellm/repositories kind=uses evidence=litellm/proxy/agent_endpoints/agent_registry.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/proxy/anthropic_endpoints to=litellm/anthropic_interface kind=uses evidence=litellm/proxy/anthropic_endpoints/endpoints.py#litellm.anthropic_interface.exceptions -->
<!-- blueprint:relation from=litellm/proxy/anthropic_endpoints to=litellm/llms kind=uses evidence=litellm/proxy/anthropic_endpoints/endpoints.py#litellm.llms.anthropic.messages.context_management -->
<!-- blueprint:relation from=litellm/proxy/anthropic_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/anthropic_endpoints/claude_code_endpoints/claude_code_marketplace.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/anthropic_endpoints to=litellm/proxy/management_endpoints kind=uses evidence=litellm/proxy/anthropic_endpoints/gateway_endpoints.py#litellm.proxy.management_endpoints.sso_helper_utils -->
<!-- blueprint:relation from=litellm/proxy/anthropic_endpoints to=litellm/proxy/mcp_server kind=uses evidence=litellm/proxy/anthropic_endpoints/gateway_endpoints.py#litellm.proxy.mcp_server.gateway_dcr_flow -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/proxy/hooks kind=crosscuts evidence=litellm/proxy/hooks/proxy_track_cost_callback.py#litellm.proxy.auth.auth_checks -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/proxy/management_endpoints kind=crosscuts evidence=litellm/proxy/management_endpoints/management_v1/users.py#user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/proxy/mcp_server kind=crosscuts evidence=litellm/proxy/mcp_server/bridge_token_flow.py#litellm.proxy.auth.auth_checks -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/proxy/pass_through_endpoints kind=crosscuts evidence=litellm/proxy/pass_through_endpoints/llm_passthrough_endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/caching kind=uses evidence=litellm/proxy/auth/auth_checks.py#litellm.caching.dual_cache -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/auth/auth_checks.py#litellm.proxy.common_utils.user_api_key_cache -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/proxy/db kind=uses evidence=litellm/proxy/auth/auth_checks.py#litellm.proxy.db.db_lookup_gate -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/proxy/spend_tracking kind=uses evidence=litellm/proxy/auth/auth_checks.py#litellm.proxy.spend_tracking -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/repositories kind=uses evidence=litellm/proxy/auth/auth_checks.py#litellm.repositories.team_repository -->
<!-- blueprint:relation from=litellm/proxy/auth to=litellm/types kind=uses evidence=litellm/proxy/auth/auth_checks.py#litellm.types.proxy.auth.auth_checks -->
<!-- blueprint:relation from=litellm/proxy/batches_endpoints to=litellm/llms kind=uses evidence=litellm/proxy/batches_endpoints/endpoints.py#litellm.llms.openai.workload_identity -->
<!-- blueprint:relation from=litellm/proxy/batches_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/batches_endpoints/endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/batches_endpoints to=litellm/proxy/openai_files_endpoints kind=uses evidence=litellm/proxy/batches_endpoints/endpoints.py#litellm.proxy.openai_files_endpoints.common_utils -->
<!-- blueprint:relation from=litellm/proxy/batches_endpoints to=litellm/proxy/pass_through_endpoints kind=uses evidence=litellm/proxy/batches_endpoints/endpoints.py#litellm.proxy.pass_through_endpoints.llm_provider_handlers.batch_attribution -->
<!-- blueprint:relation from=litellm/proxy/batches_endpoints to=litellm/repositories kind=uses evidence=litellm/proxy/batches_endpoints/endpoints.py#litellm.repositories.managed_batch_repository -->
<!-- blueprint:relation from=litellm/proxy/client to=litellm/litellm_core_utils kind=uses evidence=litellm/proxy/client/client.py#get_litellm_gateway_api_key -->
<!-- blueprint:relation from=litellm/proxy/client to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/client/cli/interface.py#litellm.proxy.common_utils.banner -->
<!-- blueprint:relation from=litellm/proxy/client to=litellm/types kind=uses evidence=litellm/proxy/client/cli/commands/pkce_login.py#litellm.types.llms.base_model -->
<!-- blueprint:relation from=litellm/proxy/common_utils to=litellm/proxy/guardrails kind=crosscuts evidence=litellm/proxy/guardrails/guardrail_endpoints.py#litellm.proxy.common_utils -->
<!-- blueprint:relation from=litellm/proxy/common_utils to=litellm/proxy/management_endpoints kind=crosscuts evidence=litellm/proxy/management_endpoints/key_management_endpoints.py#litellm.proxy.common_utils -->
<!-- blueprint:relation from=litellm/proxy/common_utils to=litellm/caching kind=uses evidence=litellm/proxy/common_utils/user_api_key_cache.py#litellm.caching.dual_cache -->
<!-- blueprint:relation from=litellm/proxy/common_utils to=litellm/proxy/auth kind=uses evidence=litellm/proxy/common_utils/request_tag_mappings.py#litellm.proxy.auth.route_checks -->
<!-- blueprint:relation from=litellm/proxy/common_utils to=litellm/proxy/db kind=uses evidence=litellm/proxy/common_utils/reset_budget_job.py#litellm.proxy.db.budget_window_spend_writer -->
<!-- blueprint:relation from=litellm/proxy/common_utils to=litellm/proxy/hooks kind=uses evidence=litellm/proxy/common_utils/callback_utils.py#litellm.proxy.hooks.prompt_injection_detection -->
<!-- blueprint:relation from=litellm/proxy/common_utils to=litellm/types kind=uses evidence=litellm/proxy/common_utils/request_tag_mappings.py#litellm.types.proxy.request_tag_mappings -->
<!-- blueprint:relation from=litellm/proxy/config_resolvers to=litellm/proxy/management_endpoints kind=crosscuts evidence=litellm/proxy/management_endpoints/router_settings_endpoints.py#litellm.proxy.config_resolvers -->
<!-- blueprint:relation from=litellm/proxy/config_resolvers to=litellm/proxy/ui_crud_endpoints kind=crosscuts evidence=litellm/proxy/ui_crud_endpoints/proxy_setting_endpoints.py#litellm.proxy.config_resolvers -->
<!-- blueprint:relation from=litellm/proxy/config_resolvers to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/config_resolvers/sso.py#litellm.proxy.common_utils.encrypt_decrypt_utils -->
<!-- blueprint:relation from=litellm/proxy/config_resolvers to=litellm/types kind=uses evidence=litellm/proxy/config_resolvers/sso.py#litellm.types.proxy.management_endpoints.ui_sso -->
<!-- blueprint:relation from=litellm/proxy/container_endpoints to=litellm/llms kind=uses evidence=litellm/proxy/container_endpoints/handler_factory.py#litellm.llms.openai.containers.transformation -->
<!-- blueprint:relation from=litellm/proxy/container_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/container_endpoints/endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/container_endpoints to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/container_endpoints/endpoints.py#litellm.proxy.common_utils.http_parsing_utils -->
<!-- blueprint:relation from=litellm/proxy/container_endpoints to=litellm/repositories kind=uses evidence=litellm/proxy/container_endpoints/ownership.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/proxy/db to=litellm/proxy/management_endpoints kind=crosscuts evidence=litellm/proxy/management_endpoints/model_insights_endpoints.py#litellm.proxy.db -->
<!-- blueprint:relation from=litellm/proxy/db to=litellm/proxy/mcp_server kind=crosscuts evidence=litellm/proxy/mcp_server/bridge_token_flow.py#litellm.proxy.db.exception_handler -->
<!-- blueprint:relation from=litellm/proxy/db to=litellm/proxy/auth kind=uses evidence=litellm/proxy/db/master_key_migration.py#litellm.proxy.auth.master_key_boot_check -->
<!-- blueprint:relation from=litellm/proxy/db to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/db/db_spend_update_writer.py#litellm.proxy.common_utils.user_api_key_cache -->
<!-- blueprint:relation from=litellm/proxy/db to=litellm/proxy/spend_tracking kind=uses evidence=litellm/proxy/db/spend_counter_reseed.py#litellm.proxy.spend_tracking.spend_counter_batch -->
<!-- blueprint:relation from=litellm/proxy/db to=litellm/repositories kind=uses evidence=litellm/proxy/db/tool_registry_writer.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/proxy/db to=litellm/secret_managers kind=uses evidence=litellm/proxy/db/prisma_client.py#litellm.secret_managers.main -->
<!-- blueprint:relation from=litellm/proxy/discovery_endpoints to=litellm/caching kind=uses evidence=litellm/proxy/discovery_endpoints/agent_skills_endpoints.py#litellm.caching.in_memory_cache -->
<!-- blueprint:relation from=litellm/proxy/discovery_endpoints to=litellm/llms kind=uses evidence=litellm/proxy/discovery_endpoints/agent_skills_endpoints.py#litellm.llms.litellm_proxy.skills.handler -->
<!-- blueprint:relation from=litellm/proxy/discovery_endpoints to=litellm/models kind=uses evidence=litellm/proxy/discovery_endpoints/agent_skills_endpoints.py#litellm.models.skills -->
<!-- blueprint:relation from=litellm/proxy/discovery_endpoints to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/discovery_endpoints/ui_discovery_endpoints.py#litellm.proxy.common_utils.html_forms.default_credentials_hint -->
<!-- blueprint:relation from=litellm/proxy/discovery_endpoints to=litellm/proxy/mcp_server kind=uses evidence=litellm/proxy/discovery_endpoints/ui_discovery_endpoints.py#litellm.proxy.mcp_server.stdio_gate -->
<!-- blueprint:relation from=litellm/proxy/example_config_yaml to=litellm/integrations kind=uses evidence=litellm/proxy/example_config_yaml/custom_callbacks.py#litellm.integrations.custom_logger -->
<!-- blueprint:relation from=litellm/proxy/example_config_yaml to=litellm/proxy kind=uses evidence=litellm/proxy/example_config_yaml/custom_auth.py#litellm.proxy._types -->
<!-- blueprint:relation from=litellm/proxy/example_config_yaml to=litellm/proxy/management_helpers kind=uses evidence=litellm/proxy/example_config_yaml/team_metadata_validator_e2e.py#litellm.proxy.management_helpers -->
<!-- blueprint:relation from=litellm/proxy/guardrails to=litellm/proxy/auth kind=crosscuts evidence=litellm/proxy/auth/auth_checks.py#litellm.proxy.guardrails.tool_name_extraction -->
<!-- blueprint:relation from=litellm/proxy/guardrails to=litellm/proxy/common_utils kind=crosscuts evidence=litellm/proxy/common_utils/registry_read_through.py#litellm.proxy.guardrails.guardrail_registry -->
<!-- blueprint:relation from=litellm/proxy/guardrails to=litellm/integrations kind=uses evidence=litellm/proxy/guardrails/guardrail_registry.py#litellm.integrations.custom_guardrail -->
<!-- blueprint:relation from=litellm/proxy/guardrails to=litellm/repositories kind=uses evidence=litellm/proxy/guardrails/guardrail_endpoints.py#litellm.repositories.prisma_protocols -->
<!-- blueprint:relation from=litellm/proxy/guardrails to=litellm/secret_managers kind=uses evidence=litellm/proxy/guardrails/guardrail_registry.py#litellm.secret_managers.main -->
<!-- blueprint:relation from=litellm/proxy/hooks to=litellm/litellm_core_utils kind=crosscuts evidence=litellm/litellm_core_utils/custom_logger_registry.py#litellm.proxy.hooks.dynamic_rate_limiter -->
<!-- blueprint:relation from=litellm/proxy/hooks to=litellm/proxy/management_endpoints kind=crosscuts evidence=litellm/proxy/management_endpoints/key_management_endpoints.py#litellm.proxy.hooks -->
<!-- blueprint:relation from=litellm/proxy/hooks to=litellm/integrations kind=uses evidence=litellm/proxy/hooks/proxy_track_cost_callback.py#litellm.integrations.custom_logger -->
<!-- blueprint:relation from=litellm/proxy/hooks to=litellm/proxy/auth kind=uses evidence=litellm/proxy/hooks/proxy_track_cost_callback.py#litellm.proxy.auth.auth_checks -->
<!-- blueprint:relation from=litellm/proxy/hooks to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/hooks/max_budget_per_session_limiter.py#litellm.proxy.common_utils.proxy_rate_limit_error -->
<!-- blueprint:relation from=litellm/proxy/hooks to=litellm/proxy/db kind=uses evidence=litellm/proxy/hooks/proxy_track_cost_callback.py#litellm.proxy.db.db_spend_update_writer -->
<!-- blueprint:relation from=litellm/proxy/hooks to=litellm/proxy/spend_tracking kind=uses evidence=litellm/proxy/hooks/proxy_track_cost_callback.py#litellm.proxy.spend_tracking.spend_counter_batch -->
<!-- blueprint:relation from=litellm/proxy/lens to=litellm/proxy kind=uses evidence=litellm/proxy/lens/adapter.py#litellm.proxy._types -->
<!-- blueprint:relation from=litellm/proxy/lens to=litellm/proxy/auth kind=uses evidence=litellm/proxy/lens/adapter.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/lens to=litellm/tracing kind=uses evidence=litellm/proxy/lens/adapter.py#litellm.tracing.remote -->
<!-- blueprint:relation from=litellm/proxy/list_api to=litellm/proxy/management_endpoints kind=crosscuts evidence=litellm/proxy/management_endpoints/management_v1/teams.py#litellm.proxy.list_api -->
<!-- blueprint:relation from=litellm/proxy/list_api to=litellm/proxy kind=uses evidence=litellm/proxy/list_api/list_framework.py#litellm.proxy._types -->
<!-- blueprint:relation from=litellm/proxy/list_api to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/list_api/common.py#litellm.proxy.common_utils.validation_error_body -->
<!-- blueprint:relation from=litellm/proxy/list_api to=litellm/types kind=uses evidence=litellm/proxy/list_api/list_framework.py#litellm.types.proxy.management_endpoints.management_v1 -->
<!-- blueprint:relation from=litellm/proxy/management to=litellm/proxy/auth kind=uses evidence=litellm/proxy/management/users/endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/management to=litellm/proxy/list_api kind=uses evidence=litellm/proxy/management/users/exceptions.py#litellm.proxy.list_api.common -->
<!-- blueprint:relation from=litellm/proxy/management to=litellm/proxy/management_endpoints kind=uses evidence=litellm/proxy/management/users/endpoints.py#litellm.proxy.management_endpoints.management_v1.common -->
<!-- blueprint:relation from=litellm/proxy/management_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/management_endpoints/key_management_endpoints.py#litellm.proxy.auth.auth_checks -->
<!-- blueprint:relation from=litellm/proxy/management_endpoints to=litellm/proxy/management kind=uses evidence=litellm/proxy/management_endpoints/auto_router_endpoints.py#litellm.proxy.management.teams.authz -->
<!-- blueprint:relation from=litellm/proxy/management_endpoints to=litellm/proxy/management_helpers kind=uses evidence=litellm/proxy/management_endpoints/access_group_endpoints.py#litellm.proxy.management_helpers.access_group_team_sync -->
<!-- blueprint:relation from=litellm/proxy/management_endpoints to=litellm/proxy/policy_engine kind=uses evidence=litellm/proxy/management_endpoints/policy_endpoints/endpoints.py#litellm.proxy.policy_engine -->
<!-- blueprint:relation from=litellm/proxy/management_endpoints to=litellm/proxy/roi_calculator kind=uses evidence=litellm/proxy/management_endpoints/roi_calculator_endpoints.py#litellm.proxy.roi_calculator.analytics -->
<!-- blueprint:relation from=litellm/proxy/management_helpers to=litellm/proxy/hooks kind=crosscuts evidence=litellm/proxy/hooks/user_management_event_hooks.py#litellm.proxy.management_helpers.audit_logs -->
<!-- blueprint:relation from=litellm/proxy/management_helpers to=litellm/proxy/auth kind=uses evidence=litellm/proxy/management_helpers/team_roster_sync.py#litellm.proxy.auth.auth_checks -->
<!-- blueprint:relation from=litellm/proxy/management_helpers to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/management_helpers/team_roster_sync.py#litellm.proxy.common_utils.auth_cache_invalidation_pubsub -->
<!-- blueprint:relation from=litellm/proxy/management_helpers to=litellm/proxy/management kind=uses evidence=litellm/proxy/management_helpers/bulk_team_member_budgets.py#litellm.proxy.management.teams.authz -->
<!-- blueprint:relation from=litellm/proxy/management_helpers to=litellm/proxy/management_endpoints kind=uses evidence=litellm/proxy/management_helpers/bulk_team_member_budgets.py#litellm.proxy.management_endpoints.common_utils -->
<!-- blueprint:relation from=litellm/proxy/management_helpers to=litellm/repositories kind=uses evidence=litellm/proxy/management_helpers/access_group_key_sync.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/proxy/mcp_server to=litellm/proxy/agent_endpoints kind=crosscuts evidence=litellm/proxy/agent_endpoints/auth/agent_permission_handler.py#litellm.proxy.mcp_server -->
<!-- blueprint:relation from=litellm/proxy/mcp_server to=litellm/proxy/management_endpoints kind=crosscuts evidence=litellm/proxy/management_endpoints/mcp_management_endpoints.py#litellm.proxy.mcp_server -->
<!-- blueprint:relation from=litellm/proxy/mcp_server to=litellm/mcp_client kind=uses evidence=litellm/proxy/mcp_server/upstream.py#litellm.mcp_client.client -->
<!-- blueprint:relation from=litellm/proxy/mcp_server to=litellm/proxy/auth kind=uses evidence=litellm/proxy/mcp_server/rest_endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/mcp_server to=litellm/repositories kind=uses evidence=litellm/proxy/mcp_server/db.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/proxy/middleware to=litellm/caching kind=uses evidence=litellm/proxy/middleware/redis_request_batch_middleware.py#litellm.caching.redis_batch -->
<!-- blueprint:relation from=litellm/proxy/middleware to=litellm/proxy kind=uses evidence=litellm/proxy/middleware/per_request_root_path_middleware.py#litellm.proxy.utils -->
<!-- blueprint:relation from=litellm/proxy/middleware to=litellm/proxy/auth kind=uses evidence=litellm/proxy/middleware/prometheus_auth_middleware.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/openai_files_endpoints to=litellm/llms kind=uses evidence=litellm/proxy/openai_files_endpoints/files_endpoints.py#litellm.llms.base_llm.files.litellm_db_storage_backend -->
<!-- blueprint:relation from=litellm/proxy/openai_files_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/openai_files_endpoints/common_utils.py#litellm.proxy.auth.auth_checks -->
<!-- blueprint:relation from=litellm/proxy/openai_files_endpoints to=litellm/proxy/batches_endpoints kind=uses evidence=litellm/proxy/openai_files_endpoints/files_endpoints.py#litellm.proxy.batches_endpoints.litellm_executed_batches -->
<!-- blueprint:relation from=litellm/proxy/openai_files_endpoints to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/openai_files_endpoints/common_utils.py#litellm.proxy.common_utils.http_parsing_utils -->
<!-- blueprint:relation from=litellm/proxy/openai_files_endpoints to=litellm/repositories kind=uses evidence=litellm/proxy/openai_files_endpoints/common_utils.py#litellm.repositories.managed_file_repository -->
<!-- blueprint:relation from=litellm/proxy/pass_through_endpoints to=litellm/integrations kind=uses evidence=litellm/proxy/pass_through_endpoints/llm_passthrough_endpoints.py#litellm.integrations.custom_guardrail -->
<!-- blueprint:relation from=litellm/proxy/pass_through_endpoints to=litellm/llms kind=uses evidence=litellm/proxy/pass_through_endpoints/codex_passthrough_endpoints.py#litellm.llms.chatgpt.common_utils -->
<!-- blueprint:relation from=litellm/proxy/pass_through_endpoints to=litellm/passthrough kind=uses evidence=litellm/proxy/pass_through_endpoints/llm_passthrough_endpoints.py#litellm.passthrough.main -->
<!-- blueprint:relation from=litellm/proxy/pass_through_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/pass_through_endpoints/codex_passthrough_endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/pass_through_endpoints to=litellm/secret_managers kind=uses evidence=litellm/proxy/pass_through_endpoints/passthrough_endpoint_router.py#litellm.secret_managers.main -->
<!-- blueprint:relation from=litellm/proxy/policy_engine to=litellm/integrations kind=uses evidence=litellm/proxy/policy_engine/pipeline_executor.py#litellm.integrations.custom_guardrail -->
<!-- blueprint:relation from=litellm/proxy/policy_engine to=litellm/proxy/auth kind=uses evidence=litellm/proxy/policy_engine/policy_endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/policy_engine to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/policy_engine/pipeline_executor.py#litellm.proxy.common_utils.callback_utils -->
<!-- blueprint:relation from=litellm/proxy/policy_engine to=litellm/proxy/guardrails kind=uses evidence=litellm/proxy/policy_engine/pipeline_executor.py#litellm.proxy.guardrails.guardrail_hooks.unified_guardrail.unified_guardrail -->
<!-- blueprint:relation from=litellm/proxy/policy_engine to=litellm/repositories kind=uses evidence=litellm/proxy/policy_engine/policy_registry.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/proxy/policy_engine to=litellm/types kind=uses evidence=litellm/proxy/policy_engine/attachment_registry.py#litellm.types.proxy.policy_engine -->
<!-- blueprint:relation from=litellm/proxy/prompts to=litellm/integrations kind=uses evidence=litellm/proxy/prompts/prompt_registry.py#litellm.integrations.custom_prompt_management -->
<!-- blueprint:relation from=litellm/proxy/prompts to=litellm/proxy/auth kind=uses evidence=litellm/proxy/prompts/prompt_endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/prompts to=litellm/repositories kind=uses evidence=litellm/proxy/prompts/prompt_endpoints.py#PromptRepository -->
<!-- blueprint:relation from=litellm/proxy/prompts to=litellm/types kind=uses evidence=litellm/proxy/prompts/prompt_registry.py#litellm.types.prompts.init_prompts -->
<!-- blueprint:relation from=litellm/proxy/public_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/public_endpoints/public_v1/model_hub.py#litellm.proxy.auth -->
<!-- blueprint:relation from=litellm/proxy/public_endpoints to=litellm/proxy/db kind=uses evidence=litellm/proxy/public_endpoints/public_endpoints.py#litellm.proxy.db.health_check_latest -->
<!-- blueprint:relation from=litellm/proxy/public_endpoints to=litellm/proxy/list_api kind=uses evidence=litellm/proxy/public_endpoints/public_v1/model_hub.py#litellm.proxy.list_api -->
<!-- blueprint:relation from=litellm/proxy/public_endpoints to=litellm/router_strategy kind=uses evidence=litellm/proxy/public_endpoints/public_endpoints.py#litellm.router_strategy.complexity_router.fuse_presets -->
<!-- blueprint:relation from=litellm/proxy/rag_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/rag_endpoints/endpoints.py#litellm.proxy.auth.auth_utils -->
<!-- blueprint:relation from=litellm/proxy/rag_endpoints to=litellm/proxy/openai_files_endpoints kind=uses evidence=litellm/proxy/rag_endpoints/endpoints.py#litellm.proxy.openai_files_endpoints.common_utils -->
<!-- blueprint:relation from=litellm/proxy/rag_endpoints to=litellm/proxy/vector_store_endpoints kind=uses evidence=litellm/proxy/rag_endpoints/endpoints.py#litellm.proxy.vector_store_endpoints.endpoints -->
<!-- blueprint:relation from=litellm/proxy/rag_endpoints to=litellm/rag kind=uses evidence=litellm/proxy/rag_endpoints/endpoints.py#litellm.rag.main -->
<!-- blueprint:relation from=litellm/proxy/response_polling to=litellm/caching kind=uses evidence=litellm/proxy/response_polling/polling_handler.py#litellm.caching.redis_cache -->
<!-- blueprint:relation from=litellm/proxy/response_polling to=litellm/proxy kind=uses evidence=litellm/proxy/response_polling/background_streaming.py#litellm.proxy.common_request_processing -->
<!-- blueprint:relation from=litellm/proxy/response_polling to=litellm/proxy/auth kind=uses evidence=litellm/proxy/response_polling/background_streaming.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/response_polling to=litellm/types kind=uses evidence=litellm/proxy/response_polling/polling_handler.py#litellm.types.llms.openai -->
<!-- blueprint:relation from=litellm/proxy/roi_calculator to=litellm/llms kind=uses evidence=litellm/proxy/roi_calculator/github.py#litellm.llms.custom_httpx.http_handler -->
<!-- blueprint:relation from=litellm/proxy/roi_calculator to=litellm/proxy/auth kind=uses evidence=litellm/proxy/roi_calculator/settings.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/roi_calculator to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/roi_calculator/settings.py#litellm.proxy.common_utils.encrypt_decrypt_utils -->
<!-- blueprint:relation from=litellm/proxy/roi_calculator to=litellm/repositories kind=uses evidence=litellm/proxy/roi_calculator/settings.py#litellm.repositories.config_repository -->
<!-- blueprint:relation from=litellm/proxy/roi_calculator to=litellm/types kind=uses evidence=litellm/proxy/roi_calculator/analytics.py#litellm.types.roi_calculator -->
<!-- blueprint:relation from=litellm/proxy/search_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/search_endpoints/endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/search_endpoints to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/search_endpoints/search_tool_registry.py#litellm.proxy.common_utils.encrypt_decrypt_utils -->
<!-- blueprint:relation from=litellm/proxy/search_endpoints to=litellm/repositories kind=uses evidence=litellm/proxy/search_endpoints/search_tool_registry.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/proxy/search_endpoints to=litellm/types kind=uses evidence=litellm/proxy/search_endpoints/search_tool_registry.py#litellm.types.search -->
<!-- blueprint:relation from=litellm/proxy/shutdown to=litellm kind=uses evidence=litellm/proxy/shutdown/scheduled_jobs.py#litellm.constants -->
<!-- blueprint:relation from=litellm/proxy/shutdown to=litellm/proxy/middleware kind=uses evidence=litellm/proxy/shutdown/graceful_shutdown_manager.py#litellm.proxy.middleware.in_flight_requests_middleware -->
<!-- blueprint:relation from=litellm/proxy/spend_tracking to=litellm/proxy/management_endpoints kind=crosscuts evidence=litellm/proxy/management_endpoints/management_v1/spend_logs.py#litellm.proxy.spend_tracking -->
<!-- blueprint:relation from=litellm/proxy/spend_tracking to=litellm/caching kind=uses evidence=litellm/proxy/spend_tracking/spend_counter_batch.py#litellm.caching.redis_batch -->
<!-- blueprint:relation from=litellm/proxy/spend_tracking to=litellm/proxy/auth kind=uses evidence=litellm/proxy/spend_tracking/spend_management_endpoints.py#litellm.proxy.auth -->
<!-- blueprint:relation from=litellm/proxy/spend_tracking to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/spend_tracking/spend_counter_batch.py#litellm.proxy.common_utils.user_api_key_cache -->
<!-- blueprint:relation from=litellm/proxy/spend_tracking to=litellm/proxy/db kind=uses evidence=litellm/proxy/spend_tracking/key_metadata_recovery.py#litellm.proxy.db.db_span -->
<!-- blueprint:relation from=litellm/proxy/spend_tracking to=litellm/repositories kind=uses evidence=litellm/proxy/spend_tracking/spend_management_endpoints.py#litellm.repositories -->
<!-- blueprint:relation from=litellm/proxy/telemetry to=litellm/proxy/auth kind=uses evidence=litellm/proxy/telemetry/endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/telemetry to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/telemetry/runtime.py#litellm.proxy.common_utils.encrypt_decrypt_utils -->
<!-- blueprint:relation from=litellm/proxy/telemetry to=litellm/proxy/middleware kind=uses evidence=litellm/proxy/telemetry/middleware.py#litellm.proxy.middleware.billable_request_metrics_middleware -->
<!-- blueprint:relation from=litellm/proxy/telemetry to=litellm/telemetry kind=uses evidence=litellm/proxy/telemetry/store.py#litellm.telemetry.consent -->
<!-- blueprint:relation from=litellm/proxy/telemetry to=litellm/types kind=uses evidence=litellm/proxy/telemetry/runtime.py#litellm.types.llms.custom_http -->
<!-- blueprint:relation from=litellm/proxy/ui_crud_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/ui_crud_endpoints/latest_release_endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/ui_crud_endpoints to=litellm/proxy/config_resolvers kind=uses evidence=litellm/proxy/ui_crud_endpoints/proxy_setting_endpoints.py#litellm.proxy.config_resolvers -->
<!-- blueprint:relation from=litellm/proxy/ui_crud_endpoints to=litellm/proxy/management_endpoints kind=uses evidence=litellm/proxy/ui_crud_endpoints/proxy_setting_endpoints.py#litellm.proxy.management_endpoints.team_admin_field_permissions -->
<!-- blueprint:relation from=litellm/proxy/ui_crud_endpoints to=litellm/repositories kind=uses evidence=litellm/proxy/ui_crud_endpoints/proxy_setting_endpoints.py#litellm.repositories.config_repository -->
<!-- blueprint:relation from=litellm/proxy/vector_store_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/vector_store_endpoints/endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/vector_store_endpoints to=litellm/proxy/mcp_server kind=uses evidence=litellm/proxy/vector_store_endpoints/utils.py#litellm.proxy.mcp_server.ui_session_utils -->
<!-- blueprint:relation from=litellm/proxy/vector_store_endpoints to=litellm/repositories kind=uses evidence=litellm/proxy/vector_store_endpoints/management_endpoints.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/proxy/vector_store_endpoints to=litellm/vector_stores kind=uses evidence=litellm/proxy/vector_store_endpoints/endpoints.py#litellm.vector_stores.utils -->
<!-- blueprint:relation from=litellm/proxy/video_endpoints to=litellm/proxy kind=uses evidence=litellm/proxy/video_endpoints/endpoints.py#litellm.proxy.image_endpoints.endpoints -->
<!-- blueprint:relation from=litellm/proxy/video_endpoints to=litellm/proxy/auth kind=uses evidence=litellm/proxy/video_endpoints/endpoints.py#litellm.proxy.auth.user_api_key_auth -->
<!-- blueprint:relation from=litellm/proxy/video_endpoints to=litellm/proxy/common_utils kind=uses evidence=litellm/proxy/video_endpoints/endpoints.py#litellm.proxy.common_utils.http_parsing_utils -->
<!-- blueprint:relation from=litellm/proxy/video_endpoints to=litellm/types kind=uses evidence=litellm/proxy/video_endpoints/endpoints.py#litellm.types.videos.utils -->
<!-- blueprint:relation from=litellm/rag to=litellm/llms kind=uses evidence=litellm/rag/ingestion/base_ingestion.py#litellm.llms.custom_httpx.http_handler -->
<!-- blueprint:relation from=litellm/rag to=litellm/types kind=uses evidence=litellm/rag/ingestion/base_ingestion.py#litellm.types.rag -->
<!-- blueprint:relation from=litellm/rag to=litellm/vector_store_files kind=uses evidence=litellm/rag/ingestion/openai_ingestion.py#litellm.vector_store_files.main -->
<!-- blueprint:relation from=litellm/rag to=litellm/vector_stores kind=uses evidence=litellm/rag/ingestion/openai_ingestion.py#litellm.vector_stores.main -->
<!-- blueprint:relation from=litellm/repositories to=litellm/litellm_core_utils kind=uses evidence=litellm/repositories/base_repository.py#litellm.litellm_core_utils.core_helpers -->
<!-- blueprint:relation from=litellm/repositories to=litellm/models kind=uses evidence=litellm/repositories/autorouter_session_repository.py#litellm.models.autorouter_session -->
<!-- blueprint:relation from=litellm/repositories to=litellm/proxy/common_utils kind=uses evidence=litellm/repositories/credentials_repository.py#litellm.proxy.common_utils.config_sync_pubsub -->
<!-- blueprint:relation from=litellm/repositories to=litellm/proxy/db kind=uses evidence=litellm/repositories/daily_activity_repository.py#litellm.proxy.db.db_span -->
<!-- blueprint:relation from=litellm/repositories to=litellm/types kind=uses evidence=litellm/repositories/daily_activity_repository.py#litellm.types.repositories.daily_activity -->
<!-- blueprint:relation from=litellm/responses to=litellm/completion_extras kind=uses evidence=litellm/responses/main.py#litellm.completion_extras.litellm_responses_transformation.transformation -->
<!-- blueprint:relation from=litellm/responses to=litellm/litellm_core_utils kind=uses evidence=litellm/responses/bridge_check.py#litellm.litellm_core_utils.get_llm_provider_logic -->
<!-- blueprint:relation from=litellm/responses to=litellm/llms kind=uses evidence=litellm/responses/bridge_check.py#litellm.llms.azure_ai.chat.transformation -->
<!-- blueprint:relation from=litellm/responses to=litellm/rust_bridge kind=uses evidence=litellm/responses/dispatch.py#litellm.rust_bridge -->
<!-- blueprint:relation from=litellm/responses to=litellm/types kind=uses evidence=litellm/responses/additional_tools.py#litellm.types.llms.base -->
<!-- blueprint:relation from=litellm/router_strategy to=litellm/caching kind=uses evidence=litellm/router_strategy/base_routing_strategy.py#litellm.caching.caching -->
<!-- blueprint:relation from=litellm/router_strategy to=litellm/litellm_core_utils kind=uses evidence=litellm/router_strategy/adaptive_router/adaptive_router.py#litellm.litellm_core_utils.prompt_templates.common_utils -->
<!-- blueprint:relation from=litellm/router_strategy to=litellm/repositories kind=uses evidence=litellm/router_strategy/adaptive_router/adaptive_router.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/router_strategy to=litellm/router_utils kind=uses evidence=litellm/router_strategy/budget_limiter.py#litellm.router_utils.batch_utils -->
<!-- blueprint:relation from=litellm/router_strategy to=litellm/types kind=uses evidence=litellm/router_strategy/adaptive_router/adaptive_router.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm/router_utils to=litellm/caching kind=uses evidence=litellm/router_utils/cooldown_cache.py#litellm.caching.caching -->
<!-- blueprint:relation from=litellm/router_utils to=litellm/litellm_core_utils kind=uses evidence=litellm/router_utils/add_retry_fallback_headers.py#litellm.litellm_core_utils.hidden_params -->
<!-- blueprint:relation from=litellm/router_utils to=litellm/responses kind=uses evidence=litellm/router_utils/pre_call_checks/deployment_affinity_check.py#litellm.responses.utils -->
<!-- blueprint:relation from=litellm/router_utils to=litellm/router_strategy kind=uses evidence=litellm/router_utils/auto_router_model_naming.py#litellm.router_strategy.complexity_router.config -->
<!-- blueprint:relation from=litellm/router_utils to=litellm/types kind=uses evidence=litellm/router_utils/access_windows.py#litellm.types.router -->
<!-- blueprint:relation from=litellm/rust_bridge to=litellm/litellm_core_utils kind=uses evidence=litellm/rust_bridge/chat_completions/detectors.py#litellm.litellm_core_utils.get_llm_provider_logic -->
<!-- blueprint:relation from=litellm/rust_bridge to=litellm/llms kind=uses evidence=litellm/rust_bridge/host/callbacks_legacy_python.py#litellm.llms.anthropic.messages.native.streaming_iterator -->
<!-- blueprint:relation from=litellm/rust_bridge to=litellm/responses kind=uses evidence=litellm/rust_bridge/detectors.py#litellm.responses.mcp.litellm_proxy_mcp_handler -->
<!-- blueprint:relation from=litellm/rust_bridge to=litellm/secret_managers kind=uses evidence=litellm/rust_bridge/host/secret_manager.py#litellm.secret_managers.main -->
<!-- blueprint:relation from=litellm/rust_bridge to=litellm/types kind=uses evidence=litellm/rust_bridge/detectors.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm/sandbox to=litellm/harness kind=uses evidence=litellm/sandbox/__init__.py#litellm.harness.sandbox -->
<!-- blueprint:relation from=litellm/sandbox to=litellm/llms kind=uses evidence=litellm/sandbox/main.py#litellm.llms.base_llm.sandbox.transformation -->
<!-- blueprint:relation from=litellm/sandbox to=litellm/secret_managers kind=uses evidence=litellm/sandbox/sandbox_tools.py#litellm.secret_managers.main -->
<!-- blueprint:relation from=litellm/sandbox to=litellm/types kind=uses evidence=litellm/sandbox/main.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm/search to=litellm/litellm_core_utils kind=uses evidence=litellm/search/cost_calculator.py#litellm.litellm_core_utils.get_model_cost_map -->
<!-- blueprint:relation from=litellm/search to=litellm/llms kind=uses evidence=litellm/search/main.py#litellm.llms.base_llm.search.transformation -->
<!-- blueprint:relation from=litellm/search to=litellm/types kind=uses evidence=litellm/search/main.py#litellm.types.utils -->
<!-- blueprint:relation from=litellm/secret_managers to=litellm/proxy kind=crosscuts evidence=litellm/proxy/proxy_server.py#litellm.secret_managers.main -->
<!-- blueprint:relation from=litellm/secret_managers to=litellm/caching kind=uses evidence=litellm/secret_managers/cyberark_secret_manager.py#litellm.caching -->
<!-- blueprint:relation from=litellm/secret_managers to=litellm/integrations kind=uses evidence=litellm/secret_managers/custom_secret_manager_loader.py#litellm.integrations.custom_secret_manager -->
<!-- blueprint:relation from=litellm/secret_managers to=litellm/litellm_core_utils kind=uses evidence=litellm/secret_managers/aws_secret_manager_v2.py#litellm.litellm_core_utils.aws_partition -->
<!-- blueprint:relation from=litellm/secret_managers to=litellm/types kind=uses evidence=litellm/secret_managers/aws_secret_manager.py#litellm.types.secret_managers.main -->
<!-- blueprint:relation from=litellm/tracing to=litellm/integrations kind=uses evidence=litellm/tracing/exporter.py#litellm.integrations.custom_logger -->
<!-- blueprint:relation from=litellm/tracing to=litellm/llms kind=uses evidence=litellm/tracing/remote.py#litellm.llms.custom_httpx.http_handler -->
<!-- blueprint:relation from=litellm/tracing to=litellm/rust_bridge kind=uses evidence=litellm/tracing/otlp_http.py#litellm.rust_bridge.loader -->
<!-- blueprint:relation from=litellm/tracing to=litellm/types kind=uses evidence=litellm/tracing/types.py#litellm.types.llms.base -->
<!-- blueprint:relation from=litellm/types to=litellm/litellm_core_utils kind=uses evidence=litellm/types/router.py#litellm.litellm_core_utils.completion_timeout -->
<!-- blueprint:relation from=litellm/types to=litellm/models kind=uses evidence=litellm/types/proxy/auth/user_api_key_auth.py#litellm.models.object_permission -->
<!-- blueprint:relation from=litellm/types to=litellm/proxy/common_utils kind=uses evidence=litellm/types/proxy/management_endpoints/team_endpoints.py#litellm.proxy.common_utils.timezone_utils -->
<!-- blueprint:relation from=litellm/vector_store_files to=litellm/litellm_core_utils kind=uses evidence=litellm/vector_store_files/main.py#litellm.litellm_core_utils.litellm_logging -->
<!-- blueprint:relation from=litellm/vector_store_files to=litellm/llms kind=uses evidence=litellm/vector_store_files/main.py#litellm.llms.custom_httpx.llm_http_handler -->
<!-- blueprint:relation from=litellm/vector_store_files to=litellm/types kind=uses evidence=litellm/vector_store_files/main.py#litellm.types.router -->
<!-- blueprint:relation from=litellm/vector_store_files to=litellm/vector_stores kind=uses evidence=litellm/vector_store_files/main.py#litellm.vector_store_registry -->
<!-- blueprint:relation from=litellm/vector_stores to=litellm/litellm_core_utils kind=uses evidence=litellm/vector_stores/main.py#litellm.litellm_core_utils.get_llm_provider_logic -->
<!-- blueprint:relation from=litellm/vector_stores to=litellm/llms kind=uses evidence=litellm/vector_stores/main.py#litellm.llms.custom_httpx.llm_http_handler -->
<!-- blueprint:relation from=litellm/vector_stores to=litellm/repositories kind=uses evidence=litellm/vector_stores/vector_store_registry.py#litellm.repositories.table_repositories -->
<!-- blueprint:relation from=litellm/vector_stores to=litellm/types kind=uses evidence=litellm/vector_stores/main.py#litellm.types.vector_stores -->
<!-- blueprint:relation from=litellm/videos to=litellm/litellm_core_utils kind=uses evidence=litellm/videos/main.py#litellm.litellm_core_utils.get_llm_provider_logic -->
<!-- blueprint:relation from=litellm/videos to=litellm/llms kind=uses evidence=litellm/videos/main.py#litellm.llms.base_llm.videos.transformation -->
<!-- blueprint:relation from=litellm/videos to=litellm/types kind=uses evidence=litellm/videos/main.py#litellm.types.router -->
<!-- blueprint:relation from=litellm_cli to=litellm kind=uses evidence=litellm_cli/main.py#litellm._process_defaults -->
<!-- blueprint:relation from=litellm_cli to=litellm/proxy/client kind=uses evidence=litellm_cli/main.py#litellm.proxy.client.cli.main -->
<!-- blueprint:relation from=migrations to=litellm-proxy-extras/litellm_proxy_extras kind=uses evidence=migrations/run.py#litellm_proxy_extras.utils -->
<!-- blueprint:relation from=migrations to=litellm/proxy/db kind=uses evidence=migrations/run.py#litellm.proxy.db.db_url_settings -->
<!-- blueprint:relation from=packaging to=litellm_cli kind=uses evidence=packaging/homebrew/lite.rb#install_symlink -->
<!-- blueprint:relation from=packaging/litellm-core to=litellm-rust kind=uses evidence=packaging/litellm-core/pyproject.toml#litellm-rust/crates/python-bridge/Cargo.toml -->
<!-- blueprint:relation from=packaging/litellm-core to=litellm/rust_bridge kind=uses evidence=packaging/litellm-core/pyproject.toml#litellm.rust_bridge._native -->
<!-- blueprint:relation from=scripts to=litellm/proxy kind=uses evidence=scripts/check_openapi_docs.py#litellm.proxy.proxy_server -->
<!-- blueprint:relation from=scripts to=litellm/proxy/mcp_server kind=uses evidence=scripts/check_mcp_sdk_install.py#litellm.proxy.mcp_server.server -->
<!-- blueprint:relation from=scripts to=litellm/rust_bridge kind=uses evidence=scripts/seed_tracing_fixtures.py#litellm.rust_bridge.clickhouse -->
<!-- blueprint:relation from=scripts to=litellm/tracing kind=uses evidence=scripts/seed_tracing_fixtures.py#RemoteTraceStore -->
<!-- blueprint:relation from=scripts to=packaging/litellm-core kind=uses evidence=scripts/build_core_distribution.py#packaging/litellm-core/pyproject.toml -->
<!-- blueprint:relation from=terraform/litellm to=litellm/proxy/auth kind=uses evidence=terraform/litellm/aws/ecs.tf#rds_iam_token.py -->
<!-- blueprint:relation from=terraform/litellm to=litellm/proxy/db kind=uses evidence=terraform/litellm/aws/ecs.tf#DATABASE_HOST -->
<!-- blueprint:relation from=terraform/litellm to=migrations kind=uses evidence=terraform/litellm/aws/migrations.tf#migrations/Dockerfile -->
<!-- blueprint:relation from=terraform/provider to=litellm/proxy kind=uses evidence=terraform/provider/tools/dump_openapi.py#litellm.proxy.proxy_server -->
<!-- blueprint:relation from=terraform/provider to=litellm/proxy/management_endpoints kind=uses evidence=terraform/provider/litellm/client.go#/key/generate -->
<!-- blueprint:relation from=tests to=litellm-rust kind=uses evidence=tests/rust-python-harness/shared/unit_runners/rust_runner.py#litellm-rust -->
<!-- blueprint:relation from=tests to=litellm/llms kind=uses evidence=tests/unit/llms/base_llm/chat/test_attribution_headers.py#litellm.llms.base_llm.chat.transformation -->
<!-- blueprint:relation from=tests to=litellm/proxy/auth kind=uses evidence=tests/unit/test_utils.py#litellm.proxy.auth.model_checks -->
<!-- blueprint:relation from=tests to=litellm/proxy/db kind=uses evidence=tests/unit/proxy/db/test_token_auth.py#litellm.proxy.db.token_auth -->
<!-- blueprint:relation from=tests to=litellm/rust_bridge kind=uses evidence=tests/test_litellm_rust/support/routing.py#litellm.rust_bridge -->
<!-- blueprint:relation from=tests to=litellm/types kind=uses evidence=tests/unit/test_aembedding_session_reuse_e2e.py#litellm.types.utils -->
<!-- blueprint:relation from=ui to=litellm/proxy kind=uses evidence=ui/litellm-dashboard/scripts/gen-api-types.mjs#litellm.proxy.proxy_server -->
<!-- blueprint:relation from=ui to=litellm/proxy/auth kind=uses evidence=ui/litellm-dashboard/src/utils/modelPermissions.ts#route_checks.py -->
<!-- blueprint:relation from=ui to=litellm/proxy/management_endpoints kind=uses evidence=ui/litellm-dashboard/src/components/networking.tsx#/key/generate -->
<!-- blueprint:relation from=ui to=litellm/proxy/spend_tracking kind=uses evidence=ui/litellm-dashboard/src/components/networking.tsx#/spend/logs/ui -->
<!-- blueprint:relation from=vscode-extension to=litellm/proxy kind=uses evidence=vscode-extension/src/gateway.ts#model_group/info -->
