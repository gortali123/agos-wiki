---
title: Index
type: index
tags: [meta]
updated: 2026-07-10
---

# Index

Catalog of every page in the wiki. Updated on every ingest/query.

## raw/
- `Agos X - Caricamento layer L0-L1.docx` — doc ufficiale L0/L1 → [[agosx-caricamento-l0-l1]]
- `Agos X - Caricamento layer L2.docx` — doc ufficiale L2/L3 → [[agosx-caricamento-l2]]
- `Agos X - Layer L2.xlsx` — data model dettagliato L2/L3 (struttura ingerita, contenuto no) → [[agosx-layer-l2-datamodel]]
- `guida_sviluppo.docx` — guida operativa interna v2.0 → [[guida-sviluppo]]
- `llm-wiki-pattern.md` — idea/pattern alla base di questa wiki

## Sources
- [[agosx-caricamento-l0-l1]] — sintesi doc ufficiale L0/L1
- [[agosx-caricamento-l2]] — sintesi doc ufficiale L2/L3
- [[agosx-layer-l2-datamodel]] — struttura/significato/uso del data model xlsx L2/L3
- [[guida-sviluppo]] — sintesi guida operativa interna

## Entities
- [[layer-l0]] — Layer L0 (landing raw)
- [[layer-l1]] — Layer L1 (tipizzato/storicizzato, 1:1 con L0)
- [[layer-l2]] — Layer L2 (entità di business per area funzionale)
- [[layer-l3]] — Layer L3 (per processo)
- [[cfg-l0-sorgente]] — TECH.CFG_L0_SORGENTE / CFG.json
- [[cfg-process-monitoring]] — tabella semaforo (nome incerto, vedi incoerenze)
- [[cfg-l1-schema]] — TECH.CFG_L1_SCHEMA
- [[cfg-l1-cluster-sto]] — TECH.CFG_L1_CLUSTER_STO
- [[cfg-l1-datamask]] — TECH.CFG_L1_DATAMASK
- [[et-l0-load-logging]] — LOG.ET_L0_LOAD_LOGGING
- [[cobol-copybook-mapping]] — COBOL_COPYBOOK_MAPPING

## Concepts
- [[naming-conventions]] — naming Snowflake/DBT
- [[storicizzazione-l1-cluster]] — Cluster A/B/C (L1)
- [[storicizzazione-l2-s1-s4]] — S1-S4 (L2)
- [[storicizzazione-l3-s5]] — S5 SCD2 mensile (L3)
- [[gestione-cancellazioni]] — cancellazioni OCS e L2
- [[data-quality-controlli]] — test/controlli L0/L1/L2/L3
- [[data-masking]] — data classification/masking
- [[file-civetta-e-formati]] — file civetta, naming, formati sorgente
- [[gestione-errori-retry-l0]] — codici errore e retry L0
- [[parsing-cobol]] — parsing dinamico record COBOL
- [[orchestrazione-control-m-vs-dbt-cloud]] — nodo aperto su orchestrazione
- [[transcodifica-datatype-l0-l1]] — macro transcod_dtype, mappatura tipi sorgente→Snowflake

## Queries
- [[incoerenze-doc-framework-vs-guida-sviluppo]] — lint incrociato tra i 3 documenti ingeriti (risolto/commentato dall'utente)
- [[incoerenze-codice-vs-documentazione]] — lint doc vs codice reale in raw/dwh-code
- [[todo-allineamento-documentazione]] — TODO concrete per correggere i documenti di framework

## Develop
Proposte di modifica al codice `raw/dwh-code/`, non ancora applicate a monte in `dwh-x-dbt`.
- `develop/tests/generic/unique_key.sql` — rename di `unique_key_table` (uniqueness-only, per source OCS)
- `develop/tests/generic/primary_key.sql` — rename di `primary_key_table` (uniqueness + nullability, per source non-OCS con chiave reale)
- `develop/tests/generic/try_cast.sql` — rename di `try_cast_table` (cast generico ricostruito dal `data_type` L1); `validation_config` con espressione custom rimosso, resta solo `skip_columns` (niente più override di espressione per colonna, solo skip/where_clause/accepted_values)
- `develop/tests/generic/try_cast_from_sql.sql` — rename di `try_cast_table_noocs` (legge l'espressione reale da `raw_code` del modello L1, per colonne con trasformazioni non banali)
- `develop/tests/adb_arc_try_cast.sql` — esempio di test singular scritto a mano (non generico), copre TUTTE le colonne di `adb_arc` hardcoded 1:1 sul modello L1, in aggiunta (doppia rete) a `try_cast_from_sql` che già le copre dinamicamente
- `develop/models/L0/OCS/AIN/*.yml` (14 file), `develop/models/L0/ADOBE/*.yml` (15 file) — call site aggiornati ai nomi test rinominati; `adb_arc_source.yml` usa `try_cast_from_sql` (legge l'espressione reale dal SQL L1) invece del `try_cast` generico
- `develop/macros/generate_models/generate_source.sql` — generatore yml L0 aggiornato: emette `unique_key`/`primary_key` in base a `sorgente` invece di sempre `primary_key_table`, emette `try_cast` (nome rinominato)
- `develop/macros/generate_models/generate_model.sql` — generatore SQL modelli L1: per colonne varchar su sorgenti OCS, valore vuoto dopo `RTRIM` sostituito con uno spazio singolo `' '` invece di `NULL` (`IFF(RTRIM(col)='',' ',RTRIM(col))` al posto di `NULLIF(RTRIM(col),'')`)
- `develop/generate_models.ps1` — rimosso il check morto su `'---'` negli Step 2 (`generate_yaml`) e Step 4 (`generate_snapshots`): quelle due macro non hanno mai emesso quel separatore (solo `generate_model.sql`, Step 3, lo fa), il flush avveniva comunque tramite il trigger `- name:`. `generate_yaml.sql`, `generate_snapshots.sql`, `get_model_names.sql`, `cobol.sql` restano invariati in `raw/` — non avevano nulla da correggere
- `develop/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql` — bug fix: `PROGRESSIVO_CONTROPARTE` risultava sempre `NULL` (mancava un `COALESCE(..., 0)` attorno al `MAX(H.OLD_PROGRESSIVO) OVER (...)` prima di sommare `ROW_NUMBER()`, perso nella riscrittura incrementale rispetto a `.old`)
- `develop/macros/materialization/drop_on_full_refresh.sql` — nuovo pre-hook per snapshot: droppa la relazione se `flags.FULL_REFRESH`, per replicare il comportamento full-refresh delle tabelle normali (gli snapshot dbt lo ignorano nativamente). Perde tutta la storia SCD2 accumulata (non ricostruibile dalla sola sorgente corrente)
- `develop/dbt_project.yml` — aggiunto `+pre-hook: "{{ drop_on_full_refresh() }}"` a livello `snapshots: agosx:` (tutti gli snapshot del progetto, non solo OCS)

## Note

Codice reale disponibile come copia semplice in `raw/dwh-code/` (aggiornata manualmente dall'utente da `dwh-x-dbt` via `sync-from-dwh-x-dbt.ps1`, mirrorata anche su `https://github.com/gortali123/my_dwh-x-dbt`). Prima verifica incrociata doc/codice effettuata il 2026-07-07, vedi [[incoerenze-codice-vs-documentazione]] — copertura parziale (campione di macro/modelli), non un'esplorazione esaustiva.
