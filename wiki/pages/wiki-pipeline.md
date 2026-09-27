---
title: The wiki pipeline
type: component
sources: [S002, S003, S004, S005, S006]
updated: 2026-09-26
---

The wiki lives at `wiki/` (S002) and is ordinary markdown committed to the repo; diffable, PR-reviewable, agent-agnostic.

Configuration (`wiki-config.yml`) owns the caps; `SPECKIT_WIKI_*` env and per-command `key=value` overrides rank higher than the file (S002). Resolved defaults are 12 pages per ingest, 600 words per page, 8-page query slice, 4000 token context budget, 90-day staleness, `auto_fix: index-and-links` (S002). `auto_fix: index-and-links` is chosen (not `none`) so `INDEX.md` cannot drift, while semantic issues stay human-reviewed.

The five commands and what each may write (S003, S006):

| Command | Touches disk | What it may write |
|---|---|---|
| `speckit.wiki.init` | `SCHEMA.md`, `INDEX.md`, `sources.md` | Skeleton only; never overwrites, never pre-populates pages. |
| `speckit.wiki.ingest` | pages, `INDEX.md`, `sources.md` | The only operation that writes knowledge. Cites every claim. |
| `speckit.wiki.query` | none | Read-only. Answers strictly from pages. |
| `speckit.wiki.lint` | `lint-report.md`, plus `INDEX.md` and link repairs | Mechanical fixes only; never rewrites prose. |
| `speckit.wiki.status` | none | Read-only one-screen snapshot. |

Hooks (`after_plan`, `after_implement`) optionally prompt to ingest right when knowledge is produced, with no extra ceremony (S003).

Key rules a reader needs to internalize (S002, S006):

- Pages live in `pages/`, one topic per page, kebab-case filenames.
- Every synthesized claim carries a `(Sxxx)` citation; conflicting claims stay side-by-side under a `> ⚠ conflict:` marker; never silently overwritten.
- Pages that outgrow 600 words split; both halves link each other.
- Sources are immutable inputs; the wiki never edits them; corrections go in pages.

Cross-references use relative markdown links with sibling paths, so the wiki is portable regardless of `state.directory` (S006). `index.md` is the only file lint may regenerate; `lint-report.md` is the only file lint may overwrite wholesale (S006). See [The LLM Wiki pattern](./llm-wiki-pattern.md) for the underlying idea this configuration encodes.

See [The wiki extension](./speckit-extension-wiki.md) for how the extension registers these commands.
