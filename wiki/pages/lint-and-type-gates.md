---
title: Lint and type gates
type: component
sources: [S010, S011, S012, S013]
updated: 2026-09-26
---

`make check` (formerly `make pre-commit`) runs `scripts/pre_commit_lint.sh` to predict CI lint for the branch (S010). The script scopes itself: staged files are the scope; nothing staged means the working tree's diff against the merge base with origin's current default branch, resolved via `scripts/default_branch.py --base` (S010).

## Scope

`make check` runs only blocks whose files are in scope, each mapped to a CI job (S010). `litellm/**.py` triggers `make lint`; `tests/e2e/**.py` triggers `make lint-e2e-basedpyright` plus the raw HTTP client ban; `tests/**.py` (with `ruff-tests.toml` and the test-quality inputs) triggers ruff-tests.toml plus `make lint-test-quality`; `ui/litellm-dashboard/**` triggers prettier, eslint, and the lint budgets; `litellm/proxy/**` plus `litellm/types/**` plus gen-api files trigger the `npm run gen:api` snapshot drift check.

## The three budget gates

`make lint` invokes three Python gates plus the test-quality gate. Each counts violations across the `litellm` tree, compares against a committed budget, and blames the branch only when its count is over the limit and higher than the base.

`scripts/ruff_strict_gate.py` runs `ruff check litellm --config ruff-strict.toml --output-format json`, groups by rule code, fails when `head[rule] > budget[rule].limit` and `head[rule] > base[rule]` (S011). Rules not in the budget are ignored; `--update` ratchets limits down by the count the branch fixed.

`scripts/type_discipline_gate.py` runs `scripts/check_type_discipline.py` over `litellm/` and parses `LIT\d+` lines (S012). Same shape. Rules absent from the base budget are seeded on this branch and left untouched by `--update`.

`scripts/type_check_gate.py` runs `basedpyright --outputjson` and counts diagnostics per rule (S013). Rules absent from the budget fall back to `DEFAULT_LIMIT = 10`. Vacuous runs are refused so a crashed pass cannot clear the gate.

## Slots and the log file

`make check` and the budget gates each hold one of two machine-wide slots via `scripts/gate_slot_lock.py`, exporting `LITELLM_GATE_SLOT_HELD` so children skip re-acquisition (S010, S011, S012, S013). Concurrent runs print "all N machine-wide slots are busy; queueing" and wait. Do not set `LITELLM_GATE_SLOTS=0` to bypass the limit.

The wrapper writes its full output to `.git/pre_commit_lint.log` (overwriting the previous run) and prints that path as the first and last output line; inspect it after a run rather than re-executing the multi-minute checks (S010).

## LIT rule cheat sheet

The four budget files hold the per-rule limits in a structured form (see [CI budgets](./ci-budgets.md)). Several rules are frozen at limit 0 (S012, S015): LIT005, LIT007, LIT009, LIT013; suppression-without-reason, TypeGuard/TypeIs, inert `# type: ignore`, suppression-of-nothing. LIT010 (no `: Final`) and LIT011 (parameter rebind / in-place mutate) were seeded at 1.5x the count left after the Final sweep; new code cannot cross that line. Any suppression the rule permits must name the exact token inside brackets — `# noqa: TID251` or `# pyright: ignore[reportArgumentType]` — and carry a reason. The broader rationale for the ratchet (do not edit budgets on a PR branch) lives in [Lint, type, and test budgets](./lint-type-test-budgets.md).

## Related

- [Lint, type, and test budgets](./lint-type-test-budgets.md): broader decision
- [CI budgets](./ci-budgets.md): the four budget files and their workflows
- [Repo dev loop](./dev-loop.md): running gates during iteration
- [Test conventions](./test-conventions.md): the test-quality rules this gate extends