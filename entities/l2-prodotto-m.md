---
title: "L2 PRODOTTO_M"
type: entity
tags: [layer/L2, area/PRODOTTO_M]
updated: 2026-07-14
---

Versioni mensili consolidate di [[l2-prodotto]]: `carta_m`, `consumo_m`, `cqs_m`, `pratica_m` (`raw/dwh-code/models/L2/PRODOTTO_M/`).

**`pratica_m`** — S3 (append mensile), `unique_key: [CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE]`, `pre_hook: delete_month()` (verificato: default `column='DT_OSSERVAZIONE'`, no-op se la tabella target non esiste ancora). `FL_DELETED='N'` filtrato su più CTE sorgente. Nessun `query_tag`.

## Collegamenti

- [[layer-l2]]
- [[l2-prodotto]]
- [[storicizzazione-l2-s1-s4]]
