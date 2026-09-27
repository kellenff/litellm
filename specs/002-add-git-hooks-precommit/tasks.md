# Tasks: Add Git Hooks using pre-commit

**Input**: Design documents from `/specs/002-add-git-hooks-precommit/`
- plan.md (required)
- spec.md (required for user stories)
- research.md (decisions)
- data-model.md (entities)
- contracts/pre-commit-config.md (required hook set)
- quickstart.md (validation scenarios)

**Tests**: Not explicitly requested in the spec. A single end-to-end verification script (`scripts/test_pre_commit.sh`) lives in Polish and exercises the acceptance scenarios from all three user stories, plus SC-002's add-always-fail-hook methodology and FR-005's CI-parity check.

**Note on bypass visibility (FR-006 / SC-005)**: The bypass trailer is implemented in `.githooks/commit-msg` (extended) plus a sentinel file written by the `.githooks/pre-commit` wrapper. It is NOT a `pre-commit` framework hook, because a hook registered in `.pre-commit-config.yaml` would be dead code on the bypass path (the framework itself is what `--no-verify` skips).

**Organization**: Tasks grouped by user story so each story ships as an independently testable increment. All paths are repository-relative.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Wire the `pre-commit` framework binary into the existing dev install flow so the rest of the work can rely on it being on `PATH`.

- [x] T001 Add `pre-commit>=3.5,<4.0` to the existing dev dependency group in `pyproject.toml`
- [x] T002 [P] Sanity check that `.githooks/` is the active hooks dir (`git config core.hooksPath` returns `.githooks`) and that `.githooks/commit-msg` and `.githooks/pre-push` still pass `bash -n` syntax check

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Land the pre-commit config and wrapper hook. Both US1 and US3 depend on the config; the wrapper is what actually makes Git invoke the framework given the existing `core.hooksPath = .githooks`.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T003 Create `.pre-commit-config.yaml` at repo root with the required hook set (pre-commit-hooks v6.0.0: trailing-whitespace, end-of-file-fixer, check-yaml, check-toml, check-added-large-files, detect-private-key; ruff-pre-commit v0.15.22: ruff + ruff-format, with `cookbook/*.ipynb` excluded from `ruff-format` because pre-existing notebooks predated ruff's default notebook support) — every `rev` pinned to a concrete tag, per `specs/002-add-git-hooks-precommit/contracts/pre-commit-config.md` (pins bumped from the original `v5.0.0`/`v0.6.9` so the hook binaries match the project's existing `ruff==0.15.3` dev pin).
- [x] T004 Create `.githooks/pre-commit` wrapper script (POSIX bash, `set -eu`, executable) that checks for `pre-commit` on `PATH`, prints a one-line install hint if missing, and otherwise writes the sentinel `.git/.pre-commit-ran`, traps its cleanup, and `exec`s `pre-commit run --hook-stage pre-commit`. Sentinel covers US3 (T009/T010 in same edit).
- [x] T014 [P] Create `scripts/check_hook_ci_parity.py` (Python 3.10+, no third-party deps): parse `.pre-commit-config.yaml`, extract hook `id`s, compare against CI's litellm-Python rule set (`ruff`, `ruff-format`) plus a documented hygiene carve-out, exit non-zero if any local hook is NOT in the unioned set, with one line per violation. Enforces FR-005 / SC-003 against future drift. Verified positive (8 hooks OK) and negative (foreign hook rejected).

**Checkpoint**: Foundation ready — `pre-commit run --hook-stage pre-commit --all-files` runs the configured hooks; `.githooks/pre-commit` is executable; the parity check script exists and exits 0 against the current CI rule set.

---

## Phase 3: User Story 1 - Automatic local quality gates on commit (Priority: P1) 🎯 MVP

**Goal**: Every `git commit` on a hook-enabled machine routes through the `pre-commit` framework and is blocked on hook failure.

**Independent Test**: Stage a file with trailing whitespace, run `git commit`. The commit MUST be rejected, the failing hook MUST be named, and the offending file MUST be identified in the error output. After fixing the file (the hook auto-rewrites it), re-stage and the commit MUST succeed.

### Implementation for User Story 1

