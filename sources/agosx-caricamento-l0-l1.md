---
title: Agos X - Caricamento layer L0-L1 (source)
type: source
tags: [layer/L0, layer/L1, source/framework]
updated: 2026-07-07
---

Documento ufficiale di analisi tecnica (condiviso col cliente) sul processo di loading dati da sorgenti esterne (OCS, Salesforce, CDE, ...) verso Snowflake, coprendo il layer **L0** (raw landing) e il layer **L1** (tipizzato/storicizzato, 1:1 con L0).

Fonte: `raw/Agos X - Caricamento layer L0-L1.docx`.

## Takeaway principali

- Pipeline: file su S3 → file "civetta" (trigger) → notifica SNS → Control-M → job AWS Glue (controlli formali + libreria python) → Procedura Snowflake (`COPY INTO`) → L0 (tabelle TRANSIENT, tutti i campi VARCHAR).
- Gestione errori a livello di singolo archivio, codificata in `TECH.CFG_L0_ERROR_CODES` (8xxx). Retry manuale via prefix `/error_dwh/fixed` o `/error_dwh/NO_fixed`.
- L0→L1 è gestito da DBT: un modello DBT per tabella L1, eseguito da Control-M con `dbt build -s +<model>` (il `+` include i test sulle source L0).
- Storicizzazione L1 basata su 3 cluster (config in `TECH.CFG_L1_CLUSTER_STO`): **Cluster A** (insert/update via merge), **Cluster B** (full truncate/insert), **Cluster C** (SCD2 via snapshot DBT).
- Cancellazioni OCS: file dedicato di ROWID cancellati, caricato in parallelo su L0, applicato in post-hook DBT (`logical_delete_merge` / `logical_delete_scd2()`), propagato come flag `FL_DELETED='Y'` + `TS_DELETED`.
- Data quality L1: due test generici custom, `primary_key_table` (severity fail) e `try_cast_table` (severity warn, poi TRY_CAST setta a NULL in run reale).
- Generazione modelli L1 automatizzata da 4 macro (`generate_yaml`, `generate_model`, `generate_snapshot`, `generate_source`) lette da `TECH.CFG_L1_SCHEMA` + `TECH.CFG_L1_CLUSTER_STO`.
- Gestione COBOL: macro metadata-driven `cobol_parse_columns` + tabella di mapping `COBOL_COPYBOOK_MAPPING`, con supporto a decodifica overpunch.
- La sezione "L1: Raccolta dei log" è esplicitamente marcata **obsoleta** nel documento ("da aggiornare sulla base della discussione con Snowflake — questione concorrenza").

## Pagine correlate

- [[layer-l0]], [[layer-l1]]
- [[gestione-errori-retry-l0]]
- [[file-civetta-e-formati]]
- [[storicizzazione-l1-cluster]]
- [[gestione-cancellazioni]]
- [[data-quality-controlli]]
- [[parsing-cobol]]
- [[cfg-l0-sorgente]], [[cfg-l1-schema]], [[cfg-l1-cluster-sto]], [[cfg-process-monitoring]], [[et-l0-load-logging]], [[cobol-copybook-mapping]]

## Staleness

Contenuto verificato solo contro il testo del doc stesso (nessun controllo incrociato col repo `my_dwh-x-dbt`, non ancora esplorato in questa sessione). Il documento contiene un placeholder non risolto ("periodo di retention di **xxx** giorni" per lo spostamento file da `dati` ad `archived`) e un rimando a "capitolo xxx" mai risolto per le modalità di forzatura caricamento L1 dopo retry L0.
