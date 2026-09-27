---
title: CI hook parity gate
type: component
sources: [S067, S068]
updated: 2026-09-27
---

`scripts/check_hook_ci_parity.py` is a stdlib-only Python script that
diffs `.pre-commit-config.yaml` hook IDs against the unioned CI rule
set, preventing drift between the local pre-commit framework and CI's
`make check` (S067, S068). The script enforces FR-005 and SC-003 from
the pre-commit feature spec.

## What it checks (S068)

- Parses `.pre-commit-config.yaml` and collects every `repos[].hooks[].id`.
- Compares the set against the CI parity set: the union of hooks CI
  runs, with a documented carve-out for hygiene hooks that the CI
  workflow runs in a different shape (whitespace, end-of-file, yaml
  syntax, toml syntax, large files, private-key detection) plus
  `ruff-format` which CI runs in its own job.
- Exits non-zero if any hook ID declared in `.pre-commit-config.yaml`
  is not in the CI parity set. This is the direction of the invariant:
  local may be a subset of CI, but never a superset.

## Why this is a separate script (S068)

The `.pre-commit-config.yaml` file alone is just data; without an
enforcement step, a contributor could add `mypy-local` or
`eslint-strict` to the local set and CI would never know until a
local-pass commit broke CI on the same check. The parity script is
the gate that catches the drift before the commit lands.

The script uses only the Python standard library (`argparse`,
`pathlib`, `re`, `sys`) — no PyYAML, no pre-commit framework import.
The hook IDs are extracted by walking the YAML text with a small
regex, since the file's structure is simple and stable. No third-party
dependency is justified for a 100-line walker.

## How to run (S068)

```bash
python3 scripts/check_hook_ci_parity.py
```

The script prints `check_hook_ci_parity: OK (8 hook(s) verified against
CI parity set)` and exits 0 on success, or names the offending hook
and exits non-zero. A `--update` flag is supported for the rare case
where the CI parity set legitimately needs to grow; that flag updates
the carve-out list and is the only sanctioned way to add a new hook
without also wiring it into CI.

## What this gate does NOT do (S067)

- It does not run the pre-commit framework itself. It only validates
  the config against the CI rule set.
- It does not edit `.pre-commit-config.yaml`. The script reports
  drift; the contributor reconciles by either adding the same check
  to CI or removing it from the local config.
- It does not enforce correctness of upstream `rev` pins. The contract
  invariant that pins must be concrete tags is enforced by code review
  and the CI supply-chain safety rule documented elsewhere in the
  repo.

## Related

- [Pre-commit framework rule set](./pre-commit-framework-rule-set.md):
  the rule set this gate protects
- [Pre-commit hook wiring](./pre-commit-hook-wiring.md): how the
  framework gets invoked
- [Lint, type, and test gates](./lint-and-type-gates.md): the broader
  gate family this script belongs to
