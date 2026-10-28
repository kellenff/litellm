---
title: PRs and issues
type: howto
sources: [S061, S062, S063, S064, S007, S065]
updated: 2026-09-27
---

How to write PRs, bug reports, and feature requests in this repo (S061, S062, S063, S064, S007).

The PR template lives in `.github/pull_request_template.md`, and its HTML comments are rules, not layout hints (S061, S007). Agent harnesses may strip those comments, so read the file from disk before writing a PR body. Sections with nothing under them (Relevant issues, Affected release, Linear ticket, Caveats, QA runbook) are dropped entirely, heading included.

PR sections and what each carries (S061):

- TLDR. Short bullets naming problem and fix, roughly ten words max. If the PR changes what users see, add an "Intentional product change:" line.
- User Flow. Two ordered lists, Before and After, walking the same end user through the same task. Every step is something the user does or observes (HTTP, URL, status, response shape, or Admin UI URL). No LiteLLM internals: never name functions, files, DB tables, config classes, hooks, or code paths.
- Relevant issues. Drop if none.
- Affected release. Only for a regression in a released or rc version; name the version and add the `backport-stable` label.
- Linear ticket. Internal contributors only; "Resolves LIT-1234" with the real id. If you do not have it, drop the section rather than guessing (S007).
- Pre-Submission checklist. Five boxes: meaningful tests, Greptile confidence at least 4/5, scope isolation, CI pass, local test pass.
- Screenshots / Proof of Fix. `Before (<hash>)` and `After (<hash>)` with the same case names in the same order on both sides. Proof must be end-to-end with no mocks, hitting real LLM APIs and costing real money; `pytest` commands are not enough (S007).
- Type. Pick one of New Feature, Bug Fix, Refactoring, Documentation, Infrastructure, Test.
- Caveats. Group under Severe, High, Medium, Low; drop empty tiers.
- QA runbook. Required only when `tests/e2e/` is edited; one bullet per test giving its pytest node id and a reviewer checklist.
- Final Attestation. Single checkbox that regressions in real-world customer use cases are not possible after this PR.

Bug reports use `.github/ISSUE_TEMPLATE/bug_report.yml` (S062, S063). Required: Description, Config (rendered as yaml), LiteLLM Version, Steps to Repro (the curl and full response, or page URL plus screenshot for UI bugs). Optional dropdowns narrow which part of LiteLLM is affected and how you deploy. Never paste a real API key, virtual key, database URL, or any credential.

Feature requests use `.github/ISSUE_TEMPLATE/feature_request.yml` (S064). Required: the duplicate-check checkbox, The Feature, User Flow (same Before/After ordered lists as the PR template, no LiteLLM internals), and How far you got (run as many After steps as you can against a live proxy on `localhost:4000`, paste curl and full output, end at the dead-end, say in user terms what stopped you). Optional: the hiring-interest radio and a social handle for credit.

All three documents are public-facing; never mention a customer or customer company name (S007). Say "a customer" or "the customer" instead. The exception is publicly known providers or vendors (OpenAI, Anthropic, AWS Bedrock) and only when the change adds general support for that provider, not when requested by them.

Human-facing text in PRs, issues, commit messages, and release notes follows the same style guide (S007): no emojis, no em dashes, no "It's not X, it's Y" framing, prose over bullets when bullets do not help, no trailing "." at paragraph end. GitHub comments must stay human-readable and 15 to 25 words max (S007).

A commit made with `git commit --no-verify` carries a `Skipped-Hooks: pre-commit` trailer in the commit message body, so reviewers can grep for bypassed hooks per commit (S065). `git log --format='%H %s%n%b' | grep -B1 '^Skipped-Hooks: pre-commit'` lists every commit where the pre-commit framework was bypassed. See [Bypass visibility mechanism](./bypass-visibility-mechanism.md) for how the trailer is produced.

Related: [Test conventions](./test-conventions.md), [Repo dev loop](./dev-loop.md), [PR target branch](./pr-target-branch.md), [Bypass visibility mechanism](./bypass-visibility-mechanism.md).
