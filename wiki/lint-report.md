# Wiki Lint Report — 2026-10-28

| # | Check | Severity | Page | Finding | Suggested fix |
|---|-------|----------|------|---------|---------------|
| - | - | - | - | No findings. | - |

## Run summary

| Check | Count | Severity |
|-------|-------|----------|
| index-drift | 0 | mechanical |
| links | 0 | mechanical |
| orphans | 0 | structural |
| contradictions | 0 | semantic |
| stale | 0 | semantic |
| citations | 0 | semantic |

All six checks pass. Mechanical fixes applied under `lint.auto_fix: index-and-links`:

- `INDEX.md` regenerated from `pages/` frontmatter: 28 pages across the 5 page types (3 concept, 6 decision, 11 component, 2 reference, 6 howto).
- No link repairs needed, every relative link resolved.
- No broken citations, all 49 registered S-ids are cited on at least one page, and every S-id cited on a page is registered.

Findings resolved inline before this pass reported clean:

- `spend-logging.md` carried the wrong attribution claim. It said the existing `used_client_oauth_token` flag "marks that the request was served by the caller's own forwarded provider credential", which is only true for Anthropic. The flag is gated on `ANTHROPIC_OAUTH_FORWARD_PROVIDERS`, so both true and false collapse to false for a chatgpt request. The claim was corrected to name the Anthropic gate, and the subscription attribution moved to its own page, because that detail pushed the page past the 600-word cap.
- The subscription attribution now lives in `credential-attribution.md`, split from `spend-logging.md` per the schema's split rule. Both halves link to each other.
- `model-scoped-credential-forwarding.md` gained the attribution decision when the cross-artifact analysis found the design could not work. That page was already near the cap, so it carries a short pointer to `credential-attribution.md` rather than the full rationale.

Coverage note (not a finding):

- `pr-and-issues.md` is 644 words, over the 600-word cap. It was already over before this pass and was not touched by this ingest, so splitting it belongs to the ingest that added its second half rather than to this one.
- The wiki directory was restored from `origin/chore/litellm_init-wiki`, the branch that holds it. It had never landed on the working branch, so the ingest had no wiki to write into until it was brought over. `wiki/` is additive here, since the branch had no `wiki/` directory of its own.

Pages: 28. Sources: 49. Caps honoured: every page this ingest created or updated is under 600 words.