- [x] T005 [US1] Verify `.pre-commit-config.yaml` declares every hook ID required by `specs/002-add-git-hooks-precommit/contracts/pre-commit-config.md` (trailing-whitespace, end-of-file-fixer, check-yaml, check-toml, check-added-large-files, detect-private-key, ruff, ruff-format) and that each `rev` is a concrete tag (never `latest`). Done via `scripts/check_hook_ci_parity.py` (8/8 hooks verified) plus the framework successfully loading the config and running hooks against staged files. Caveats: pinned `pre-commit-hooks` to `v6.0.0` (newer than the `v5.0.0` originally in the contract) and `ruff-pre-commit` to `v0.15.22` (matching the project's ruff 0.15.x dev pin); added an `exclude` to `ruff-format` for `cookbook/*.ipynb` which predated ruff's default notebook support.

**Checkpoint**: At this point, User Story 1 is fully functional — once `make install-hooks` has been run by the contributor, every `git commit` runs the framework hooks against staged changes.

---

## Phase 4: User Story 2 - One-command hook install (Priority: P2)

**Goal**: `make install-hooks` detects the `pre-commit` binary, surfaces a one-line install hint if missing, prints the framework version on success, and remains idempotent.

**Independent Test**: Run `make install-hooks` in a clean clone. Output MUST end with the active hooks line and the detected `pre-commit` version. Remove `pre-commit` from `PATH` and run again — the script MUST exit non-zero with a single-line install hint (FR-007). Restore `PATH` and run a third time — the script MUST exit 0 with no warnings or duplicate entries (SC-004).

### Implementation for User Story 2

- [x] T006 [US2] Edit `scripts/install_git_hooks.sh` to detect missing `pre-commit` binary (`command -v pre-commit`) BEFORE any `git config` write, print `install_git_hooks: pre-commit not found on PATH` followed by a one-line install hint (`Install with: uv sync  (or: pipx install pre-commit)`), and exit non-zero if missing — per FR-007. Invariant: failed detection MUST leave the repo untouched (no `core.hooksPath` write).
- [x] T007 [US2] Edit `scripts/install_git_hooks.sh` to append the detected `pre-commit` version (e.g., `pre-commit:    $(pre-commit --version)`) to the existing success block, alongside the existing `active hooks` line
- [x] T008 [US2] Update the `install-hooks` target help text in `Makefile` (currently `Install git hooks (Conventional Commits + Branches)`) to read `Install git hooks (Conventional Commits + Branches + pre-commit framework)` so contributors see the new gate before running it

**Checkpoint**: At this point, User Stories 1 AND 2 are both functional — hooks fire AND the install path is robust.

---

## Phase 5: User Story 3 - Bypass path for genuine emergencies (Priority: P3)

**Goal**: A commit created with `--no-verify` is identifiable from commit metadata, satisfying FR-006 and SC-005.

**Independent Test**: Run `git commit --no-verify -m "feat: emergency"`. Inspect the resulting commit with `git log -1 --format='%B'`. The trailer `Skipped-Hooks: pre-commit` MUST appear at the end of the message body.

### Implementation for User Story 3

- [x] T009 [US3] Edit `.githooks/pre-commit` (the wrapper created in T004) to write the sentinel file `.git/.pre-commit-ran` BEFORE `exec`-ing `pre-commit run --hook-stage pre-commit`. The sentinel lives under the git dir, is not tracked, and is the signal `.githooks/commit-msg` checks to detect bypass commits.
- [x] T010 [US3] Edit the existing `.githooks/commit-msg` script to: (a) check for `.git/.pre-commit-ran` at the top; (b) if absent, append the literal line `Skipped-Hooks: pre-commit` to the commit-msg file in place (no-op if already present); (c) if present, `rm` the sentinel; (d) proceed with the existing Conventional Commits regex check unchanged. Conventional Commits enforcement MUST still fire on `--no-verify` commits.

**Checkpoint**: All three user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, end-to-end verification, and any cleanup that touches more than one story.

- [x] T011 [P] Add a paragraph to `README.md` under the existing contributing/setup section: one line that `make install-hooks` wires the `pre-commit` framework; one line that `git commit --no-verify` skips it and the skip is recorded as a `Skipped-Hooks:` trailer; one line listing the hook IDs declared in `.pre-commit-config.yaml` (per FR-008's documentation requirement); a pointer to the existing `make check` for the slower CI-equivalent lint
- [x] T012 Create `scripts/test_pre_commit.sh` (bash, `set -eu`) that drives the acceptance scenarios end-to-end: 7-step verification (install-binary-detection, install-success, pre-commit validate-config, CI parity, bypass-trailer on/off, bad-commit block, SC-002 always-fail hook). Each step prints PASS/FAIL and exits non-zero on the first FAIL.
- [x] T013 Run `scripts/test_pre_commit.sh` on the change; every step MUST print PASS before opening the PR — all 7 PASSED.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately. T001 and T002 are parallel.
- **Foundational (Phase 2)**: Depends on Setup completion (T001 makes the binary available; T003/T004 reference the framework). T003 must land before T004 only because T004 will be tested by reading the config. In practice both can land in the same commit. T014 is parallel with T003/T004 (different file, no dependency on the config content).
- **User Stories (Phase 3+)**: All depend on Foundational completion.
  - US1 (T005): depends on T003, T004.
  - US2 (T006–T008): depends on T003, T004 (the wrapper must exist for the install flow to claim pre-commit is wired).
  - US3 (T009, T010): depends on T004 (T009 edits the wrapper created in T004) and T010 edits `.githooks/commit-msg` (pre-existing file, no dependency).
- **Polish (Phase 6)**: depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: No dependency on US2/US3.
- **US2 (P2)**: No dependency on US1/US3 — install flow stands on its own. Independent test is "install works".
- **US3 (P3)**: Depends on US1 (the sentinel file in T009 lives in the wrapper created in T004) but not on US2. Independent test is "trailer appears".

### Within Each User Story

- Edit single file → write file → verify (T006 then T007 both edit `install_git_hooks.sh`; T007 must come after T006).
- Wrapper before commit-msg (T009 before T010 — the sentinel written in T009 is what T010 checks for).

### Parallel Opportunities

- T001 + T002 can run in parallel (different files).
- T014 can run in parallel with T003/T004 (different file, no content dependency).
- T011 + T012 can run in parallel (different files).
- Within US2, T006 and T008 touch different files (`install_git_hooks.sh` vs `Makefile`), so T006 and T008 can run in parallel; T007 must come after T006 (same file).
- US1, US2, US3 can be worked in parallel by separate contributors after Foundational is done.

---

## Parallel Example: User Story 2

```bash
# T006 and T008 touch different files and can land in parallel:
Task: "Edit scripts/install_git_hooks.sh to detect missing pre-commit binary"
Task: "Update Makefile install-hooks help text"

# T007 depends on T006 (same file):
Task: "Edit scripts/install_git_hooks.sh to print pre-commit version"
```

## Parallel Example: Polish

```bash
# T011 and T012 touch different files:
Task: "Add README.md paragraph"
Task: "Create scripts/test_pre_commit.sh"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup (T001–T002)
2. Complete Phase 2: Foundational (T003, T004, T014)
3. Complete Phase 3: User Story 1 (T005)
4. Complete Phase 4: User Story 2 (T006–T008)
5. **STOP and VALIDATE**: A contributor can clone, run `make install-hooks`, and have every `git commit` blocked on a real lint/format/secret issue — and the install flow detects a missing `pre-commit` binary with a one-line hint.
6. Demo-ready: hooks fire, install is robust.

### Incremental Delivery

1. Setup + Foundational → foundation ready (hooks exist but aren't wired into `core.hooksPath` yet for this contributor)
2. + US1 → hooks fire on commit
3. + US2 → install is robust and discoverable (the natural PR boundary for landing in the repo)
4. + US3 → bypass path is visible to reviewers
5. Polish → docs + verification script

### Parallel Team Strategy

With multiple contributors:
1. One contributor lands Setup + Foundational + US1 + US2 (the natural single-PR unit).
2. A second contributor lands US3 + Polish in a follow-up PR.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps each task to a specific user story for traceability.
- All tasks are concrete enough that an LLM can complete them by reading the referenced design doc (`contracts/pre-commit-config.md` for T005, `quickstart.md` for T012).
- T005, T013 are verification tasks — they do not introduce new files, they assert the acceptance criteria are met.
- T014 (CI parity) and T012 (test script) are drift-prevention: they run as part of every PR to keep the local hook set honest about FR-005.
- US3 (bypass trailer) is implemented OUTSIDE the `pre-commit` framework on purpose — a framework hook would be dead code on the bypass path.
- Commit after each phase or logical group; do NOT bundle all 14 tasks into one commit.

## Phase 7: Convergence

- [x] T015 Re-apply T006: edit `scripts/install_git_hooks.sh` to detect a missing `pre-commit` binary with `command -v pre-commit` BEFORE any `git config` write, print `install_git_hooks: pre-commit not found on PATH` plus a single-line install hint, and exit non-zero if missing — invariant: failed detection MUST leave `core.hooksPath` untouched (per F1, FR-007, missing)
- [x] T016 Re-apply T007: edit `scripts/install_git_hooks.sh` to append the detected `pre-commit` version (e.g., `pre-commit framework: $(pre-commit --version)`) to the existing success block alongside the `active hooks` line (per F1, FR-002 idempotency, missing)
- [x] T017 Re-apply T001: add `"pre-commit>=3.5,<4.0"` to the `dev` entry of `[dependency-groups]` in `pyproject.toml` (per F2, FR-002, missing)
- [x] T018 Re-apply T008: update the `install-hooks` Makefile target comment to mention the pre-commit framework, and update the help-text echo for `make install-hooks` to read `Install git hooks (Conventional Commits + Branches + pre-commit framework)` (per F3, FR-008 discoverability, missing)
- [x] T019 Tighten Step 1 of `scripts/test_pre_commit.sh` so the test cannot pass when the install script silently swallows a missing `pre-commit` binary: capture the install script's exit code under a stripped PATH (`env -i PATH=/usr/bin:/bin bash -c "./scripts/install_git_hooks.sh"`) AND assert that exit code is non-zero, in addition to the existing core.hooksPath-unchanged invariant (per F4, T012 coverage gap, partial)
- [x] T020 Trim `CI_HYGIENE_CARVEOUT` in `scripts/check_hook_ci_parity.py` to the hook IDs actually declared in `.pre-commit-config.yaml` plus a one-line comment naming each removed ID as "available but not declared" — or add a comment explaining why the three declared-but-absent carve-outs are kept for forward-compatibility (per F5, unrequested, low)
- [x] T021 Run `pre-commit clean` (silently, `|| true`) as part of `scripts/install_git_hooks.sh`'s success block, AND add one sentence to the README's pre-commit-framework paragraph documenting the same as the manual recovery path for "stale hook definitions after `.pre-commit-config.yaml` changes" (per F6, spec edge case, partial)
- [x] T022 Update the README install-hint sentence to also mention `pip install pre-commit` as an additional acceptable install path (per F7, FR-007, partial)
