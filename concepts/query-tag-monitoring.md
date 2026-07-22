---
title: "query_tag per monitoring"
type: concept
tags: [monitoring, convention, layer/L2, layer/L3]
updated: 2026-07-22
---

Il `query_tag` è un campo di config dbt (JSON: `'{"app": "DBT", "schema": "L2_<AREA>", "entita": "<NOME>"}'`, o `L3_<AREA>` per i DataMart L3) dichiarato **obbligatorio** in [[guida-sviluppo]] (checklist pre-rilascio) per identificare, lato monitoring Snowflake, quale modello ha eseguito una query.

## Copertura reale nel codice (riverificato 2026-07-22 contro `raw/dwh-code/models/L2/` e `models/L3/`, 107 file yml scansionati)

- **Assente del tutto** (63 file) in ANAGR_CONTROPARTE, ANTIFRODE, ASSICURAZIONI, GESTIONE_CREDITI, ONBOARDING, PRODOTTO, PRODOTTO_M, SWORD (L2) e in `basilea_core`/`monitoraggio_produzione` (L3) — inclusa l'area più documentata, [[l2-anagr-controparte]].
- **Presente ma con `schema` errato** (21 file): tutti i 6 modelli di [[l2-carte]] dichiarano `schema: "L2_PRODOTTO"` invece di `L2_CARTE`; 15 dei 19 modelli di SCORE_BANCHE_DATI dichiarano `schema: "L2_SCORING"` invece di `L2_SCORE_BANCHE_DATI` (i 4 corretti: `accettazione_input`, `prescreening_input`, `prescreening_output`, `prescreening_output_pr`).
- **Presente ma con `entita` errata** (1 file): `indice_rischio_m.yml` ha `entita: "INDICE_RISCHIO"` (manca `_M`).
- **Presente e coerente** (22 file): tutti i modelli di [[l2-rischi-adempimenti]] (tranne `indice_rischio_m`), [[l2-saldi]] (L2+L3), [[l2-provvigioni-rappel]] (schema `L2_PROVVIGIONI_RAPPEL`, attivo — nessun `#` di commento trovato in questo giro), e i 4 modelli SCORE_BANCHE_DATI citati sopra.
- Nota: la voce precedente di questa pagina segnalava `l2-provvigioni-rappel` con `schema: "L2_MAIN"` e query_tag commentato con `#` — non confermato nel giro 2026-07-22 (i 2 modelli in `raw/dwh-code/models/L2/PROVVIGIONI_RAPPEL/` risultano attivi e con schema corretto `L2_PROVVIGIONI_RAPPEL`); possibile fix intermedio già applicato upstream, oppure discrepanza da chiarire in un giro successivo.

## Correzione proposta in `develop/` (2026-07-22, non ancora applicata upstream)

Workflow `develop` eseguito su tutti gli 85 file non conformi: file corretti scritti sotto `develop/models/L2/<AREA>/` e `develop/models/L3/<area>/`, mirror esatto della struttura in `raw/dwh-code/models/`, con solo la chiave `query_tag` aggiunta o corretta in ciascun `config:` (nessun'altra riga toccata). Aree toccate: L2 ANAGR_CONTROPARTE, ANTIFRODE, ASSICURAZIONI, CARTE, GESTIONE_CREDITI, ONBOARDING, PRODOTTO, PRODOTTO_M, RISCHI_ADEMPIMENTI (solo `indice_rischio_m`), SCORE_BANCHE_DATI, SWORD; L3 `basilea_core`, `monitoraggio_produzione`. Vedi `index.md` sezione Develop per l'elenco dei file. `raw/dwh-code/` resta invariato (read-only) — l'utente deve portare questi file a monte manualmente nella repo live `dwh-x-dbt`.

## Due tassonomie di naming non riconciliate

Lo `schema` atteso nel `query_tag` (nome esteso, es. `L2_ANAGR_CONTROPARTE`) non coincide con le sigle a 3+3 lettere usate nella xlsx "Nomenclatura SubjectArea Tabell" (es. `L2_ANA_CNT`). Vedi [[naming-convention-agos-x]].

Dettaglio completo delle occorrenze in [[inconsistenze]].

## Collegamenti

- [[storicizzazione-l2-s1-s4]]
- [[guida-sviluppo]]
- [[naming-convention-agos-x]]
- [[inconsistenze]]
