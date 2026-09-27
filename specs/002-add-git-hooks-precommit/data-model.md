# Data Model: Add Git Hooks using pre-commit

**Feature**: `002-add-git-hooks-precommit`
**Date**: 2026-09-27

This feature is configuration-only; there are no runtime entities in the application. The "entities" below are the declarative artifacts that make up the hook system.

## Entity 1: Pre-commit configuration

- **Path**: `.pre-commit-config.yaml` (repo root)
- **Shape** (YAML):
  - `repos` (list): one entry per upstream or local hook source
    - `repo` (str): upstream repo URL or `local` for inline hooks
    - `rev` (str, upstream only): pinned revision (git tag or commit SHA)
    - `hooks` (list):
      - `id` (str): stable hook identifier used to enable/disable/refresh
      - `name` (str, optional): display name shown in commit output
      - `entry` (str, local hooks only): script path or command
      - `language` (str, local hooks only): `system` for shell, `python` for inline Python
      - `stages` (list, optional): defaults to `[pre-commit]`; explicit `commit-msg` for the bypass trailer
      - `files` / `exclude` (regex): file globs the hook applies to
      - `args` (list, optional): passed to the hook entrypoint
- **Validation rules**:
  - Every `id` MUST be unique across all `repos[].hooks[].id`.
  - Every upstream `rev` MUST be a concrete tag or SHA (never `latest`, per CI supply-chain safety rule).
  - Every `stages` value MUST be one of the framework's documented stages.
- **Lifecycle**: read on every `git commit`; `pre-commit` framework caches resolved hook versions under `.cache/pre-commit/` and refreshes on `pre-commit autoupdate` or `pre-commit clean`.
- **Relationships**: one `pre-commit-config.yaml` is consumed by one or more Git hook wrappers; one wrapper corresponds to one `stages` set.

## Entity 2: Hook

- **Path**: declared inside `.pre-commit-config.yaml`
- **Attributes**:
  - `id` (unique within the config)
  - `name` (human-readable)
  - `stage` (which Git hook stage fires it)
  - `applies_to` (file pattern)
  - `command` (the actual check; for upstream hooks, the upstream repo defines this)
- **Validation rules**:
  - The set of hooks at the `pre-commit` stage MUST be a strict subset of the checks CI runs on pull requests (FR-005).
  - No hook MAY mutate the working tree silently; use `args: [--fix]` only where the fix is deterministic and reviewable.
- **Lifecycle**: invoked on every `git commit`; the framework re-invokes a hook whenever its declared files changed, otherwise reuses the cached result.

## Entity 3: Wrapper hook script + sentinel

- **Path**: `.githooks/pre-commit` (new file in this feature)
- **Shape**: POSIX shell script with shebang `#!/usr/bin/env bash` and `set -eu`
- **Behavior**:
  - On `git commit`, Git invokes this script with no arguments.
  - The script verifies `pre-commit` is on `PATH`; if not, prints a one-line install hint (per FR-007) and exits non-zero.
  - If present, the script writes the sentinel file `.git/.pre-commit-ran` and `exec`s `pre-commit run --hook-stage pre-commit`. The framework takes over from there.
- **Validation rules**:
  - Script MUST be executable (`chmod +x`).
  - Script MUST NOT shadow or remove the existing `.githooks/commit-msg` or `.githooks/pre-push`.
  - The sentinel MUST be written BEFORE the framework `exec` and removed by `.githooks/commit-msg` after a successful check.
- **Sentinel path**: `.git/.pre-commit-ran` (file existence indicates the pre-commit framework ran for this commit; absence indicates `--no-verify` was used or the framework failed before reaching the `pre-commit` stage).

## Entity 3b: Commit-msg hook (extended)

- **Path**: `.githooks/commit-msg` (existing file, edited in this feature)
- **Added behavior**:
  - Before the existing Conventional Commits regex check, check for the sentinel `.git/.pre-commit-ran`.
  - If the sentinel is absent, append `Skipped-Hooks: pre-commit` to the commit-msg file in place (idempotent — skip if already present).
  - If the sentinel is present, `rm` it and proceed with the existing Conventional Commits check.
- **Rationale**: The bypass trailer must be appended OUTSIDE the `pre-commit` framework, because the framework is exactly what `--no-verify` skips. Putting the detection in the existing commit-msg hook guarantees it fires on every commit, including bypass commits.
- **Validation rules**:
  - The trailer append MUST be a no-op if the trailer is already in the message (idempotent across re-runs).
  - The Conventional Commits check MUST still run after the trailer append — bypass does not bypass message conventions.

## Entity 4: Install command

- **Path**: `scripts/install_git_hooks.sh` (existing, edited in this feature)
- **Shape**: bash script invoked by `make install-hooks`
- **Pre-existing behavior** (unchanged): set `core.hooksPath = .githooks`, `chmod +x` all hooks in `.githooks/`
- **New behavior** (this feature):
  - Detect whether `pre-commit` is on `PATH` (`command -v pre-commit`).
  - If absent: print a single-line install hint (`Install with: uv sync  (or: pipx install pre-commit)`) and exit non-zero. Do NOT silently skip.
  - If present: print the framework version alongside the existing "active hooks" line.
- **Validation rules**:
  - Re-running the script MUST NOT duplicate entries or emit warnings (SC-004).
  - Detection MUST happen before any `git config` write so a failed install leaves the repo untouched.
- **Lifecycle**: invoked once per fresh clone and any time the contributor adds a new hook to `.githooks/`.
