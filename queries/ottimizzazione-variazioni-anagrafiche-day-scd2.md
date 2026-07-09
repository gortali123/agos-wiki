---
title: Ottimizzazione incrementale di variazioni_anagrafiche_day (SCD2 giorno su variazioni_anagrafiche)
type: query
tags: [layer/L2, domain/anagrafica, performance, pattern/scd2]
updated: 2026-07-09
---

# Domanda

Stesso problema già diagnosticato per `variazioni_anagrafiche.sql` ([[ottimizzazione-variazioni-anagrafiche-scd2]]) e `indirizzi_postalizzazione.sql` ([[ottimizzazione-indirizzi-postalizzazione-scd2]]): si applica anche a `raw/dwh-code/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche_day.sql`?

# Diagnosi

Confermato leggendo il codice (verificato 2026-07-09):

- `BASE` (righe 1-236): legge tutto `{{ ref('variazioni_anagrafiche') }}` senza filtro incrementale e dedup-a-giorno già qui, con `QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_CONTROPARTE, giorno ORDER BY TS_INIZIO_VALIDITA DESC, PROGRESSIVO_PK DESC) = 1` — sceglie la variazione più tarda del giorno.
- `DAY` (righe 238-474): calcola `DT_FINE_VALIDITA` con `LEAD(DT_INIZIO_VALIDITA) OVER (PARTITION BY CD_CONTROPARTE ORDER BY DT_INIZIO_VALIDITA)` — su tutta la storia della controparte, non solo sui giorni cambiati.
- `SELECT` finale (righe 476-719): applica il filtro incrementale (`LASTMODIFIEDDATA` o `DT_FINE_VALIDITA` scaduta) solo alla fine, dopo che `ROW_NUMBER` e `LEAD` hanno già scansionato tutto.

Stesso pattern "SCD2 storicizzato con window function su tutta la storia + filtro incrementale applicato dopo", terza istanza dopo `variazioni_anagrafiche.sql` e `indirizzi_postalizzazione.sql` — rafforza il caso per [[pattern-incrementale-scd2]] in `concepts/` (ancora da scrivere).

Differenze rispetto ai due casi precedenti:
- **Nessun dedup-hash (`HASHED_COLS`)**: questo modello non ha una logica "scarta se identico al record precedente", ha solo "una riga per (controparte, giorno)". Aggregazione via `ROW_NUMBER`, non `hash_cols`/`LAG`.
- **Fonte già SCD2 incrementale a grana evento** (`variazioni_anagrafiche`, oggetto di [[ottimizzazione-variazioni-anagrafiche-scd2]]), non una tabella L1 grezza: il delta da usare per il filtro è lo stesso `LASTMODIFIEDDATA` del modello upstream.
- **Punto critico non presente nei due casi precedenti**: per rideterminare correttamente il "vincitore" del giorno via `ROW_NUMBER`, il ramo delta non può limitarsi alle righe *nuove* di `variazioni_anagrafiche` — deve includere **tutte** le righe di `variazioni_anagrafiche` per i `(CD_CONTROPARTE, giorno)` toccati dal delta, altrimenti una nuova riga con `TS_INIZIO_VALIDITA` non necessariamente più recente di una riga già esistente nello stesso giorno rischierebbe di essere scelta (o scartata) senza confrontarla con le sorelle del giorno. Questo perché a differenza di `ccanalog`/`bapratag` (fonti a grana evento con PK naturale), qui la "riga" è già un aggregato (il giorno) e il vincitore dipende da tutte le righe del giorno, non solo dall'ultima arrivata.
- **Nessuna `unique_key` con progressivo**: `unique_key: [CD_CONTROPARTE, DT_INIZIO_VALIDITA]` (da `variazioni_anagrafiche_day.yml`), compatibile 1:1 con l'output della soluzione.

# Soluzione adottata: stesso pattern SCD2 incrementale, con il fix sul ramo 1

