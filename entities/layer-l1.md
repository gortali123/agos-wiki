---
title: Layer L1
type: entity
tags: [layer/L1]
updated: 2026-07-07
---

Secondo layer Snowflake: dato tipizzato e storicizzato, con granularità identica alla sorgente (L0→L1 è sempre **1:1**, stessa struttura di campi al netto dei campi tecnici). Popolato da DBT.

## Triggering

- Scatenato dal completamento OK/OK-con-warning del job L0 relativo al modulo (tre esiti possibili per il job Glue L0: KO, OK, OK con warning).
- Un job Control-M = un comando dbt = un modello = una tabella L1 (alta granularità).
- Comando standard: `dbt build -s +<model_name>` — il `+` include l'esecuzione dei test sulle source L0 (`primary_key_table`, `try_cast_table`, vedi [[data-quality-controlli]]). I test sulle source si eseguono **solo in L1**: il comando L2 (senza `+`, vedi [[layer-l2]]) è quindi corretto per design, non un'omissione — confermato dall'utente 2026-07-07.
- Un archivio L1 viene caricato solo se sia la tabella dati sia la tabella cancellazioni sono state caricate correttamente in L0.

## File per modello

Ogni modello L1 richiede 3-4 file, generabili automaticamente (vedi sotto):
- `<tabella>_source.yml` — source L0 + test data quality
- `<tabella>.yml` — config modello (materializzazione, contract, query_tag)
- `<tabella>.sql` — logica di tipizzazione
- `<tabella>.yml` in `snapshots/` — solo per Cluster C (SCD2)

## Storicizzazione

Vedi [[storicizzazione-l1-cluster]] per il dettaglio dei cluster A/B/C.

## Cancellazioni

Vedi [[gestione-cancellazioni]] (sezione OCS).

## Generazione automatica dei modelli

Le 4 macro `generate_yaml` / `generate_model` / `generate_snapshot` / `generate_source` leggono da [[cfg-l1-schema]] e [[cfg-l1-cluster-sto]]. Nella pratica sono invocate tramite lo script PowerShell `generate_models.ps1` (documentato in dettaglio nella [[guida-sviluppo]]).

## Data quality

Vedi [[data-quality-controlli]].

## Campi tecnici

`ts_riferimento`, `ts_caricamento`, `fl_deleted`, `ts_deleted`, e solo per Cluster C: `ts_inizio_validita`, `ts_fine_validita`, `id_scd`, `ts_updated_at` (nome reale confermato in `dbt_project.yml` → `snapshot_meta_column_names`; il documento ufficiale L0-L1 riporta erroneamente `ts_update_at`, refuso da correggere).

## Gestione eccezioni: parsing COBOL

Vedi [[parsing-cobol]] e [[cobol-copybook-mapping]].

## Note di staleness

La sezione "Raccolta dei log" del documento ufficiale L0-L1 relativa a L1 è marcata come **obsoleta** e va riscritta (confermato dall'utente 2026-07-07): il meccanismo reale non è dbt Artifacts ma una stored procedure custom `TECH.LOG_DBT`, vedi [[incoerenze-codice-vs-documentazione]] e [[todo-allineamento-documentazione]].

## Collegato da
[[agosx-caricamento-l0-l1]], [[guida-sviluppo]], [[layer-l0]], [[layer-l2]]
