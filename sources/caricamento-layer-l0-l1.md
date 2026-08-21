---
title: Caricamento layer L0-L1
type: source
tags: [layer/L0, layer/L1, source/docx]
updated: 2026-08-19
---

Sintesi di `raw/Agos X - Caricamento layer L0-L1.docx` ("Agos X – Processo di Loading", documento di analisi tecnica). Descrive l'ingestione dati da sorgenti esterne (OCS, Salesforce, CDE, ...) verso Snowflake L0, e la trasformazione L0→L1 tramite DBT.

## L0: architettura e caricamento

- I dati sono depositati su un bucket AWS S3 e caricati in Snowflake da job **AWS Glue** + procedure Snowflake. Orchestrazione/schedulazione: **AWS SNS Topic** + **Control-M**.
- Trigger: deposito del **file civetta** (`<modulo>_<YYYYMMDDHHMISS>_flag.txt`, pipe-delimited: nome archivio, nomi file, numero record, inizio/fine elaborazione, status) sul prefix `logs/` genera un evento SNS → Control-M lancia il job Glue parametrico per quel modulo/archivio.
- Il job Glue esegue controlli **file-level** (esistenza, dimensione max 250MB compressi, naming convention, estensione/compressione) poi **header-level** (per sorgenti con file di schema) confrontando con lo schema atteso.
- Se un controllo fallisce, tutto l'archivio viene scartato e i file copiati su `error_dwh/` (poi eventualmente `fixed/` o `NO_fixed/` dopo intervento manuale).
- Procedura Snowflake: esegue la DDL (`CREATE OR REPLACE` — tabella **TRANSIENT**, tutti i campi VARCHAR/VARIANT), poi `COPY INTO` con `ON_ERROR = ABORT_STATEMENT`. Se presente, carica anche il file di schema in `TECH.CFG_L1_SCHEMA`.
- Tabelle tecniche chiave: `TECH.CFG_L0_SORGENTE` (mappatura sorgente→defaults/eccezioni, tipo VARIANT), `TECH.CFG_PROCESS_MONITORING` (tabella semaforo stato/data ultimo run per archivio), `TECH.CFG_L1_SCHEMA` (tracciato campi da file di schema), `LOG.ET_L0_LOAD_LOGGING` (log caricamento, un record per archivio per run).
- Codici di errore L0: tabella `TECH.CFG_L0_ERROR_CODES` con range 8001-8602 (file/header/schema/civetta/procedura/config) — es. 8001 errore lettura file S3, 8006 naming convention non rispettata, 8102 header non conforme allo schema, 8304 mismatch numero record vs file civetta, 8401 esito negativo procedura Snowflake, 8601/8602 archivio atteso/mappato assente.
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
  - **Cluster D** (sezione aggiunta nel resync 2026-08-19): archivi a cadenza periodica non giornaliera (mensile di default, o settimanale), gestiti tramite 3 macro dedicate in `raw/dwh-code/macros/materialization/`, tutte parametrizzate su `schedule` (`'monthly'`|`'weekly'`): `compute_dt_osservazione(column, schedule='monthly')` (in SELECT, deriva `DT_OSSERVAZIONE` da una data sorgente: per monthly la riporta all'ultimo giorno del mese se non lo è già, per weekly al venerdì della settimana ISO); `get_dt_osservazione(schedule='monthly')` (calcola il periodo "corrente" da caricare rispetto a `CURRENT_DATE` — nessun parametro di data in input, solo override manuale via `var('dt_osservazione')`); `delete_dt_osservazione(column='DT_OSSERVAZIONE', schedule='monthly')` (pre_hook, cancella le righe del periodo corrente prima dell'insert incrementale `append`). Verificato riga per riga contro il codice il 2026-08-19: firme e comportamento del doc coincidono col codice reale (non più un'incongruenza, vedi [[inconsistenze]]).
- Cancellazioni OCS: file dedicato con sole chiavi ROWID cancellate (`<archivio>_deleted_<ts>_<progressivo>.csv.gz`, gzip, pipe, backslash escape, UTF-8 no BOM), caricato in L0 in parallelo al file dati, poi applicato in L1 via post-hook (`logical_delete_merge` per cluster A, `logical_delete_scd2()` per cluster C) che valorizza `FL_DELETED = Y` + `TS_DELETED`. **Nota**: verificare in code review — la convenzione di naming campi (xlsx `Nomenclatura Campi`) prescrive per i flag (prefisso `FL_`) valori rigorosamente `"S"`/`"N"`, non `Y`/`N` — vedi [[naming-convention-agos-x]] e la query di inconsistenze.
- Data quality L1: test generici custom `primary_key` (severity **fail**) e `try_cast` (severity **warn**, usa `TRY_CAST` in dry-run) applicati in fase di source test prima del caricamento in L1 — **aggiornamento 2026-08-03**: il documento ora usa gli stessi nomi del codice, senza il suffisso `_table` (era un'incongruenza aperta, vedi [[inconsistenze]]). Record problematici salvabili in `DBT_STORE_FAILURES`, aggregati poi in `LOGS.TEST_LOG_RECORDS` dalla macro `pop_test_log_records`.
- **Generazione modelli** (sezione riscritta 2026-08-03): quattro macro per archivio — `generate_source` (yml source L0), `generate_yaml` (yml modello L1: colonne, tipi, constraint, materializzazione/strategia per cluster, query_tag, masking), `generate_model` (sql L1: lettura da L0 + casting; per cluster C anche `stg_<nome_tabella>.sql`), `generate_snapshots` (yml snapshot, solo cluster C). Le macro leggono da `TECH.CFG_L1_SCHEMA`, `TECH.CFG_L1_CLUSTER_STO` e — solo per archivi OCS — da `TECH.CFG_L0_L1_MODULO_LOOKUP`, che aggrega il modulo grezzo OCS (`cd_modulo`, es. `ANA`/`XAN`) sotto un modulo soprafolder comune (`cd_modulo_l1`, es. `ANA`). Struttura di output risultante per OCS: `models/L{0,1}/OCS/<cd_modulo_l1>/<cd_modulo>/<archivio>.*` (due livelli di cartella). Macro di transcodifica dtype: `transcod_dtype` (usata da `generate_model`/`generate_yaml`), sentinella `TRANSCOD_ERROR` per tipi non mappati. Comportamento su file esistenti: warning + nessun overwrite, salvo `--force`. Verificato contro `raw/dwh-code/macros/generate_models/generate_source.sql` (2026-08-03): il join usa `mlk.cd_modulo = s.cd_modulo`, coerente con la doc — l'incongruenza di join/path precedentemente aperta risulta **risolta upstream**, vedi [[inconsistenze]].
- **Gestione job** (nuova sezione, ex capitolo "L1: Gestione job"): ogni modello va anche schedulato su dbt Cloud tramite `jobs.yml` versionato, generato da `generate_jobs.ps1` e sincronizzato con `dbt-jobs-as-code`; `fetch_dbt_jobs.py`/`fetch_dbt_dependencies.py` esportano id/dipendenze dei job. Dettaglio in [[guida-sviluppo]] (4.1).
- Gestione COBOL: macro metadata-driven `cobol_parse_columns(source_table)`, guidata da tabella mapping `COBOL_COPYBOOK_MAPPING` (una riga per campo per copybook/tipo record), con supporto overpunch tramite `decode_overpunch(val, scale)`.
- Query tag L0/L1: JSON `{"app":"GLUE","sorgente":"OCS","schema":"L0","modulo":"ANA"}` / `{"app":"DBT","sorgente":"OCS","schema":"L1_O_ANA","modulo":"CCANAGR"}`.

## L1: raccolta log (sezione riscritta 2026-08-03)

Il vecchio capitolo basato su `dbt_artifacts.upload_results` (segnalato come obsoleto) è stato **sostituito**: i log di modelli/snapshot/test vengono raccolti dalla macro custom `log_run_results` (hook `on-run-end` in `dbt_project.yml`), che costruisce un JSON per nodo/test ed esegue una singola chiamata alla stored procedure `LOG_DBT`, la quale scrive nella event table nativa Snowflake `LOGS.EVENT_LOG`. Sopra questa tabella sono definite: `V_EVENT_LOG` (estrae i campi dal payload JSON, vista di base), `DT_EVENT_LOG` (dynamic table analoga), `V_LAST_RUN_STATUS` (ultimo stato per coppia schema/tabella + esito test aggregato PASS/WARN/FAIL, per orchestrazione layer successivi). Coerente con `raw/dwh-code/macros/log/log_run_results.sql` verificato in data odierna (usa `default(x, true)` su `nm_execution_time`/`nm_failures`, coerente col fix proposto in `develop/macros/log/log_run_results.sql` — **risulta applicato upstream**, vedi [[inconsistenze]]). Risolve l'incongruenza precedentemente aperta su `dbt_artifacts`.

## Note di staleness

- Diversi rimandi a documenti esterni non vendorizzati in questo wiki: `Loading_Flow_L0_L1.pdf`, `Agos X - Requisiti Agos Integrazione OCS-DWHX_20260226.pdf`, `L1_TRY_CAST_Flow.pdf`.
- Letto e riverificato per intero contro `raw/dwh-code/` il 2026-08-19 (vedi [[inconsistenze]] per i risultati del confronto, rigenerata da zero in questo giro). Le viste `V_EVENT_LOG`/`DT_EVENT_LOG`/`V_LAST_RUN_STATUS` non sono vendorizzate in `raw/dwh-code/` (probabile DDL solo Snowflake-side, non nel progetto dbt) — non verificabili riga per riga localmente.
- Nota: `raw/Agos X - Layer L2.xlsx` e i csv `cfg_l1_schema`/`cfg_l1_cluster_sto` sono stati rimossi da `raw/` dall'utente in questo giro — le pagine [[layer-l2-xlsx-reference]] e [[cfg-l1-schema-e-cluster-sto]] restano come riferimento storico ma non sono più verificabili contro un file vivo.

## Collegamenti

- [[layer-l0]], [[layer-l1]]
- [[storicizzazione-l1-cluster-a-b-c]]
- [[cancellazioni-fl-deleted]]
- [[naming-convention-agos-x]]
- [[cobol-parsing]]
- [[inconsistenze]]
