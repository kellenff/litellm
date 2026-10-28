---
title: Test mirroring convention
type: concept
sources: [S007]
updated: 2026-09-26
---

`tests/test_litellm/` mirrors `litellm/` in a parallel path (S007). See `tests/test_litellm/readme.md` for the directory map.

Naming (S007):

- Default: `test_<filename>.py`.
- Many provider directories use longer descriptive names (e.g. `test_anthropic_chat_transformation.py`) to avoid ambiguity across sibling folders. Match the existing convention in the directory you touch.

When to edit vs. create (S007):

- Bug fix: extend the existing mapped test file. A new test file is justified only for a new feature (provider, endpoint, transformation module) that has no mapped test yet.
- One focused regression beats many shallow ones; they must fail before the fix and succeed only when the feature is fully working.

Tests must fail when litellm code changes, never from external facts (S007):

- Never pin a vendor's price, a third party's field, an upstream default, or today's date as a literal.
- Never assert "X must be absent" to the structure of an outside product.
- If an outside fact is load-bearing, cite its source and date next to the assertion.

Coverage and quality (S007):

- A test that doesn't fail when broken is failure-shaped noise; add tests that fail before the feature and pass only after.
- Run mutation testing; aim for > 90% kill rate.

Related: [Test conventions](./test-conventions.md), [Repo dev loop](./dev-loop.md).
