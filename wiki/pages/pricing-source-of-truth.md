---
title: Pricing source of truth
type: reference
sources: [S007]
updated: 2026-09-26
---

When referencing or running models in this repo; coding, QA, docs, tests; use the **latest** model in that family unless otherwise specified (S007).

Treat your training knowledge, memories, configs, and tests as stale. Determine the family's latest from `model_prices_and_context_window.json` (which the `auto_update_price_and_context_window.yml` workflow refreshes) or via web search (S007). Do not pin a price, context window, or capability assertion as a literal in a test without the source-and-date citation (S007); see [Test mirroring convention](./test-mirroring.md) for the "never pin facts we don't own" rule.

Related: [Test mirroring convention](./test-mirroring.md).
