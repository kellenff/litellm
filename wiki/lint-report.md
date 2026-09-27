# Wiki Lint Report — 2026-09-26

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

- `INDEX.md` regenerated from `pages/` frontmatter: 19 pages across the 5 page types (2 concept, 3 decision, 7 component, 2 reference, 5 howto).
- No link repairs needed — every relative link resolved.
- No broken citations — all 42 S-ids cited on pages are registered in `sources.md`, and every registered source is cited at least once.

Two findings were resolved inline before this pass reported clean:

- `prompt-template-factory.md` was an orphan (no inbound page link). Added a one-line inbound from `llm-wiki-pattern.md` (the concept page that motivates the shared-helper pattern).
- `ci-budgets.md` carried a self-flagged `> conflict:` marker. The conflict was internal framing — the workflow enforces direction, the JSON shape files are direction-agnostic by design. Rephrased as a normal paragraph so the resolution is documented and the marker is gone.

Coverage note (not a finding):

- Three backlog items in `wiki/INGEST-TODO.md` were skipped because their sources are absent from this checkout: `docs/my-website/docs/completion/` (the entire `docs/` subtree has zero files in `git ls-files`); `litellm/router_utils/README.md`; `.github/workflows/ci.yml` (only `test-linting.yml`, `ci-coverage.yml`, `publish-basedpyright-base-counts.yml`, etc. exist).
- The `litellm/llms/<provider>/` item is a per-provider template; the TODO's own recommended order defers it to "one at a time, as the first question on each provider comes up" so this pass does not create 139 speculative pages.
- Six "Working artifacts to re-ingest when they change" items are conditional triggers; `specs/` does not exist in this checkout. They are standing rules, not a backlog, and are recorded as such in `INGEST-TODO.md`.

Pages: 19. Sources: 42. Caps honoured: every page under 600 words.
