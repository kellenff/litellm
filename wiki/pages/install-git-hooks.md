---
title: Install git hooks
type: howto
sources: [S065]
updated: 2026-09-27
---

End-to-end procedure for wiring the pre-commit framework into a fresh
clone. The documented entry point is `make install-hooks`; the binary
is provided through the existing dev dependency group (S065).

## Standard flow

```bash
make install-dev    # pulls in pre-commit via the dev dependency group
make install-hooks  # wires the .githooks/ directory into core.hooksPath
                    # and verifies pre-commit is installed
```

The expected output ends with:

```text
✓ Git hooks installed.
  core.hooksPath = .githooks
  active hooks:  commit-msg pre-commit pre-push
  pre-commit:    <version>
```

`make install-hooks` is idempotent. Re-running it exits 0 with no
warnings (SC-004); existing `core.hooksPath` is preserved, hook
permissions are re-asserted, and the `pre-commit` version line is
reprinted.

## Failure path: pre-commit binary not on PATH

If `pre-commit` is not on `PATH` when `make install-hooks` runs, the
script exits non-zero with a one-line install hint and does NOT write
`core.hooksPath` (FR-007). The literal output is:

```text
install_git_hooks: pre-commit not found on PATH
Install with: uv sync  (or: pipx install pre-commit)
```

The detection happens before any `git config` write so a failed install
leaves the repo untouched. Pick one of the install paths below, then
re-run `make install-hooks`.

## Install paths

The `pre-commit` binary can be installed any of three ways. Pick the
one that matches how you manage Python tooling in this project:

- **`uv sync`** (preferred): the project uses `uv` for dev dependencies,
  so contributors who already ran `make install-dev` already have
  `pre-commit` on PATH via the dev dependency group. This is the
  default.
- **`pipx install pre-commit`**: for contributors who do not use `uv`
  but want a globally isolated `pre-commit` install.
- **`pip install pre-commit`**: vanilla fallback. Works but the
  binary lives in the active virtualenv, so it disappears when the
  venv is deactivated.

## Verifying the install

After `make install-hooks` exits 0, three checks confirm the wiring:

1. `git config core.hooksPath` prints `.githooks`.
2. `ls -l .githooks/` shows `commit-msg`, `pre-commit`, and `pre-push`
   all executable.
3. `pre-commit validate-config` exits 0 against the repo's
   `.pre-commit-config.yaml`.

## Confirming the bypass path

To verify the bypass trailer is wired (FR-006, SC-005):

```bash
git commit --allow-empty -m "feat: empty test of bypass path" --no-verify
git log -1 --format='%B' | grep '^Skipped-Hooks:'
```

The trailer `Skipped-Hooks: pre-commit` must appear in the commit
message body. If it does not, the sentinel mechanism in
`.githooks/commit-msg` is not wired; re-run `make install-hooks` and
check the output.

## What this does NOT cover

- CI does NOT need `make install-hooks` — CI runs `make check`
  directly, which is the same rule set the local pre-commit framework
  is a subset of. See [CI hook parity gate](./ci-hook-parity-gate.md).
- Adding new hooks to the local pre-commit set is gated on adding
  the same check to CI first. The parity script enforces this.

## Related

- [Pre-commit hook wiring](./pre-commit-hook-wiring.md): what the
  install wires
- [Bypass visibility mechanism](./bypass-visibility-mechanism.md):
  why `--no-verify` produces a visible trailer
- [Repo dev loop](./dev-loop.md): the install is one step in the
  daily verification loop
