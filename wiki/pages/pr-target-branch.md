---
title: PR target branch
type: howto
sources: [S022]
updated: 2026-09-26
---

Always resolve the live default branch with `scripts/default_branch.py` before opening a PR (S022). Never assume a branch name and never read a cached `origin/HEAD`.

## The command

```bash
python3 scripts/default_branch.py --branch
```

This prints only the branch name, without fetching (S022). The full script also resolves `origin/<branch>` for comparison (`python3 scripts/default_branch.py` with no flag) and accepts `--base <ref>` to skip discovery (S022).

## Why this script and not `origin/HEAD` (S022)

`origin/HEAD` is whatever the last `git remote set-head` saw, and a stale checkout or worktree can hand you a cached value that is not what origin advertises today. The script asks origin directly: `git ls-remote --symref origin HEAD` reads the symbolic ref origin itself publishes, parses the single `ref: refs/heads/<name>\tHEAD` line, then validates the name with `git check-ref-format refs/heads/<name>`. If origin advertises no default, or advertises more than one, the script aborts with a clear message instead of guessing.

The `GIT_TERMINAL_PROMPT=0` environment and 60-second timeout are set on every `git` call, so a stuck credential prompt cannot hang the run.

## When to use it

- Opening a PR; confirm the base branch before pushing.
- Authoring automation that compares against the default; pass the resolved name as `--base` (S022).
- Internal contributors; branch off the resolved default; the repo's internal convention prefixes such branches with `litellm_` (S022 plus repo conventions). Do not use a `claude/` prefix or any branch name containing `/`.

The script is the same one the rest of the tooling uses, so the answer is consistent across the PR pipeline, the lint/type/test budgets, and the proxy dev config.

Related: [Repo dev loop](./dev-loop.md), [Prisma migration rule](./prisma-migration-rule.md), [PRs and issues](./pr-and-issues.md).
