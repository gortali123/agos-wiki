---
title: "PROGRESSIVO_PK e PROGRESSIVO_CONTROPARTE"
type: concept
tags: [layer/L2, storicizzazione, entita/VARIAZIONI_ANAGRAFICHE]
updated: 2026-07-14
---

Pattern documentato in [[caricamento-layer-l2]] e [[guida-sviluppo]] per gestire archivi L1 con chiave primaria non univoca (l'unica PK certa è il campo tecnico `ROWID`).

- **`PROGRESSIVO_PK`**: disambigua record fisici distinti che condividono la stessa chiave funzionale e lo stesso timestamp di modifica. Calcolato come `ROW_NUMBER() OVER (PARTITION BY <chiave_funzionale>, <data_modifica>, <ora_modifica> ORDER BY <ROWID>)`. Si estende a `unique_key`/`primary_key` del modello.
- **`PROGRESSIVO_CONTROPARTE`**: campo aggiuntivo, **specifico solo di `VARIAZIONI_ANAGRAFICHE`**, che numera le versioni di una controparte partizionando su `AL_CODICE` (codice controparte) e ordinando su `ROWID`.

## Verifica nel codice (2026-07-14)

Confermato: **`VARIAZIONI_ANAGRAFICHE` è l'unico modello in tutta `raw/dwh-code/models/L2/` che usa questo pattern.** Nel modello reale:

- `PROGRESSIVO_PK` = `ROW_NUMBER() OVER (PARTITION BY CC.AL_CODICE, CC.AL_DATA_MODIFICA, CC.AL_ORA_MODIFICA ORDER BY CC.ROWID)`, incluso in `unique_key: [CD_CONTROPARTE, TS_INIZIO_VALIDITA, PROGRESSIVO_PK]`.
- `PROGRESSIVO_CONTROPARTE` = `COALESCE(OLD_PROGRESSIVO, COALESCE(MAX(OLD_PROGRESSIVO) OVER (PARTITION BY CD_CONTROPARTE),0) + ROW_NUMBER() OVER (PARTITION BY CD_CONTROPARTE, IS_EXISTING ORDER BY TS_INIZIO_VALIDITA, PROGRESSIVO_PK))` — un contatore di generazione per controparte, portato avanti tra run incrementali via `OLD_PROGRESSIVO`.
- Modelli affini (`variazioni_anagrafiche_day`, `indirizzi_postalizzazione`, `legame_pratica_controparte`) **non** usano né `PROGRESSIVO_PK` né `PROGRESSIVO_CONTROPARTE`: hanno una chiave naturale/composita sufficiente. Conferma quanto dichiarato nei docx.

Nota su naming: né `PROGRESSIVO_PK` né `PROGRESSIVO_CONTROPARTE` usano il prefisso `PR_` (Progressivo) della xlsx — vedi [[naming-convention-agos-x]].

## Fix proposto: TS_INIZIO_VALIDITA del primo record storico (2026-07-14)

Bug funzionale (non un'inconsistenza doc-vs-codice, ma una correzione di logica) concordato con l'utente: per ogni controparte, il **primo record storico** (il più vecchio) deve avere `TS_INIZIO_VALIDITA` derivato da `AL_DATA_INSERIMENTO` (a mezzanotte, `custom_to_timestamp_ntz('CC.AL_DATA_INSERIMENTO')` — vedi [[macro-catalogo-dbt]]) invece che da `AL_DATA_MODIFICA`/`AL_ORA_MODIFICA` come tutti gli altri record. Motivazione: l'inserimento precede sempre la modifica, quindi il primo stato noto della controparte deve risultare valido da quando è stata effettivamente creata, non da quando è stata (eventualmente) modificata la prima volta.

- **Proposto in**: `develop/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql` (non ancora applicato in `raw/dwh-code/` / upstream).
- **Implementazione (semplificata su richiesta dell'utente, senza guard NULL/NOT EXISTS)**: `CASE` su `TS_INIZIO_VALIDITA` nel branch 1 di `COMBINED` — se `ROW_NUMBER() OVER (PARTITION BY AL_CODICE ORDER BY AL_DATA_MODIFICA, AL_ORA_MODIFICA, ROWID) = 1` usa `AL_DATA_INSERIMENTO`, altrimenti `AL_DATA_MODIFICA`/`AL_ORA_MODIFICA` come prima. Nessun controllo su `AL_DATA_INSERIMENTO` NULL/zero né `NOT EXISTS` contro `{{ this }}`: la prima versione andava bene per i futuri run incrementali, ma è stata scartata come inutile overengineering vista la scelta di fare comunque un full-refresh (vedi sotto).
- **Rollout concordato**: l'utente farà un **full-refresh** per ripulire lo storico già caricato con la regola vecchia — la semplificazione della condizione è corretta in questo scenario perché ad ogni run tutta la storia di ogni controparte passa dal branch 1, quindi `ROW_NUMBER() = 1` identifica sempre il vero primo record.
- **Non toccato**: `PROGRESSIVO_PK` (partizionato su `AL_DATA_MODIFICA`/`AL_ORA_MODIFICA`, non su `TS_INIZIO_VALIDITA`) resta invariato; `DEDUP`/`ts_fine_validita` funzionano invariati perché `AL_DATA_INSERIMENTO` è comunque precedente a `AL_DATA_MODIFICA`, quindi l'ordinamento cronologico non cambia.
- **Non ancora deciso/verificato**: se propagare la stessa correzione a `variazioni_anagrafiche_day` (che deriva da questo modello) — quel file è comunque già segnalato come proposta non testata, vedi sotto.

## Nota sul file `variazioni_anagrafiche_day.sql`

Il file contiene un header che lo dichiara esplicitamente una **proposta di riscrittura non testata su dati reali** ("PROPOSTA", "Non testata su dati reali"), che rimanda a un documento esterno `queries/ottimizzazione-variazioni-anagrafiche-day-scd2.md` non presente in questo wiki. Non è confermato se sia la versione effettivamente deployata in produzione — da verificare col team prima di considerarla come comportamento canonico. Esistono anche file orfani `variazioni_anagrafiche.sql.old` e `variazioni_anagrafiche_day.sql.old` nella stessa cartella.

## Collegamenti

- [[caricamento-layer-l2]], [[guida-sviluppo]]
- [[storicizzazione-l2-s1-s4]]
- [[inconsistenze-doc-vs-codice]]
