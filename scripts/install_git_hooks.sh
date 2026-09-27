#!/usr/bin/env bash
#
# Install the repo's git hooks by pointing core.hooksPath at .githooks.
#
# Idempotent: re-running just reaffirms the config and refreshes chmod bits.
# Run from anywhere inside the repo.

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "install_git_hooks: not inside a git working tree" >&2
    exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
hooks_dir="$repo_root/.githooks"

if [ ! -d "$hooks_dir" ]; then
    echo "install_git_hooks: $hooks_dir does not exist" >&2
    exit 1
fi

# Ensure the hook scripts are executable. New clones on case-preserving
# filesystems sometimes lose the exec bit; this normalizes it.
chmod +x "$hooks_dir"/* 2>/dev/null || true

# FR-007: detect missing pre-commit binary BEFORE any git config write so a
# failed detection leaves core.hooksPath untouched.
if ! command -v pre-commit >/dev/null 2>&1; then
    echo "install_git_hooks: pre-commit not found on PATH" >&2
    echo "Install with: uv sync  (or: pipx install pre-commit, or: pip install pre-commit)" >&2
    exit 1
fi

# T021: clear stale hook cache so .pre-commit-config.yaml changes take effect
# on the next commit without a manual refresh step.
pre-commit clean >/dev/null 2>&1 || true

git config core.hooksPath .githooks

cat <<EOF
✓ Git hooks installed.
  core.hooksPath = .githooks
  active hooks:  $(ls "$hooks_dir" | tr '\n' ' ')
  pre-commit framework: $(pre-commit --version)

These hooks enforce Conventional Commits and Conventional Branches.
Bypass with --no-verify when you need to (e.g. for emergency hotfixes).

The CI-equivalent lint is deliberately not installed as an auto-firing hook
(it can take minutes); run it on demand with 'make check' before committing.

To uninstall:  git config --unset core.hooksPath
EOF
