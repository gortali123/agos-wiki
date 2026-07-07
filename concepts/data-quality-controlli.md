---
title: Controlli di data quality
type: concept
tags: [data-quality]
updated: 2026-07-07
---

## L0

Controlli formali svolti dal job Glue e dalla procedura Snowflake, guidati da flag in [[cfg-l0-sorgente]]:
- **File-level check**: esistenza file, dimensione (max 250MB compressi, salvo diverso limite in config), estensione/compressione attese, naming convention (con coerenza timestamp tra i file dello stesso archivio).
- **Header check**: solo per file con header dichiarato in config, confrontato contro il file di schema; per file senza header verificabile solo il numero di campi.
- **Structural check** (in COPY INTO): parsing, numero campi vs header, encoding UTF-8 — `ON_ERROR = ABORT_STATEMENT` interrompe al primo record non conforme.

Un solo errore in una qualsiasi fase scarta **tutti** i file dello stesso archivio (non solo il file in errore). Codici in `TECH.CFG_L0_ERROR_CODES` — vedi [[gestione-errori-retry-l0]].

## L1

Due test generici custom, eseguiti su L0 prima del caricamento (dichiarati nel file `_source.yml`, eseguiti con `dbt build -s +<model>`):
- `primary_key_table` — unicità della PK dichiarata su L0. Severity: **fail** (blocca il caricamento). Necessario perché la materializzazione merge (Cluster A/A2 e snapshot Cluster C) non verifica sempre questa condizione da sola.
- `try_cast_table` — conformità dei data type dichiarati, via `TRY_CAST` in dry run. Severity: **warn**. Nel modello reale, i campi che falliscono il cast vengono impostati a `NULL` (non bloccano il run).

Record problematici salvabili in tabelle dedicate (opzione `store failures` DBT, schema `DBT_STORE_FAILURES`, una tabella per archivio), poi aggregati nella tabella storicizzata `LOGS.TEST_LOG_RECORDS` dalla macro `pop_test_log_records` (che elimina le tabelle di dettaglio dopo l'aggregazione). Nota: questa macro compare nell'hook `on-run-end` riportato per L1, ma non nell'hook equivalente riportato per L2 — vedi [[incoerenze-doc-framework-vs-guida-sviluppo]].

## L2/L3

Framework nativo DBT:
- Test standard (`not_null`, `unique`, `accepted_values`, `relationships`).
- Test generici custom in `tests/generic/`, referenziati con la stessa sintassi dei test nativi.
- Test da pacchetti esterni (es. `dbt-utils`), installati via `packages.yml`.

Eseguiti da `dbt build` (modello + test in un'unica operazione, orchestrata da Control-M). Severity (warn/error) configurabile a livello di modello/colonna, usata da Control-M per decidere se bloccare l'esecuzione dei modelli dipendenti. Strategia di tracciamento esiti e dettagli avanzati **dichiarati come non ancora definiti** nel documento ufficiale ("Ulteriori dettagli saranno integrati durante la fase progettuale dedicata alla data quality").

## Collegato da
[[layer-l0]], [[layer-l1]], [[layer-l2]], [[agosx-caricamento-l0-l1]], [[agosx-caricamento-l2]]
