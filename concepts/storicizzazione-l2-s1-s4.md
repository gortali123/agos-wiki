---
title: "Storicizzazione L2: pattern S1-S4"
type: concept
tags: [layer/L2, storicizzazione]
updated: 2026-07-16
---

I quattro pattern di storicizzazione L2 documentati in [[caricamento-layer-l2]] e [[guida-sviluppo]], verificati contro i modelli reali in `raw/dwh-code/models/L2/` (risincronizzato 2026-07-16 dalla repo live; ricontrollato in data).

| Pattern | Materializzazione | Chiave tecnica | Uso tipico |
|---|---|---|---|
| **S1** (SCD2) | `incremental`, `merge` | `TS_INIZIO_VALIDITA`/`TS_FINE_VALIDITA` | storia versionata di un'entità (es. `VARIAZIONI_ANAGRAFICHE`, `INDIRIZZI_POSTALIZZAZIONE`, `WFL_ISTANZA`, `CARTE_UTILIZZI`) |
| **S2** (append giornaliero) | `incremental`, `append` | `TS_INSERIMENTO` | eventi/inserimenti puntuali (es. `LEGAME_PRATICA_CONTROPARTE`, `SEGNALAZIONI_ANAGRAFICHE`, `ANTIFRODE.*`, `GIORNI_SCADUTO`) |
| **S3** (append mensile) | `incremental`, `append` | `DT_OSSERVAZIONE`, pre_hook `delete_month()` | consolidati di fine mese (es. `PRATICA_M`, `SALDO_CONTABILE_M`) |
| **S4** (attualizzato) | `incremental`, `insert_overwrite` | — | stato corrente, full rebuild (es. `ANAGRAFICA_CONTROPARTE`, `PRATICA`, `CESSIONI`, tutte le `SWORD.*`) |

Regola d'ordine colonne (da [[caricamento-layer-l2]]): campi di storicizzazione subito dopo la PK funzionale, `LASTMODIFIEDDATA` sempre in coda.

## Due implementazioni di S1 coesistenti nel codice (corretto 2026-07-16)

Ricontrollato dopo il resync di `raw/dwh-code/`: la caratterizzazione precedente ("bespoke con hash_cols" vs "macro `is_incremental_S1` senza CTE di dedup") era imprecisa e comunque superata dall'adozione più ampia della macro. Stato attuale:

1. **Completamente bespoke** (nessun uso di `is_incremental_S1`): solo `variazioni_anagrafiche.sql` (`raw/dwh-code/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql`), che usa `is_incremental()` grezzo + `QUALIFY ... IS DISTINCT FROM LAG(...)` manuale e `{{ ts_fine_validita(...) }}` per calcolare `TS_FINE_VALIDITA`.
2. **`hash_cols()` + macro condivisa `is_incremental_S1(...)`**: tutti gli altri modelli S1 ispezionati costruiscono comunque una CTE con `{{ hash_cols([...]) }}` per calcolare `HASHED_COLS`, poi passano quella colonna alla macro `is_incremental_S1`, che internamente applica sia il filtro incrementale (`WHERE LASTMODIFIEDDATA > ...` o finestra `TS_FINE_VALIDITA` aperta) sia il `QUALIFY HASHED_COLS IS DISTINCT FROM LAG(HASHED_COLS) OVER (...)` di dedup — quindi la macro non salta il dedup-hash, lo assorbe. Verificato in `raw/dwh-code/macros/materialization/is_incremental_S1.sql` e in almeno 8 modelli: `models/L2/ANAGR_CONTROPARTE/indirizzi_postalizzazione.sql`, `models/L2/CARTE/carte_utilizzi.sql`, `models/L2/ONBOARDING/wfl_istanza.sql`, `wfl_attivita.sql`, `wfl_fase.sql`, `wfl_sottofase.sql`, `models/L2/PRODOTTO/tabelle_finanziarie.sql`, `models/L2/PRODOTTO/variazioni_stato_prat.sql`.

Quindi non è più corretto dire che "solo `wfl_istanza` usa la macro condivisa": l'adozione di `is_incremental_S1` è oggi la norma per i nuovi modelli S1, e `variazioni_anagrafiche.sql` è l'eccezione bespoke residua (probabilmente per storia/anzianità del modello). Nessuna evidenza che le due varianti producano risultati diversi nella pratica — la macro condivisa è funzionalmente equivalente al pattern manuale, solo fattorizzata. Voce corrispondente in [[inconsistenze]] aggiornata/risolta.

## query_tag: copertura incompleta

Vedi pagina dedicata [[query-tag-monitoring]] (copertura reale nel codice, schemi errati, tassonomie di naming non riconciliate).

## Gestione cancellazioni: due approcci non equivalenti

- **`pre_hook: delete_l2(...)`**: DELETE fisica reale in `{{ this }}` per le chiavi con `FL_DELETED='Y'` più recenti del max `LASTMODIFIEDDATA` in target (approccio prescritto da [[guida-sviluppo]]).
- **Solo filtro `WHERE FL_DELETED = 'N'`** nel SELECT del modello, senza alcun DELETE fisico sulle righe già caricate in precedenza e ora cancellate (visto in `ANTIFRODE.archivio_tessere` e altri modelli senza `delete_l2`).

Questi due approcci **non sono equivalenti**: il secondo lascia righe stale nel target quando una chiave viene cancellata dopo essere già stata caricata. Vedi [[cancellazioni-fl-deleted]] e [[inconsistenze]].

## Collegamenti

- [[caricamento-layer-l2]], [[guida-sviluppo]]
- [[progressivo-pk-e-progressivo-controparte]]
- [[cancellazioni-fl-deleted]]
- [[macro-catalogo-dbt]]
- [[query-tag-monitoring]]
- [[inconsistenze]]
