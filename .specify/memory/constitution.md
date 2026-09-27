<!--
Sync Impact Report
==================
Version change: 0.0.0 (placeholder template) -> 1.0.0

Rationale: Initial population of the constitution from the scaffold template.
All prior content was bracketed placeholders; this is the first codified set
of principles for the brownfield codebase. Bumps MAJOR because prior governance
content is fully replaced rather than refined.

Modified principles (all new):
  - [PRINCIPLE_1_NAME] -> I. Type Discipline
  - [PRINCIPLE_2_NAME] -> II. Immutability by Default
  - [PRINCIPLE_3_NAME] -> III. Test Quality and Coverage
  - [PRINCIPLE_4_NAME] -> IV. Compositional Simplicity and Boundaries
  - [PRINCIPLE_5_NAME] -> V. Honest Communication and Pragmatic Brownfield

Added sections:
  - Technology Stack (was [SECTION_2_NAME])
  - Development Workflow (was [SECTION_3_NAME])
  - Governance (template kept; rewritten)

Removed sections:
  - None (template scaffold replaced wholesale)

Deferred items:
  - RATIFICATION_DATE: assumed today; if a prior ratification exists in an
    older commit, replace and bump PATCH.
-->

# LiteLLM Constitution

This constitution codifies the coding standards and existing patterns observed
across the LiteLLM codebase. It is a snapshot of current consensus, not a
frozen law. The patterns are not set in stone: when something looks wrong,
speak up, break it, and replace it with something better. The constitution
evolves as the codebase evolves.

Detailed, file-level rules live in `AGENTS.md` and the linked reference docs (`boundaries.md`,
`parse-do-not-validate.md`, `simple-made-easy.md`,
`integrated-tests-are-a-scam.md`).

## Core Principles

### I. Type Discipline

Strong typing throughout. No `Any` or coarse `dict[str, Any]` shapes on
public or internal boundaries. Validate external input with Pydantic (a
`BaseModel` or `TypeAdapter` that returns the typed value or raises) at trust
boundaries, then operate on precise domain types downstream. `# type: ignore`
is banned: `pyrightconfig.json` sets `enableTypeIgnoreComments` to false, so
it silently does nothing. Every suppression names the exact rule inside
brackets and carries a reason, e.g.
`# pyright: ignore[reportArgumentType]  # stubs lack async overload`.
Python max line length is 120, not 88.

### II. Immutability by Default

Prefer immutable values: tuples, frozen dataclasses with `slots=True`,
`MappingProxyType`, `frozenset`. Annotate every binding with `: Final`
(LIT010). Never rebind function parameters (LIT011); `self`/`cls` attribute
stores are the only acceptable mutation site. `TypedDict` fields are wrapped
in `ReadOnly[...]` (LIT012). Comprehensions take at most one `for` clause and
one `if` clause (LIT014); stacked clauses split into a helper generator or a
plain loop. Mutations and pattern literals that are only
acceptable when a frozen rewrite is truly so reach for the `# mutable-ok` /
`# writable-ok` / `# rebind-ok` suppressions only as a last resort, each with
a real reason, not convenience.

### III. Test Quality and Coverage

A test must only fail when litellm code changes. Never pin facts we don't own (a vendor's price, a third party's field,
an upstream default, today's date)
as literals or as "X must be absent"; assert the invariant our code
guarantees instead (two rows agree, a value is within range, a field is
derived from another). If an outside fact is truly load-bearing, cite its
source and date next to the assertion so a reader can tell stale from broken.
Tests must fail before the feature or fix lands and pass only when it works;
the mutation-kill target is > 90%. For bug fixes, extend the existing mapped
test file in `tests/test_litellm/` rather than creating a new one. Only
create a new test file for a new feature with no mapped test, matching that
directory's naming convention. Never test structure, only function.
End-to-end tests belong in `tests/e2e/` and follow that directory's
`AGENTS.md`.

### IV. Compositional Simplicity and Boundaries

Composition over inheritance; dependency injection over monkeypatching;
tagged unions plus `match` over ad-hoc branching. Early returns over deep
nesting; don't throw, model failures as values. Standard over hand-rolled:
use the official SDK where one exists; where none does, follow industry
standards. No monster files or god objects. Boundaries: convert external
input into precise domain values at trust boundaries, then write the rest of
the program against those types. A check that returns no new value throws
away the proof it just learned; parse, don't validate. Small, pure components
connected by simple data beat big tangled ones.

### V. Honest Communication and Pragmatic Brownfield

Code comments only when absolutely necessary: complex business logic that
needs a concise, clear note; tool input consumed by another tool (lint or
type suppression that names the rule and the reason, a `.git-blame-ignore-revs`
entry); a TODO or FIXME with a strong reason and ideally a link to a
follow-up. Everything else is AI slop. PRs, issues, discussion posts,
release notes, and docs follow the same humanizing rules: no emojis, no
"->" arrows, no "It's not X, it's Y" pattern, prose over bullets when bullets
don't carry their weight, no trailing period at paragraph ends, plain
engineering language over compact phrasing.

Git workflow: conventional commits for messages and PR titles; conventional
branches (the local git hooks enforce this once `make install-hooks` is
run). Internal contributors branch off the default branch with a `litellm_`
prefix and target that default branch (verify with
`python3 scripts/default_branch.py --branch`). Never add `Co-Authored-By:
Claude` or any Claude attribution to commits, PRs, or comments. Never put a
customer or company name in a public artifact; refer to "the customer" or
describe the request generically. Public providers (OpenAI, Anthropic, AWS
Bedrock, etc.) are the only company-name exception when adding support for
that provider in general, never when framed as a customer request.

