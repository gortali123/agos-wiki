---
title: "L2 ANTIFRODE"
type: entity
tags: [layer/L2, area/ANTIFRODE]
updated: 2026-07-14
---

Modelli (`raw/dwh-code/models/L2/ANTIFRODE/`): `archivio_tessere`, `gestione_truffe`. Entrambi S2 (append), nessun `query_tag`, nessun `pre_hook delete_l2`.

**`archivio_tessere`** filtra `FL_DELETED = 'N'` direttamente nel blocco incrementale, senza cancellazione fisica — approccio diverso da [[l2-anagr-controparte]] (vedi [[cancellazioni-fl-deleted]] per la nota sui due approcci non equivalenti).

## Collegamenti

- [[layer-l2]]
- [[cancellazioni-fl-deleted]]
