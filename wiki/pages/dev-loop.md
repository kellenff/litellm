---
title: Repo dev loop
type: howto
sources: [S007, S065]
updated: 2026-09-27
---

Daily verification loop in this repo (S007).

1. Pull before any work; the checkout may be on a stale branch.
2. Run `make check` (alias for `make pre-commit`). It writes its full output to a managed log file inside `.git` (overwriting previous logs) and prints that path as its first and last line; read that log instead of re-running for a different slice (S007).
3. `make check`, `make lint`, `scripts/pre_commit_lint.sh`, and the standalone budget gates (`scripts/ruff_strict_gate.py`, `scripts/type_discipline_gate.py`, `scripts/type_check_gate.py`) each hold one of two machine-wide slots; when other sessions or worktrees are running heavy work, your command prints `"all N machine-wide slots are busy; queueing"`, then waits. Give it a long timeout; do not kill, retry, or change `LITELLM_GATE_SLOTS` to 0 (S007).

Proof of fix is `curl` against a live proxy on `localhost:4000`, not `pytest` (S007). Start the proxy with:

```bash
python litellm/proxy/proxy_cli.py \
  --config litellm/proxy/dev_config.yaml \
  --detailed_debug --reload --use_v2_migration_resolver \
  2>&1 | tee litellm.log
```

The Admin UI dev server is `npm run dev` in `ui/litellm-dashboard`, served on port 3000. End-to-end tests live in `tests/e2e/` and follow that directory's harness conventions.

Style: Python max line length is **120**, not 88 (S007). Auto-format after every edit per [Programming Preferences](../../AGENTS.md) (oxfmt for `.m?[t,j]sx?`, ruff for `.py`, rustfmt for `.rs`, gofmt for `.go`).

The pre-commit framework runs on every `git commit` and blocks commits that fail the configured hooks; running `make install-hooks` once per fresh clone wires it in alongside the existing Conventional Commits and Conventional Branches shell hooks (S065). See [Install git hooks](./install-git-hooks.md) and [Pre-commit hook wiring](./pre-commit-hook-wiring.md) for the wiring and [Bypass visibility mechanism](./bypass-visibility-mechanism.md) for the `--no-verify` trailer.

Related: [Lint, type, and test budgets](./lint-type-test-budgets.md), [PR target branch](./pr-target-branch.md), [Install git hooks](./install-git-hooks.md), [Pre-commit framework rule set](./pre-commit-framework-rule-set.md).
