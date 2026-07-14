---
title: "Repo dwh-x-dbt"
type: entity
tags: [repo, dbt]
updated: 2026-07-14
---

Progetto DBT unico per tutti i layer (L0-L3) del DWH Agos X.

- **Repo live (source of truth)**: GitLab `https://gitlabx.agositafinco.it/dwh/dwh-x-dbt.git` (da [[guida-sviluppo]]).
- **Snapshot vendorizzato in questo wiki**: `raw/dwh-code/` (plain files, sincronizzati manualmente dall'utente via `sync-dwh-code.ps1`), mirrorato anche su `https://github.com/gortali123/my_dwh-x-dbt` (solo backup/pubblicazione, non canonico).
- **Clone locale addizionale**: `C:\Users\g.ortali\work\my_dwh-x-dbt` (per grep/lettura diretta fuori dal vault).
- Branching: `dev` come branch di sviluppo comune, branch personale/gruppo staccato da `dev` (es. `feature/AGON1FP`), merge request senza review obbligatoria attualmente, ma `dbt.exe compile` pulito è obbligatorio prima del merge.

## Struttura reale verificata (2026-07-14, snapshot parziale)

- `models/L0/{ADOBE,CTC,OCS}` — solo file `*_source.yml`, nessun `.sql` (L0 è puro layer di dichiarazione source). Snapshot attuale (pre-resync) senza CRIF, pur essendo CRIF popolato in `models/L1/CRIF`.
- `models/L1/{ADOBE,CRIF,CTC,OCS}`.
- **`sync-dwh-code.ps1` aggiornato (2026-07-14)**: per `models/L0`, `models/L1` e `snapshots/L1` ora enumera dinamicamente tutte le sottocartelle sorgente presenti nella repo `dwh-x-dbt` e le mirrora **tutte tranne OCS**; di OCS continua a prendere solo il modulo `AIN` come campione. Prima solo ADOBE/CTC (L0) e ADOBE/CRIF/CTC (L1) erano hardcoded — quindi al prossimo sync questo snapshot coprirà automaticamente anche sorgenti L0/L1/snapshot non ancora viste qui, senza dover riaggiornare lo script.
- `models/L2/{ANAGR_CONTROPARTE,ANTIFRODE,ASSICURAZIONI,CARTE,GESTIONE_CREDITI,ONBOARDING,PRODOTTO,PRODOTTO_M,PROVVIGIONI_RAPPEL,RISCHI_ADEMPIMENTI,SALDI,SWORD}` — 13 aree, vedi pagine dedicate per area.
- `models/L3/{basilea_core,monitoraggio_produzione}`.
- `snapshots/L1/OCS/AIN` — solo questo modulo OCS vendorizzato finora (pre-resync); con lo script aggiornato copriranno anche le altre sorgenti snapshot non-OCS.
- `macros/{basilea,dtype_conversion,generate_models,log,logic_delete,materialization,xml_utility}` — vedi [[macro-catalogo-dbt]].
- `templates/models/{L0,L1/{A,B,C,D},L2/{S1,S2,S3,S4}}`, `templates/snapshots/L1` — pattern di riferimento per nuovi modelli.
- `tests/generic/` — 5 test custom: `primary_key.sql`, `primary_key_positional.sql`, `try_cast.sql`, `try_cast_from_sql.sql`, `try_cast_positional.sql`. **Nomi diversi da quelli citati nei docx** (`primary_key_table`, `try_cast_table`) — vedi [[inconsistenze-doc-vs-codice]]. **Nota di design confermata con l'utente (2026-07-14)**: il test `try_cast` valida il `TRY_CAST` sul valore **grezzo** di L0 (non applica `RTRIM`), mentre il modello L1 (macro `generate_model`, vedi [[macro-catalogo-dbt]]) applica `RTRIM` prima del cast per le colonne VARCHAR OCS. Questo è intenzionale: il test è il guardiano della regola "la stringa con gli spazi di padding non deve superare la lunghezza dichiarata" (va tenuto sul valore grezzo, non trimmato); il modello si occupa solo del caricamento del valore business (trimmato). **Semplificazione proposta** (2026-07-14, non ancora applicata upstream): `develop/tests/generic/try_cast.sql` rimuove due campi ridondanti dalla lista di colonne precomputata (`col_ref`, identico a `name`; `check_expr`, stringa precalcolata usata una sola volta) e scrive `try_cast(...)` inline nel loop di rendering — stessa logica, meno codice, più vicino allo stile diretto di `primary_key.sql` (che non ha bisogno di precomputazione perché non deve risolvere il `data_type` per colonna).

**Bug trovato e fix proposto in `try_cast_from_sql.sql`** (`develop/tests/generic/try_cast_from_sql.sql`): il file originale valorizza `l1_sql = l1_node.raw_code | upper` — cioè maiuscolizza **tutto** il codice SQL del modello L1, non solo per la ricerca posizionale di `SELECT`/`FROM`. Le espressioni colonna vengono poi estratte da questo testo già maiuscolizzato, quindi eventuali letterali stringa nelle espressioni del modello (es. `CASE WHEN x = 'abc' THEN ...`) finiscono nel test come `'ABC'` — un confronto diverso da quello reale eseguito dal modello. Il fix mantiene `l1_sql` nel case originale (come già fa correttamente `try_cast_positional.sql`) e usa una variabile separata `sql_upper` solo per localizzare `SELECT`/`FROM`/`WHERE`; unificati anche i due loop ridondanti (`expressions` + `cols_to_check`) in uno solo.

**Incoerenza di `accepted_values` allineata**: `try_cast.sql` e `try_cast_from_sql.sql` indicizzano `accepted_values` per **data type** della colonna; `try_cast_positional.sql` lo indicizzava invece per **nome colonna**, un comportamento diverso per lo stesso parametro. Su richiesta dell'utente, `develop/tests/generic/try_cast_positional.sql` è stato allineato a indicizzare per data type come gli altri due — **è un cambio di comportamento**: chi già passa `accepted_values` keyed by nome colonna a `try_cast_positional` dovrà aggiornare la chiamata quando/se questo fix viene portato upstream.
- `dbt_project.yml` — presente, confermato `+transient: false`, `+contract.enforced: true` globali; `on-run-end` reale: `log_run_results(results)` + `pop_test_log_records(results)` (**non** `dbt_artifacts.upload_results` come da docx); `on-run-start`: `drop_snapshots_on_full_refresh()`. Snapshot config centralizzata con `+strategy: timestamp` e mapping custom delle colonne SCD2.
- `packages.yml` **non presente** in questo snapshot — solo `package-lock.yml` (dbt_utils 1.3.3).
- Script di supporto in root: `generate_models.ps1`, `generate_jobs.ps1`, `fetch_dbt_jobs.py`, `fetch_dbt_dependencies.py`, `load-env.ps1`, `sync-from-dwh-x-dbt.ps1`.

## Collegamenti

- [[macro-catalogo-dbt]]
- [[layer-l0]], [[layer-l1]], [[layer-l2]], [[layer-l3]]
- [[inconsistenze-doc-vs-codice]]
