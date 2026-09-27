# Quickstart: Add Git Hooks using pre-commit

**Feature**: `002-add-git-hooks-precommit`
**Date**: 2026-09-27

End-to-end validation guide. Follows the spec's User Stories in order.

## Prerequisites

- Git 2.x
- Python with `uv` (the project's existing dev installer). If you don't use `uv`, substitute `pipx install pre-commit` in the install step.
- A clean working tree (no uncommitted changes that should not be touched).

## 1. Install (User Story 2 — P2)

```sh
make install-dev    # pulls in pre-commit via the dev dependency group
make install-hooks  # wires the .githooks/ directory into core.hooksPath and verifies pre-commit is installed
```

Expected output ends with:

```
✓ Git hooks installed.
  core.hooksPath = .githooks
  active hooks:  commit-msg pre-commit pre-push
  pre-commit:    <version>
```

Re-run `make install-hooks`. It MUST exit 0 with no warnings (SC-004).

**Failure path (FR-007)**: if `pre-commit` is not on `PATH`, the script MUST exit non-zero with a one-line install hint, e.g.:

```
install_git_hooks: pre-commit not found on PATH
Install with: uv sync  (or: pipx install pre-commit)
```

Run `uv sync` (or `pipx install pre-commit`) and re-run `make install-hooks`.

## 2. Confirm a hook blocks a bad commit (User Story 1 — P1)

```sh
# Create a file with trailing whitespace (violates trailing-whitespace hook)
printf 'hello world   \n' > /tmp/bad-trailing.txt
git add /tmp/bad-trailing.txt
git commit -m "feat: should be blocked by pre-commit"
```

Expected: the commit is rejected. Output names `trailing-whitespace` and the offending file:

```
trailing-whitespace.......................................................Failed
- hook id: trailing-whitespace
- exit code: 1
- files were modified by this hook
```

The fix:

```sh
# Re-stage after the hook auto-fixes (trailing-whitespace rewrites the file)
git add -u /tmp/bad-trailing.txt
git commit -m "feat: trailing whitespace gone"
```

Expected: commit succeeds.

## 3. Confirm a secret is blocked (User Story 1 — P1)

```sh
cat > /tmp/bad-secret.py <<'EOF'
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
EOF
git add /tmp/bad-secret.py
git commit -m "feat: this should never land"
```

Expected: `detect-private-key` hook fails, the file path and the matched key prefix are named in the error output. Remove the file (`rm /tmp/bad-secret.py`) and try again.

## 4. Confirm the bypass path is visible (User Story 3 — P3, FR-006, SC-005)

```sh
# Stage anything (clean or not; --no-verify skips the framework hooks)
git commit --no-verify -m "feat: emergency fix that needs to bypass hooks"
git log -1 --format="%B" | grep '^Skipped-Hooks:'
```

Expected: the trailer line `Skipped-Hooks: pre-commit` appears in the commit message.

## 5. Confirm CI parity (FR-005, SC-003)

After installing hooks locally, run the same checks CI would:

```sh
make check
```

If `make check` is green locally, CI MUST be green for the same set of checks. If a check fails locally that doesn't fail in CI, the `.pre-commit-config.yaml` has drifted from CI and MUST be reconciled before the PR can merge.

## 6. Confirm Conventional Commits + Conventional Branches still fire

The pre-commit framework does NOT replace the existing shell hooks:

```sh
# Conventional Commits violation (uppercase description) — commit-msg should reject
git commit -m "feat: Wrong case" --allow-empty
```

Expected: `.githooks/commit-msg` rejects with the Conventional Commits error, even if pre-commit's hooks were already bypassed. This confirms the two layers coexist (SC-003 implicit).

## Done

If all six steps above behave as described, the feature is installed and verified. No additional setup is needed for new clones — `make install-hooks` is the single documented entry point.
