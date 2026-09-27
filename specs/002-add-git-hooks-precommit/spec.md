# Feature Specification: Add Git Hooks using pre-commit

**Feature Branch**: `002-add-git-hooks-precommit`
**Created**: 2026-09-27
**Status**: Draft
**Input**: User description: "add git hooks using pre-commit"

## User Scenarios & Testing

### User Story 1 - Automatic local quality gates on commit (Priority: P1)

A contributor clones the repository, installs the local hooks once with the project's documented setup command, then proceeds to commit changes normally. The same checks that gate `main` (linting, type checks, secret scanning, formatting) run automatically on staged files before the commit is accepted, catching regressions locally instead of after push.

**Why this priority**: This is the core value of the feature. Every other story depends on hooks actually firing on commit. Without this, no other hook benefit matters.

**Independent Test**: Stage a file that violates a configured hook (e.g., contains a hardcoded secret or a formatting error). Attempt `git commit`. The commit is rejected with a clear, actionable message pointing to the failing hook. The developer runs the fix command, re-stages, and the commit succeeds.

**Acceptance Scenarios**:
1. **Given** hooks are installed and a staged file violates a configured hook, **When** the developer runs `git commit`, **Then** the commit is blocked, the offending file is named, and a one-line fix instruction is shown.
2. **Given** hooks are installed and all staged files pass every configured hook, **When** the developer runs `git commit`, **Then** the commit proceeds and a `git log` entry confirms it was created.
3. **Given** hooks are installed and the developer does not have a required tool (e.g., `pre-commit` binary) available, **When** `git commit` is attempted, **Then** the failure is reported with the missing tool name and a one-line install hint, not a stack trace.

### User Story 2 - One-command hook install (Priority: P2)

A new contributor (or an existing one on a fresh checkout) gets the local hooks set up with a single documented command from the project root, with no manual editing of `.git/hooks/`. Existing contributors can confirm their environment is wired up by running the same command in idempotent mode.

**Why this priority**: The feature only delivers value if every contributor can install the hooks reliably. A separate one-shot install story keeps the commit-time story (P1) from being blocked on documentation or bootstrap friction.

**Independent Test**: On a clean clone, run the install command. Confirm `.git/hooks/pre-commit` exists, is executable, and that subsequent `git commit` invocations route through the pre-commit framework. Running the install command a second time does not error and does not duplicate hook entries.

**Acceptance Scenarios**:
1. **Given** a fresh clone with no previously installed hooks, **When** the contributor runs the documented install command, **Then** the pre-commit framework is wired into the local repo and a confirmation line is printed.
2. **Given** hooks are already installed, **When** the same install command is run again, **Then** the command exits successfully and the existing hook configuration is preserved (idempotent).
3. **Given** the install command is run from a directory that is not the repo root, **When** the command executes, **Then** it fails with a clear message indicating the repo root must be the current directory.

### User Story 3 - Bypass path for genuine emergencies (Priority: P3)

A developer with a justified reason to skip a failing hook (e.g., reverting a known regression on a Friday afternoon) can bypass it using a documented escape hatch, and the bypass is visible in the resulting commit so reviewers can flag it.

**Why this priority**: This is a safety valve, not the happy path. It must exist so that broken hooks never block critical fixes, but it should never be the default flow.

**Independent Test**: Stage a file that fails a hook. Run `git commit --no-verify`. The commit succeeds. A reviewer inspecting the commit message or local log can detect that hooks were skipped for that commit.

**Acceptance Scenarios**:
1. **Given** a staged file fails a hook, **When** the developer runs `git commit --no-verify -m "<message>"`, **Then** the commit is created and a clearly visible `SKIPPED-HOOKS` marker is present in the developer-facing commit metadata or message.
2. **Given** a commit was created with `--no-verify`, **When** a reviewer inspects the commit, **Then** they can identify from commit metadata (or a documented convention) that hook checks were skipped.

## Edge Cases

