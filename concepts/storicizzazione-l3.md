---
title: "Storicizzazione L3: S2-S4 e S5 (SCD2 mensile)"
type: concept
tags: [layer/L3, storicizzazione]
updated: 2026-07-14
---

Da [[guida-sviluppo]] (§6): L3 riusa S2/S3/S4 di L2. **S1 non è previsto in L3** (segnalato con un punto interrogativo esplicito nel documento — da confermare col team, non ancora verificato nel codice L3 vendorizzato, che copre solo `basilea_core` e `monitoraggio_produzione`).

## S3 in L3: blocco incrementale dipende dalla sorgente main

A differenza di L2, il blocco incrementale di un modello S3 in L3 dipende dal tipo di storicizzazione della **L2 main** che lo alimenta:
- Main L2 **S3** (ha `DT_OSSERVAZIONE`): filtra sul mese precedente `WHERE DT_OSSERVAZIONE = {{ get_dt_osservazione() }}`.
- Main L2 **S1** (ha `TS_INIZIO_VALIDITA`/`TS_FINE_VALIDITA`): seleziona il record il cui intervallo copre la fine del mese precedente: `WHERE TS_INIZIO_VALIDITA <= {{ get_dt_osservazione() }} AND TS_FINE_VALIDITA > {{ get_dt_osservazione() }}`.

## S5 — SCD2 a granularità mensile (`scd2_foto_mensile`)

Pattern nuovo, implementato dalla macro `scd2_foto_mensile` (vedi [[macro-catalogo-dbt]]). Mantiene lo storico delle modifiche di un'entità, ma a differenza della SCD2 classica la storicizzazione avviene a granularità mensile: una nuova versione si apre solo quando cambia il payload (colonne di business, non chiave) confrontando l'hash tra fotografie mensili consecutive.

- **Full-refresh**: ricostruisce tutta la storia — dedup a "foto di fine mese" (`ver_dedup`, una riga per chiave+mese, l'ultima osservata), poi tiene solo i mesi in cui l'hash cambia rispetto al precedente (`win_starts`), poi chiude le finestre con `LEAD` (`emitted`).
- **Incrementale**: confronta la foto del mese di riferimento (`snap`) con le finestre attualmente aperte in tabella (`open_win`, lette da `{{ this }}`), producendo nuove righe (`new_rows`, chiave nuova o hash cambiato) e chiusure (`close_rows`, vecchia finestra aperta chiusa alla nuova data), poi fa `merge`.
- Prerequisiti modello: `materialized: incremental`, `incremental_strategy: merge`, `unique_key: key_cols + [DT_INIZIO_VALIDITA]`.
- **Nota tipo**: usa sentinella **DATE** `TO_DATE('9999-12-31')` per la finestra aperta, mentre il pattern S1 di L2 (macro `ts_fine_validita`/`is_incremental_S1`) usa sentinella **TIMESTAMP** `9999-12-31 00:00:00.000` — incoerenza di tipo tra L2 S1 e L3 S5, da tenere presente quando si fa un JOIN tra i due livelli su condizione di validità.

## Collegamenti

- [[guida-sviluppo]]
- [[macro-catalogo-dbt]]
- [[storicizzazione-l2-s1-s4]]
- [[inconsistenze]]
