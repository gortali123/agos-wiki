---
title: "Layer L3"
type: entity
tags: [layer/L3]
updated: 2026-07-14
---

Quarto layer Snowflake: datamart/processi derivati da L2, organizzato per processo (schema `L3_<processo>`). Vedi [[storicizzazione-l3]] per S2-S4 riusati e il pattern S5 (SCD2 mensile).

Nello snapshot vendorizzato: `raw/dwh-code/models/L3/{basilea_core,monitoraggio_produzione}`. `basilea_core` include datamart PD/LGD/CCF/RWA/EAD/EL (vedi macro `check_*` e report MasterScale in [[macro-catalogo-dbt]]).

## Collegamenti

- [[layer-l2]]
- [[storicizzazione-l3]]
- [[repo-dwh-x-dbt]]
