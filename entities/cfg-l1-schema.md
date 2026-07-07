---
title: TECH.CFG_L1_SCHEMA
type: entity
tags: [layer/L0, layer/L1, config-table]
updated: 2026-07-07
---

Tabella che contiene il tracciato (schema) di ogni archivio, alimentata durante il caricamento L0 dai file di schema (per le sorgenti che li prevedono: OCS, Salesforce, Fea) tramite `COPY INTO` eseguito dalla Procedura Snowflake di L0. Usata poi in fase L1 per generare dinamicamente la DDL delle tabelle e i modelli DBT (vedi [[layer-l1]]).

## Struttura

**Nomi colonna reali** (confermati contro `macros/generate_models/generate_source.sql` in `raw/dwh-code`, 2026-07-07): `ds_archivio`, `cd_modulo`, `ds_sorgente`, `ds_column_name`, `ds_data_type`, `ds_length_col`, `fl_is_nullable`, `fl_is_primary_key`, `ts_riferimento`, `nm_campo`.

Il documento ufficiale L0-L1 descrive invece una struttura diversa (`NM_CAMPO`, `DS_MODULO`, `DS_TABELLA`, `DS_CAMPO`, `DS_FORMATO`, `NM_LUNGHEZZA`, `FL_PK`, `FL_NULL`, `TS_INSERIMENTO`) — da correggere, il documento va allineato ai nomi reali sopra. Vedi [[todo-allineamento-documentazione]] e [[incoerenze-codice-vs-documentazione]] (punto 2).

## Note

- Caricata solo quando il file di schema è stato aggiornato (evita duplicati); l'unicità dei record in caso di modifica è garantita da un campo tecnico timestamp (`ts_riferimento` nel codice reale), che offre anche tracciabilità storica delle modifiche al tracciato.
- Per sorgenti senza file di schema nativo, viene creato e caricato una tantum manualmente, recuperando le info dai processi as-is.
- Il data type finale usato in L1 è ottenuto da questa tabella tramite una macro di transcodifica dei data type sorgente → Snowflake.

## Collegato da
[[layer-l0]], [[layer-l1]], [[agosx-caricamento-l0-l1]]
