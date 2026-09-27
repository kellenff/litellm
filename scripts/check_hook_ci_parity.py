#!/usr/bin/env python3
# check_hook_ci_parity.py — enforce FR-005 / SC-003.
#
# Reads .pre-commit-config.yaml, extracts hook IDs declared at the
# `pre-commit` stage, compares each against the set of checks CI runs in
# test-linting.yml (the litellm-Python lint job) plus a documented carve-out
# for standard pre-commit-hooks file hygiene hooks that CI doesn't run
# separately but also doesn't contradict.
#
# Exits 0 when every local hook is in the unioned set; non-zero with one
# line per violation otherwise. Designed to be run from
# scripts/test_pre_commit.sh and from CI as a parity gate.
#
# Stdlib only: PyYAML not in scope; we parse only the small fixed-shape
# subset of YAML that .pre-commit-config.yaml uses.

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / ".pre-commit-config.yaml"

# CI's litellm-Python checks (test-linting.yml, "Run lint" job).
# Mirror them here so a future CI change forces a config change too.
CI_LINTELLM_CHECKS: frozenset[str] = frozenset({"ruff", "ruff-format"})

# Documented carve-out: standard pre-commit-hooks hygiene checks that CI
# doesn't run as separate jobs but also doesn't fail on. This is the only
# place this list lives; new carve-outs need a spec update.
# Available but not declared in .pre-commit-config.yaml: check-merge-conflict,
# check-case-conflict, mixed-line-ending (add to config before carving out).
CI_HYGIENE_CARVEOUT: frozenset[str] = frozenset(
    {
        "trailing-whitespace",
        "end-of-file-fixer",
        "check-yaml",
        "check-toml",
        "check-added-large-files",
        "detect-private-key",
    }
)

ALLOWED_HOOK_IDS: frozenset[str] = CI_LINTELLM_CHECKS | CI_HYGIENE_CARVEOUT


def _scan_hook_ids(lines: list[str]) -> list[str]:
    """Find `id:` values that live under a `hooks:` block in a repo entry."""
    hook_ids: list[str] = []
    hooks_indent: int | None = None
    pending_id: str | None = None
    pending_stages: list[str] | None = None

    def flush() -> None:
        nonlocal pending_id, pending_stages
        if pending_id is not None and (pending_stages is None or "pre-commit" in pending_stages):
            hook_ids.append(pending_id)
        pending_id = None
        pending_stages = None

    for raw in lines:
        stripped = raw.rstrip()
        if not stripped or stripped.lstrip().startswith("#"):
            continue
        indent = len(stripped) - len(stripped.lstrip())
        content = stripped.lstrip()

        if hooks_indent is not None and indent <= hooks_indent:
            flush()
            hooks_indent = None

        if content == "hooks:":
            hooks_indent = indent
            continue

        if hooks_indent is None:
            continue

        if content.startswith("- id:"):
            flush()
            pending_id = content.split(":", 1)[1].strip().strip('"').strip("'")
            continue

        if content.startswith("stages:"):
            rest = content.split(":", 1)[1].strip()
            if rest.startswith("[") and rest.endswith("]"):
                pending_stages = [s.strip().strip('"').strip("'") for s in rest[1:-1].split(",") if s.strip()]
            continue

    flush()
    return hook_ids


def parse_hook_ids(yaml_text: str) -> list[str]:
    return _scan_hook_ids(yaml_text.splitlines())


def main() -> int:
    if not CONFIG_PATH.exists():
        print(f"check_hook_ci_parity: {CONFIG_PATH} not found", file=sys.stderr)  # noqa: T201  # CLI status output to stderr
        return 2

    yaml_text = CONFIG_PATH.read_text(encoding="utf-8")
    declared = sorted(set(parse_hook_ids(yaml_text)))
    if not declared:
        print(  # noqa: T201  # CLI status output to stderr
            f"check_hook_ci_parity: no hooks at pre-commit stage in {CONFIG_PATH}",
            file=sys.stderr,
        )
        return 2

    violations = [hook_id for hook_id in declared if hook_id not in ALLOWED_HOOK_IDS]
    if violations:
        for v in sorted(violations):
            print(  # noqa: T201  # CLI status output to stderr
                f"check_hook_ci_parity: hook '{v}' is declared locally but not in "
                f"CI's litellm-Python lint set ({sorted(CI_LINTELLM_CHECKS)}) or the "
                f"documented hygiene carve-out ({sorted(CI_HYGIENE_CARVEOUT)}). "
                f"Add it to test-linting.yml and update CI_LINTELLM_CHECKS, or remove it.",
                file=sys.stderr,
            )
        return 1

    print(f"check_hook_ci_parity: OK ({len(declared)} hook(s) verified against CI parity set)")  # noqa: T201  # CLI success message to stdout
    return 0


if __name__ == "__main__":
    sys.exit(main())
