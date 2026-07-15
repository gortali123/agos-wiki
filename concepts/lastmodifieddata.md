---
title: "LASTMODIFIEDDATA"
type: concept
tags: [layer/L2, convention, storicizzazione]
updated: 2026-07-15
---

Campo tecnico presente su (quasi) tutti i modelli L2, con due ruoli distinti:

1. **Ordine colonne**: sempre l'ultimo campo dello schema (regola d'ordine da [[caricamento-layer-l2]]: campi di storicizzazione subito dopo la PK funzionale, `LASTMODIFIEDDATA` in coda).
2. **Filtro incrementale**: fonte di verità per capire cosa è "nuovo" da caricare, in due varianti a seconda del pattern di [[storicizzazione-l2-s1-s4]]:
   - **S1 (SCD2)**: usato da `is_incremental_S1(...)` (macro in [[macro-catalogo-dbt]]) per individuare righe con `LASTMODIFIEDDATA` più recente del max in target, escluso dall'hash di dedup (`hash_cols([...])`, vedi [[guida-sviluppo]]).
   - **S2 (append giornaliero)**: blocco incrementale diretto `LASTMODIFIEDDATA > MAX(...)` (vedi [[guida-sviluppo]]).
   - **S3 (append mensile)**: non usato per il filtro incrementale (si usa `DT_OSSERVAZIONE`), resta solo come campo tecnico in coda.
   - **S4 (attualizzato)**: non applicabile, full overwrite.
3. **Cancellazioni**: `delete_l2(...)` confronta `TS_DELETED` del sorgente col max `LASTMODIFIEDDATA` del target per decidere quali righe cancellare fisicamente — vedi [[cancellazioni-fl-deleted]].

## Collegamenti

- [[storicizzazione-l2-s1-s4]]
- [[caricamento-layer-l2]]
- [[guida-sviluppo]]
- [[macro-catalogo-dbt]]
- [[cancellazioni-fl-deleted]]
