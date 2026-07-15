---
title: Catalogo macro DBT (Agos X)
type: concept
tags: [dbt, macro, layer/L0, layer/L1, layer/L2, layer/L3]
updated: 2026-07-14
---

Catalogo delle macro DBT presenti in `raw/dwh-code/macros/` (49 file .sql, 62 macro), verificato contro `raw/dwh-code/` in data 2026-07-14. Le macro documentate nei tre file `raw/` sono confermate quasi tutte presenti, con alcune differenze di naming — vedi [[inconsistenze]].

## Conversioni dtype (`macros/dtype_conversion/`)

| Macro | Firma | Cosa fa |
|---|---|---|
| `custom_to_date` | `(column, zero='null')` | Numero COBOL `YYYYMMDD`/`YYYYMM` → DATE. `99999999`→9999-12-31. Bug noto: la guard per input a 5 cifre referenzia una variabile Jinja non definita (`col_str`) e va in errore invece di dare un messaggio pulito. |
| `custom_to_time` | `(column)` | Numero `HHMMSSss` → TIME. |
| `custom_to_timestamp_ntz` | `(data_ins, ora_ins='00000000', zero='null')` | Combina data+ora numeriche → TIMESTAMP_NTZ. |
| `custom_to_decimal` | `(column, precision=13, decimal=2)` | Intero con decimali impliciti COBOL → NUMBER(precision,decimal), divide per 10^decimal. Valida a compile-time che precision>decimal. |
| `ole_to_timestamp` / `timestamp_to_ole` / `ole_to_date` / `date_to_ole` | in `ole_date.sql` | Conversioni da/verso OLE Automation date serial (epoca `1899-12-30`). `timestamp_to_ole` produce due espressioni (`ole_date`, `ole_time`) da usare in SELECT, non un singolo scalare. |

## Storicizzazione (`macros/materialization/`)

- `is_incremental_S1(partition_by, ts_inizio='TS_INIZIO_VALIDITA', ts_fine='TS_FINE_VALIDITA', lastmodified='LASTMODIFIEDDATA', hashed_cols='HASHED_COLS', order_extra='')` — filtro incrementale S1: prende righe nuove/modificate (`LASTMODIFIEDDATA` più recente del max in target, o finestra di validità appena chiusa — vedi [[lastmodifieddata]]) + `QUALIFY` che collassa hash consecutivi identici per partizione. Sentinelle hardcoded: `1900-01-01` (floor) e `9999-12-31 00:00:00.000` (infinito, TIMESTAMP).
- `ts_fine_validita(partition_by, ts_inizio_validita='TS_INIZIO_VALIDITA', order_extra=none)` — `LEAD()` per calcolare la fine finestra, sentinella TIMESTAMP `9999-12-31 00:00:00.000`.
- `hash_cols(cols)` — hash di riga generico via `MD5(CONCAT_WS('|', COALESCE(CAST(col AS VARCHAR),''), ...))` (diverso da `HASH()` nativo usato in `scd2_foto_mensile`/`_scd2_hash`).
- `delete_month(column='DT_OSSERVAZIONE', date_expr=get_dt_osservazione())` — pre-hook che cancella la partizione mensile prima del reload. **Bug noto**: il parametro `column` è accettato ma ignorato — la DELETE usa sempre il letterale `DT_OSSERVAZIONE` indipendentemente da cosa viene passato.
- `get_dt_osservazione(ts_riferimento=none)` — risolve la data di osservazione: se passato un timestamp di riferimento, verifica se è già un fine-mese (altrimenti retrocede al fine mese precedente); altrimenti usa `var('dt_osservazione')` se settata da CLI, altrimenti fine mese precedente.
- `last_day_past_month()` — versione semplificata di `get_dt_osservazione` (senza branch su `ts_riferimento`), usata come default `ref_month_end` in `scd2_foto_mensile`.
- `scd2_foto_mensile(src_sql, key_cols, ts_col='TS_INIZIO_VALIDITA', pre_ctes=none, biz_cols=none, payload_cols=none, ref_month_end=none, dt_inizio='DT_INIZIO_VALIDITA', dt_fine='DT_FINE_VALIDITA', fine_validita_max="TO_DATE('9999-12-31')")` — pattern L3 S5, vedi [[storicizzazione-l3]]. **Nota tipo**: usa sentinella DATE `TO_DATE('9999-12-31')`, mentre `ts_fine_validita`/`is_incremental_S1` (pattern L2 S1) usano sentinella TIMESTAMP `9999-12-31 00:00:00.000` — incoerenza di tipo tra i due pattern SCD2 del progetto.
  - Helper privati nello stesso file: `_scd2_cols(cols, prefix='')`, `_scd2_cols_as(cols, prefix)`, `_scd2_join(a, b, cols)`, `_scd2_hash(cols, prefix='')`.
