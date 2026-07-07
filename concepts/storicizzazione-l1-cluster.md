---
title: Storicizzazione L1 (Cluster A/B/C)
type: concept
tags: [layer/L1, storicizzazione]
updated: 2026-07-07
---

Modalità di storicizzazione dei record a parità di chiave logica in [[layer-l1]], classificate in [[cfg-l1-cluster-sto]] per archivio.

## Cluster A

Archivi con una data tra i campi chiave, o popolati sempre per inserimento. Delta giornaliero = solo insert; eventuali update (bonifiche puntuali) sostituiscono direttamente il record. Strategia: **INSERT/UPDATE**, materializzazione DBT **incremental / merge**.

## Cluster B

Archivi ricevuti come fotografia completa ogni giorno. Strategia: **FULL** (TRUNCATE/INSERT ad ogni ricezione), nessuna storicizzazione necessaria. Materializzazione DBT **incremental / insert_overwrite**.

## Cluster C

Archivi che richiedono storicizzazione vera (SCD2 — Slowly Changing Dimensions tipo 2): nuovo record ad ogni update di chiave, record precedenti invalidati logicamente via `TS_INIZIO_VALIDITA`/`TS_FINE_VALIDITA`. Implementato con **snapshot DBT, strategia timestamp** (basata su `LastModifiedDate`). Richiede un modello intermedio **ephemeral** di tipizzazione (`stg_<modello>.sql` + `.yml`), che alimenta lo snapshot.

## Fotografie full mensili

Per alcuni archivi di Cluster B/C: scarico aggiuntivo mensile OCS con i dati a chiusura consolidata del mese, caricato in una tabella L1 dedicata in modalità **APPEND** (materializzazione incrementale append) — parallela alla tabella giornaliera.

## Cluster D (trovato nel codice, non documentato in nessun documento)

Scoperto in `templates/models/L1/D/` in `raw/dwh-code` (2026-07-07), assente da entrambi i documenti di framework e dalla guida sviluppo. Materializzazione **incremental / append**, con:
- `pre_hook: delete_month(get_dt_osservazione('ts_riferimento'))` — cancella e ricarica il mese osservato ad ogni run (idempotenza, stesso pattern di [[storicizzazione-l2-s1-s4]] S3).
- PK composta da chiave funzionale + `DT_OSSERVAZIONE`.
- Campi tecnici: `ts_riferimento`, `ts_caricamento`, **`sys_change_operation`**, `lastmodifieddata`, `dt_osservazione`, `rowid`.

Il campo `sys_change_operation` è tipico del **CDC (Change Data Capture) di SQL Server** — suggerisce che il Cluster D sia usato per sorgenti alimentate via CDC (es. SWORD/SQL Server), con logica di storicizzazione mensile via append invece che SCD2 continua. **Confermato reale dall'utente (2026-07-08)**: va formalmente definito e aggiunto al documento di framework insieme ai sotto-cluster A1/A2 — vedi [[todo-allineamento-documentazione]].

## Nota

I sotto-cluster A1/A2 (citati in guida sviluppo) sono reali ma ancora non formalmente definiti — vedi [[cfg-l1-cluster-sto]] e [[todo-allineamento-documentazione]].

## Collegato da
[[layer-l1]], [[cfg-l1-cluster-sto]], [[agosx-caricamento-l0-l1]]
