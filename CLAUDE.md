# AGOS Wiki — Schema & Maintainer Instructions

This is a persistent, LLM-maintained knowledge base about the `my_dwh-x-dbt` project (and related DWH/dbt work at Agos). You (the LLM) own the `wiki` layer entirely: you read raw sources and write/update markdown pages. The user reads the wiki in Obsidian and directs what gets ingested or investigated.

Full background on the pattern this follows: see `raw/llm-wiki-pattern.md`.

## Layers

- **raw/** — immutable source material: pasted docs, exported specs, meeting notes, links to code in `my_dwh-x-dbt` (referenced by path, not copied), screenshots, etc. Never edit files here except to add new ones.
- **raw/dwh-code/** — plain vendored copy (regular tracked files, not a git submodule) of relevant parts of the `my_dwh-x-dbt` dbt project: macros, L2/L3 models, a sample of L1 models — not necessarily everything. Synced manually by the user from the live GitLab repo via `raw/dwh-code/sync-from-dwh-x-dbt.ps1`, then pushed to `https://github.com/gortali123/my_dwh-x-dbt` and re-copied here. Treated like the rest of `raw/`: never edit, only read. Its presence lets wiki pages cite real, Obsidian-openable paths (e.g. `raw/dwh-code/macros/add_datamask.sql`) instead of bare text paths. It is a pinned snapshot, not live — see staleness note below.
- **entities/** — one page per concrete thing: a dbt model, a source table, a business entity (e.g. "ANAGR_CONTROPARTE"), a layer (L1/L2/L3), a person/team.
- **concepts/** — one page per idea/pattern that cuts across entities: business rules, data lineage patterns, naming conventions, recurring transformations (e.g. "variazioni anagrafiche" logic), glossary terms.
- **sources/** — one summary page per raw source ingested, with key takeaways and links to the entity/concept pages it touched.
- **queries/** — saved answers to substantive questions the user asked, filed back as pages so the analysis compounds instead of disappearing into chat history.
- **index.md** — catalog of every page in the wiki, one line each, grouped by folder.
- **log.md** — append-only chronological record of ingests/queries/lints.

## Conventions

- Use Obsidian `[[wikilink]]` syntax (link by filename without extension) for all cross-references.
- Every page gets YAML frontmatter:
  ```yaml
  ---
  title: <human title>
  type: entity | concept | source | query
  tags: [layer/L2, domain/anagrafica, ...]
  updated: <YYYY-MM-DD>
  ---
  ```
- Filenames: kebab-case, no spaces, matching the `title`.
- When a source or answer touches code that exists in `raw/dwh-code/`, cite the path relative to it (e.g. `raw/dwh-code/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql`) so it's a real, clickable path in Obsidian — rather than copying large code blocks. The repo is the source of truth for code, the wiki is the source of truth for *synthesized understanding*.
- If code is referenced but not present in `raw/dwh-code/` (e.g. it lives only in the live GitLab repo, not yet copied over), cite the path as plain text against `my_dwh-x-dbt` (no link) and note that it isn't in the local snapshot.
- When the user says they've re-run the sync/re-uploaded the code, re-check any wiki page whose staleness note predates that update — `raw/dwh-code/` is a plain folder, so refreshing it means the user replaces the files directly (no submodule pull step).
- Keep pages honest about staleness: if a claim came from code, note the date you checked it; code changes without the wiki knowing.

## Workflows

### Ingest
Triggered when the user drops something in `raw/` or points at a dbt model/doc and says "ingest this."
1. Read the source in full (or the referenced code/model).
2. Summarize key takeaways with the user if the source is substantial — don't just silently write pages.
3. Write/update a `sources/` page for it.
4. Update or create relevant `entities/` and `concepts/` pages, adding cross-links.
5. Append an entry to `log.md`.
6. Update `index.md`.

### Query
Triggered when the user asks a question about the domain.
1. Read `index.md` first to find candidate pages.
2. Drill into relevant entity/concept/source pages (and the live repo if the wiki doesn't yet cover it).
3. Synthesize an answer with citations to wiki pages and/or repo paths.
4. If the answer is substantive and reusable, offer to file it as a `queries/` page and link it from the relevant entity/concept pages.
5. Append an entry to `log.md` if a new page was filed.

### Lint (run when asked, e.g. "lint the wiki")
Check for and report:
- Orphan pages (no inbound `[[links]]`) — via `index.md` and a grep for links.
- Contradictions between pages.
- Claims that look stale vs. current repo state (e.g. an entity page describing a model that has since changed — spot check the actual file).
- Concepts mentioned in multiple pages but lacking their own `concepts/` page.
- Missing cross-references between clearly related pages.

## Log format

Each `log.md` entry starts with a consistent prefix so it stays greppable:
```
## [YYYY-MM-DD] ingest | <source title>
## [YYYY-MM-DD] query | <question, short>
## [YYYY-MM-DD] lint
```

## Notes specific to this project

- The DWH project's live source of truth is the GitLab repo `dwh-x-dbt` (see `sources/guida-sviluppo.md` for clone URL). A curated copy — macros, L2/L3 models, and a sample of L1 models (not exhaustive) — is vendored into this wiki as plain files at `raw/dwh-code/` (also mirrored on GitHub at `https://github.com/gortali123/my_dwh-x-dbt`, but that's just the user's backup/publish target, not something this repo depends on). Treat `raw/dwh-code/` as a pinned snapshot: it can lag behind GitLab, and it deliberately doesn't include every L1 model. When a claim needs verifying against code that isn't in `raw/dwh-code/`, say so rather than assuming it matches.
- A separate local clone at `C:\Users\g.ortali\work\my_dwh-x-dbt` may also exist on this machine for direct grep/read access outside the vault — useful for verification even when not linked from wiki pages.
- Domain is Italian financial services (Agos) — expect Italian naming (ANAGR_CONTROPARTE = anagrafica controparte, variazioni anagrafiche = counterparty registry change history). Keep glossary entries in `concepts/` for recurring Italian domain terms.