- `drop_snapshots_on_full_refresh()` — on-run-start, droppa gli snapshot selezionati prima di un `--full-refresh` (dbt non lo fa nativamente per gli snapshot).

## Cancellazioni logiche (`macros/logic_delete/`)

- `delete_l2(source_name, tgt_keys, src_keys)` — cancellazione fisica in L2, solo dentro `is_incremental()`. Confronto chiavi posizionale (`tgt_keys`/`src_keys` liste parallele, nessuna validazione di lunghezza); conversione automatica per colonne `DT_`/`TS_` via `custom_to_date`/`custom_to_timestamp_ntz`.
- `logic_delete_merge()` — post-hook per modelli L1 cluster A/A1/A2: `UPDATE ... SET fl_deleted='Y', ts_deleted=del.lastmodifieddata` da tabella companion `<archivio>_deleted`. **Nome nel codice differisce dal nome nei docx** (`logical_delete_merge`) — vedi [[inconsistenze]].
- `logic_delete_scd2()` — post-hook per modelli L1 cluster C (snapshot), in transazione esplicita `BEGIN/COMMIT`: step 1 flag `fl_deleted='Y'` sui rowid cancellati, step 2 chiude la finestra aperta (`ts_fine_validita`/`ts_deleted` = lastmodifieddata del feed cancellazioni) per il record con `MAX(ts_fine_validita)` di quel rowid. **Nome differisce dai docx** (`logical_delete_scd2`).

## Generazione modelli (`macros/generate_models/`)

Suite di codegen che legge le tabelle di configurazione `TECH.CFG_L1_SCHEMA`, `TECH.CFG_L1_CLUSTER_STO`, `TECH.CFG_L1_DATAMASK` per generare automaticamente file dbt:

