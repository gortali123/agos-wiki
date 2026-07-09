---
title: Ottimizzazione incrementale di variazioni_anagrafiche (SCD2 su CCANALOG)
type: query
tags: [layer/L2, domain/anagrafica, performance, pattern/scd2]
updated: 2026-07-08
---

# Domanda

In `raw/dwh-code/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql`, ogni run incrementale riprocessa tutta `CCANALOG` per calcolare `TS_FINE_VALIDITA` (via `LEAD` partizionato per `CD_CONTROPARTE`) e il dedup hash (via `LAG`), e solo *dopo* applica il filtro incrementale di `is_incremental_S1`. Se `CCANALOG` ha decine di miliardi di righe, questo è potenzialmente costosissimo ad ogni run. Come si ottimizza?

# Diagnosi

Confermato leggendo il codice (verificato 2026-07-08):

- `variazioni_anagrafiche.sql` righe 1-227 (`BASE`): legge tutto `{{ ref('ccanalog') }}` senza filtro incrementale, e calcola già qui `TS_FINE_VALIDITA` con la macro `ts_fine_validita` (`raw/dwh-code/macros/materialization/ts_fine_validita.sql`) → `LEAD(...) OVER (PARTITION BY CD_CONTROPARTE ORDER BY TS_INIZIO_VALIDITA)`.
- Righe 229-442 (`DEDUP`): calcola l'hash di dedup (`hash_cols`) e applica `is_incremental_S1` (`raw/dwh-code/macros/materialization/is_incremental_S1.sql`), che aggiunge un `WHERE LASTMODIFIEDDATA > max(...)` **ma dopo** che `LAG`/hash sono già stati calcolati sull'intera partizione per `CD_CONTROPARTE`.

Quindi ogni run: scan completo di `CCANALOG`, sort+partition per `CD_CONTROPARTE` per `LEAD` e `LAG`, e solo alla fine si scartano le righe non necessarie. Il filtro incrementale limita l'output ma non il lavoro di scan+window.

Punto chiave per la soluzione: `LEAD`/`LAG` sono partizionati per `CD_CONTROPARTE`. Per calcolare correttamente `TS_FINE_VALIDITA` e l'hash di dedup di un record nuovo serve solo:
1. le righe nuove/modificate dal source (delta via `LASTMODIFIEDDATA`);
2. l'ultimo record aperto (`TS_FINE_VALIDITA = 9999-12-31`) già nel target per le controparti toccate da (1) — per chiudere la validità precedente e fare il confronto hash.

Non serve la storia completa di ogni controparte.

Configurazione attuale del modello (da `variazioni_anagrafiche.yml`): `materialized: incremental`, `incremental_strategy: merge`, `unique_key: [CD_CONTROPARTE, TS_INIZIO_VALIDITA, PROGRESSIVO_PK]`. Questo è compatibile con la soluzione proposta: basta che l'output della query per una riga già esistente riporti lo stesso `unique_key` perché dbt/Snowflake la aggiorni (UPDATE) invece di duplicarla.

# Idea scartata (parziale): filtrare solo per controparti cambiate

Filtrare `WHERE CD_CONTROPARTE IN (controparti cambiate)` prima dei window function riduce il *numero* di partizioni processate ma non la *dimensione* di ciascuna: per una controparte con storia lunga, la ricalcoli tutta ad ogni run anche se è cambiata solo l'ultima riga. Non risolve il caso di clienti "storici" con centinaia di variazioni.

# Soluzione adottata: pattern SCD2 incrementale "vero"

Non ricalcolare mai `LEAD`/`LAG` sulla storia intera di una controparte. Usare solo:
- **delta**: righe nuove da CCANALOG (`LASTMODIFIEDDATA` > max nel target);
- **last-open**: la singola riga aperta (`TS_FINE_VALIDITA = 9999-12-31`) già nel target, solo per le controparti toccate dal delta.

Union dei due (tipicamente 1 riga vecchia + poche nuove per controparte), window function ricalcolati solo su questo set minuscolo, poi merge:
- se la riga `last-open` esce dal calcolo con `TS_FINE_VALIDITA` diverso da 9999, il suo `unique_key` combacia con la riga già in tabella → **UPDATE** (chiusura validità);
- le righe nuove sopravvissute al dedup hash → **INSERT**.

Nessuna macro nuova: le uniche macro riusate sono `ts_fine_validita` e `hash_cols`, già esistenti nel repo (incapsulano logica non banale, a differenza dei wrapper da 2-3 righe scartati in una prima iterazione di questa proposta). Struttura a **3 CTE**, stesso numero di quella originale (`BASE`→`DEDUP`→`DEDUP_FV`, qui `COMBINED`→`DEDUP`→`DEDUP_FV`), senza alcun `SELECT *`.

