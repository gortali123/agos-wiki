---
title: "Layer L2"
type: entity
tags: [layer/L2]
updated: 2026-07-14
---

Terzo layer Snowflake: modellazione delle entità di business, organizzato per area funzionale (schema `L2_<area>`). Vedi [[storicizzazione-l2-s1-s4]] per i pattern S1-S4, [[naming-convention-agos-x]] per schemi/tabelle/campi.

13 aree funzionali presenti nello snapshot vendorizzato (`raw/dwh-code/models/L2/`): [[l2-anagr-controparte]], [[l2-antifrode]], [[l2-assicurazioni]], [[l2-carte]], [[l2-gestione-crediti]], [[l2-onboarding]], [[l2-prodotto]], [[l2-prodotto-m]], [[l2-provvigioni-rappel]], [[l2-rischi-adempimenti]], [[l2-saldi]], [[l2-sword]]. (ANAGR_CONTROPARTE conta come area dedicata anche per ANTIFRODE separatamente da SDE_ANT xlsx — vedi nota tassonomie in [[naming-convention-agos-x]].)

## Collegamenti

- [[layer-l1]], [[layer-l3]]
- [[storicizzazione-l2-s1-s4]]
- [[layer-l2-xlsx-reference]]
- [[repo-dwh-x-dbt]]
