---
title: "Proposta correzione testo: L1 - Raccolta dei log"
type: query
tags: [layer/L1, source/docx, logging, develop]
updated: 2026-07-27
---

Proposta di testo per sostituire il capitolo "L1: Raccolta dei log" in `raw/Agos X - Caricamento layer L0-L1.docx`, attualmente marcato dal documento stesso come **obsoleto** ("da aggiornare sulla base della discussione con Snowflake — questione concorrenza") e basato su un pacchetto `dbt_artifacts` non presente nel codice reale (vedi [[inconsistenze]] voce 6).

`raw/` è immutabile: questa pagina è la proposta da incollare a mano nel `.docx`, non un'edit diretta del file.

## Testo proposto

> I log delle esecuzioni di modelli e test DBT vengono raccolti tramite una macro custom, `log_run_results`, richiamata nel `dbt_project.yml` come hook `on-run-end`:
>
> ```
> on-run-end:
>   - "{{ log_run_results(results) }}"
>   - "{{ pop_test_log_records(results) }}"
> ```
>
> Ad ogni esecuzione, la macro scorre l'oggetto `results` di dbt e, per ciascun nodo di tipo **modello o snapshot** (esclusi ephemeral e view) e per ciascun **test**, costruisce un record JSON con l'esito dell'esecuzione (tipo, timestamp di avvio, tempo di esecuzione, schema/tabella, status, nome test ed eventuali failure per i test, messaggio d'errore, id dell'invocazione dbt e query_id Snowflake). I record vengono aggregati in un array e passati con una singola chiamata alla stored procedure `TECH.LOG_DBT`, che li scrive nella tabella nativa Snowflake `LOGS.EVENT_LOG` (event table), evitando così la scrittura concorrente diretta su una tabella custom durante run paralleli.
>
> Sopra `LOGS.EVENT_LOG` sono definite due viste di consultazione:
>
> - **V_EVENT_LOG**: estrae dal payload JSON i singoli campi (tipo esecuzione, timestamp, tempo di esecuzione, schema, tabella, status, nome test, numero di failure, messaggio, id run dbt, query_id), filtrando sui soli record scritti da `LOG_DBT`. È la vista di base da cui derivano le altre.
> - **V_LAST_RUN_STATUS**: per ciascuna coppia schema/tabella, riporta l'ultimo stato di esecuzione del modello e l'esito aggregato dei test associati (PASS/WARN/FAIL, con FAIL prevalente su WARN) più il numero di righe fallite, pensata come vista di supporto per l'orchestrazione dei layer successivi.

## Basi di questa proposta

- `develop/macros/log/log_run_results.sql` — macro proposta, non presente in `raw/dwh-code/` (nessuna macro di logging equivalente vendorizzata al momento).
- `develop/views/logs/v_event_log.sql`, `develop/views/logs/v_last_run_status.sql` — viste proposte.
- Tutti i file sono **proposti in `develop/`, non ancora applicati upstream** — se l'utente porta il codice nel repo live prima di aggiornare il docx, verificare che i nomi campo/vista non siano cambiati in fase di revisione.

## Collegamenti

- [[caricamento-layer-l0-l1]]
- [[inconsistenze]]
