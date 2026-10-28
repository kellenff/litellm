---
title: Test conventions
type: howto
sources: [S060, S007]
updated: 2026-09-26
---

How to add tests in this repo without producing coverage-shaped noise (S060, S007).

The parallel-path mirror. `tests/test_litellm/` mirrors `litellm/` one-to-one and may only contain mocked tests, so contributors can run them without LLM API keys (S060). The default file name is `test_<​filename>.py`, but many provider directories already use longer descriptive names such as `test_anthropic_chat_transformation.py` to avoid ambiguity across sibling folders; match the existing convention in the directory you touch (S060, S007).

Extend the existing mapped file when you fix a bug; do not create a new one (S007). One focused regression beats many shallow tests, and the new test must fail before the fix and pass only when the bug is actually gone. Aim for more than 90% kill rate under mutation testing (S007).

Create a new test file only when adding a new feature (a provider, endpoint, or transformation module) that has no mapped test yet (S007). A second file for the same module is just sprawl.

Tests must fail only when litellm code changes (S007). Never pin a vendor's price, a third party's field, an upstream default, or today's date as a literal; assert the invariant the code guarantees instead (two rows agree, a value is within range, one field is derived from another). When an outside fact really is load-bearing, cite its source and date next to the assertion so a reader can tell stale from broken. Never test structure only; iterating `expected_body.items()` cannot see an extra key, while asserting on the whole value can.

End-to-end tests belong in `tests/e2e/` and follow that directory's harness conventions (S060, S007).

Proof of fix is `curl` against a live proxy on `localhost:4000`, not `pytest` (S007). Start the proxy with:

```bash
python litellm/proxy/proxy_cli.py \
  --config litellm/proxy/dev_config.yaml \
  --detailed_debug --reload --use_v2_migration_resolver \
  2>&1 | tee litellm.log
```

then run `curl` (or a short `for` loop) against it and paste both the command and the output in the PR. The Admin UI dev server is `npm run dev` in `ui/litellm-dashboard`, served on port 3000. `pytest` output is not acceptable proof; the user-facing reproduction costs real money on real APIs, and that is the most realistic check.

Related: [Test mirroring convention](./test-mirroring.md), [Repo dev loop](./dev-loop.md), [Proxy dev config](./proxy-dev-config.md), [PRs and issues](./pr-and-issues.md).
