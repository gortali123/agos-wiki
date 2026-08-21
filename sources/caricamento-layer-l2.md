---
title: Caricamento layer L2
type: source
tags: [layer/L2, layer/L3, source/docx]
updated: 2026-08-19
---

Sintesi di `raw/Agos X - Caricamento layer L2.docx` ("Agos X – Processo di Loading", parte 2). Descrive l'integrazione Snowflake L1→L2/L3 dove avviene la modellazione delle entità di business.

## Architettura

- Orchestrazione dei modelli L2/L3 in carico a Control-M, sulla base delle dipendenze estratte da `manifest.json` (colonna `DEPENDS_ON_NODE` in `DBT_ARTIFACTS.MODELS`/`DBT_ARTIFACTS.SNAPSHOTS`).
- Comando tipico: `dbt build -s <nome_modello>` (esegue modello + test data quality).
- Un modello DBT per entità L2/L3 (con eventuali modelli intermedi per performance/gestione).

## Naming convention

- Schema: `L2_<area_funzionale>` / `L3_<processo>`.
- Aree funzionali L2 documentate: ANAGR_CONTROPARTE, ANAGR_COMMERCIALE, ANTIFRODE, ANTIRICICLAGGIO, ASSICURAZIONI, BUDGET, CONTATTI, DIGITAL, GESTIONE_CREDITI, HR, ONBOARDING, PRODOTTO, PRODOTTO_M, PAGAMENTI_CONTABILITA, PROVVIGIONI_RAPPEL, RISCHI_ADEMPIMENTI, SCORE_BANCHE_DATI.
- Tabelle: `L2: <nome>_<frequenza>`, `L3: <tipo_oggetto>_<nome_tabella>_<frequenza>`. Frequenze: `_W` sett., `_M` mensile, `_T` trim., `_Q` quadrim., `_S` semestrale, `_Y` annuale, `_O` on demand, nessun suffisso = giornaliera.
- Tipo oggetto (prefisso): Vista `V_`, Vista materializzata `VM_`, Datamart `DM_`, Flusso di output `FL_OUT_`, Tabella di processo `PRC_`. Function `FN_`, Stored procedure `PR_`.
- Prefissi campo documentati qui: `CD_` Codice, `ID_` Identificativo, `DS_` Descrizione, `NM_` Misure/KPI, `DT_` Data, `TS_` Timestamp, `FL_` Flag, `TP_` Tipo, `EU_` Importo euro, `PC_` Percentuale, `SK_` Smart key, `GN_` generico. **Nota**: la lista campi nella xlsx `Nomenclatura Campi` non ha `ID_` né `SK_`, ma ha `PR_` (Progressivo) assente da questa lista — vedi [[naming-convention-agos-x]] e [[inconsistenze]].

## Storicizzazione L2 (S1-S4)

Vedi pagina dedicata [[storicizzazione-l2-s1-s4]] per il dettaglio implementativo (letto anche da `guida_sviluppo.docx`, più tecnico). In sintesi:

| Tipo | Materializzazione | Campi tecnici |
|---|---|---|
| S1 (SCD2) | incremental, merge | TS_INIZIO_VALIDITA, TS_FINE_VALIDITA, LASTMODIFIEDDATA |
| S2 (append giornaliero) | incremental, append | TS_INSERIMENTO, LASTMODIFIEDDATA |
| S3 (append mensile) | incremental, append | DT_OSSERVAZIONE, LASTMODIFIEDDATA |
| S4 (attualizzato) | incremental, insert_overwrite | — |

Regola d'ordine colonne: campi di storicizzazione subito dopo la PK funzionale, `LASTMODIFIEDDATA` sempre in coda (vedi [[lastmodifieddata]]).

## Gestione duplicazioni di chiave (PROGRESSIVO_PK)

