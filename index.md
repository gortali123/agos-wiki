---
title: Index
type: index
tags: [meta]
updated: 2026-07-07
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
- [[bozza-doc-s1-main-senza-pk]] — blocco doc S1 con main L1 priva di PK — applicato in guida sviluppo il 2026-07-08

## Note

Codice reale disponibile come copia semplice in `raw/dwh-code/` (aggiornata manualmente dall'utente da `dwh-x-dbt` via `sync-from-dwh-x-dbt.ps1`, mirrorata anche su `https://github.com/gortali123/my_dwh-x-dbt`). Prima verifica incrociata doc/codice effettuata il 2026-07-07, vedi [[incoerenze-codice-vs-documentazione]] — copertura parziale (campione di macro/modelli), non un'esplorazione esaustiva.
