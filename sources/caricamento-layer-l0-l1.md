---
title: Caricamento layer L0-L1
type: source
tags: [layer/L0, layer/L1, source/docx]
updated: 2026-07-14
---

Sintesi di `raw/Agos X - Caricamento layer L0-L1.docx` ("Agos X – Processo di Loading", documento di analisi tecnica). Descrive l'ingestione dati da sorgenti esterne (OCS, Salesforce, CDE, ...) verso Snowflake L0, e la trasformazione L0→L1 tramite DBT.

## L0: architettura e caricamento

- I dati sono depositati su un bucket AWS S3 e caricati in Snowflake da job **AWS Glue** + procedure Snowflake. Orchestrazione/schedulazione: **AWS SNS Topic** + **Control-M**.
- Trigger: deposito del **file civetta** (`<modulo>_<YYYYMMDDHHMISS>_flag.txt`, pipe-delimited: nome archivio, nomi file, numero record, inizio/fine elaborazione, status) sul prefix `logs/` genera un evento SNS → Control-M lancia il job Glue parametrico per quel modulo/archivio.
- Il job Glue esegue controlli **file-level** (esistenza, dimensione max 250MB compressi, naming convention, estensione/compressione) poi **header-level** (per sorgenti con file di schema) confrontando con lo schema atteso.
- Se un controllo fallisce, tutto l'archivio viene scartato e i file copiati su `error_dwh/` (poi eventualmente `fixed/` o `NO_fixed/` dopo intervento manuale).
- Procedura Snowflake: esegue la DDL (`CREATE OR REPLACE` — tabella **TRANSIENT**, tutti i campi VARCHAR/VARIANT), poi `COPY INTO` con `ON_ERROR = ABORT_STATEMENT`. Se presente, carica anche il file di schema in `TECH.CFG_L1_SCHEMA`.
- Tabelle tecniche chiave: `TECH.CFG_L0_SORGENTE` (mappatura sorgente→defaults/eccezioni, tipo VARIANT), `TECH.CFG_PROCESS_MONITORING` (tabella semaforo stato/data ultimo run per archivio), `TECH.CFG_L1_SCHEMA` (tracciato campi da file di schema), `LOG.ET_L0_LOAD_LOGGING` (log caricamento, un record per archivio per run).
- Codici di errore L0: tabella `TECH.CFG_L0_ERROR_CODES` con range 8001-8602 (file/header/schema/civetta/procedura/config).
- Retry: parametro `--retry` del job Glue (mutuamente esclusivo con `--civetta`); per OCS più archivi dello stesso modulo insieme, per no-OCS un archivio alla volta.
- Excel come formato sorgente: convertito in CSV dal job Glue (prefix `/dati_conv`) con vincoli stringenti (no macro/formule, un solo foglio, niente celle unite/colonne vuote/valori N/A come placeholder).

## L1: architettura, storicizzazione, cancellazioni

- Ogni schedulazione Control-M esegue un solo modello DBT ↔ una sola tabella. Comando: `dbt build -s +<model_name>` (esegue anche gli snapshot e i test sulle source).
- Passaggio L0→L1 è **1:1** (stessa granularità, stessi campi al netto dei tecnici): tipizzazione + storicizzazione.
- Campi tecnici L1: `ts_riferimento`, `ts_caricamento`, `fl_deleted`, `ts_deleted` sempre; `ts_inizio_validita`, `ts_fine_validita`, `id_scd`, `ts_update_at` solo per cluster C (snapshot SCD2).
- **Cluster di storicizzazione** (tabella `TECH.CFG_L1_CLUSTER_STO`):
  - **Cluster A**: delta giornaliero solo insert (rari update puntuali) → strategia incrementale `merge`.
  - **Cluster B**: fotografia completa ogni giorno → `TRUNCATE/INSERT`, materializzazione `insert_overwrite` (nessuna storicizzazione necessaria).
  - **Cluster C**: richiede SCD2 vera e propria (snapshot DBT strategy `timestamp`, con modello ephemeral intermedio `stg_<modello>.sql` di tipizzazione a monte dello snapshot).
  - Fotografie full mensili: per alcuni archivi cluster B/C, un secondo scarico mensile consolidato → tabella dedicata popolata in `append`.
- Cancellazioni OCS: file dedicato con sole chiavi ROWID cancellate (`<archivio>_deleted_<ts>_<progressivo>.csv.gz`, gzip, pipe, backslash escape, UTF-8 no BOM), caricato in L0 in parallelo al file dati, poi applicato in L1 via post-hook (`logical_delete_merge` per cluster A, `logical_delete_scd2()` per cluster C) che valorizza `FL_DELETED = Y` + `TS_DELETED`. **Nota**: verificare in code review — la convenzione di naming campi (xlsx `Nomenclatura Campi`) prescrive per i flag (prefisso `FL_`) valori rigorosamente `"S"`/`"N"`, non `Y`/`N` — vedi [[naming-convention-agos-x]] e la query di inconsistenze.
- Data quality L1: test generici custom `primary_key_table` (severity **fail**) e `try_cast_table` (severity **warn**, usa `TRY_CAST` in dry-run) applicati in fase di source test prima del caricamento in L1. Record problematici salvabili in `DBT_STORE_FAILURES`, aggregati poi in `LOGS.TEST_LOG_RECORDS` dalla macro `pop_test_log_records`.
- Generazione modelli: script PowerShell `generate_models.ps1` legge da `TECH.CFG_L1_SCHEMA` e `TECH.CFG_L1_CLUSTER_STO`, genera in sequenza `generate_source` (yml L0), `generate_yaml` (yml L1), `generate_model` (sql L1), `generate_snapshots` (yml snapshot, solo cluster C).
- Gestione COBOL: macro metadata-driven `cobol_parse_columns(source_table)`, guidata da tabella mapping `COBOL_COPYBOOK_MAPPING` (una riga per campo per copybook/tipo record), con supporto overpunch tramite `decode_overpunch(val, scale)`.
- Query tag L0/L1: JSON `{"app":"GLUE","sorgente":"OCS","schema":"L0","modulo":"ANA"}` / `{"app":"DBT","sorgente":"OCS","schema":"L1_O_ANA","modulo":"CCANAGR"}`.

## Note di staleness

- Il capitolo "L1: Raccolta dei log" è segnalato nel documento stesso come **obsoleto** ("da aggiornare sulla base della discussione con Snowflake — questione concorrenza").
- Diversi rimandi a documenti esterni non vendorizzati in questo wiki: `Loading_Flow_L0_L1.pdf`, `Agos X - Requisiti Agos Integrazione OCS-DWHX_20260226.pdf`, `L1_TRY_CAST_Flow.pdf`.
- Letto e verificato contro `raw/dwh-code/` in data 2026-07-14 (vedi [[inconsistenze-doc-vs-codice]] per i risultati del confronto).

## Collegamenti

- [[layer-l0]], [[layer-l1]]
- [[storicizzazione-l1-cluster-a-b-c]]
- [[cancellazioni-fl-deleted]]
- [[naming-convention-agos-x]]
- [[cobol-parsing]]
- [[inconsistenze-doc-vs-codice]]
