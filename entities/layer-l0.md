---
title: Layer L0
type: entity
tags: [layer/L0]
updated: 2026-07-07
---

Primo layer di atterraggio dati in Snowflake. Contiene il dato grezzo così come arriva dalla sorgente, con tutti i campi tipizzati come `VARCHAR` (in alcuni casi `VARIANT`). Nessuna storicizzazione: le tabelle sono `TRANSIENT` e vengono ricreate ad ogni run (`CREATE OR REPLACE`), quindi il dato è volatile.

## Pipeline di caricamento

1. Il sorgente deposita i file su S3 (bucket per modulo/archivio, vedi [[file-civetta-e-formati]]).
2. Il file "civetta" (o il file dati stesso, per sorgenti *FileTrigger*) genera un evento `ObjectCreated` → notifica SNS → Control-M.
3. Control-M lancia un job AWS Glue parametrico (`--sorgente`, `--civetta` | `--retry`).
4. Il job Glue esegue controlli formali (file-level check, header check — vedi [[gestione-errori-retry-l0]]) leggendo la configurazione da `TECH.CFG_L0_SORGENTE` ([[cfg-l0-sorgente]]).
5. Il job Glue invoca una **Procedura Snowflake** parametrica che fa `CREATE OR REPLACE` della tabella L0 e `COPY INTO` (structural check incluso, `ON_ERROR = ABORT_STATEMENT`).
6. In caso di errore, i file dell'archivio vengono spostati su prefix `error_dwh`; log su [[et-l0-load-logging]].

## Oggetti Snowflake

- Storage Integration (una tantum, out of scope rispetto al doc L0-L1)
- Stage per bucket (es. `STG_OCS_DEV`, `STG_SAP_DEV`)
- File Format per sorgente/archivio (es. `FF_OCS_L0`, `FF_SAP_L0`)

## Tabelle tecniche coinvolte

- [[cfg-l0-sorgente]] — mappatura configurazione per sorgente/archivio
- [[et-l0-load-logging]] — log di ogni run per archivio
- [[cfg-process-monitoring]] — stato/ultima elaborazione per archivio (tabella "semaforo")
- `TECH.CFG_L0_ERROR_CODES` — codifica errori (8xxx), vedi [[gestione-errori-retry-l0]]
- [[cfg-l1-schema]] — alimentata dai file di schema durante il caricamento L0, usata poi da L1

## Note

- Cluster tipo Excel: conversione automatica xlsx→csv dal job Glue (con vincoli stringenti: no macro/formule/link, un solo foglio, no colonne/celle vuote di comodo, no "N/A"/"-"/"NULL" come indicatori di assenza).
- Retention dei file su prefix `dati`: periodo indicato come "xxx giorni" nel documento ufficiale — **valore non specificato**, da chiarire.

## Collegato da
[[agosx-caricamento-l0-l1]], [[guida-sviluppo]], [[layer-l1]]
