---
title: LLM Wiki Pattern (source idea document)
type: raw-source
tags: [meta]
updated: 2026-07-07
---

# LLM Wiki

A pattern for building personal knowledge bases using LLMs.

This is an idea file, it is designed to be copy pasted to your own LLM Agent (e.g. OpenAI Codex, Claude Code, OpenCode / Pi, or etc.). Its goal is to communicate the high level idea, but your agent will build out the specifics in collaboration with you.

## The core idea

Most people's experience with LLMs and documents looks like RAG: you upload a collection of files, the LLM retrieves relevant chunks at query time, and generates an answer. This works, but the LLM is rediscovering knowledge from scratch on every question. There's no accumulation. Ask a subtle question that requires synthesizing five documents, and the LLM has to find and piece together the relevant fragments every time. Nothing is built up. NotebookLM, ChatGPT file uploads, and most RAG systems work this way.

The idea here is different. Instead of just retrieving from raw documents at query time, the LLM **incrementally builds and maintains a persistent wiki** — a structured, interlinked collection of markdown files that sits between you and the raw sources. When you add a new source, the LLM doesn't just index it for later retrieval. It reads it, extracts the key information, and integrates it into the existing wiki — updating entity pages, revising topic summaries, noting where new data contradicts old claims, strengthening or challenging the evolving synthesis. The knowledge is compiled once and then *kept current*, not re-derived on every query.

This is the key difference: **the wiki is a persistent, compounding artifact.** The cross-references are already there. The contradictions have already been flagged. The synthesis already reflects everything you've read. The wiki keeps getting richer with every source you add and every question you ask.

You never (or rarely) write the wiki yourself — the LLM writes and maintains all of it. You're in charge of sourcing, exploration, and asking the right questions. The LLM does all the grunt work — the summarizing, cross-referencing, filing, and bookkeeping that makes a knowledge base actually useful over time.

## Architecture

Three layers: **raw sources** (immutable), **the wiki** (LLM-owned markdown), **the schema** (CLAUDE.md/AGENTS.md — tells the LLM how to maintain the wiki).

## Operations

- **Ingest** — read a source, summarize, update entity/concept pages, update index, append to log.
- **Query** — search index, read relevant pages, synthesize with citations; file substantive answers back as new pages.
- **Lint** — periodically check for contradictions, staleness, orphan pages, missing pages, missing cross-references.

## Indexing and logging

`index.md` is content-oriented (catalog with one-line summaries). `log.md` is chronological and append-only, with a consistent line prefix so it's greppable (`grep "^## \[" log.md`).

(See original document for full text, tips on Obsidian Web Clipper, image handling, Marp, Dataview, and the Memex framing.)
