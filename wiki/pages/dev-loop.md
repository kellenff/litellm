---
title: Repo dev loop
type: howto
sources: [S007]
updated: 2026-09-26
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

Related: [Lint, type, and test budgets](./lint-type-test-budgets.md), [PR target branch](./pr-target-branch.md).
