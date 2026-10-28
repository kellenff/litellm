---
title: Lint, type, and test budgets
type: decision
sources: [S007]
updated: 2026-09-26
---

Four budget files are ratcheted down automatically on the default branch by a scheduled Devin automation and **must never be edited or committed on a PR branch** (S007):

- `ruff-strict-budget.json`
- `type-discipline-budget.json`
- `basedpyright-code-budget.json`
- `test-quality-budget.json`

Do not run `make lint-budget-update` on a PR branch. The automation lowers the limits on `main` by exactly what landed since the last ratchet, so concurrent PRs do not fight over the same `"limit"` lines (S007). Keep the automation's target in sync when the default branch changes.

Drop any budget edit before opening the PR.

Top-level rules referenced by the gates (S007):

- `LIT001`, `LIT002` (mutability); refactor toward immutable data; tuples, frozen dataclasses (with `slots=True`), `MappingProxyType`, `frozenset()`; comprehensions over seed-then-mutate. `# mutable-ok` is a last resort with a stated reason.
- `LIT009` (`# type: ignore`); banned. Every suppression must name the exact rule inside brackets and carry a reason, e.g. `# pyright: ignore[reportArgumentType]  # stubs lack async overload`.
- `LIT010..LIT012` (typed-dict mutability); annotate `Final`, qualify every TypedDict field with `ReadOnly[...]`.
- `LIT014` (comprehensions); at most one `for` and one `if` clause; split stacked clauses into a helper generator.

The default branch must be resolved with `python3 scripts/default_branch.py --branch`, never from a cached `origin/HEAD`.

Related: [Lint and type gates](./lint-and-type-gates.md), [CI budgets](./ci-budgets.md), [Repo dev loop](./dev-loop.md).
