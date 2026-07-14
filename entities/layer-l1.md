---
title: "Layer L1"
type: entity
tags: [layer/L1]
updated: 2026-07-14
---

Secondo layer Snowflake: tipizzazione e storicizzazione 1:1 rispetto a L0, tramite modelli DBT. Vedi [[storicizzazione-l1-cluster-a-b-c]] per la classificazione cluster A/B/C(/D) e [[cancellazioni-fl-deleted]] per le cancellazioni logiche.

Nello snapshot vendorizzato, presente per ADOBE, CRIF, CTC, OCS (`raw/dwh-code/models/L1/`), con snapshot SCD2 solo per `OCS/AIN` (`raw/dwh-code/snapshots/L1/OCS/AIN/`).

Dettagli completi: [[caricamento-layer-l0-l1]], [[guida-sviluppo]].

## Collegamenti

- [[layer-l0]], [[layer-l2]]
- [[storicizzazione-l1-cluster-a-b-c]]
- [[repo-dwh-x-dbt]]
