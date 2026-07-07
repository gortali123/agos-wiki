---
title: Gestione errori e retry (L0)
type: concept
tags: [layer/L0, errori, retry]
updated: 2026-07-07
---

Ogni errore rilevato blocca il caricamento dell'intero **archivio** (non del singolo file). Per OCS, quindi, un modulo può avere alcuni archivi caricati e altri no; L1 processerà solo gli archivi arrivati correttamente in L0.

## Codici errore (`TECH.CFG_L0_ERROR_CODES`)

Famiglie di codici a 4 cifre:
- **80xx** — controlli file-level (lettura, encoding, file non trovato, estensione/dimensione invalida, naming convention, copia fallita, parametri input non attesi).
- **81xx** — header (illeggibile, non conforme allo schema).
- **82xx** — file di schema (non trovato, illeggibile, non conforme, vuoto).
- **83xx** — file civetta (non trovato, illeggibile, timestamp mancante, mismatch conteggio record caricati vs civetta).
- **84xx** — esito negativo procedura Snowflake.
- **85xx** — errore tabella di configurazione.
- **86xx** — archivio atteso non presente / non mappato.

## Flusso di retry — OCS

1. File dell'archivio in errore copiati in `/error_dwh`.
2. Intervento manuale di un operatore.
3. Se risolto → file spostato in `/error_dwh/fixed`; da qui si può lanciare il job Glue in modalità manuale/retry (parametro `--retry`, lista `archivio|timestamp`, più archivi ammessi per lo stesso modulo OCS).
4. Se non risolto → file spostato in `/error_dwh/NO_fixed`; si richiede un nuovo invio al sistema sorgente. Il job in questo caso processa solo gli archivi non caricati correttamente per quel giorno.
5. In ogni caso di job Glue terminato in errore: notifica SNS.
6. Ogni retry o reinvio su L0 richiede di **forzare** anche il caricamento verso L1, per garantire coerenza tra i livelli (modalità di forzatura non dettagliata — rimando a un capitolo mai risolto nel documento, "capitolo xxx").

## Retry — sorgenti no-OCS

Stessa logica basata sulla tabella di monitoraggio ([[cfg-process-monitoring]]), ma vincolo di **un solo archivio alla volta** per il retry manuale (a differenza di OCS, dove più archivi dello stesso modulo sono ammessi insieme).

## Tabella semaforo

[[cfg-process-monitoring]] previene esecuzioni doppie: se richiesta un'esecuzione impropria su una data già processata correttamente per tutti gli archivi, il job Glue termina a monte.

## Collegato da
[[layer-l0]], [[et-l0-load-logging]], [[agosx-caricamento-l0-l1]], [[guida-sviluppo]]
