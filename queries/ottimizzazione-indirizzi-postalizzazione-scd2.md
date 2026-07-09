---
title: Ottimizzazione incrementale di indirizzi_postalizzazione (SCD2 su BAPRATAG)
type: query
tags: [layer/L2, domain/anagrafica, performance, pattern/scd2]
updated: 2026-07-09
---

# Domanda

Stesso problema già diagnosticato per `variazioni_anagrafiche.sql` ([[ottimizzazione-variazioni-anagrafiche-scd2]]): anche `raw/dwh-code/models/L2/ANAGR_CONTROPARTE/indirizzi_postalizzazione.sql` ricalcola `TS_FINE_VALIDITA` e l'hash di dedup su tutta la storia della partizione prima di applicare il filtro incrementale. Si applica lo stesso pattern di ottimizzazione?

# Diagnosi

Confermato leggendo il codice (verificato 2026-07-09):

- `BASE` (righe 1-38): legge tutto `{{ ref('bapratag') }}` senza filtro incrementale.
- `DEDUP` (righe 40-79): calcola l'hash (`hash_cols`) e applica `is_incremental_S1` (`raw/dwh-code/macros/materialization/is_incremental_S1.sql`) partizionato per `CD_PRATICA, TP_PROCEDURA` — il `LAG` per il dedup gira già su tutta la storia della pratica prima che il filtro `WHERE LASTMODIFIEDDATA > max(...)` scarti le righe non necessarie.
- `SELECT` finale (riga 85): `{{ ts_fine_validita('H.CD_PRATICA, H.TP_PROCEDURA', 'H.TS_INIZIO_VALIDITA') }}` → stesso `LEAD` su tutta la partizione, stesso problema di `variazioni_anagrafiche.sql`.

Differenza rispetto a `variazioni_anagrafiche.sql` (rende la soluzione più semplice, non più complessa):
- **Nessun `PROGRESSIVO_PK` / `PROGRESSIVO_CONTROPARTE`**: la `unique_key` del modello (`indirizzi_postalizzazione.yml`) è `[CD_PRATICA, TP_PROCEDURA, TS_INIZIO_VALIDITA]` — non serve un progressivo separato perché non ci sono righe con lo stesso `TS_INIZIO_VALIDITA` per la stessa pratica da distinguere via tie-breaker.
- **Nessun join a tabelle di lookup** nel `SELECT` finale (niente `ccanatXX`/descrizioni) — il finale è quasi identico a `DEDUP_FV`.
- Chiave di partizione composita (`CD_PRATICA, TP_PROCEDURA`) invece di una singola colonna (`CD_CONTROPARTE`), ma il pattern si applica identico: basta portare entrambe le colonne nel `PARTITION BY` e nella condizione di join del ramo 2.

Configurazione attuale (`indirizzi_postalizzazione.yml`): `materialized: incremental`, `incremental_strategy: merge`, `unique_key: [CD_PRATICA, TP_PROCEDURA, TS_INIZIO_VALIDITA]` — compatibile con la stessa soluzione: se l'output per una riga già esistente riporta la stessa `unique_key`, dbt/Snowflake fa `UPDATE` invece di duplicare.

# Soluzione adottata: stesso pattern SCD2 incrementale "vero"

Stessa struttura a 3 CTE di [[variazioni_anagrafiche_ottimizzato.sql|queries/variazioni_anagrafiche_ottimizzato.sql]] (`COMBINED`→`DEDUP`→`DEDUP_FV`), semplificata perché non serve gestire `PROGRESSIVO_PK`/`PROGRESSIVO_CONTROPARTE` né i join di lookup:

```
COMBINED
├─ ramo 1 (sempre): righe nuove/modificate da bapratag
│    stesso mapping colonne di oggi (BASE), filtrato su LASTMODIFIEDDATA > max(target) se incrementale
│    + OLD_TS_FINE_VALIDITA=NULL, IS_EXISTING=FALSE
└─ ramo 2 (solo incrementale, UNION ALL): riga aperta nel target
     per le sole pratiche (CD_PRATICA, TP_PROCEDURA) presenti nel ramo 1 (sottoquery su bapratag, stesso filtro delta)
     WHERE TS_FINE_VALIDITA = 9999-12-31
     + TS_FINE_VALIDITA AS OLD_TS_FINE_VALIDITA, IS_EXISTING=TRUE

DEDUP
  = COMBINED + HASHED_COLS (hash_cols su stessa lista colonne di oggi)
  QUALIFY hash diverso da LAG(hash) PARTITION BY CD_PRATICA, TP_PROCEDURA — dedup invariato nella logica, ora su poche righe

DEDUP_FV
  = DEDUP + TS_FV_NEXT (macro ts_fine_validita, PARTITION BY CD_PRATICA, TP_PROCEDURA — invariata)

SELECT finale
  = stesso mapping colonne dell'originale (nessun join da eliminare, a differenza di variazioni_anagrafiche)
  TS_FINE_VALIDITA: MAX(TS_FV_NEXT) OVER (PARTITION BY CD_PRATICA, TP_PROCEDURA, TS_INIZIO_VALIDITA) — stessa tecnica
  QUALIFY finale: NOT (IS_EXISTING AND TS_FV_NEXT = OLD_TS_FINE_VALIDITA) — evita un UPDATE no-op
    quando le righe nuove sono tutte duplicati hash e la riga resta aperta
```

Codice completo (colonne esplicite, nessun `SELECT *`): [[indirizzi_postalizzazione_ottimizzato.sql|queries/indirizzi_postalizzazione_ottimizzato.sql]]

## Punti da sistemare in fase di implementazione (nel repo live, non in questo snapshot)

1. **`HASHED_COLS` non è persistita** nel target (non è in `indirizzi_postalizzazione.yml`). Nel ramo 2 di `COMBINED` viene ricalcolata dalle colonne già presenti nel target — funziona senza modifiche di schema, come nell'analogo per `variazioni_anagrafiche`.
2. Il join del ramo 2 di `COMBINED` è su una tupla `(CD_PRATICA, TP_PROCEDURA) IN (subquery)` invece di una singola colonna: verificare il piano di query su Snowflake (subquery con più colonne in `IN` può performare diversamente da una singola colonna) e il clustering del target su queste due colonne.
3. **Pre-hook `delete_l2`** e **caso full-refresh** (`is_incremental()` falso) restano identici alla versione attuale.
4. Verificare che `LASTMODIFIEDDATA` sul target sia aggiornato anche sulla riga chiusa dopo l'`UPDATE`, altrimenti il filtro delta del run successivo rischia di non vederla come già processata (stesso punto aperto dell'analogo per `variazioni_anagrafiche`).

# Generalizzazione

Seconda istanza confermata dello stesso pattern "SCD2 storicizzato con LEAD/LAG su tutta la storia + filtro incrementale applicato dopo", dopo `variazioni_anagrafiche.sql`. Rafforza il caso per una pagina [[pattern-incrementale-scd2]] in `concepts/` — da scrivere quando si trova una terza istanza o si implementa una delle due proposte.

# Stato

Proposta di design completa (codice SQL pronto in [[indirizzi_postalizzazione_ottimizzato.sql|queries/indirizzi_postalizzazione_ottimizzato.sql]]), non ancora implementata né validata su dati reali. Da portare nel repo `dwh-x-dbt` live e testare.
