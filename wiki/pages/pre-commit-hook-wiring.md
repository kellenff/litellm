---
title: Pre-commit hook wiring
type: component
sources: [S065, S066, S067]
updated: 2026-09-27
---

The pre-commit framework is wired into the existing `core.hooksPath =
.githooks` flow via a small wrapper script. Three layers coexist on
`git commit`: the existing `.githooks/commit-msg` (Conventional
Commits), the new `.githooks/pre-commit` wrapper, and the existing
`.githooks/pre-push` (Conventional Branches). The framework's own
`.git/hooks/pre-commit` is never written (S067).

## Why a wrapper, not `pre-commit install` (S066, S067)

`pre-commit install` writes `.git/hooks/pre-commit` by default, but the
repo already sets `core.hooksPath = .githooks`. With that setting, Git
ignores `.git/hooks/` entirely, so `pre-commit install` would be a silent
no-op. The wrapper preserves the existing `core.hooksPath` flow and keeps
all hook scripts version-controlled under `.githooks/`.

## The wrapper (S067)

`.githooks/pre-commit` is a POSIX bash script with `set -eu`:

1. Verify `pre-commit` is on `PATH` (`command -v pre-commit`).
   If absent, print a one-line install hint and exit non-zero. This
   is FR-007: detect missing binary, surface a one-line fix, do not
   silently write a broken hook.
2. If present, write the sentinel `.git/.pre-commit-ran` and
   `exec pre-commit run --hook-stage pre-commit`. The framework takes
   over from there.

The sentinel is what the extended `.githooks/commit-msg` script reads
to decide whether to append the bypass trailer. See
[Bypass visibility mechanism](./bypass-visibility-mechanism.md).

## Three layers, one commit (S066)

`git commit` triggers Git's hook chain at the `pre-commit` and
`commit-msg` stages, in that order:

1. **`.githooks/pre-commit`** (new): the wrapper. If the binary is
   missing, commit blocks here with the install hint. If the wrapper
   runs the framework and a hook fails, the framework exits non-zero
   and commit blocks with the hook's output.
2. **`.githooks/commit-msg`** (extended): sentinel check →
   `Skipped-Hooks: pre-commit` trailer if absent, else remove sentinel
   → Conventional Commits regex. Bypass does not bypass Conventional
   Commits.
3. **`.githooks/pre-push`** (unchanged): enforces Conventional
   Branches on the branch name before push.

The Conventional Commits + Conventional Branches hooks are independent
of the framework and continue to fire even if the framework itself is
absent or the contributor used `--no-verify`. The pre-commit stage is
the only one that can be bypassed via `--no-verify`, and only the
pre-commit trailer records the bypass.

## Why not replace `core.hooksPath` (S066, S067)

Switching `core.hooksPath` to `.git/hooks/` would force the framework
install to write there, but it would also break `.githooks/commit-msg`
and `.githooks/pre-push`, which already enforce Conventional Commits
and Conventional Branches. Reusing the existing path is the
compositional-simpler option: one directory for hook scripts, one
`make install-hooks` command wires everything.

## What this component does NOT do (S067)

- It does not run the pre-commit framework on pre-push. The framework's
  hooks are declared at the `pre-commit` stage only (`default_stages:
  [pre-commit]`). Pre-push runs the existing Conventional Branches
  check.
- It does not shadow or remove `.githooks/commit-msg` or
  `.githooks/pre-push`. The wrapper coexists with both.
- It does not write anything under `.git/hooks/`. Everything stays
  under `.githooks/`.

## Related

- [Pre-commit framework rule set](./pre-commit-framework-rule-set.md):
  what the wrapper delegates to
- [Bypass visibility mechanism](./bypass-visibility-mechanism.md):
  what the sentinel signals
- [Install git hooks](./install-git-hooks.md): how the wrapper gets
  installed on a fresh clone
