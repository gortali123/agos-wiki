---
title: Agos X - Caricamento layer L2 (source)
type: source
tags: [layer/L2, layer/L3, source/framework]
updated: 2026-07-07
---

Documento ufficiale di analisi tecnica (condiviso col cliente) sul processo di modellazione/integrazione tra L1 e i layer L2/L3 su Snowflake, gestito da DBT e orchestrato da Control-M.

Fonte: `raw/Agos X - Caricamento layer L2.docx`.

## Takeaway principali

- Un modello DBT per entità L2/L3 (più eventuali modelli intermedi), eseguito con `dbt build -s <nome_modello>` (**senza** `+`, a differenza del comando L1).
- Naming convention completa: schemi `L2_<area_funzionale>` / `L3_<processo>`; elenco delle 16 aree funzionali L2 (ANAGR_CONTROPARTE, ANAGR_COMMERCIALE, ANTIFRODE, ANTIRICICLAGGIO, ASSICURAZIONI, BUDGET, CONTATTI, DIGITAL, GESTIONE_CREDITI, HR, ONBOARDING, PRODOTTO, PRODOTTO_M, PAGAMENTI_CONTABILITA, PROVVIGIONI_RAPPEL, RISCHI_ADEMPIMENTI, SCORE_BANCHE_DATI); prefissi tabella/oggetto (V_, VM_, DM_, FL_OUT_, PRC_, FN_, PR_) e prefissi campo (CD_, ID_, DS_, NM_, DT_, TS_, FL_, TP_, EU_, PC_, SK_, GN_).
- Storicizzazione L2: 4 tipi mappati su materializzazioni DBT — **S1** (SCD2, incremental/merge), **S2** (append giornaliero), **S3** (append mensile, cancella/ricarica mese corrente), **S4** (full overwrite, insert_overwrite). Regole dettagliate in `Agos X - Linee_Guida_Layer_L2_Storicizzazione_20260304.pptx` (non ancora presente in `raw/`).
- Lettura da L1: obbligo di escludere `FL_DELETED='Y'`; per SCD2 (Cluster C) filtro `TS_INIZIO_VALIDITA <= data < TS_FINE_VALIDITA`, **mai BETWEEN** (include entrambi gli estremi → duplicati).
- Gestione chiavi duplicate in L1 (es. CCANALOG): dedup via hash di riga, più campo tecnico `PROGRESSIVO_PK`; per l'entità VARIAZIONI_ANAGRAFICHE anche `PROGRESSIVO_CONTROPARTE` (partizionato su `AL_CODICE`).
- Cancellazioni L2 in due step: filtro in lettura (`FL_DELETE='Y'`, nota: qui il documento scrive `FL_DELETE`, altrove sempre `FL_DELETED`) + cancellazione fisica post-hook via macro dedicata.
- Data classification/masking: tagging colonne Snowflake a partire da L1 (L0 non è accessibile agli utenti finali), propagazione automatica a L2/L3 via tag propagation nativa Snowflake; catalogo in `TECH.CFG_L1_DATAMASK`; macro `add_datamask()` / `remove_datamask()`.
- Data quality L2/L3: stessi meccanismi nativi DBT (test standard, generici custom in `tests/generic/`, pacchetti esterni tipo dbt-utils); sezione esplicitamente indicata come da completare ("Ulteriori dettagli saranno integrati durante la fase progettuale dedicata alla data quality").
- Sezione "Git e versionamento": vuota, "specifiche in fase di definizione" — poi effettivamente dettagliata solo nella guida sviluppo interna.
- Raccolta log: stesso meccanismo DBT Artifacts di L1, viste dedicate `V_L2_DBT_RUN_MODELS`, `V_L2_TEST`, `V_L2_TEST_RESULTS` (quest'ultima "da integrare").

## Pagine correlate

- [[layer-l2]], [[layer-l3]]
- [[naming-conventions]]
- [[storicizzazione-l2-s1-s4]]
- [[gestione-cancellazioni]]
- [[data-masking]]
- [[data-quality-controlli]]
- [[cfg-l1-datamask]]

## Staleness

Il capitolo storicizzazione rimanda a un file pptx esterno mai ingerito nella wiki — il dettaglio delle regole S1-S4 nella wiki proviene solo da questo documento + dalla guida sviluppo, non dal pptx originale. Sezioni "Git e versionamento" e "Data quality" sono dichiarate incomplete dal documento stesso.
