---
title: The LLM Wiki pattern
type: concept
sources: [S001]
updated: 2026-09-26
---

The pattern this wiki implements: instead of re-deriving knowledge from raw documents on every question, the LLM incrementally maintains a persistent, interlinked set of markdown pages that compounds over time (S001).

Three layers (S001):

- **Raw sources**; curated, immutable documents the LLM reads but never edits. The source of truth.
- **The wiki**; a directory of LLM-written markdown pages (summaries, entity pages, concept pages, decisions). The LLM owns this layer end to end.
- **The schema**; a configuration document (`SCHEMA.md` here) that tells the LLM the page types, naming, linking, and citation policy. Without it the LLM acts like a generic chatbot; with it the LLM acts like a disciplined wiki maintainer.

Three operations (S001):

- **Ingest.** Read a source, extract what outlives the moment (decisions, constraints, gotchas, verified facts), update the few pages that absorb it with per-claim citations, keep cross-references consistent, mark but do not erase conflicts.
- **Query.** Answer strictly from wiki pages; report coverage gaps as concrete ingest suggestions.
- **Lint.** Mechanical drift (broken links, missing index entries) auto-fixed; semantic drift (contradictions, orphan pages, stale claims, uncited claims) reported as suggested edits only.

Why it works: humans abandon wikis because maintenance (updating cross-refs, noting contradictions, keeping summaries current) grows faster than value; an LLM handles that bookkeeping cheaply (S001). The schema is the load-bearing file; invest in it first, the wiki generates itself (S001).

The architectural analogy is a compiler: sources are source code, the wiki is the intermediate representation, ingest is compilation, query is code generation from the IR, lint is an optimization pass that detects dead code, undefined references, and stale constants (S001).

This wiki operationalizes the pattern; see [The wiki pipeline](./wiki-pipeline.md) for how the three operations are implemented here, with caps, citations, and conflict markers. The pattern also motivates shared helpers over per-surface duplication, and [Prompt template factory](./prompt-template-factory.md) is the litellm-specific instance: one file normalizes chat completions, Anthropic Messages, Responses API, Bedrock Converse, and provider-specific tool-call shapes, instead of letting every guardrail or integration re-parse the format.
