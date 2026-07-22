---
title: "L2 ANAGR_CONTROPARTE"
type: entity
tags: [layer/L2, area/ANAGR_CONTROPARTE]
updated: 2026-07-16
---

Area funzionale L2 più documentata del progetto. Modelli (`raw/dwh-code/models/L2/ANAGR_CONTROPARTE/`):

- **`anagrafica_controparte`** — S4 (`insert_overwrite`), PK `[CD_CONTROPARTE]`, "stato corrente" della anagrafica controparte, con numerosi JOIN a lookup filtrati su `TS_FINE_VALIDITA = 9999-12-31 AND FL_DELETED='N'`. Nessun `query_tag`. Oddity: `DS_COMUNE_NASCITA` e `DS_CITTA_NASCITA` mappati dalla stessa colonna sorgente (probabile ridondanza).
- **`variazioni_anagrafiche`** — S1 (merge SCD2), modello più elaborato del progetto: usa [[progressivo-pk-e-progressivo-controparte]] (`PR_PK`, `PROGRESSIVO_CONTROPARTE`), `pre_hook: delete_l2('ccanalog', ['CD_CONTROPARTE'], ['AL_CODICE'])`, dedup via hash/QUALIFY/LAG completamente bespoke (unico modello S1 del progetto a non usare la macro condivisa `is_incremental_S1` — vedi [[storicizzazione-l2-s1-s4]], riverificato 2026-07-20). Sorgente main: `CCANALOG` (cluster A1 secondo xlsx Catalogo Entità). **Fix applicato upstream** (verificato 2026-07-16 dopo resync `raw/dwh-code/`): il primo record storico per controparte ora usa `COALESCE(AL_DATA_INSERIMENTO, AL_DATA_MODIFICA/AL_ORA_MODIFICA)` come `TS_INIZIO_VALIDITA` (`raw/dwh-code/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql`, righe 7-16); il file proposto in `develop/` è stato rimosso dopo il porting (vedi `log.md`, 2026-07-15 "pulizia develop/ dopo sync raw/dwh-code"). **Rinominato 2026-07-20** (nuovo resync): il campo tecnico era `PROGRESSIVO_PK`, ora è `PR_PK` in `unique_key`/`constraints`/colonne yml — allineato al nome usato dalla guida sviluppo aggiornata (sezione 5.1, variante S1 senza PK propria) e alla convenzione prefisso `PR_` della xlsx. Vedi [[progressivo-pk-e-progressivo-controparte]]. **Bug individuato 2026-07-21, fix con split ramo1/ramo2 poi rivelatosi non funzionante (segnalato dall'utente 2026-07-22)**: il fix del 2026-07-21 riscriveva il modello con una CTE `COMBINED` a due rami (ramo1: delta via `LEFT JOIN EXISTING_CODES` + `EX.CD_CONTROPARTE IS NULL`; ramo2: riga aperta nel target per le controparti toccate) per evitare che la riga più vecchia *del solo delta* fosse scambiata per il vero primo record storico. Questa versione risulta non funzionante nell'uso reale.

**Fix sostitutivo 2026-07-22 (proposto in `develop/`, non ancora portato upstream)**: ripristinata la struttura originale `variazioni_anagrafiche.sql.old` (CTE `BASE` → `DEDUP` con la macro condivisa `is_incremental_S1`, nessuno split ramo1/ramo2) e reintegrata la logica `AL_DATA_INSERIMENTO`. Punto chiave: in questa struttura `BASE` rilegge sempre l'intero storico di `ccanalog` ad ogni run (il filtro incrementale è applicato dopo, dentro `is_incremental_S1`, non su `BASE`) — quindi `ROW_NUMBER() OVER (PARTITION BY CC.AL_CODICE ORDER BY ...) = 1` individua già il vero primo record storico per costruzione, senza bisogno del check aggiuntivo `EX.CD_CONTROPARTE IS NULL` che serviva solo nella versione con split (dove il ramo1 leggeva solo il delta). `TS_FINE_VALIDITA` di `BASE` è stato aggiornato di conseguenza per restare coerente con la stessa espressione di `TS_INIZIO_VALIDITA` (stesso `CASE`, passato anche a `ts_fine_validita()` per l'ordinamento del `LEAD`).
- **`variazioni_anagrafiche_day`** — derivato giornaliero di `variazioni_anagrafiche` (non dell'L1 diretto), un record per (controparte, giorno). **Il file è marcato nell'header come proposta non testata su dati reali** — verificarne lo stato reale prima di considerarlo canonico.
- **`legame_pratica_controparte`** — S2 (append), PK composta a 5 colonne. Contiene un TODO irrisolto nel codice: `-- TODO: riceviamo 0, perchè?` su `TS_INSERIMENTO`.
- **`legame_ditte_individuali`** — S2-like, usa `LAG()` per rilevare cambi di riferimento P.IVA/controparte.
- **`indirizzi_postalizzazione`** — S1, TS_INIZIO/FINE_VALIDITA ereditati direttamente dalla sorgente L1 (diversamente da `variazioni_anagrafiche` che li ricalcola).
- **`segnalazioni_anagrafiche`** — S2, `pre_hook: delete_l2` con chiave composta a 4 colonne (la più lunga vista nell'area). Ha `NM_ORA_INSERIMENTO_RECORD` che devia dalla naming convention (NM_ per un valore orario).

Nessun modello dell'area ha `query_tag` valorizzato — vedi [[storicizzazione-l2-s1-s4]] e [[inconsistenze]].

File orfani nella cartella: `variazioni_anagrafiche.sql.old`, `variazioni_anagrafiche_day.sql.old`.

## Collegamenti

- [[layer-l2]]
- [[storicizzazione-l2-s1-s4]]
- [[progressivo-pk-e-progressivo-controparte]]
- [[inconsistenze]]
