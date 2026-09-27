# Contract: `.pre-commit-config.yaml`

**Feature**: `002-add-git-hooks-precommit`
**Date**: 2026-09-27

This document defines the contract between the `pre-commit` framework and the repository. The actual file is `.pre-commit-config.yaml`; this contract is the human-readable specification the file must conform to.

## Schema (semantic)

```yaml
# Minimal version of the format consumed by pre-commit 3.5+.
# Top-level keys:
#   repos:        list of hook sources (upstream or local)
#   default_install_hook_types: optional, defaults to [pre-commit]
#   default_stages:              optional, defaults to [pre-commit]
#
# Repo entry keys:
#   repo:   upstream URL or "local"
#   rev:    git tag or SHA (upstream only; required for reproducibility)
#   hooks:  list of hook definitions
#
# Hook keys (subset most relevant here):
#   id:     unique identifier within the config
#   name:   human-readable display name
#   stages: list of stages to run this hook at; defaults to [pre-commit]
#   files:  regex of files this hook applies to
#   args:   list of CLI args passed to the hook entry
#   entry:  (local hooks only) command to invoke
#   language: (local hooks only) "system" or "python"
```

## Required hook set (FR-005, SC-003)

The `.pre-commit-config.yaml` MUST declare, at minimum, these hooks at the `pre-commit` stage:

| `id` | `repo` | `rev` (pinned) | `stages` | Purpose |
|---|---|---|---|---|
| `trailing-whitespace` | `https://github.com/pre-commit/pre-commit-hooks` | `v6.0.0` (or newer) | `[pre-commit]` | Strip trailing whitespace |
| `end-of-file-fixer` | `https://github.com/pre-commit/pre-commit-hooks` | same `rev` as above | `[pre-commit]` | Ensure files end with a newline |
| `check-yaml` | `https://github.com/pre-commit/pre-commit-hooks` | same `rev` | `[pre-commit]` | Validate YAML syntax |
| `check-toml` | `https://github.com/pre-commit/pre-commit-hooks` | same `rev` | `[pre-commit]` | Validate TOML syntax |
| `check-added-large-files` | `https://github.com/pre-commit/pre-commit-hooks` | same `rev` | `[pre-commit]` | Block files > 500 KB |
| `detect-private-key` | `https://github.com/pre-commit/pre-commit-hooks` | same `rev` | `[pre-commit]` | Block accidental secret commits |
| `ruff` | `https://github.com/astral-sh/ruff-pre-commit` | `v0.15.22` (latest pre-commit tag matching the project's ruff 0.15.x pin) | `[pre-commit]` | Lint with `--fix` |
| `ruff-format` | `https://github.com/astral-sh/ruff-pre-commit` | same `rev` as `ruff` | `[pre-commit]` | Format check (matches CI) |

## Bypass trailer (FR-006 / SC-005)

The `--no-verify` bypass MUST be detectable by reviewers. Detection lives in the existing `.githooks/commit-msg` shell script, NOT in `.pre-commit-config.yaml`: a hook registered in the pre-commit framework never runs when the user invokes `git commit --no-verify`, so any trailer-appender inside `.pre-commit-config.yaml` is dead code on the bypass path.

- **Location**: edit the existing `.githooks/commit-msg` (no new file under `scripts/`).
- **Mechanism**: the wrapper `.githooks/pre-commit` writes a sentinel file (e.g., `.git/.pre-commit-ran`) when it successfully invokes the framework. The `.githooks/commit-msg` script checks for that sentinel; if absent, it appends `Skipped-Hooks: pre-commit` to the commit-msg file in place. If the sentinel is present, the script removes it and exits 0 without modifying the message.
- **Sentinel path**: `.git/.pre-commit-ran` (under the git dir, not tracked, ignored by hook files).
- **Output on bypass**: appends `Skipped-Hooks: pre-commit` as a trailer only if not already present (idempotent).

## Invariants

1. Every `rev` MUST be a concrete tag or full SHA. The strings `latest`, `stable`, `main`, or any branch ref are forbidden.
2. Every `id` MUST be unique across all `repos[].hooks[].id`.
3. The set of hooks at `stages: [pre-commit]` MUST be a strict subset of the checks CI runs (`make check`). Any new hook added here MUST also be added to CI before the PR that introduces it can merge.
4. Local hooks MUST live under `scripts/` and be invoked via `entry: scripts/<file>`.
5. `default_stages` MUST NOT be set to a non-`[pre-commit]` value; this prevents accidental broadening of which stages the framework hooks fire at.

## What this contract does NOT cover

- The wrapper hook script (`.githooks/pre-commit`) — see `data-model.md` Entity 3.
- The install command (`scripts/install_git_hooks.sh`) — see `data-model.md` Entity 4.
- The CI workflow file (`.github/workflows/test-linting.yml` or equivalent) — out of scope; this feature does not edit CI.
