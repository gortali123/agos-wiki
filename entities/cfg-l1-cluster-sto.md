---
title: TECH.CFG_L1_CLUSTER_STO
type: entity
tags: [layer/L1, config-table]
updated: 2026-07-07
---

Tabella di configurazione che associa ogni archivio L1 alla sua tipologia di storicizzazione (Cluster A/B/C, vedi [[storicizzazione-l1-cluster]]) e alla relativa strategia. Letta dalle macro di generazione modelli L1 (`generate_yaml`, `generate_model`, `generate_snapshot`, `generate_source`), insieme a [[cfg-l1-schema]].

## Sotto-cluster A1/A2

Confermato dall'utente (2026-07-07): i sotto-cluster **A1/A2**, citati dalla guida sviluppo ma mai definiti in nessun documento, sono reali — non un refuso. Restano da documentare formalmente (criterio di distinzione A1 vs A2) sia in wiki sia nel documento di framework ufficiale, che oggi parla solo di "Cluster A" generico. Vedi [[todo-allineamento-documentazione]].

## Collegato da
[[layer-l1]], [[storicizzazione-l1-cluster]], [[agosx-caricamento-l0-l1]], [[guida-sviluppo]]
