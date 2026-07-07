---
title: TECH.CFG_L1_SCHEMA
type: entity
tags: [layer/L0, layer/L1, config-table]
updated: 2026-07-07
---

Tabella che contiene il tracciato (schema) di ogni archivio, alimentata durante il caricamento L0 dai file di schema (per le sorgenti che li prevedono: OCS, Salesforce, Fea) tramite `COPY INTO` eseguito dalla Procedura Snowflake di L0. Usata poi in fase L1 per generare dinamicamente la DDL delle tabelle e i modelli DBT (vedi [[layer-l1]]).

## Struttura

`NM_CAMPO`, `DS_MODULO`, `DS_TABELLA`, `DS_CAMPO`, `DS_FORMATO`, `NM_LUNGHEZZA`, `FL_PK`, `FL_NULL`, `TS_INSERIMENTO`.

## Note

- Caricata solo quando il file di schema è stato aggiornato (evita duplicati); l'unicità dei record in caso di modifica è garantita dal campo tecnico **`TS_INSERIMENTO`** (nome confermato corretto dall'utente 2026-07-07), che offre anche tracciabilità storica delle modifiche al tracciato. Il documento ufficiale usa erroneamente `DT_INSERIMENTO` nel paragrafo esplicativo — refuso da correggere, vedi [[todo-allineamento-documentazione]].
- **Da non confondere** con una scoperta più ampia emersa dal confronto col codice reale: la macro `generate_source.sql` in [[dwh-code]] interroga in realtà colonne come `ds_archivio`, `ds_column_name`, `fl_is_primary_key`, `ts_riferimento` — nomi diversi sia da quelli del documento ufficiale sia da questa nota sul refuso. Vedi [[incoerenze-codice-vs-documentazione]] (punto 2) per il dettaglio, non ancora validato con l'utente.
- Per sorgenti senza file di schema nativo, viene creato e caricato una tantum manualmente, recuperando le info dai processi as-is.
- Il data type finale usato in L1 è ottenuto da questa tabella tramite una macro di transcodifica dei data type sorgente → Snowflake.

## Collegato da
[[layer-l0]], [[layer-l1]], [[agosx-caricamento-l0-l1]]
