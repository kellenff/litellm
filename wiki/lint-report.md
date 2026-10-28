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

- `INDEX.md` regenerated from `pages/` frontmatter: 27 pages across the 5 page types (3 concept, 6 decision, 10 component, 2 reference, 6 howto).
- No link repairs needed, every relative link resolved.
- No broken citations, all 48 registered S-ids are cited on at least one page, and every S-id cited on a page is registered.

Findings resolved inline before this pass reported clean:

- `model-scoped-credential-forwarding.md` grew past the 600-word cap once the fallback-naming material was folded into it. Split per the schema's split rule into `model-scoped-credential-forwarding.md` (the scope decision and its enforcement point) and `model-scope-and-fallback-naming.md` (the naming split and the rejected alternatives). Both halves link to each other.
- The same paragraph had been added to `routing-decisions.md`, which pushed that page past the cap as well. It moved to `model-scoped-credential-forwarding.md`, which had room, and `routing-decisions.md` now points there through its Related line.

Coverage note (not a finding):

- `pr-and-issues.md` is 644 words, over the 600-word cap. It was already over before this pass and was not touched by this ingest, so splitting it belongs to the ingest that added its second half rather than to this one.
- The wiki directory was restored from `origin/chore/litellm_init-wiki`, the branch that holds it. It had never landed on the working branch, so the ingest had no wiki to write into until it was brought over. `wiki/` is additive here, since the branch had no `wiki/` directory of its own.

Pages: 27. Sources: 48. Caps honoured: every page this ingest created or updated is under 600 words.