## Struttura del nuovo `variazioni_anagrafiche.sql`

Codice completo (colonne esplicite, nessun `SELECT *`): [[variazioni_anagrafiche_ottimizzato.sql|queries/variazioni_anagrafiche_ottimizzato.sql]]

Schema logico:

```
COMBINED
├─ ramo 1 (sempre): righe nuove/modificate da ccanalog
│    stesso mapping colonne di oggi (BASE), filtrato su LASTMODIFIEDDATA > max(target) se incrementale
│    + PROGRESSIVO_PK, OLD_PROGRESSIVO=NULL, OLD_TS_FINE_VALIDITA=NULL, IS_EXISTING=FALSE
└─ ramo 2 (solo incrementale, UNION ALL): riga aperta nel target
     per le sole controparti presenti nel ramo 1 (sottoquery su ccanalog, stesso filtro delta)
     WHERE TS_FINE_VALIDITA = 9999-12-31
     + PROGRESSIVO_CONTROPARTE AS OLD_PROGRESSIVO, TS_FINE_VALIDITA AS OLD_TS_FINE_VALIDITA, IS_EXISTING=TRUE

DEDUP
  = COMBINED + HASHED_COLS (hash_cols su stessa lista colonne di oggi)
  QUALIFY hash diverso da LAG(hash) per CD_CONTROPARTE — dedup, invariato nella logica, ma ora su poche righe

DEDUP_FV
  = DEDUP + TS_FV_NEXT (macro ts_fine_validita, invariata)

SELECT finale
  = uguale all'originale (stessi join a ccanatXX/cccretci), tranne:
  - PROGRESSIVO_CONTROPARTE: COALESCE(OLD_PROGRESSIVO, MAX(OLD_PROGRESSIVO) OVER(...) + ROW_NUMBER() OVER(... IS_EXISTING ...))
    al posto dei due LEFT JOIN EX/MX contro {{ this }} (eliminati, rileggevano tutto il target raggruppato)
  - QUALIFY finale: NOT (IS_EXISTING AND TS_FV_NEXT = OLD_TS_FINE_VALIDITA) — evita un UPDATE no-op
    quando tutte le righe nuove sono duplicati hash e la riga resta aperta
```

## Punti da sistemare in fase di implementazione (nel repo live, non in questo snapshot)

1. **`HASHED_COLS` non è persistita** nel target oggi (non è nell'elenco colonne finale né in `variazioni_anagrafiche.yml`). Nel ramo 2 di `COMBINED` viene ricalcolata dalle colonne già presenti nel target (stessa lista usata da `hash_cols(...)` oggi) — funziona senza modifiche di schema.
2. **Confronto nel `QUALIFY` finale**: usa `TS_FV_NEXT` puntuale mentre `TS_FINE_VALIDITA` in output è `MAX(...) OVER(...)` — coincidono tranne nel caso limite di due righe con lo stesso `TS_INIZIO_VALIDITA` per la stessa controparte (già gestito con `PROGRESSIVO_PK` come tie-breaker anche nell'originale). Da verificare con un test su dati reali.
3. **Pre-hook `delete_l2`** e **caso full-refresh** (`is_incremental()` falso) restano identici alla versione attuale: la prima materializzazione è necessariamente full scan, cambia solo il costo *ricorrente*.
4. Verificare che `LASTMODIFIEDDATA` sul target sia aggiornato anche sulla riga chiusa (dopo l'`UPDATE`), altrimenti il prossimo run rischia di non considerarla già processata per il filtro delta.
5. Il join del ramo 2 di `COMBINED` (`CD_CONTROPARTE IN (subquery su ccanalog filtrata sul delta)`) richiede che `CD_CONTROPARTE` sia una buona chiave di pruning/clustering sul target, altrimenti rischia di scansionare troppo.

# Generalizzazione

Questo è un pattern riutilizzabile per qualunque modello L2 con la stessa struttura "SCD2 storicizzato con LEAD/LAG su tutta la storia + filtro incrementale applicato dopo" — es. `variazioni_stato_prat.sql` in `PRODOTTO/` usa probabilmente lo stesso schema `is_incremental_S1`. Da candidare per una pagina [[pattern-incrementale-scd2]] in `concepts/` se si conferma che il pattern è condiviso da altri modelli (non ancora verificato).

# Stato

Proposta di design completa (codice SQL pronto in [[variazioni_anagrafiche_ottimizzato.sql|queries/variazioni_anagrafiche_ottimizzato.sql]]), non ancora implementata né validata su dati reali. Da portare nel repo `dwh-x-dbt` live e testare.
