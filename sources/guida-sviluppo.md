---
title: Guida Sviluppo AGOS-X DWH (source, interno)
type: source
tags: [internal, dev-guide, layer/L0, layer/L1, layer/L2, layer/L3]
updated: 2026-07-08
---

Documento operativo **interno** (non condiviso col cliente), v2.0. Per esplicito principio del progetto ([[naming-conventions]] a parte, vedi CLAUDE.md): non dovrebbe ripetere ciò che è nei documenti di framework, ma aggiungere dettagli pratici per gli sviluppatori (setup, comandi, checklist, macro).

Fonte: `raw/guida_sviluppo.docx`.

## Takeaway principali

- **Setup ambiente**: VSCode + Git, clone da `https://gitlabx.agositafinco.it/dwh/dwh-x-dbt.git`, dbt Cloud CLI (`dbt.exe` nella root repo + config `dbt_cloud.yml`), variabili in `.env` (mai committato) caricate con `load_env.ps1`.
- **Git workflow**: branch personali/di gruppo staccati da `dev` (`feature/<utente>` o `feature/<ticket>`), merge via Merge Request GitLab verso `dev`, **nessuna review obbligatoria** attualmente, obbligo di `dbt.exe compile` pre-merge.
- **Libreria Glue** (`dwh-x-glue-library`): pacchettizzata come wheel, versionata in `setup.py`, pipeline la pubblica su S3 (`library_dwhx/<branch>/`) tramite job OpenShift `dwh-x-glue-library-run`.
- **CFG.json**: mappatura parametrica per sorgente (dettaglio implementativo di `TECH.CFG_L0_SORGENTE`, non descritto a questo livello di dettaglio nel doc ufficiale L0-L1): blocchi `defaults`/`eccezioni` (merge per-archivio), parametri di file check (estensione, dimensione, encoding, separatore, regex naming/civetta/schema con gruppi nominati `archivio`/`ts`/`tipo`/`id`/`unit`).
- **Prerequisiti Snowflake pre-lancio job**: caricamento/merge di CFG.json in `TECH.CFG_L0_SORGENTE`, gestione perimetro archivi in `TECH.CFG_L0_L1_PROCESS_MONITORING` (flag `FL_PERIMETRO`), grant `GLUE_ROLE` sulle stored procedure.
- **Lancio job Glue**: via AWS Console (profilo `GlueDeveloperAccess`), parametri `--sorgente`/`--civetta`/`--retry` (mutuamente esclusivi civetta/retry, come da doc ufficiale).
- **Generazione modelli L1**: script `generate_models.ps1` (wrapper attorno alle macro `generate_source/yaml/model/snapshots` descritte nel doc ufficiale), con opzioni `--models`, `--modulo`, `--sorgente`, `--only`, `--force`.
- **Gestione job dbt Cloud**: flusso `generate_jobs.ps1` → `jobs.yml` → sync con `dbt-jobs-as-code sync` → export con `fetch_dbt_jobs.py` / `fetch_dbt_dependencies.py`. Questo flusso dbt Cloud non è menzionato nei documenti ufficiali, che descrivono l'orchestrazione come compito di **Control-M** — vedi nota di inconsistenza in [[incoerenze-doc-framework-vs-guida-sviluppo]].
- **L2 — riepilogo storicizzazioni** (S1-S4): tabella pratica con strategia/unique_key/campi tecnici, dettaglio SQL a blocchi per ciascun tipo, regola ordine colonne (storicizzazione subito dopo PK, `LASTMODIFIEDDATA` sempre in coda).
- **L2 — S1, variante main senza PK propria (aggiunta 2026-07-08)**: nuova sottosezione subito dopo "S1 — SCD2", che documenta il pattern reale usato in `variazioni_anagrafiche.sql` per gestire una tabella main L1 la cui unica chiave certa è `ROWID` (nessuna PK funzionale univoca). Introduce il campo tecnico `PROGRESSIVO_PK` (disambiguazione a parità di chiave+timestamp modifica), estende `unique_key`/PK del modello, passa `order_extra='PROGRESSIVO_PK'` a `is_incremental_S1()`, e propaga `TS_FINE_VALIDITA` con una window function su tutti i record con lo stesso `TS_INIZIO_VALIDITA`. Esplicitamente esclude `PROGRESSIVO_CONTROPARTE`, che resta specifico della sola entità `VARIAZIONI_ANAGRAFICHE`. Colma esattamente il gap segnalato in [[incoerenze-codice-vs-documentazione]] (punto 7).
- **L2 — checklist pre-rilascio**: tipi dato per prefisso, tracciato/ordine colonne, cluster/join SCD2, query_tag, niente `SELECT *`, no duplicazione config già in `dbt_project.yml`, `dbt.exe compile` obbligatorio.
- **L3**: storicizzazioni S2/S3/S4 "analoghe a L2", più **S5** ("SCD2 mensile", non menzionato nel doc ufficiale L2/L3): macro dedicata che storicizza a granularità mensile confrontando hash del payload, con rami full-refresh e incrementale (merge). Sezione documentata in grande dettaglio con esempio numerico completo.
- Diversi punti della sezione L3 sono esplicitamente aperti/incerti nel testo stesso ("S1 non previsto?", "Oppure invece di dt_osservazione la colonna rilevante...", "Se ci sono funzioni più complesse nel passaggio della chiave da L1 a L2 staging?").

## Pagine correlate

- [[layer-l0]], [[layer-l1]], [[layer-l2]], [[layer-l3]]
- [[storicizzazione-l1-cluster]], [[storicizzazione-l2-s1-s4]], [[storicizzazione-l3-s5]]
- [[cfg-l0-sorgente]], [[cfg-process-monitoring]]
- [[naming-conventions]]
- [[incoerenze-doc-framework-vs-guida-sviluppo]]

## Staleness

Documento v2.0, verificato solo testualmente in questa sessione (non incrociato col codice in `my_dwh-x-dbt`, non ancora esplorato). Contiene più punti irrisolti espliciti nella sezione L3 (S5), e una descrizione operativa dbt Cloud che non trova corrispondenza nei documenti di framework letti finora.
