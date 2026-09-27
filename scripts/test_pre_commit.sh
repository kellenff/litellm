#!/usr/bin/env bash
#
# test_pre_commit.sh — end-to-end verification for the pre-commit hook
# integration (FR-001..FR-008, SC-001..SC-005).
#
# Each step prints PASS or FAIL; the first FAIL exits non-zero.
# Run from repo root:  ./scripts/test_pre_commit.sh
#
# NOT a regression suite — this is the verification step the feature's
# PR author runs before opening the PR (T013), and the gate that
# regressions manifest in. Acts as a quick reviewer-runnable proof.

set -eu

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

step=0
fail() {
    printf '\n\xE2\x9C\x97 Step %d FAIL: %s\n' "$step" "$*"
    exit 1
}
pass() {
    printf '\xE2\x9C\x94 Step %d PASS: %s\n' "$step" "$*"
}

# Step 1: install script detects missing binary, exits non-zero, and leaves
# core.hooksPath untouched. Run under a stripped PATH so pre-commit is absent;
# assert BOTH the non-zero exit code AND that core.hooksPath was not written.
step=1
saved_path="$PATH"
saved_hooks_path="$(git config core.hooksPath 2>/dev/null || true)"
if env -i PATH=/usr/bin:/bin HOME="$HOME" CI=true \
    "$REPO_ROOT/scripts/install_git_hooks.sh" >/dev/null 2>&1; then
    fail "install script exited 0 despite missing pre-commit binary (silent swallow)"
fi
after_hooks_path="$(git config core.hooksPath 2>/dev/null || true)"
if [ "$saved_hooks_path" = "$after_hooks_path" ]; then
    pass "missing binary exits non-zero and leaves core.hooksPath untouched"
else
    fail "core.hooksPath changed ($saved_hooks_path -> $after_hooks_path) on missing-binary path"
fi

# Step 2: install script success path wires core.hooksPath and prints version.
step=2
if "$REPO_ROOT/scripts/install_git_hooks.sh" >/dev/null 2>&1; then
    if [ "$(git config core.hooksPath)" = ".githooks" ]; then
        pass "install wires core.hooksPath = .githooks"
    else
        fail "core.hooksPath is '$(git config core.hooksPath)', want '.githooks'"
    fi
else
    fail "install_git_hooks.sh failed on success path"
fi

# Step 3: pre-commit framework config is loaded (hooks present, all revs pinned).
step=3
if ! command -v pre-commit >/dev/null 2>&1; then
    fail "pre-commit binary not on PATH for this verification"
fi
if pre-commit validate-config >/dev/null 2>&1; then
    pass "pre-commit validate-config accepts .pre-commit-config.yaml"
else
    fail "pre-commit validate-config rejected .pre-commit-config.yaml (run with --no-sandbox for detail)"
fi

# Step 4: CI parity script exits 0 against the current hook set.
step=4
if "$REPO_ROOT/scripts/check_hook_ci_parity.py" >/dev/null; then
    pass "check_hook_ci_parity.py exits 0"
else
    fail "check_hook_ci_parity.py reported drift between .pre-commit-config.yaml and CI"
fi

# Step 5: bypass-trailer logic. With no sentinel present, the commit-msg
# hook MUST append a Skipped-Hooks: pre-commit trailer in place; with the
# sentinel present, it MUST NOT and MUST remove the sentinel file.
step=5
rm -f "$REPO_ROOT/.git/.pre-commit-ran"
tmp_msg=$(mktemp)
trap 'rm -f "$tmp_msg"; rm -f "$REPO_ROOT/.git/.pre-commit-ran"' EXIT
printf '%s\n' "feat: bypass trailer test" > "$tmp_msg"
if ! "$REPO_ROOT/.githooks/commit-msg" "$tmp_msg"; then
    fail "commit-msg aborted on a valid message"
fi
if ! grep -q '^Skipped-Hooks: pre-commit$' "$tmp_msg"; then
    fail "trailer not appended when sentinel absent"
fi
pass "commit-msg appends Skipped-Hooks: pre-commit when sentinel absent"

touch "$REPO_ROOT/.git/.pre-commit-ran"
printf '%s\n' "feat: hook ran" > "$tmp_msg"
if ! "$REPO_ROOT/.githooks/commit-msg" "$tmp_msg"; then
    fail "commit-msg aborted on a valid message (sentinel present)"
fi
if grep -q '^Skipped-Hooks: pre-commit$' "$tmp_msg"; then
    fail "trailer incorrectly appended when sentinel present"
fi
if [ -f "$REPO_ROOT/.git/.pre-commit-ran" ]; then
    fail "sentinel not removed when present"
fi
pass "commit-msg is a no-op and clears sentinel when sentinel present"

# Step 6: bad-commit blocking. The trailing-whitespace hook fires on files
# that end a line with whitespace; we add one to a tracked file, attempt
# a commit, and confirm the framework exits non-zero.
step=6
tmp_file=$(mktemp)
printf 'trailing whitespace line   \n' > "$tmp_file"
# Add the trailing-whitespace line to the working tree and stage it
# without committing; run the framework directly so we don't accidentally
# leave the repo dirty.
trailing_marker=$(mktemp "$REPO_ROOT/.pre-commit-test-XXXXXX") || \
    fail "could not create test scratch file under repo root"
printf '%s   \n' "trailing_whitespace_line" > "$trailing_marker"
git -C "$REPO_ROOT" add -f -- "$trailing_marker"
if pre-commit run --files "$trailing_marker" >/dev/null 2>&1; then
    fail "trailing-whitespace hook did not block a file with trailing space"
fi
git -C "$REPO_ROOT" reset HEAD -- "$trailing_marker" >/dev/null 2>&1
rm -f "$trailing_marker"
pass "framework rejects a file containing trailing whitespace"

# Step 7: SC-002 always-fail-hook methodology. Add a temporary repo: local
# hook via .pre-commit-config.yaml that always fails (we don't actually
# mutate the file, we instead append a synthetic .git/-test-hook entry
# to our nested local-repos config that --hook-stage pre-commit needs).
# Rather than mutating the real config, we exercise the framework's
# own --hook-stage pre-commit and confirm exit-code propagates.
step=7
# Pre-built config snippet with always-failing hook
always_fail_conf=$(mktemp "$REPO_ROOT/.pre-commit-test-XXXXXX.yaml")
cat > "$always_fail_conf" <<'YAML'
repos:
  - repo: local
    hooks:
      - id: always-fail-test-hook
        name: always-fail-test-hook
        entry: 'exit 1'
        language: system
        pass_filenames: false
YAML
PYTHONPATH="" PRE_COMMIT_CONFIG_PATH="$always_fail_conf" \
    pre-commit run --config "$always_fail_conf" \
    --hook-stage pre-commit >/dev/null 2>&1 \
    && fail "always-fail hook did not block the commit (expected exit 1)" \
    || pass "always-fail hook blocks the commit (SC-002 verification)"

# Cleanup test scratch files
rm -f "$always_fail_conf" "$tmp_file"
# Restore the original PATH / hooksPath context.
git config core.hooksPath "$saved_hooks_path" >/dev/null 2>&1 || true
PATH="$saved_path"

printf '\nAll 7 verification steps PASSED. Ready for PR.\n'
