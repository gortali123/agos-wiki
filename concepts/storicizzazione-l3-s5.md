---
title: Storicizzazione L3 — S5 (SCD2 mensile)
type: concept
tags: [layer/L3, storicizzazione]
updated: 2026-07-07
---

Tipo di storicizzazione confermato come reale e stabile (macro `scd2_foto_mensile` in `raw/dwh-code`), ma documentato **solo** nella [[guida-sviluppo]] — manca ancora dal documento di framework L2/L3, dove andrebbe aggiunto (vedi [[todo-allineamento-documentazione]]). Una variante di SCD2 a granularità mensile, pensata per contesti di reportistica dove interessa lo stato dell'entità a fine mese, non ogni variazione infra-mensile.

## Logica

Una nuova finestra di validità (`DT_INIZIO_VALIDITA`/`DT_FINE_VALIDITA`) viene aperta solo quando cambia il **payload** (colonne di business, chiavi escluse), verificato tramite hash confrontato con la versione aperta in tabella. Se due fotografie mensili consecutive hanno lo stesso hash, la finestra resta aperta (nessuna nuova riga) — i cambiamenti infra-mensili vengono assorbiti nell'ultima fotografia del mese e quindi persi.

Due modalità:
- **Full-refresh**: ricostruisce l'intera storia da tutte le osservazioni mensili disponibili (usa `LAG`/`LEAD` per collassare mesi stabili e aprire/chiudere finestre ai cambi di hash).
- **Incrementale**: confronta la "foto" del mese chiuso più recente con le finestre attualmente aperte in tabella (`{{ this }}`), e via `merge` chiude ciò che è cambiato e inserisce ciò che è nuovo — lasciando intatto il resto.

Prerequisiti modello: `materialized = incremental`, `incremental_strategy = merge`, `unique_key = key_cols + [DT_INIZIO_VALIDITA]`.

## Parametri macro

| Parametro | Ruolo |
|---|---|
| `src_sql` | SQL proiezione L2→L3, una riga per (chiave, mese); 1ª colonna = `ts_col`. Obbligatorio |
| `key_cols` | chiave naturale |
| `ts_col` | colonna "as-of" (es. `DT_OSSERVAZIONE`); default `TS_INIZIO_VALIDITA` — gestisce come input sia S1/C (`TS_INIZIO_VALIDITA`), S3 (`DT_OSSERVAZIONE`) che S2/A (`TS_INSERIMENTO`) |
| `pre_ctes` | CTE di appoggio opzionali |
| `biz_cols` | colonne business (auto-derivate via probe query se non passate) |
| `payload_cols` | colonne confrontate per rilevare cambi (default = `biz_cols - key_cols`) |
| `ref_month_end` | fine mese di riferimento (default: fine del mese scorso) |
| `dt_inizio`/`dt_fine` | nomi output colonne validità |
| `fine_validita_max` | sentinella finestra aperta (default `9999-12-31`) |

## Helper interni

`_scd2_cols`, `_scd2_cols_as`, `_scd2_join`, `_scd2_hash` — generano CSV di colonne, alias, condizioni di join e hash del payload per evitare ripetizioni tra i rami full-refresh/incrementale.

## Fasi (ramo full-refresh)

1. `ver_dedup` — una riga per (chiave, mese): l'ultima versione osservata in quel mese (`ROW_NUMBER` su `TS_INIZIO_VALIDITA DESC`).
2. `win_starts` — tiene solo dove il payload cambia rispetto al mese precedente (`LAG` + `IS DISTINCT FROM`; la prima occorrenza di una chiave apre sempre una finestra).
3. `emitted` — chiude ogni finestra alla data di inizio della successiva (`LEAD`), o a `9999-12-31` se non c'è successiva.

## Fasi (ramo incrementale)

1. `snap` — foto corrente per chiave a fine mese di riferimento.
2. `open_win` — finestre attualmente aperte in `{{ this }}`.
3. `new_rows` — nuove finestre (chiave nuova, o payload cambiato).
4. `close_rows` — chiude le finestre il cui payload è cambiato (join con `snap` su hash diverso).
5. `emitted` = `new_rows UNION ALL close_rows`, poi `MERGE` sulla `unique_key`.

Un esempio numerico completo (pratiche A/B/C su gennaio-aprile 2024) è documentato passo-passo nella guida sviluppo con tutte le CTE e i risultati intermedi — utile come riferimento per debug/onboarding, non riportato qui per esteso.

## Da chiarire

Il documento sorgente contiene punti aperti non risolti: se S1 "tradizionale" sia previsto anche in L3, e quale colonna usare nel blocco incrementale S3 quando la sorgente non ha `DT_OSSERVAZIONE` (proposta alternativa: `dt_estrazione` o "colonna rilevante", non specificata).

## Collegato da
[[layer-l3]], [[guida-sviluppo]]
