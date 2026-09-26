---
title: The wiki extension
type: component
sources: [S003, S004]
updated: 2026-09-26
---

The extension is registered by `.specify/extensions/wiki/extension.yml` against Spec Kit version `>=0.2.0` (S003). Its category is `docs`; its effect is `read-write`.

It provides (S003):

- Five commands: `speckit.wiki.init`, `speckit.wiki.ingest`, `speckit.wiki.query`, `speckit.wiki.lint`, `speckit.wiki.status`.
- One optional config file: `wiki-config.yml` (template `config-template.yml`).
- Two optional hooks: `after_plan` and `after_implement`, both invoking `speckit.wiki.ingest` with a confirmation prompt (S003).

The extension's own README explains the install paths and how it complements, rather than competes with, `OpenWiki` (code documentation derived from code) and personal-memory extensions (S004). The division of labour: code derivable from code lives in OpenWiki, decisions and constraints that live only in conversation get caught here (S004).

Each command's full spec lives in `.specify/extensions/wiki/commands/speckit.wiki.<name>.md`, and those specs are the canonical description of what that command does; pages cite them rather than paraphrasing (S003). Cross-reference [The wiki pipeline](./wiki-pipeline.md) for the operational summary and cap table.
