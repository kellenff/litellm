# Implementation Plan: Add Git Hooks using pre-commit

**Branch**: `002-add-git-hooks-precommit` | **Date**: 2026-09-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-add-git-hooks-precommit/spec.md`

## Summary

Add the `pre-commit` framework (pre-commit.com) as the runner for the Git `pre-commit` hook stage, configured via a new `.pre-commit-config.yaml`. Reconcile with the existing hook infrastructure (`.githooks/commit-msg` for Conventional Commits and `.githooks/pre-push` for Conventional Branches) by adding a `.githooks/pre-commit` wrapper script that delegates to the `pre-commit` framework. Extend `scripts/install_git_hooks.sh` so the documented `make install-hooks` flow detects a missing `pre-commit` binary and prints a single-line install hint (FR-007), remains idempotent (FR-002), and confirms wiring (FR-008). The chosen hook set is the fast subset of CI's `make check` rule set (FR-005): formatter check, linter, and the standard text-file hygiene hooks (trailing whitespace, end-of-file fixer, check-yaml, check-toml, detect-private-key). Slower checks (full basedpyright, full test suite) remain a manual `make check` invocation, matching the existing repo note in `install_git_hooks.sh` that says the CI-equivalent lint is deliberately not auto-firing.

Bypass visibility (FR-006 / SC-005) is NOT a `pre-commit` framework hook: a hook registered in `.pre-commit-config.yaml` would be skipped along with the rest of the framework when the user runs `git commit --no-verify`. Instead, the existing `.githooks/commit-msg` shell script is extended with a sentinel-file mechanism: the wrapper writes `.git/.pre-commit-ran` when it successfully invokes the framework, and the commit-msg hook appends a `Skipped-Hooks: pre-commit` trailer when the sentinel is absent. This makes every `--no-verify` commit identifiable to reviewers without depending on framework internals.

## Technical Context

- **Language/Version**: YAML for `.pre-commit-config.yaml`; Bash for the wrapper script. No new language runtime required.
- **Primary Dependencies**: `pre-commit` (Python package, from pre-commit.com) — must be available on the developer's machine and in CI; pin a minimum version in `pyproject.toml` under a `[dependency-groups]` dev group so `uv sync` installs it.
- **Storage**: N/A (tooling feature; no data persistence).
- **Testing**: Manual + scripted (`scripts/test_pre_commit.sh`): run `git commit` against a known-bad staged file and a known-clean staged file, assert block and pass respectively. CI runs the same check in a workflow step.
- **Target Platform**: Linux + macOS developer workstations; existing Git 2.x; existing `core.hooksPath = .githooks` flow.
- **Project Type**: tooling / build-system (single new config file + one wrapper hook script + edit to install script + edit to `pyproject.toml`).
- **Performance Goals**: pre-commit phase completes in under 60 seconds on a developer laptop for a typical commit touching ≤ 50 staged files.
- **Constraints**: Must not regress existing `.githooks/commit-msg` or `.githooks/pre-push`. Hook set MUST be a strict subset of CI's `make check` rule set (FR-005). Install script MUST detect missing `pre-commit` binary and surface a single-line install hint (FR-007). Install script MUST remain idempotent (FR-002 / SC-004).
- **Scale/Scope**: 1 config file, 1 wrapper script, 2 edits (`pyproject.toml`, `install_git_hooks.sh`), 1 README addendum, 1 verification script. No new package, no new CLI.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Type Discipline | Pass | YAML config is structurally typed by the `pre-commit` framework's schema. No new runtime types introduced. |
| II. Immutability by Default | Pass | Config and wrapper script are written once and not mutated; idempotent install re-asserts the same state. |
| III. Test Quality Coverage | Pass | Verification script asserts hook blocks bad commits and passes clean ones (regression for FR-003, FR-004). No vendor facts pinned. |
| IV. Compositional Simplicity | Pass | Reuses `pre-commit` framework instead of inventing hook orchestration. Reuses existing `core.hooksPath` + `.githooks/` pattern. Reuses existing `make install-hooks` + `install_git_hooks.sh`. No new abstraction layers. |
| V. Honest Communication | Pass | README documents install + bypass with `--no-verify`; no AI-slop comments; no customer names referenced. |
| Technology Stack | Pass | `pre-commit` is added under a dev dependency group; mirrors the project's existing `uv`-based dev workflow. SHA-256 / version pinning applies only if a binary is downloaded, which this plan does not require (the package is installed from PyPI through existing tooling). |
| Development Workflow | Pass | New contributor: `make install-hooks` → `pre-commit install` runs automatically inside the script. CI stays `make check`. The pre-commit framework's `pre-commit run --all-files` is optional. |
| Governance | Pass | No lint budgets, type budgets, or migration scripts are touched. |

No constitution violations; no Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/002-add-git-hooks-precommit/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── contracts/           # Phase 1 output
    └── pre-commit-config.md
```

### Source Code (repository root)

```text
# New and edited files for this feature
.pre-commit-config.yaml              # NEW   — pre-commit framework hook config
.githooks/pre-commit                 # NEW   — wrapper that delegates to `pre-commit run`; writes .git/.pre-commit-ran sentinel
.githooks/commit-msg                 # EDIT  — append Skipped-Hooks: pre-commit trailer when sentinel is absent
scripts/install_git_hooks.sh         # EDIT  — detect `pre-commit` binary, print hint if missing
pyproject.toml                       # EDIT  — add pre-commit to a dev dependency group
scripts/test_pre_commit.sh           # NEW   — verification script (manual + CI); asserts CI parity
scripts/check_hook_ci_parity.py      # NEW   — diff .pre-commit-config.yaml IDs against CI's `make check` rule set (FR-005 enforcement)
README.md                            # EDIT  — one paragraph documenting the new hook stage
```

**Structure Decision**: Single-project repository; new files live at the repo root and under `scripts/`, matching the existing convention. No new packages, no new modules, no new directories beyond `.githooks/pre-commit` (already exists as a directory).

## Complexity Tracking

No constitution violations to justify.