Quando un archivio L1 ha PK non univoca (es. `CCANALOG`), si distingue tra:
- record duplicati con stesso contenuto → solo uno viene portato in L2. **Aggiornamento 2026-08-03**: la doc ora precisa che l'hash considera **tutti** i campi portati da L1 a L2 (non solo "i restanti"), su righe consecutive della stessa controparte;
- record duplicati con contenuto diverso → si aggiunge `PROGRESSIVO_PK` (rinominato `PR_PK` nel codice, vedi [[progressivo-pk-e-progressivo-controparte]]), calcolato partizionando per chiave e ordinando su `ROWID`.
- **Rimosso 2026-08-03**: il paragrafo dedicato a `PROGRESSIVO_CONTROPARTE` (caso speciale `VARIAZIONI_ANAGRAFICHE`) non è più presente in questa versione della docx — il campo esiste tuttora nel codice come `PR_CONTROPARTE` (vedi [[l2-anagr-controparte]], [[progressivo-pk-e-progressivo-controparte]]), quindi si tratta di una semplificazione del testo, non di una rimozione funzionale.

Vedi [[progressivo-pk-e-progressivo-controparte]].

## Cancellazioni

Due step: filtro in lettura (`FL_DELETED = Y` escluso) + cancellazione fisica post-esecuzione via macro nel post-hook DBT, che recupera le chiavi cancellate logicamente in L1 non ancora propagate e fa la DELETE fisica in L2 (o su tutta la storia per tabelle S1).

## Data classification / masking

- Tabella di catalogo `TECH.CFG_L1_DATAMASK` censisce le colonne soggette a masking per archivio.
- Masking applicato a partire da L1 (L0 non è accessibile agli utenti finali) e propagato automaticamente a L2/L3 tramite **tag propagation nativa di Snowflake**.
- Macro `add_datamask()`: post-hook alla prima esecuzione del modello, ALTER TABLE per assegnare il Tag Snowflake associato a una masking policy. Rieseguibile estemporaneamente per allineamenti.
- Macro `remove_datamask()`: rimuove un tag da una colonna specifica in qualsiasi layer (rimozione del metadato yml è manuale).

## Data quality e log

- Test DBT nativi (`not_null`, `unique`, `accepted_values`, `relationships`), test generici custom in `tests/generic/`, eventuali pacchetti esterni (`dbt-utils`).
- **Log — sezione non aggiornata (gap confermato 2026-08-19)**: il documento descrive ancora il pacchetto `dbt_artifacts` (`dbt_artifacts.upload_results(results)` come hook `on-run-end`, tabelle `DBT_ARTIFACTS.MODELS/TESTS/SNAPSHOTS/*_EXECUTIONS`) e tre viste `LOGS.V_L2_DBT_RUN_MODELS`/`V_L2_TEST`/`V_L2_TEST_RESULTS`. Il codice reale (`raw/dwh-code/macros/log/log_run_results.sql`, unico hook `on-run-end` per l'intero progetto, non solo L2) scrive invece in `LOGS.EVENT_LOG` tramite la stored procedure `LOG_DBT` — stesso meccanismo già documentato correttamente in [[caricamento-layer-l0-l1]] (viste `V_EVENT_LOG`/`DT_EVENT_LOG`/`V_LAST_RUN_STATUS`). Nessuna occorrenza di `dbt_artifacts` in `raw/dwh-code/`. Vedi [[inconsistenze]] (voce 8).

## Note di staleness

- Rimanda a un documento esterno non vendorizzato: `Agos X - Linee_Guida_Layer_L2_Storicizzazione_20260304.pptx`.
- Sezione data quality segnalata come non definitiva ("Ulteriori dettagli saranno integrati durante la fase progettuale dedicata alla data quality").
- Sezione "Raccolta dei log" (fine documento) obsoleta rispetto al codice — vedi sopra.
- Letto e riverificato per intero contro `raw/dwh-code/` il 2026-08-19 — vedi [[inconsistenze]].

## Collegamenti

- [[layer-l2]], [[layer-l3]]
- [[storicizzazione-l2-s1-s4]]
- [[progressivo-pk-e-progressivo-controparte]]
- [[cancellazioni-fl-deleted]]
- [[naming-convention-agos-x]]
- [[data-masking-agos-x]]
- [[inconsistenze]]
