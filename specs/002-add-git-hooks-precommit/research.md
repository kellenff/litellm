# Phase 0 Research: Add Git Hooks using pre-commit

**Feature**: `002-add-git-hooks-precommit`
**Date**: 2026-09-27

## Decision: Hook set is the fast subset of CI's `make check`

- **Decision**: Wire the following hooks in `.pre-commit-config.yaml`:
  - `pre-commit-hooks` standard set: `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-toml`, `check-added-large-files`, `detect-private-key`
  - `ruff` repo (`astral-sh/ruff-pre-commit`): `ruff` (lint, `--fix`) and `ruff-format` (format check)
- **Rationale**: CI runs `make check`, which expands to `lint-format-check-changed lint-ruff lint-gate lint-type-discipline lint-test-quality lint-basedpyright lint-e2e-basedpyright check-circular-imports check-import-safety`. Several of those (basedpyright, full test quality, circular import scan) routinely take minutes on a developer laptop and would make every `git commit` feel broken. The chosen set is the subset that runs in seconds and catches the highest-frequency regressions (formatter drift, unused imports, leaked secrets, malformed YAML/TOML). This satisfies FR-005 (subset of CI) and the spec's stated performance assumption ("under 60 seconds").
- **Alternatives considered**:
  - **Full CI mirror on pre-commit**: rejected — minutes-per-commit is unacceptable for the day-to-day inner loop.
  - **Manual-only (no framework)**: rejected — the user explicitly asked for the `pre-commit` framework. A `.githooks/pre-commit` shell script that inlines ruff would also drift from `make check` over time.
  - **`pre-commit` on every stage (pre-commit + pre-push)**: rejected — adding a pre-commit *hook stage* in addition to the existing `.githooks/pre-push` is duplication. Existing `.githooks/pre-push` already enforces Conventional Branches; the framework's `pre-push` would only run the same `pre-commit-config.yaml` again, doubling the work. Stage the new framework hooks at `pre-commit` only.

## Decision: Provision `pre-commit` via the existing dev-dependency group

- **Decision**: Add `pre-commit` to `pyproject.toml` under `[dependency-groups]` (or whatever dev group `make install-dev` activates). Document the install hint in `install_git_hooks.sh` as `uv sync` (matching the project's existing install story) or `pipx install pre-commit` for contributors who don't use `uv`.
- **Rationale**: The project already uses `uv` and a dev-group-based install (`install-dev`). Adding `pre-commit` to the same group means a contributor who already ran `make install-dev` already has the binary. The install hint only fires for the edge case where someone runs `make install-hooks` without first running `make install-dev`, or has a stripped `uv` setup. Pin a minimum version (e.g., `pre-commit>=3.5`) for reproducibility, but do not pin exact — the framework follows semver and forcing a hard pin creates needless churn.
- **Alternatives considered**:
  - **Document-only install (no group entry)**: rejected — a contributor who reads the README and runs `make install-hooks` without the dev group installed would hit the FR-007 failure path. Easier to make the binary appear by default than to chase that failure class.
  - **Brew formula / system package**: rejected — adds a second install path for the same tool and drifts from the project's `uv` workflow.
  - **Pin exact version (e.g., `pre-commit==4.0.1`)**: rejected — semver framework, no known incompatibility with `<4.1`. Pin a floor.

## Decision: `.githooks/pre-commit` wrapper delegates to the framework

- **Decision**: Add `.githooks/pre-commit` (a thin shell wrapper) that calls `pre-commit run --hook-stage pre-commit`. The wrapper exists because `core.hooksPath = .githooks` makes Git look for `.githooks/pre-commit`; without the wrapper, the framework's own `.git/hooks/pre-commit` is bypassed.
- **Rationale**: The framework's `pre-commit install` writes `.git/hooks/pre-commit`, but the project has already set `core.hooksPath = .githooks`, so Git ignores `.git/hooks/`. The wrapper preserves the existing `core.hooksPath` flow and keeps all hook scripts in version control under `.githooks/`. The wrapper is six lines: shebang, `set -eu`, check for the binary, print install hint if missing (FR-007), then `exec pre-commit run --hook-stage pre-commit`.
- **Alternatives considered**:
  - **Replace `core.hooksPath` and let the framework install into `.git/hooks/`**: rejected — the install script would need to remove `core.hooksPath`, but the existing `.githooks/commit-msg` and `.githooks/pre-push` live under that path; switching would break Conventional Commits enforcement.
  - **Call `pre-commit install` from `install_git_hooks.sh`**: rejected — `pre-commit install` writes to `.git/hooks/pre-commit`, which Git ignores here, so it would silently no-op.
  - **Inline ruff directly in `.githooks/pre-commit` (no framework)**: rejected — the user asked for the `pre-commit` framework, and a raw shell wrapper cannot auto-update hook versions or share config with CI.

## Decision: Bypass detection uses a sentinel file + commit-msg hook, not a pre-commit framework hook

- **Decision**: The `.githooks/pre-commit` wrapper writes a sentinel file (`.git/.pre-commit-ran`) when it successfully invokes the framework. The existing `.githooks/commit-msg` script is extended to check for that sentinel; if absent, it appends `Skipped-Hooks: pre-commit` to the commit-msg file in place.
- **Rationale**: A hook registered in `.pre-commit-config.yaml` runs INSIDE the framework. When the user invokes `git commit --no-verify`, the wrapper never runs, so the framework never invokes any of its hooks either — including any `commit-msg` stage hook. Putting the bypass trailer inside the framework is dead code on the bypass path, which would silently break FR-006 / SC-005 / US3. The sentinel mechanism keeps the detection OUTSIDE the framework so it still fires on `--no-verify` commits.
- **Alternatives considered**:
  - **Convention-only (developer writes `[skip-hooks]` in the message)**: rejected — relies on the contributor remembering and following a convention; reviewers can't trust it.
  - **Block `--no-verify` entirely**: rejected — FR-006 mandates a bypass path for emergencies. The bypass exists; it must just be visible.
  - **Git notes**: rejected — adds tooling reviewers don't already use; trailers are universally supported.
  - **`pre-commit` framework `commit-msg` local hook**: rejected — dead on the bypass path, same architectural flaw as the original design.
  - **Reflog inspection**: rejected — reflog is local to the contributor's machine and not always available during scripted commit flows.

## Resolved NEEDS CLARIFICATION

None remain — every choice above has a documented decision and a rejected alternative.
