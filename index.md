---
title: Index
type: index
tags: [meta]
updated: 2026-07-13
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
Proposte di modifica al codice `raw/dwh-code/`. **Aggiornamento 2026-07-13**: dopo un re-sync di `raw/dwh-code/`, quasi tutte le voci sotto risultano ormai applicate a monte in `dwh-x-dbt` (confermato per confronto diretto col codice re-sincronizzato) — segnate `[APPLICATO]`. Eccezioni segnalate esplicitamente.
- `develop/tests/generic/unique_key.sql` — rename di `unique_key_table` (uniqueness-only, per source OCS) `[APPLICATO]`
- `develop/tests/generic/primary_key.sql` — rename di `primary_key_table` (uniqueness + nullability, per source non-OCS con chiave reale) `[APPLICATO]`
- `develop/tests/generic/try_cast.sql` — rename di `try_cast_table` (cast generico ricostruito dal `data_type` L1); `validation_config` con espressione custom rimosso, resta solo `skip_columns` (niente più override di espressione per colonna, solo skip/where_clause/accepted_values) `[APPLICATO]`
- `develop/tests/generic/try_cast_from_sql.sql` — rename di `try_cast_table_noocs` (legge l'espressione reale da `raw_code` del modello L1, per colonne con trasformazioni non banali) `[APPLICATO]`
- `develop/tests/adb_arc_try_cast.sql` — esempio di test singular scritto a mano (non generico), copre TUTTE le colonne di `adb_arc` hardcoded 1:1 sul modello L1, in aggiunta (doppia rete) a `try_cast_from_sql` che già le copre dinamicamente. `[APPLICATO ma con BUG]`: nel re-sync il file è arrivato come `raw/dwh-code/tests/.adb_arc_try_cast.sql` (nome col punto iniziale, file nascosto) — dbt scarta i file nascosti in fase di discovery, quindi questo test oggi **non viene eseguito**, silenziosamente. Da correggere (rinominare senza punto) nel repo live.
- `develop/models/L0/OCS/AIN/*.yml` (14 file), `develop/models/L0/ADOBE/*.yml` (15 file) — call site aggiornati ai nomi test rinominati; `adb_arc_source.yml` usa `try_cast_from_sql` (legge l'espressione reale dal SQL L1) invece del `try_cast` generico `[APPLICATO]`
- `develop/macros/generate_models/generate_source.sql` — generatore yml L0 aggiornato: emette `unique_key`/`primary_key` in base a `sorgente` invece di sempre `primary_key_table`, emette `try_cast` (nome rinominato) `[APPLICATO]`
- `develop/macros/generate_models/generate_model.sql` — generatore SQL modelli L1: per colonne varchar su sorgenti OCS, valore vuoto dopo `RTRIM` sostituito con uno spazio singolo `' '` invece di `NULL` (`IFF(RTRIM(col)='',' ',RTRIM(col))` al posto di `NULLIF(RTRIM(col),'')`) `[APPLICATO]`
- `develop/generate_models.ps1` — rimosso il check morto su `'---'` negli Step 2 (`generate_yaml`) e Step 4 (`generate_snapshots`). `[NON APPLICATO]`: il re-sync mostra ancora il check morto in entrambi gli step (righe ~268 e ~418 di `raw/dwh-code/generate_models.ps1`) — non bloccante (il flush avviene comunque tramite il trigger `- name:`), ma la correzione proposta non è stata portata a monte.
- `develop/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql` — bug fix: `PROGRESSIVO_CONTROPARTE` risultava sempre `NULL` (mancava un `COALESCE(..., 0)` attorno al `MAX(H.OLD_PROGRESSIVO) OVER (...)` prima di sommare `ROW_NUMBER()`, perso nella riscrittura incrementale rispetto a `.old`) `[APPLICATO]`
- `develop/macros/materialization/drop_snapshots_on_full_refresh.sql` — droppa gli snapshot selezionati nell'invocazione corrente quando `flags.FULL_REFRESH` è vero, agganciato come `on-run-start` di progetto (non come pre-hook sullo snapshot: la materialization snapshot risolve esistenza/colonne del target prima di eseguire i pre-hook, quindi un drop lì disallinea lo stato interno e produce errori tipo "tried to drop relation ... but its type is null" / "snapshot target is missing configured columns" — riscontrati entrambi durante l'iterazione su questo macro). Perde comunque tutta la storia SCD2 accumulata (non ricostruibile dalla sola sorgente corrente) `[APPLICATO]`
- `develop/dbt_project.yml` — aggiunto `on-run-start: "{{ drop_snapshots_on_full_refresh() }}"` a livello di progetto `[APPLICATO]`

**Novità non derivanti da `develop/`**: il re-sync ha portato anche modelli L1 nuovi non ancora documentati in wiki — `raw/dwh-code/models/L1/CRIF/crifra_np041rt.sql` e `crifrc_np042rt.sql` (fonte CRIF, mai vista prima in nessuna pagina). Da ingerire quando l'utente lo richiede.

## Note

Codice reale disponibile come copia semplice in `raw/dwh-code/` (aggiornata manualmente dall'utente da `dwh-x-dbt` via `sync-from-dwh-x-dbt.ps1`, mirrorata anche su `https://github.com/gortali123/my_dwh-x-dbt`). Prima verifica incrociata doc/codice effettuata il 2026-07-07, vedi [[incoerenze-codice-vs-documentazione]] — copertura parziale (campione di macro/modelli), non un'esplorazione esaustiva.
