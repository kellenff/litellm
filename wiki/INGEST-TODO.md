# Wiki Ingest Backlog

Each item is one `/speckit.wiki.ingest <source>` call. Check the box when the
ingest has run and the resulting page IDs are linked under "Done" below. The
order at the bottom is the recommended execution order; do it in that order
unless a higher one is forced by an in-flight PR.

## Wiki harness files (the pipeline itself)

- [x] `.specify/extensions/wiki/wiki-config.yml` → `wiki-pipeline.md`
- [x] `.specify/extensions/wiki/CHANGELOG.md` → folded into `wiki-pipeline.md`
- [x] `.specify/extensions/wiki/extension.yml` → `speckit-extension-wiki.md`
- [x] `.specify/extensions/wiki/README.md` → folded into `speckit-extension-wiki.md`
- [x] `.specify/extensions/wiki/commands/speckit.wiki.init.md` → folded into `wiki-pipeline.md`
- [x] `.specify/extensions/wiki/commands/speckit.wiki.ingest.md` → folded into `wiki-pipeline.md`
- [x] `.specify/extensions/wiki/commands/speckit.wiki.lint.md` → folded into `wiki-pipeline.md`
- [x] `.specify/extensions/wiki/commands/speckit.wiki.query.md` → folded into `wiki-pipeline.md`
- [x] `.specify/extensions/wiki/commands/speckit.wiki.status.md` → folded into `wiki-pipeline.md`

## Karpathy LLM-Wiki concept (the theory the schema encodes)

- [x] Karpathy's LLM Wiki write-up (https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) → `llm-wiki-pattern.md`

## Litellm-specific starting corpus

- [x] `AGENTS.md` (repo root) → `dev-loop.md`, `test-mirroring.md`, `lint-type-test-budgets.md`, `pricing-source-of-truth.md`
- [x] `litellm/router_strategy/` (and the `litellm/router_utils/` helpers, not the absent README) → `router-strategies.md`, `routing-decisions.md`
- [x] `litellm/proxy/proxy_server.py` + `litellm/proxy/proxy_cli.py` → `proxy-server.md`
- [x] `litellm/litellm_core_utils/litellm_logging.py` (+ the spend-log writers and schema) → `spend-logging.md`
- [x] `litellm/litellm_core_utils/prompt_templates/factory.py` → `prompt-template-factory.md`
- [x] `tests/test_litellm/readme.md` + mapping convention → `test-conventions.md`
- [x] `.github/pull_request_template.md` + `.github/ISSUE_TEMPLATE/*.yml` → `pr-and-issues.md`
- [x] `.github/workflows/test-linting.yml` (replacing the absent `ci.yml`) → `ci-budgets.md`
- [x] `scripts/pre_commit_lint.sh` + the three Python budget gates → `lint-and-type-gates.md`
- [x] `scripts/default_branch.py` → `pr-target-branch.md`
- [x] `tests/code_coverage_tests/check_migrations_no_data_rewrites.py` → `prisma-migration-rule.md`
- [x] `litellm/proxy/example_config_yaml/` + `litellm/proxy/dev_config.yaml` → `proxy-dev-config.md`

## Items deferred or skipped

- [x] `docs/my-website/docs/completion/` → **skipped: source absent.** `git ls-files | grep ^docs/` returns zero paths in this checkout; the website docs live in a separate repo. Replace with `litellm/llms/<provider>/` once providers are first asked about (next item).
- [x] `litellm/llms/<provider>/` → **deferred per the item's own recommended order** ("one at a time, as the first question on each provider comes up"). 139 folders; batch-producing them now would flood lint with speculative pages that no question has called for.
- [x] `litellm/router_utils/README.md` → **skipped: source absent.** Used the real `litellm/router_utils/` directory contents plus `litellm/router_strategy/base_routing_strategy.py` instead, registered as `S039`.
- [x] `.github/workflows/ci.yml` → **skipped: source absent.** Used `.github/workflows/test-linting.yml` (+ `ci-coverage.yml`, `publish-basedpyright-base-counts.yml`) instead, registered as `S014`.

## Working artifacts to re-ingest when they change

These are conditional triggers, not backlog entries:

- [ ] Each new `specs/<feature>/research.md` → ingest on the same PR that lands the feature (status command's rule #4). **`specs/` does not exist in this checkout yet; the first feature to land one will pick this up.**
- [ ] Each new `specs/<feature>/plan.md` decision section → same; decisions get a `decision` page with the rejected alternatives. Holds until `specs/` is populated.
- [ ] Any new top-level lint rule (`LIT013…`) → ingest the diff to `pyproject.toml` + the rule's enforcement file; `lint-and-type-gates.md` gets a one-line update. Triggered by `scripts/type_discipline_gate.py` adding a new `LIT\d+` regex.
- [ ] Any new gate script under `scripts/` → ingest it; one-line row added to the lint-and-type-gates index.
- [ ] Any new provider folder under `litellm/llms/` → one reference page, same template. Watch for first PR that adds a new directory there.
- [ ] Any new entry in `.github/ISSUE_TEMPLATE/` or change to `.github/pull_request_template.md` → re-ingest to update `pr-and-issues.md`.

## Recommended execution order

1. ~~Karpathy LLM-Wiki write-up~~ → done; see `llm-wiki-pattern.md`.
2. ~~`AGENTS.md`~~ → done; the four pages under `Litellm-specific starting corpus` above.
3. ~~`wiki-config.yml` + the five command files~~ → done; see `wiki-pipeline.md` + `speckit-extension-wiki.md`.
4. ~~The four gate scripts + `check_migrations_no_data_rewrites.py`~~ → done; see `lint-and-type-gates.md` + `ci-budgets.md` + `prisma-migration-rule.md`.
5. ~~`router_strategy/` + `prompt_templates/factory.py`~~ → done; see `router-strategies.md` + `routing-decisions.md` + `prompt-template-factory.md`.
6. Provider folders under `litellm/llms/` → first PR that adds a new provider folder, or first question on a provider. Avoid speculative ingestion.
7. ~~`tests/test_litellm/readme.md` mirroring convention~~ → done; see `test-conventions.md`.

## Done

Newest first; one row per ingest run (each run may touch several pages).

- [2026-09-26] S042-S045 → proxy-server.md, proxy-dev-config.md (proxy boot order, dev_config.yaml, example_config_yaml tour)
- [2026-09-26] S060-S064 → test-conventions.md, pr-and-issues.md (test mirroring, PR/issue templates, human-facing writing rules)
- [2026-09-26] S050-S058 → spend-logging.md (StandardLoggingPayload, LiteLLM_SpendLogs schema, write/repo/queue path)
- [2026-09-26] S030-S040 → router-strategies.md, routing-decisions.md, prompt-template-factory.md (router_strategy/, router_utils/, factory.py)
- [2026-09-26] S022 → pr-target-branch.md (default_branch.py)
- [2026-09-26] S020 → prisma-migration-rule.md (check_migrations_no_data_rewrites.py + AGENTS.md Prisma paragraph)
- [2026-09-26] S010-S015 → lint-and-type-gates.md, ci-budgets.md (scripts/pre_commit_lint.sh + three Python gates + four budget JSONs + workflows)
- [2026-09-26] S007 → dev-loop.md, test-mirroring.md, lint-type-test-budgets.md, pricing-source-of-truth.md, prisma-migration-rule.md, pr-and-issues.md, test-conventions.md (AGENTS.md; folded across the seven pages that cite it)
- [2026-09-26] S006 → wiki-pipeline.md (`.specify/extensions/wiki/commands/`, the five command files collectively)
- [2026-09-26] S005 → wiki-pipeline.md (CHANGELOG.md folded into the changelog sub-section)
- [2026-09-26] S004 → speckit-extension-wiki.md (README.md folded into the install paths section)
- [2026-09-26] S003 → speckit-extension-wiki.md (extension.yml: which commands/hooks the extension registers)
- [2026-09-26] S002 → wiki-pipeline.md (wiki-config.yml: caps, auto_fix, the operational summary)
- [2026-09-26] S001 → llm-wiki-pattern.md (Karpathy gist, the pattern the schema encodes)

Skipped / not yet actionable:

- `docs/my-website/docs/completion/` → source absent in this checkout (`git ls-files | grep ^docs/` is empty). First step: confirm where litellm's website docs live; then either point the wiki at that path or accept that this is a separate repo.
- `litellm/llms/<provider>/` → per the recommended order, on-demand per provider rather than batched.
- `specs/<feature>/research.md` etc. → `specs/` does not exist in this checkout yet; the first feature to land one will start the chain.