```
COMBINED
├─ ramo 1 (sempre): righe di variazioni_anagrafiche per i (controparte, giorno) toccati dal delta
│    filtro (se incrementale): (CD_CONTROPARTE, giorno) IN (subquery su variazioni_anagrafiche
│    filtrata su LASTMODIFIEDDATA > max(target)) — NON solo le righe nuove, tutte quelle del giorno
│    QUALIFY ROW_NUMBER ... = 1 (stessa logica di oggi, ora su un set piccolo)
│    + OLD_DT_FINE_VALIDITA=NULL, IS_EXISTING=FALSE
└─ ramo 2 (solo incrementale, UNION ALL): riga aperta nel target
     per le sole controparti toccate dal ramo 1 (stesso filtro delta)
     WHERE DT_FINE_VALIDITA = 9999-12-31
     + DT_FINE_VALIDITA AS OLD_DT_FINE_VALIDITA, IS_EXISTING=TRUE

DAY
  = COMBINED + DT_FV_NEXT (LEAD(DT_INIZIO_VALIDITA) PARTITION BY CD_CONTROPARTE — invariato, ora su poche righe)

SELECT finale
  = stesso mapping colonne dell'originale
  DT_FINE_VALIDITA: MAX(DT_FV_NEXT) OVER (PARTITION BY CD_CONTROPARTE, DT_INIZIO_VALIDITA) — stessa tecnica
    usata per gli altri due modelli
  QUALIFY finale: NOT (IS_EXISTING AND DT_FV_NEXT = OLD_DT_FINE_VALIDITA) — evita un UPDATE no-op
```

Codice completo (colonne esplicite, nessun `SELECT *`): [[variazioni_anagrafiche_day_ottimizzato.sql|queries/variazioni_anagrafiche_day_ottimizzato.sql]]

## Punti da sistemare in fase di implementazione (nel repo live, non in questo snapshot)

1. **Costo del ramo 1**: il filtro `(CD_CONTROPARTE, giorno) IN (subquery)` richiede comunque uno scan di `variazioni_anagrafiche` per i giorni toccati — non è "solo il delta" come negli altri due modelli, ma è comunque uno scan filtrato per pochi `(controparte, giorno)` invece di un `LEAD`/`ROW_NUMBER` su tutta la tabella. Da validare che il filtro sia sargable/pruning-friendly su Snowflake (dipende dal clustering di `variazioni_anagrafiche` su `CD_CONTROPARTE`).
2. **Dipendenza a cascata**: questo modello legge `{{ ref('variazioni_anagrafiche') }}`, quindi il suo filtro incrementale corretto presuppone che l'ottimizzazione proposta in [[ottimizzazione-variazioni-anagrafiche-scd2]] (o comunque il modello upstream) aggiorni `LASTMODIFIEDDATA` in modo coerente — stesso punto aperto #4 di quella pagina, propagato qui.
3. **Pre-hook e caso full-refresh** restano identici alla versione attuale.
4. Non testato il caso limite di due variazioni nello stesso giorno con `TS_INIZIO_VALIDITA` identico (già gestito nell'originale con `PROGRESSIVO_PK` come tie-breaker nel `ROW_NUMBER`, mantenuto identico qui).

# Generalizzazione

Terza istanza confermata dello stesso pattern, la prima con la complicazione "il delta grezzo non basta, serve tutto il giorno". Conferma che vale la pena scrivere [[pattern-incrementale-scd2]] in `concepts/`, distinguendo la variante "grana evento" (`variazioni_anagrafiche`, `indirizzi_postalizzazione`) dalla variante "aggregato per periodo" (`variazioni_anagrafiche_day`).

# Stato

Proposta di design completa (codice SQL pronto in [[variazioni_anagrafiche_day_ottimizzato.sql|queries/variazioni_anagrafiche_day_ottimizzato.sql]]), non ancora implementata né validata su dati reali. Da portare nel repo `dwh-x-dbt` live e testare, con priorità dopo (o insieme a) l'ottimizzazione del modello upstream `variazioni_anagrafiche`.
