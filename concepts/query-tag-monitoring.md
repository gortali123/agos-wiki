---
title: "query_tag per monitoring"
type: concept
tags: [monitoring, convention, layer/L2]
updated: 2026-07-15
---

Il `query_tag` è un campo di config dbt (JSON: `'{"app": "DBT", "schema": "L2_<AREA>", "entita": "<NOME>"}'`) dichiarato **obbligatorio** in [[guida-sviluppo]] (checklist pre-rilascio) per identificare, lato monitoring Snowflake, quale modello ha eseguito una query.

## Copertura reale nel codice (verificato 2026-07-14 contro `raw/dwh-code/models/L2/`)

- **Assente del tutto** in ANAGR_CONTROPARTE, ANTIFRODE, ASSICURAZIONI, GESTIONE_CREDITI, ONBOARDING, PRODOTTO, PRODOTTO_M, SWORD (circa metà del progetto, inclusa l'area più documentata — [[l2-anagr-controparte]]).
- **Presente ma con `schema` errato**: tutti i 6 modelli di [[l2-carte]] dichiarano `schema: "L2_PRODOTTO"` invece di `L2_CARTE`; i 2 modelli di [[l2-provvigioni-rappel]] dichiarano `schema: "L2_MAIN"` (né `L2_PROVVIGIONI_RAPPEL` né un'area xlsx nota) **e sono commentati con `#`** (quindi disattivi).
- **Presente e coerente**: [[l2-rischi-adempimenti]] e [[l2-saldi]] (schema = nome cartella, corretto).
- Un caso di `entita` non allineata al nome modello: `indice_rischio_m.yml` ha `entita: "INDICE_RISCHIO"` (manca `_M`).

## Due tassonomie di naming non riconciliate

Lo `schema` atteso nel `query_tag` (nome esteso, es. `L2_ANAGR_CONTROPARTE`) non coincide con le sigle a 3+3 lettere usate nella xlsx "Nomenclatura SubjectArea Tabell" (es. `L2_ANA_CNT`). Vedi [[naming-convention-agos-x]].

Dettaglio completo delle occorrenze in [[inconsistenze]].

## Collegamenti

- [[storicizzazione-l2-s1-s4]]
- [[guida-sviluppo]]
- [[naming-convention-agos-x]]
- [[inconsistenze]]