- **Partial install / broken pre-commit binary**: The install command must detect a missing or non-functional `pre-commit` binary and surface a single-line install hint rather than silently writing a hook that will fail on every commit.
- **Hooks take a long time**: A single failing hook should not leave the developer waiting through every other configured hook. The framework should report failures fast (fail-fast per file) and let the developer re-run only the affected hook after fixing.
- **Stale hook definitions after config changes**: When `.pre-commit-config.yaml` is updated (added/removed/renamed hooks), the next commit must run against the updated config, not a cached version, without requiring a manual refresh step.
- **Newly added file types**: A new file extension added in a commit should be checked by the relevant hook on that same commit, not only on subsequent commits.
- **Merge commits and rebases**: The hook must behave consistently for normal commits, merge commits, and during rebase-driven history rewrites. Skipping hooks during a rebase must follow the same explicit `--no-verify` convention.
- **CI vs local divergence**: The hooks installed locally must enforce the same rules CI enforces, so a green local commit does not fail on push. Any deliberate CI-only rule must be documented as such.
- **Bypass visibility under `--no-verify`**: When a contributor bypasses the framework with `git commit --no-verify`, the framework itself is skipped, so any hook registered in `.pre-commit-config.yaml` will not run. The bypass-trailer mechanism MUST therefore live OUTSIDE the framework (in the existing shell-based `.githooks/commit-msg` hook), so that bypass commits still receive the `Skipped-Hooks:` trailer.

## Requirements

### Functional Requirements

- **FR-001**: The repository MUST contain a `.pre-commit-config.yaml` at the root declaring every hook that runs on `pre-commit`.
- **FR-002**: A contributor MUST be able to install all configured hooks with a single documented command, and that command MUST be idempotent on repeat execution.
- **FR-003**: Every `git commit` on a contributor machine with hooks installed MUST run the configured `pre-commit` hooks against the staged changes before the commit is accepted.
- **FR-004**: If any hook fails, the commit MUST be blocked and the failure output MUST name the failing hook and the offending file.
- **FR-005**: The set of hooks configured locally MUST be a subset of (or equal to) the set of checks CI runs on pull requests, so a green local commit cannot fail CI on the same check.
- **FR-006**: A documented `git commit --no-verify` escape hatch MUST exist, and any commit created with that flag MUST be detectable as hook-skipped from commit metadata or a documented message convention.
- **FR-007**: Hook installation MUST detect a missing `pre-commit` binary and fail with a single-line install instruction rather than writing a broken hook.
- **FR-008**: The hook configuration and install instructions MUST be documented in `README.md` (or a linked setup doc) so a new contributor can get hooks running without reading the source.

### Key Entities

- **Pre-commit configuration**: A versioned YAML file at the repo root that lists each hook (id, language/version, files it applies to, arguments). Acts as the single source of truth for which checks run on commit.
- **Hook**: A single named check (e.g., a formatter, a linter, a secret scanner) declared in the configuration and executed by the pre-commit framework on staged files.
- **Install command**: A project-documented shell command (e.g., `make install-hooks`, `pre-commit install`) that a contributor runs once per clone to wire the framework into the local repo.

## Success Criteria

- **SC-001**: A new contributor can go from a fresh clone to a hook-blocked commit being rejected in under 5 minutes, with no manual editing of files under `.git/`.
- **SC-002**: 100% of `git commit` invocations on a hook-enabled machine route through the configured pre-commit framework (verifiable by adding a hook that always fails and confirming every commit is blocked).
- **SC-003**: A commit that passes all local hooks is not subsequently failed by CI for the same set of checks (zero divergence between local and CI rule sets for the checks declared in `.pre-commit-config.yaml`).
- **SC-004**: The documented install command succeeds on first run and on every subsequent run without producing duplicate hook entries or warnings (idempotent in 100% of cases).
- **SC-005**: A commit made with `--no-verify` is identifiable as hook-skipped by a reviewer inspecting the commit, using either commit metadata or a documented message convention.

## Assumptions

- The project uses `pre-commit` (the well-known framework by pre-commit.com) as the hook runner, since the user explicitly named it.
- The project already runs a defined set of quality checks (lint, type check, format, secrets) via `make check` or equivalent; these are the same checks the hooks will run locally.
- The repository is a normal Git working tree (not a shallow clone with restricted hook installation) and contributors have permission to write into `.git/hooks/`.
- The set of hooks on `pre-commit` is intentionally a strict subset of CI, not a superset, so the rules a contributor sees locally match what reviewers see on the PR.
- Python is the primary language in this repo, so hook tooling (formatters, linters, type checkers) targets Python sources by default; non-Python hooks (e.g., shell, yaml) are added only if they apply to files actually in the repo.
- The project tolerates the additional commit-time latency of running configured hooks, and will keep the hook set lean enough that a typical commit completes the hook phase in well under a minute on a developer laptop.
