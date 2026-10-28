---
title: CI budgets and gating workflows
type: reference
sources: [S014, S015]
updated: 2026-09-26
---

The repo enforces a ratchet: each budget file's limits can only ever decrease, and the gates fail any PR that pushes a rule past its limit (S014). Four budgets feed three Python gates and one CI workflow (S014, S015).

## The four budget files (S015)

Each file is `{rule: {"limit": N}}`. Limit N is the codebase ceiling.

`ruff-strict-budget.json` caps ruff rules outside the default `make lint` set. ANN\* (annotations), ASYNC230, and B\* appear at write time (S011, S015). New rules are added deliberately, never on `--update` (S011).

`type-discipline-budget.json` covers LIT001 through LIT014. LIT005, LIT007, LIT009, and LIT013 are frozen at limit 0 (S012, S015).

`basedpyright-code-budget.json` caps basedpyright diagnostics per rule (`reportAny`, `reportGeneralTypeIssues`, etc.). Rules absent fall back to `DEFAULT_LIMIT = 10` (S013, S015).

`test-quality-budget.json` covers TQ001 through TQ009 (TQ008 absent): zero-assert tests, `sys.path.insert`, raw env writes, `litellm` global mutation, credential-gated skips, conftest snapshot inventory (S014, S015).

## `test-linting.yml` (S014)

PRs targeting `main` or `litellm_**`. The `lint` job times out at 15 minutes. A `detect-changes` action decides which steps to run; the job fetches the merge-base via `gh api repos/{owner}/{repo}/compare/...` and exports it as `GATE_BASE_SHA`, so diff-based gates share one base.

Steps: ruff format check, MCP operation boundary, ruff (`ruff.toml` for `litellm/`, `ruff-tests.toml` for `tests/`), the three Python budget gates, tests/e2e basedpyright, Claude code e2e tests, circular import test, `from litellm import *` safety, plus a `secret-scan` job (`test_no_hardcoded_secrets.py`, ggshield) (S014).

## `publish-basedpyright-base-counts.yml` (S014)

Triggered on every push to `main` and on `workflow_dispatch`. Runs `python scripts/type_check_gate.py --emit-counts-dir "$RUNNER_TEMP/basedpyright-counts"` and uploads the JSON as artifact `basedpyright-counts-<key>.json`. The name is keyed on the merge-base commit plus fingerprints (`pyrightconfig.json`, `uv.lock`, Prisma schema, dep group set), so different package sets never share a count. On cache miss, the gate first tries to download the merge-base artifact via `gh api`; any fetch failure falls back to a local basedpyright pass, so the gate is never worse than local compute alone (S013, S014).

## The ratchet automation (S014)

A separate `budget-ratchet` job in `test-linting.yml` runs `python scripts/budget_ratchet_check.py --base "$BASE_SHA"` and is intentionally NON-GATING. It turns red when any `*-budget.json` ceiling is raised or a budget is dropped, so loosening is obvious in review; it stays OUT of branch-protection required-checks so a justified bump still merges once a human accepts the red (S014).

`--update` on each gate ratchets the limit down by what this branch fixed; limits only ever fall (S011, S012, S013).

## `ci-coverage.yml` (S014)

PRs targeting `main` or `litellm_**` and pushes to `main`. Asserts every test file is invoked by a Dockerfile and no `-k` expression deselects a file whose job globs it; also runs `assert_workflow_dir_hygiene.py`.

## The hard rule

Never edit the four budget files on a PR branch, and never run `make lint-budget-update` there (S014, S015). A scheduled Devin automation lowers the limits on the default branch by exactly what landed since the last ratchet, so concurrent PRs do not fight over the same `"limit"` lines. If your branch already carries a budget edit, drop it before opening the PR.

The workflow (`S014`) enforces that limits only ever decrease; the JSON shape files (`S015`) do not encode direction. CI enforces the direction: the `budget-ratchet` job turns red on any raise but stays non-gating, so a justified bump can still ship once a human accepts red.

## Related

- [Lint and type gates](./lint-and-type-gates.md): the three Python budget gates
- [Lint, type, and test budgets](./lint-type-test-budgets.md): the broader decision framing the ratchet
- [PRs and issues](./pr-and-issues.md): PR body rules and the branch-prefix rule
- [Repo dev loop](./dev-loop.md): what `make check` runs locally