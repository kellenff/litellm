---
title: Bypass visibility mechanism
type: decision
sources: [S065, S066, S067]
updated: 2026-09-27
---

When a contributor runs `git commit --no-verify`, the entire pre-commit
framework is skipped, so any hook registered in `.pre-commit-config.yaml`
is silently dead on the bypass path. Recording the bypass for reviewers
therefore has to live OUTSIDE the framework. The chosen mechanism is a
sentinel file plus the existing shell-based `.githooks/commit-msg` hook
(S065, S066, S067).

## How it works (S067)

1. The wrapper `.githooks/pre-commit` writes the sentinel file
   `.git/.pre-commit-ran` BEFORE `exec`-ing `pre-commit run --hook-stage
   pre-commit`. If the framework runs to completion, the sentinel
   remains on disk through commit-msg.
2. The existing `.githooks/commit-msg` shell script is extended to:
   - Check `.git/.pre-commit-ran` at the top.
   - If absent, append the literal line `Skipped-Hooks: pre-commit` to
     the commit message in place. The append is idempotent — no-op if
     the trailer is already present.
   - If present, remove the sentinel and proceed.
   - Conventional Commits regex still runs after the trailer append —
     the bypass skips pre-commit's quality gates, not the message
     convention.

## Why not a hook inside `.pre-commit-config.yaml` (S066)

`git commit --no-verify` is implemented at the Git level by skipping the
entire hook chain. The pre-commit framework never even gets the call, so
a hook inside `.pre-commit-config.yaml` that appended the trailer would
never fire on the bypass path. The analyzer flagged this as CRITICAL
during the original design; the sentinel mechanism is the remediation.

## Why not a separate tool or convention (S066)

- **`[skip-hooks]` convention-only**: rejected — adds a review convention
  reviewers don't already use; trailers are universally supported in
  every Git log viewer.
- **`pre-commit` framework's own `commit-msg` stage**: rejected — same
  architectural flaw, dead on the bypass path.
- **Reflog inspection at review time**: rejected — reflog is local to
  the contributor's machine and not always available to scripted
  commit flows.

## How a reviewer detects a bypass (S067)

```bash
git log --format='%H %s%n%b' | grep -B1 '^Skipped-Hooks: pre-commit'
```

Or per-commit:

```bash
git log -1 --format='%B' | grep '^Skipped-Hooks: pre-commit'
```

A bypassed commit will have the trailer on its own line in the message
body. The pre-commit `ruff` and `ruff-format` hooks did not run on that
commit; the contributor chose to skip them.

## Related

- [Pre-commit framework rule set](./pre-commit-framework-rule-set.md):
  what got skipped
- [Pre-commit hook wiring](./pre-commit-hook-wiring.md): where the
  sentinel is written
- [PRs and issues](./pr-and-issues.md): trailer shows up in commit
  metadata reviewers see