Brownfield pragmatism: these patterns are observed across the codebase, not
set in stone. When an existing pattern looks wrong (code smell, security gap,
performance trap), call it out, fix the root cause once where every caller
routes through, and move on. A bug fix that patches only the path the ticket
names leaves every sibling caller still broken.

## Technology Stack

- Language: Python is primary. TypeScript/JavaScript for the Admin UI (`ui/litellm-dashboard`), Rust for
  performance-critical paths (`litellm-rust`), Go where present in tooling.
- Test runner: pytest. Unit tests under `tests/test_litellm/` mirroring
  `litellm/` paths. End-to-end tests under `tests/e2e/`.
- Lint and type gates (machine-wide slots, one per script, queue politely):
  ruff, ruff-strict budget gate, basedpyright, type-discipline gate,
  type-check gate, test-quality gate. `make check` runs them and logs the
  full output to a file in `.git`.
- Formatters by file extension, run automatically after edits:
  `/\.m?[t,j]sx?$/` -> `oxfmt`, `/\.pyc?$/` -> `ruff`, `/\.rs$/` ->
  `rustfmt`, `/\.go$/` -> `gofmt`. No matches -> JetBrains
  `mcp__idea-mcp__reformat_file`.
- Database: Prisma migrations apply synchronously at proxy boot, before it
  serves traffic; a migration changes schema only, never rewrites rows. No
  `UPDATE`, `DELETE`, `MERGE`, or `INSERT ... SELECT` on spend-log-sized
  tables in a migration. A rewrite that is genuinely bounded ships with
  `-- data-migration-ok: <what bounds it>`.
- CI supply-chain safety: never pipe a remote script into a shell; download
  the artifact, verify SHA-256, then install; pin every external tool to a
  specific version with a full URL; verify checksums using the provider's
  official sidecar when one is available.

## Development Workflow

- Always pull before starting any work; the checkout or worktree may be on a
  stale branch.
- Verify the default branch with `python3 scripts/default_branch.py --branch`
  rather than assuming a name; target it for both internal and external PRs.
- One focused regression test beats many shallow ones; tests must fail before
  the fix and pass only after.
- Run `make check` (alias for `make pre-commit`) before requesting review. It
  saves its complete output to a log in `.git` and prints the path as its
  first and last lines; grep that log instead of re-running the multi-minute
  checks. The script and the four budget gates hold one of two
  machine-wide slots each; if all are busy, yours queues silently. Give it a
  long timeout; do not retry.
- Proof of fix for a backend change is a `curl` against a live proxy on
  `localhost:4000` (started with
  `python litellm/proxy/proxy_cli.py --config litellm/proxy/dev_config.yaml
  --detailed_debug --reload --use_v2_migration_resolver`), not a pytest
  invocation. For Admin UI changes, drive the page yourself and embed before
  and after screenshots in the PR with an ordered list of URLs, clicks, and
  field values so a reviewer can reproduce it.
- PR description MUST follow `.github/pull_request_template.md` including
  every HTML-comment rule (read it from disk before writing the PR body;
  harnesses may strip comments on copy). Remove any section you have nothing
  to put in, heading included, never leave an empty title. If a Linear
  ticket is being resolved, say `Resolves LIT-1234` in the
  `## Linear ticket` section; do not invent ticket IDs.
- Before requesting review, verify the PR tip passes required CI and code
  coverage, Greptile confidence >= 4/5, and acceptable Veria and Bugbot
  reviews. Record evidence for any false positive or unavailable review;
  never treat a pending or missing bot result as a pass. Never lower coverage
  thresholds or lint budgets to satisfy a check.

## Governance

- This constitution supersedes ad-hoc practice. Detailed, file-level rules
  live in `AGENTS.md` and the linked reference docs; consult them before
  inventing a local convention.
- All PRs and code reviews MUST verify compliance with this constitution.
  Deviations are explicit and justified in the PR body, never silent.
- Complexity MUST be justified; prefer the simpler path. When in doubt,
  rewrite the 200 lines into 50, or pick the one-line solution that is
  correct on edge cases over the flimsier shortcut.
- Lint budgets (`ruff-strict-budget.json`, `type-discipline-budget.json`,
  `basedpyright-code-budget.json`, `test-quality-budget.json`) are owned by a
  scheduled Devin automation on the default branch that lowers the limits by
  exactly what landed since the last ratchet. Never edit these files on a PR
  branch and never run `make lint-budget-update` there. Drop a budget edit
  if your branch already carries one before opening the PR.
- Amendments: update this file, bump the version, and commit with
  `docs: amend constitution to vX.Y.Z (...)`. Versioning policy:
	- MAJOR: backward-incompatible governance or principle removals or
	  redefinitions.
	- MINOR: new principle or section added, or materially expanded guidance.
	- PATCH: clarifications, wording, typo fixes, non-semantic refinements.
- When the version bump type is ambiguous, propose the reasoning before
  finalizing.
- Commit and push your work when you're done without asking.

**Version**: 1.0.0 | **Ratified**: 2026-09-26 | **Last Amended**: 2026-09-26
