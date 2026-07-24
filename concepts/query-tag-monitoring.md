---
title: "query_tag per monitoring"
type: concept
tags: [monitoring, convention, layer/L2, layer/L3]
updated: 2026-07-24
---

Il `query_tag` è un campo di config dbt (JSON: `'{"app": "DBT", "schema": "L2_<AREA>", "entita": "<NOME>"}'`, o `L3_<AREA>` per i DataMart L3) dichiarato **obbligatorio** in [[guida-sviluppo]] (checklist pre-rilascio) per identificare, lato monitoring Snowflake, quale modello ha eseguito una query.

## Copertura reale nel codice (riverificato 2026-07-24 dopo il resync `raw/dwh-code/`, commit "new fetch")

Il resync ha portato a monte **73 degli 85 fix** proposti in `develop/` il 2026-07-22 (tutta l'area L2 tranne CARTE). Stato attuale:

- **Presente e corretto** (ora la stragrande maggioranza): tutti i modelli L2 di ANAGR_CONTROPARTE, ANTIFRODE, ASSICURAZIONI, GESTIONE_CREDITI, ONBOARDING, PRODOTTO, PRODOTTO_M, SWORD, SCORE_BANCHE_DATI (tutti e 19, schema ora sempre `L2_SCORE_BANCHE_DATI`), RISCHI_ADEMPIMENTI (tutti e 12, incluso `indice_rischio_m` ora con `entita: "INDICE_RISCHIO_M"` corretto), [[l2-saldi]] (L2+L3), [[l2-provvigioni-rappel]].
- **Ancora con `schema` errato** (6 file, non toccati dal resync): tutti i modelli di [[l2-carte]] dichiarano ancora `schema: "L2_PRODOTTO"` invece di `L2_CARTE`.
- **Ancora assente del tutto** (12 file, non toccati dal resync): L3 `basilea_core` (3 modelli) e `monitoraggio_produzione` (6 modelli), più la nuova area L3 **CAMPIONI** (3 modelli: `dm_campioni_base_lgd_t`, `dm_cliente_default_m`, `dm_pratiche_default_m` — subject area comparsa per la prima volta in questo resync, mai avuta query_tag).
- Nota storica: la voce precedente di questa pagina segnalava un possibile `l2-provvigioni-rappel` con schema/query_tag commentato — non confermato nei giri 2026-07-22/2026-07-24, i modelli risultano attivi e coerenti.

## Correzione proposta in `develop/` — stato dopo il resync (2026-07-24)

Del set di 85 file scritto in `develop/models/L2/` e `develop/models/L3/` il 2026-07-22, **73 sono ora superflui** (applicati upstream dal resync, possono essere rimossi da `develop/`/`index.md`). Restano da portare a monte:
- **CARTE** (6 file): fix `schema` già pronto in `develop/models/L2/CARTE/*.yml`.
- **L3 basilea_core + monitoraggio_produzione** (9 file): fix già pronto in `develop/models/L3/{basilea_core,monitoraggio_produzione}/*.yml`.
- **L3 CAMPIONI** (3 file, nuovi): **non coperti dal fix del 2026-07-22** (l'area non esisteva ancora) — serve un nuovo passaggio `develop` per aggiungere `query_tag` a `dm_campioni_base_lgd_t.yml`, `dm_cliente_default_m.yml`, `dm_pratiche_default_m.yml`.

`raw/dwh-code/` resta il riferimento read-only per questo wiki — l'utente deve portare i file residui a monte manualmente nella repo live `dwh-x-dbt`.

## Due tassonomie di naming non riconciliate

Lo `schema` atteso nel `query_tag` (nome esteso, es. `L2_ANAGR_CONTROPARTE`) non coincide con le sigle a 3+3 lettere usate nella xlsx "Nomenclatura SubjectArea Tabell" (es. `L2_ANA_CNT`). Vedi [[naming-convention-agos-x]].

Dettaglio completo delle occorrenze in [[inconsistenze]].

## Collegamenti

- [[storicizzazione-l2-s1-s4]]
- [[guida-sviluppo]]
- [[naming-convention-agos-x]]
- [[inconsistenze]]
