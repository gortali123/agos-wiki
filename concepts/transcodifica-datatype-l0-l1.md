---
title: Transcodifica data type L0→L1
type: concept
tags: [layer/L0, layer/L1]
updated: 2026-07-07
---

Entrambi i documenti di framework menzionano genericamente "una macro di transcodifica dei data type" che mappa i data type dichiarati nel file di schema sorgente (in [[cfg-l1-schema]]) ai data type Snowflake usati in L1, senza però mostrarne la logica.

## Macro reale: `transcod_dtype(data_type, length_col)`

In `raw/dwh-code/macros/generate_models/transcod_dtype.sql`. Mappatura (case-insensitive sul tipo dichiarato):

| Tipo dichiarato | Con lunghezza | Data type Snowflake risultante |
|---|---|---|
| `CHAR`, `VARCHAR`, `STRING` | sì | `VARCHAR(<length>)` |
| `NUMERIC`, `DECIMAL`, `NUMBER` | sì | `NUMBER(<length>)` |
| `BOOLEAN`, `BINARY` | — | `BOOLEAN` |
| `DATE` | — | `DATE` |
| `INT`, `INTEGER`, `SMALLINT`, `TINYINT`, `BIGINT` | — | `NUMBER(38, 0)` |
| contiene `TIMESTAMP` (anche il refuso `TINMESTAMP`) | — | `TIMESTAMP_NTZ` |
| contiene `TEXT`/`VARCHAR`/`CHAR`/`STRING` (fallback senza lunghezza) | — | `VARCHAR` |
| contiene `FLOAT`/`DOUBLE`/`REAL` | — | `NUMBER(38,10)` |
| contiene `NUMBER`/`NUMERIC`/`DECIMAL` (fallback senza lunghezza) | — | `NUMBER(38,10)` |
| contiene `VARIANT`/`OBJECT`/`ARRAY` | — | `VARIANT` |
| nessun match | — | `'TRANSCOD_ERROR'` (stringa letterale, non un errore di compilazione — un valore sentinella da intercettare a valle) |

Nota: la macro gestisce esplicitamente anche il refuso `TINMESTAMP` come sinonimo di `TIMESTAMP` — indizio che nei file di schema sorgente questo errore di battitura si presenta realmente in produzione.

## Collegato da
[[cfg-l1-schema]], [[layer-l1]], [[agosx-caricamento-l0-l1]]
