---
title: Layer L2
type: entity
tags: [layer/L2]
updated: 2026-07-07
---

Layer di modellazione delle entità di business, organizzato per **area funzionale** (schema `L2_<area_funzionale>`, es. `L2_ANAGR_CONTROPARTE`). Popolato da DBT a partire da L1, orchestrato da Control-M.

## Triggering ed esecuzione

- Un modello DBT per entità (più eventuali modelli intermedi per performance/ottimizzazione).
- Comando: `dbt build -s <nome_modello>` (**senza `+`**, a differenza di L1 — corretto per design: i test sulle source si eseguono solo in L1, non in L2).
- Dipendenze estraibili da `manifest.json` o dalle tabelle `DBT_ARTIFACTS.MODELS`/`DBT_ARTIFACTS.SNAPSHOTS` (colonna `DEPENDS_ON_NODE`).
- Controlli sulla bontà L1 basati sulla vista `VW_L1_TEST_RESULTS`.
- Tabella Snowflake standard (non transient), time travel + fail safe consigliati a 7 giorni.

## Lettura da L1 — regole

- Escludere sempre le chiavi con `FL_DELETED = 'Y'` (direttamente o in condizione di JOIN).
- Per tabelle L1 SCD2 (Cluster C): filtro `TS_INIZIO_VALIDITA <= data_di_interesse < TS_FINE_VALIDITA`. **Mai `BETWEEN`** (include entrambi gli estremi → possibili duplicati).
- Conversioni data/importo tramite macro dedicate — vedi tabella in [[storicizzazione-l2-s1-s4]].

## Storicizzazione

Vedi [[storicizzazione-l2-s1-s4]] (S1-S4).

## Gestione chiavi duplicate in L1

Per archivi con PK non univoca in L1 (es. `CCANALOG`): dedup tramite hash di righe consecutive per stessa controparte; se identiche, si tiene un solo record. Campo tecnico `PROGRESSIVO_PK` (partizione su chiave, ordinamento per `ROWID`). Per l'entità **VARIAZIONI_ANAGRAFICHE** in aggiunta `PROGRESSIVO_CONTROPARTE` (partizione su `AL_CODICE`).

## Cancellazioni

Vedi [[gestione-cancellazioni]] (sezione L2).

## Naming convention e data masking

Vedi [[naming-conventions]] e [[data-masking]].

## Query tag

Obbligatorio nel file yml di ogni modello L2: `{"app": "DBT", "schema": "L2_<AREA>", "entita": "<ENTITA>"}`. Chiave corretta confermata: `"entita"` **senza accento** (il documento ufficiale L2 riporta erroneamente `"entità"` in un esempio — refuso da correggere, vedi [[todo-allineamento-documentazione]]).

## Checklist pre-rilascio

Dettagliata in [[guida-sviluppo]] §5.4: tipi dato per prefisso campo, tracciato/ordine colonne, coerenza cluster/join SCD2, query_tag, niente `SELECT *`, no duplicazione config già coperte da `dbt_project.yml`, `dbt.exe compile` prima della MR.

## Collegato da
[[agosx-caricamento-l2]], [[guida-sviluppo]], [[layer-l1]], [[layer-l3]]
