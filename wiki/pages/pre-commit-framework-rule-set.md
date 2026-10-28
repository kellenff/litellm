---
title: Pre-commit framework rule set
type: decision
sources: [S065, S066, S068]
updated: 2026-09-27
---

The pre-commit framework runs a strict subset of CI's `make check` rule set
on staged files at commit time. The set is the fastest checks that still
catch the most regressions: a formatter check, a linter with `--fix`, and
six standard text-file hygiene hooks (S065, S066).

## What runs locally (S068)

`.pre-commit-config.yaml` declares eight hooks on the `[pre-commit]` stage:

- `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-toml`,
  `check-added-large-files`, `detect-private-key` from
  `pre-commit-hooks` pinned at `v6.0.0`
- `ruff` and `ruff-format` from `ruff-pre-commit` pinned at `v0.15.22`,
  matching the project's `ruff==0.15.3` dev pin (S066)
- `ruff-format` excludes `cookbook/*.ipynb` because ruff's default notebook
  support fails on pre-existing magic-line cells (S066)

## What is intentionally NOT in the local set (S065, S066)

- Full basedpyright sweep, full test suite, circular-import / import-safety
  scans, the `LIT*` budget gates. These are minute-scale and live in
  `make check`; running them on every commit would break the inner loop.
- Anything broader than CI's rule set. The local set is a strict subset
  by design: a green local commit must not fail on the same checks in CI
  (FR-005 / SC-003). The drift-prevention gate that enforces this is
  documented in [CI hook parity gate](./ci-hook-parity-gate.md).

## Pin policy (S066)

Upstream `rev` values are concrete tags, never `latest` or `stable` —
the CI supply-chain safety rule. The original spec planned
`pre-commit-hooks` `v5.0.0` and `ruff-pre-commit` `v0.6.9`; both were
bumped to `v6.0.0` and `v0.15.22` so the framework's hook binaries match
the project's existing `ruff==0.15.3` dev pin. Mismatched ruff versions
between local hooks and the CI gate would produce a class of false-pass
commits, which the parity gate is supposed to catch — better to not
create the drift in the first place.

## Why this set, not alternatives (S066)

- **Full CI mirror on pre-commit**: rejected — minute-per-commit
  unacceptable for the inner loop.
- **Manual-only (no framework)**: rejected — user explicitly named
  `pre-commit` (pre-commit.com).
- **Inline ruff in `.githooks/pre-commit` shell**: rejected — raw shell
  drifts from `make check` over time; the framework is the single
  config source of truth.
- **Pre-commit hook stage on `.githooks/pre-push`**: rejected — the
  existing pre-push script already enforces Conventional Branches;
  running the same `.pre-commit-config.yaml` rules there would double
  the work without adding signal.

## Related

- [Pre-commit hook wiring](./pre-commit-hook-wiring.md): how the
  framework integrates with the existing `.githooks/` flow
- [CI hook parity gate](./ci-hook-parity-gate.md): drift prevention
- [Bypass visibility mechanism](./bypass-visibility-mechanism.md):
  `git commit --no-verify` and the trailer that records it
