---
title: Tabella di monitoraggio processo (semaforo)
type: entity
tags: [layer/L0, layer/L1, config-table]
updated: 2026-07-07
---

Tabella "semaforo" che tiene stato e data dell'ultima elaborazione di ogni archivio, usata per evitare doppie esecuzioni e per guidare il job Glue sugli archivi attesi per modulo.

## Nome tabella

Nome corretto (confermato dall'utente 2026-07-07): **`TECH.CFG_L0_L1_PROCESS_MONITORING`** (versione guida sviluppo). Il documento ufficiale L0-L1 la chiama erroneamente `TECH.CFG_PROCESS_MONITORING` — refuso da correggere nel documento, vedi [[todo-allineamento-documentazione]]. Struttura: colonne `CD_MODULO`, `DS_ARCHIVIO`, `DT_ULTIMO_RUN_L0`, `CD_STATUS_L0`, `FL_PERIMETRO`, `DT_ULTIMO_RUN_L1`, `CD_STATUS_L1`.

## Uso operativo (da guida sviluppo)

- `FL_PERIMETRO = 'S'` (attivo) / `'N'` (escluso) — il job Glue skippa automaticamente gli archivi con `FL_PERIMETRO = 'N'`.
- Inserimento di nuovi archivi con stato iniziale `NULL`.
- Verifica prerequisito da eseguire prima di ogni lancio manuale/retry del job L0.

## Collegato da
[[layer-l0]], [[layer-l1]], [[agosx-caricamento-l0-l1]], [[guida-sviluppo]]