- `get_model_names(model_names, modulo=None, sorgente=None)` — risolve la lista di archivi da processare.
- `generate_source` — genera `sources.yml` (test `try_cast`, `unique_key`/`primary_key`, entry companion `_deleted` per OCS).
- `generate_model` — genera il corpo SQL del modello staging L1 (campi tecnici condizionati dal cluster, `TRY_CAST` per colonna, gestione valori vuoti OCS→spazio invece di NULL: `TRY_CAST(IFF(RTRIM(col)='', ' ', RTRIM(col)) AS T)`). **Valutata e scartata un'ottimizzazione** (2026-07-14): l'espressione valuta `RTRIM(col)` due volte (nella condizione dell'`IFF` e nel ramo falso); una riscrittura equivalente a singola valutazione (`COALESCE(NULLIF(TRY_CAST(RTRIM(col) AS T), ''), ' ')`) è stata provata in `develop/` ma poi scartata: `RTRIM` è una funzione deterministica e Snowflake la deduplica già a piano di esecuzione (common subexpression elimination), quindi il guadagno di performance è nullo — non è stato applicato nessun cambiamento, il codice in `raw/dwh-code/` resta quello di riferimento.
- `generate_yaml` — genera lo `schema.yml` completo per modello: materializzazione/strategia per cluster (A/A1/A2→incremental+merge, B1/B2→incremental+insert_overwrite, C→ephemeral con nome `stg_<table>`, D→incremental+append con pre_hook `delete_month(get_dt_osservazione(...))`), post_hook `logic_delete_merge()` per A/A1/A2 OCS, `query_tag`, blocco `masking` da `CFG_L1_DATAMASK` per colonna (letto poi da `add_datamask()` a runtime).
- `generate_snapshots` — genera `snapshots.yml` solo per cluster C, `unique_key` da PK o fallback `[rowid]`.
- `transcod_dtype(data_type, length_col)` — mappa tipo sorgente → tipo Snowflake. Ha un sentinel di errore silenzioso `'TRANSCOD_ERROR'` per tipi non mappati (comparirebbe direttamente nel YAML/SQL generato).
- `cobol_parse_columns(source_table)` — vedi [[cobol-parsing]].

Questi script sono la controparte DBT-macro degli script PowerShell `generate_models.ps1` descritti in [[guida-sviluppo]] (lo script PowerShell chiama queste macro).

## Data masking (`macros/`)

- `add_datamask()` — post-hook, legge `model.columns[*].meta.masking` e applica `ALTER TABLE ... SET TAG AGOS_DEV_16000.TAGS.sensitivity = '<valore>'`.
- `apply_privacy_to_l0_from_matrix(results)` — setup one-time: crea tag/masking policy (`policy_mask_by_sensitivity`, valori ammessi `DOLLAR`/`SPACES`/`ZEROS`, bypass per ruolo `DEVELOPER`), applica la matrice `var('l0_privacy_matrix')` direttamente su L0.
- **`remove_datamask()` non esiste nel codice** nonostante sia documentato nei docx — vedi [[inconsistenze]].

Vedi [[data-masking-agos-x]] per la pagina dedicata.

## Log (`macros/log/`)

- `log_run_results(results)` — on-run-end reale (non `dbt_artifacts.upload_results` come dicono i docx): costruisce un JSON array di risultati (modelli/snapshot/test) e chiama `CALL AGOS_DEV_16000.TECH.LOG_DBT(...)`.
- `pop_test_log_records(results)` — on-run-end: aggrega le tabelle `DBT_STORE_FAILURES.<test>` (fail/warn) in `LOGS.test_log_records`, poi le droppa.

## COBOL (`macros/generate_models/cobol.sql`)

Vedi [[cobol-parsing]].

## Basilea / data quality (`macros/basilea/`)

16 macro `check_*` (parametriche, nessun riferimento a tabelle/colonne hardcoded) usate probabilmente in singular test per regole di data quality Basilea: `check_not_null`, `check_not_negative[_multi|_nullable]`, `check_range[_if[_multi]]`, `check_values[_if[_multi]]`, `check_coerenza_if`, `check_missing_if_not`, `check_monotonia`, `check_not_zero`, `check_present_if_not_null`, `check_score_range_by_default`. **Assumono che le colonne di condizione (`campo_cond`) siano VARCHAR** (i valori di confronto sono sempre quotati nel SQL generato).

Inoltre: `create_probit_udf()` (UDF Python `PROBIT` via scipy per trasformazioni PD/LGD), `create_proc_report_masterscale()` e `call_proc_report_fondi_masterscale()` (stored procedure/report Excel per Fondi MasterScale — **nota**: `call_proc_report_fondi_masterscale.sql` contiene un workaround hardcoded che forza il mese di calcolo a marzo, con commento esplicito "togliere il replace che forza il 1/03/2026" — è un hack temporaneo, non una scelta di design).

## XML utility (`macros/xml_utility/`)

- `flatten_xml(root_xml_col, child_tag_name, alias, dt_type='VARCHAR', outer=false)` — estrae un tag figlio da XML flattened.
- `get_xml_path(xml_col, path_string, data_type='VARCHAR')` — naviga un path XML profondo (`'A/B/C'`) senza annidare manualmente `XMLGET`.

## Altre macro top-level

- `generate_schema_name(custom_schema_name, node)` — override standard, usa sempre il nome custom verbatim.
- `truncate_models(models=[], paths=[])` — run-operation di utilità per troncare modelli/snapshot per nome o path (gestisce il prefisso `stg_` risolvendo lo snapshot sottostante).

## Collegamenti

- [[storicizzazione-l1-cluster-a-b-c]], [[storicizzazione-l2-s1-s4]], [[storicizzazione-l3]]
- [[cancellazioni-fl-deleted]]
- [[data-masking-agos-x]]
- [[cobol-parsing]]
- [[inconsistenze]]
