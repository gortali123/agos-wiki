---
title: "L2 ANAGR_CONTROPARTE"
type: entity
tags: [layer/L2, area/ANAGR_CONTROPARTE]
updated: 2026-07-14
---

Area funzionale L2 più documentata del progetto. Modelli (`raw/dwh-code/models/L2/ANAGR_CONTROPARTE/`):

- **`anagrafica_controparte`** — S4 (`insert_overwrite`), PK `[CD_CONTROPARTE]`, "stato corrente" della anagrafica controparte, con numerosi JOIN a lookup filtrati su `TS_FINE_VALIDITA = 9999-12-31 AND FL_DELETED='N'`. Nessun `query_tag`. Oddity: `DS_COMUNE_NASCITA` e `DS_CITTA_NASCITA` mappati dalla stessa colonna sorgente (probabile ridondanza).
- **`variazioni_anagrafiche`** — S1 (merge SCD2), modello più elaborato del progetto: usa [[progressivo-pk-e-progressivo-controparte]] (`PROGRESSIVO_PK`, `PROGRESSIVO_CONTROPARTE`), `pre_hook: delete_l2('ccanalog', ['CD_CONTROPARTE'], ['AL_CODICE'])`, dedup via hash bespoke (non usa la macro condivisa `is_incremental_S1`). Sorgente main: `CCANALOG` (cluster A1 secondo xlsx Catalogo Entità). **Fix in corso** (2026-07-14, non ancora applicato upstream): il primo record storico per controparte userà `AL_DATA_INSERIMENTO`@00:00 invece di `AL_DATA_MODIFICA`/`AL_ORA_MODIFICA` come `TS_INIZIO_VALIDITA` — vedi `develop/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql` e [[progressivo-pk-e-progressivo-controparte]]. Da applicare con un full-refresh.
- **`variazioni_anagrafiche_day`** — derivato giornaliero di `variazioni_anagrafiche` (non dell'L1 diretto), un record per (controparte, giorno). **Il file è marcato nell'header come proposta non testata su dati reali** — verificarne lo stato reale prima di considerarlo canonico.
- **`legame_pratica_controparte`** — S2 (append), PK composta a 5 colonne. Contiene un TODO irrisolto nel codice: `-- TODO: riceviamo 0, perchè?` su `TS_INSERIMENTO`.
- **`legame_ditte_individuali`** — S2-like, usa `LAG()` per rilevare cambi di riferimento P.IVA/controparte.
- **`indirizzi_postalizzazione`** — S1, TS_INIZIO/FINE_VALIDITA ereditati direttamente dalla sorgente L1 (diversamente da `variazioni_anagrafiche` che li ricalcola).
- **`segnalazioni_anagrafiche`** — S2, `pre_hook: delete_l2` con chiave composta a 4 colonne (la più lunga vista nell'area). Ha `NM_ORA_INSERIMENTO_RECORD` che devia dalla naming convention (NM_ per un valore orario).

Nessun modello dell'area ha `query_tag` valorizzato — vedi [[storicizzazione-l2-s1-s4]] e [[inconsistenze-doc-vs-codice]].

File orfani nella cartella: `variazioni_anagrafiche.sql.old`, `variazioni_anagrafiche_day.sql.old`.

## Collegamenti

- [[layer-l2]]
- [[storicizzazione-l2-s1-s4]]
- [[progressivo-pk-e-progressivo-controparte]]
- [[inconsistenze-doc-vs-codice]]
