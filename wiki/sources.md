# Source Registry

Append-only IDs (S001, S002…). Dedup key: normalized path or URL.
Sources are immutable inputs: the wiki never edits them.

| ID | Source | Type | First ingested | Last ingested | Pages touched |
|----|--------|------|----------------|---------------|---------------|
| S001 | `https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f` | url | 2026-09-26 | 2026-09-26 | llm-wiki-pattern.md |
| S002 | `.specify/extensions/wiki/wiki-config.yml` | file | 2026-09-26 | 2026-09-26 | wiki-pipeline.md |
| S003 | `.specify/extensions/wiki/extension.yml` | file | 2026-09-26 | 2026-09-26 | speckit-extension-wiki.md, wiki-pipeline.md |
| S004 | `.specify/extensions/wiki/README.md` | file | 2026-09-26 | 2026-09-26 | speckit-extension-wiki.md, wiki-pipeline.md |
| S005 | `.specify/extensions/wiki/CHANGELOG.md` | file | 2026-09-26 | 2026-09-26 | wiki-pipeline.md |
| S006 | `.specify/extensions/wiki/commands/` | directory | 2026-09-26 | 2026-09-26 | wiki-pipeline.md |
| S007 | `AGENTS.md` | file | 2026-09-26 | 2026-09-26 | dev-loop.md, lint-type-test-budgets.md, pr-and-issues.md, pricing-source-of-truth.md, prisma-migration-rule.md, test-conventions.md, test-mirroring.md |
| S010 | `scripts/pre_commit_lint.sh` | file | 2026-09-26 | 2026-09-26 | lint-and-type-gates.md |
| S011 | `scripts/ruff_strict_gate.py` | file | 2026-09-26 | 2026-09-26 | ci-budgets.md, lint-and-type-gates.md |
| S012 | `scripts/type_discipline_gate.py` | file | 2026-09-26 | 2026-09-26 | ci-budgets.md, lint-and-type-gates.md |
| S013 | `scripts/type_check_gate.py` | file | 2026-09-26 | 2026-09-26 | ci-budgets.md, lint-and-type-gates.md |
| S014 | `.github/workflows/test-linting.yml + ci-coverage.yml + publish-basedpyright-base-counts.yml` | directory | 2026-09-26 | 2026-09-26 | ci-budgets.md |
| S015 | `ruff-strict-budget.json + type-discipline-budget.json + basedpyright-code-budget.json + test-quality-budget.json` | directory | 2026-09-26 | 2026-09-26 | ci-budgets.md, lint-and-type-gates.md |
| S020 | `tests/code_coverage_tests/check_migrations_no_data_rewrites.py` | file | 2026-09-26 | 2026-09-26 | prisma-migration-rule.md |
| S022 | `scripts/default_branch.py` | file | 2026-09-26 | 2026-09-26 | pr-target-branch.md |
| S030 | `litellm/router_strategy/lowest_tpm_rpm.py + lowest_tpm_rpm_v2.py` | file | 2026-09-26 | 2026-09-26 | router-strategies.md, routing-decisions.md |
| S031 | `litellm/router_strategy/lowest_latency.py` | file | 2026-09-26 | 2026-09-26 | router-strategies.md |
| S032 | `litellm/router_strategy/lowest_cost.py` | file | 2026-09-26 | 2026-09-26 | router-strategies.md |
| S033 | `litellm/router_strategy/least_busy.py + simple_shuffle.py + tag_based_routing.py` | file | 2026-09-26 | 2026-09-26 | router-strategies.md, routing-decisions.md |
| S035 | `litellm/router_strategy/budget_limiter.py` | file | 2026-09-26 | 2026-09-26 | router-strategies.md, routing-decisions.md |
| S036 | `litellm/router_strategy/savings_baseline.py` | file | 2026-09-26 | 2026-09-26 | router-strategies.md, routing-decisions.md |
| S037 | `litellm/router_strategy/lar1_routing.py` | file | 2026-09-26 | 2026-09-26 | router-strategies.md |
| S038 | `litellm/router_strategy/adaptive_router/ + auto_router/ + complexity_router/ + quality_router/` | directory | 2026-09-26 | 2026-09-26 | router-strategies.md, routing-decisions.md |
| S039 | `litellm/router_strategy/base_routing_strategy.py + litellm/router_utils/` | file | 2026-09-26 | 2026-09-26 | prompt-template-factory.md, router-strategies.md, routing-decisions.md |
| S040 | `litellm/litellm_core_utils/prompt_templates/factory.py` | file | 2026-09-26 | 2026-09-26 | prompt-template-factory.md |
| S042 | `litellm/proxy/proxy_server.py` | file | 2026-09-26 | 2026-09-26 | proxy-server.md |
| S043 | `litellm/proxy/proxy_cli.py` | file | 2026-09-26 | 2026-09-26 | proxy-dev-config.md, proxy-server.md |
| S044 | `litellm/proxy/dev_config.yaml` | file | 2026-09-26 | 2026-09-26 | proxy-dev-config.md, proxy-server.md |
| S045 | `litellm/proxy/example_config_yaml/` | directory | 2026-09-26 | 2026-09-26 | proxy-dev-config.md |
| S050 | `litellm/litellm_core_utils/litellm_logging.py` | file | 2026-09-26 | 2026-09-26 | spend-logging.md |
| S051 | `litellm/proxy/schema.prisma (LiteLLM_SpendLogs block)` | file | 2026-09-26 | 2026-09-26 | spend-logging.md |
| S052 | `litellm/models/spend_logs.py` | file | 2026-09-26 | 2026-09-26 | spend-logging.md |
| S053 | `litellm/repositories/table_repositories.py` | file | 2026-09-26 | 2026-09-26 | spend-logging.md |
| S054 | `litellm/proxy/db/db_spend_update_writer.py` | file | 2026-09-26 | 2026-09-26 | spend-logging.md |
| S055 | `litellm/proxy/_types.py (spend_logging types + retention knobs)` | file | 2026-09-26 | 2026-09-26 | spend-logging.md |
| S056 | `litellm/proxy/utils.py (ProxyUpdateSpend, monitor tasks)` | file | 2026-09-26 | 2026-09-26 | spend-logging.md |
| S058 | `litellm/types/utils.py (StandardLoggingPayload, status fields, error info)` | file | 2026-09-26 | 2026-09-26 | spend-logging.md |
| S060 | `tests/test_litellm/readme.md` | file | 2026-09-26 | 2026-09-26 | test-conventions.md |
| S061 | `.github/pull_request_template.md` | file | 2026-09-26 | 2026-09-26 | pr-and-issues.md |
| S062 | `.github/ISSUE_TEMPLATE/bug_report.yml` | file | 2026-09-26 | 2026-09-26 | pr-and-issues.md |
| S063 | `.github/ISSUE_TEMPLATE/config.yml` | file | 2026-09-26 | 2026-09-26 | pr-and-issues.md |
| S064 | `.github/ISSUE_TEMPLATE/feature_request.yml` | file | 2026-09-26 | 2026-09-26 | pr-and-issues.md |
