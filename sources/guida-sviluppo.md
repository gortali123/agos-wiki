---
title: Guida Sviluppo
type: source
tags: [layer/L0, layer/L1, layer/L2, layer/L3, source/docx, operativo]
updated: 2026-07-20
---

Sintesi di `raw/guida_sviluppo.docx` ("AGOS-X DWH — Guida Sviluppo v2.0", documento operativo interno). È la guida pratica/quotidiana per sviluppare sul progetto `dwh-x-dbt`, complementare (più tecnica e concreta) ai due documenti di analisi [[caricamento-layer-l0-l1]] e [[caricamento-layer-l2]].

## Setup e Git

- Repo GitLab: `https://gitlabx.agositafinco.it/dwh/dwh-x-dbt.git`. Vedi [[repo-dwh-x-dbt]].
- dbt Cloud CLI, file `.env` locale (mai pushato) con `DBT_API_KEY`, `DBT_BASE_URL`, `DBT_ACCOUNT_ID`, `DBT_PROJECT_ID`, `DBT_ENVIRONMENT_ID`.
- Branching: branch personale/di gruppo staccato da `dev` (es. `feature/ANA_CNT`), merge request verso `dev` senza review obbligatoria attualmente. **Obbligatorio** `./dbt.exe compile` senza errori prima di ogni merge (un errore di sintassi blocca i run su `dev` per tutti).

## Layer L0 — libreria Glue e configurazione sorgenti

- Codice Glue pacchettizzato come libreria Python (wheel) in repo separata `dwh-x-glue-library`; build con `python setup.py bdist_wheel`, versione in `setup.py`.
- **CFG.json**: mappatura parametrica per sorgente (`defaults` + `eccezioni` opzionale per archivio), case-sensitive. Parametri documentati: Estensione, Dimensione, FileFormat, Stage, Encoding, Separatore, HeaderIndex, Bucket, Modulo, LoadProcedure, FileCheck, HeaderCheck, InfoInCivetta, PercorsoCivetta, DateFormatCivetta, DateFormatFile, RegexNamingLoad, RegexNamingDeleted, RegexCivetta, RegexSchema. Meccanismo eccezioni = merge (solo i parametri specificati sovrascrivono i defaults).
- Prima di ogni run/retry: caricare CFG.json in `TECH.CFG_L0_SORGENTE` (via COPY INTO da S3 o insert diretto), verificare/aggiornare `TECH.CFG_L0_L1_PROCESS_MONITORING` (campi `DT_ULTIMO_RUN_L0`, `CD_STATUS_L0`, `FL_PERIMETRO` S/N per includere/escludere un archivio), grant su `PROC_LOADING_L0` e `PROC_LOG_L0` a `ROLE GLUE_ROLE`.
- Lancio job Glue: parametri `--sorgente`, `--civetta` (mutuamente esclusivo con `--retry`).
- Monitoring: `LOGS.ET_L0_LOAD_LOGGING` (un record riepilogativo per archivio per job), `TECH.CFG_L1_SCHEMA` per verifica schemi caricati.

## Layer L1 — generazione modelli e job

- `generate_models.ps1` genera source yml (L0), yml/sql modelli L1, snapshot yml (solo cluster C), leggendo da `TECH.CFG_L1_SCHEMA` e `TECH.CFG_L1_CLUSTER_STO`. Non sovrascrive file esistenti senza `--force`.
- Flusso job dbt Cloud: sviluppo modelli → `generate_jobs.ps1` (genera `jobs.yml`) → `dbt-jobs-as-code sync` (allinea dbt Cloud, senza cambiare `job_id` sugli update) → `fetch_dbt_jobs.py` / `fetch_dbt_dependencies.py` per esportare job ID e dipendenze in CSV.
- **NB esplicito nel documento**: per eseguire modelli L1 serve `dbt build --select +modello` (non il solo `dbt run`), altrimenti snapshot e test sulle source non vengono eseguiti.

## Layer L2 — checklist implementativa

Questa sezione è la più operativa/prescrittiva e integra (con più dettaglio SQL) quanto descritto in [[caricamento-layer-l2]]:

