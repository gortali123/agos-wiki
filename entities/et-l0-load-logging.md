---
title: LOG.ET_L0_LOAD_LOGGING
type: entity
tags: [layer/L0, log-table]
updated: 2026-07-07
---

Tabella di log dei caricamenti L0, popolata da una procedura Snowflake dedicata richiamata dal job Glue. Un record per archivio per ogni run.

## Struttura

`CD_SORGENTE`, `DS_NOME_MODULO`, `DS_NOME_TABELLA`, `DT_RIFERIMENTO`, `NM_RECORD_INSERT`, `DT_INGESTION_INIZIO`, `DT_INGESTION_FINE`, `NM_INGESTION_DURATA`, `CD_ERRORE`, `DS_ERRORE`, `DS_MESSAGGIO`, `ID_JOB`, `DS_STATO`.

## Note operative (guida sviluppo)

- Un solo record riepilogativo per archivio per run: in caso di successo i campi errore sono `NULL`, in caso di KO sono valorizzati con codice/messaggio.
- Interrogabile per `ID_JOB` (formato `jr_...`, recuperato dalla UI AWS Glue) per vedere tutti gli archivi elaborati da un dato job.
- Per il dettaglio esecutivo completo (log Python, operazioni S3, worker paralleli) serve AWS CloudWatch (profilo `AuditReadOnlyAccess`) — questa tabella non lo contiene.

## Collegato da
[[layer-l0]], [[gestione-errori-retry-l0]], [[agosx-caricamento-l0-l1]], [[guida-sviluppo]]