- **S1 (SCD2)**: `unique_key: [PK_funzionale, TS_INIZIO_VALIDITA]`. Struttura SQL a 3 CTE fisse: base (deriva TS_INIZIO/FINE_VALIDITA, ereditati da sorgente se cluster C, calcolati con macro altrimenti) → dedup (hash colonne via `hash_cols([...])`, esclude LASTMODIFIEDDATA e le date di validità, usa `is_incremental_S1('PK')`) → select finale (ricalcola `TS_FINE_VALIDITA` con `ts_fine_validita(...)`, LEFT JOIN ai lookup).
- **Variante S1 senza PK propria** (main L1 con solo ROWID come chiave tecnica, es. quando ci sono duplicati non discriminabili da chiave+timestamp): si introduce `PR_PK` = `ROW_NUMBER() OVER (PARTITION BY <chiave>, <data/ora modifica> ORDER BY <ROWID>)`, esteso a `unique_key`/`primary_key`; `is_incremental_S1(..., order_extra='PR_PK')`; chiusura finestra con `MAX(...) OVER (PARTITION BY PK, TS_INIZIO_VALIDITA)` per evitare che record duplicati dello stesso istante si chiudano a vicenda. `PROGRESSIVO_CONTROPARTE` (usato solo in `VARIAZIONI_ANAGRAFICHE`) è un pattern separato, entità-specifico. **Nota (2026-07-20)**: la docx ora chiama esplicitamente questo campo `PR_PK` (in precedenza, fino al 2026-07-16, sia doc sia codice usavano `PROGRESSIVO_PK`); il codice in `raw/dwh-code/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql`/`.yml` è stato rinominato in coerenza — vedi [[progressivo-pk-e-progressivo-controparte]].
- **S2 (append giornaliero)**: `primary_key: [PK, TS_INSERIMENTO]`, blocco incrementale su `LASTMODIFIEDDATA > MAX(...)`.
- **S3 (append mensile)**: `primary_key: [PK, DT_OSSERVAZIONE]`, `pre_hook: delete_month()`, blocco incrementale su `DT_OSSERVAZIONE = get_dt_osservazione()`. Nessuna cancellazione fisica.
- **S4 (attualizzato)**: `insert_overwrite`, full overwrite ogni run.
- Conversioni dtype L1→L2: `custom_to_timestamp_ntz`, `custom_to_date`, `custom_to_time`, `custom_to_decimal(col, precision, decimal)` (OCS sempre `decimal=2`), `ole_to_timestamp`, `timestamp_to_ole`, `ole_to_date`, `date_to_ole`.
- Cancellazioni: filtro `FL_DELETED = 'N'` in lettura (nota: qui il documento usa `'N'` come valore da mantenere, implicitamente `Y` = cancellato — coerente con gli altri due documenti ma **da verificare contro la convenzione xlsx `S`/`N` per i flag**, vedi [[inconsistenze]]) + `pre_hook: delete_l2('ARCHIVIO', [PK_L2...], [PK_L1...])`.
- Query tag obbligatorio: `'{"app": "DBT", "schema": "L2_<AREA>", "entita": "<NOME>"}'`.
- Checklist pre-rilascio: tipi dato per prefisso (TS_/DT_/EU_), tracciato e ordine colonne allineati all'analisi tecnica, cluster/join SCD2 coerenti col `Catalogo Entità` della xlsx, mai `SELECT *`, non duplicare in yml quanto già in `dbt_project.yml`, `dbt.exe compile` pulito prima della MR.

## Layer L2 — gestione campi varchar vuoti OCS (nuova sezione 5.5, 2026-07-20)

Sezione nuova rispetto alla versione precedente della docx (non presente nell'ingest del 2026-07-14): le sorgenti OCS non prevedono NULL sui campi varchar, per cui un valore "bianco" arriva in L1 come stringa a singolo spazio (`' '`). Impatti prescritti per L2/L3:

1. Sostituire `campo IS NULL` con `{{ custom_is_null('campo') }}` (copre `IS NULL OR campo = ' '`), salvo casi con valorizzazione specifica nota (unico caso documentato: `BACCPTES`, dove `' '` = "Poste Italiane").
2. Nei `COALESCE` con primo input di sorgente OCS, aggiungere `NULLIF(campo, ' ')`.
3. JOIN/UNION: nessuna modifica richiesta in generale; unico punto critico segnalato è un campo OCS (`' '`) in join con un campo non-OCS (`NULL`) — da trattare caso per caso.

Analisi di dettaglio, inventario dei punti di codice da correggere e verifica puntuale contro `raw/dwh-code/`: vedi [[null-vs-placeholder-ocs]] (pagina dedicata, gestita separatamente).

## Layer L3 — storicizzazioni

- S2/S3/S4 analoghe a L2. **S1 non previsto in L3** (segnalato con "?" nel documento, quindi da confermare).
- **S5** (nuovo, ibrido S1/S3): SCD2 a granularità mensile via macro `scd2_foto_mensile` (nome non esplicitato nel testo ma dedotto dal contesto — verificare nome esatto nel codice). Full-refresh ricostruisce tutta la storia collassando i mesi con payload invariato (CTE `ver_dedup`→`win_starts`→`emitted`); incrementale confronta la foto del mese di riferimento (`snap`) con le finestre aperte (`open_win`) e fa merge (`new_rows` + `close_rows`). Parametri: `src_sql`, `key_cols`, `ts_col`, `pre_ctes`, `biz_cols`, `payload_cols`, `ref_month_end`, `dt_inizio`/`dt_fine`, `fine_validita_max`. Helper: `_scd2_cols`, `_scd2_cols_as`, `_scd2_join`, `_scd2_hash`.

## Note di staleness

- La sezione S1 variante ROWID e la sezione S5 sono le più recenti/dettagliate del documento e non hanno ancora un doppione nei due file di analisi tecnica — probabile che siano state aggiunte dopo.
- Diversi punti aperti segnalati esplicitamente nel testo: "Se ci sono funzioni più complesse nel passaggio della chiave da L1 a L2 staging?" (5.3 Cancellazioni), "S1 non previsto?" (L3).
- Letto e verificato contro `raw/dwh-code/` in data 2026-07-14, e ri-verificato il 2026-07-20 dopo un secondo resync di `raw/dwh-code/` e un aggiornamento della docx (nuova sezione 5.5 "Gestione campi varchar vuoti OCS"; rinomina `PROGRESSIVO_PK`→`PR_PK` nella sezione 5.1) — vedi [[inconsistenze]].

## Collegamenti

- [[repo-dwh-x-dbt]]
- [[storicizzazione-l2-s1-s4]]
- [[storicizzazione-l3]]
- [[progressivo-pk-e-progressivo-controparte]]
- [[cancellazioni-fl-deleted]]
- [[caricamento-layer-l0-l1]], [[caricamento-layer-l2]]
- [[null-vs-placeholder-ocs]]
- [[inconsistenze]]
