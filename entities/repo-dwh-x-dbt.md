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

- `models/L0/{ADOBE,CTC,OCS}` — solo file `*_source.yml`, nessun `.sql` (L0 è puro layer di dichiarazione source). **Manca `models/L0/CRIF`** nonostante CRIF sia popolato in `models/L1/CRIF` — lo snapshot vendorizzato non copre tutte le sorgenti (conferma la nota di staleness in CLAUDE.md: "non necessariamente tutti gli L1").
- `models/L1/{ADOBE,CRIF,CTC,OCS}`.
- `models/L2/{ANAGR_CONTROPARTE,ANTIFRODE,ASSICURAZIONI,CARTE,GESTIONE_CREDITI,ONBOARDING,PRODOTTO,PRODOTTO_M,PROVVIGIONI_RAPPEL,RISCHI_ADEMPIMENTI,SALDI,SWORD}` — 13 aree, vedi pagine dedicate per area.
- `models/L3/{basilea_core,monitoraggio_produzione}`.
- `snapshots/L1/OCS/AIN` — solo questo modulo OCS vendorizzato.
- `macros/{basilea,dtype_conversion,generate_models,log,logic_delete,materialization,xml_utility}` — vedi [[macro-catalogo-dbt]].
- `templates/models/{L0,L1/{A,B,C,D},L2/{S1,S2,S3,S4}}`, `templates/snapshots/L1` — pattern di riferimento per nuovi modelli.
- `tests/generic/` — 5 test custom: `primary_key.sql`, `primary_key_positional.sql`, `try_cast.sql`, `try_cast_from_sql.sql`, `try_cast_positional.sql`. **Nomi diversi da quelli citati nei docx** (`primary_key_table`, `try_cast_table`) — vedi [[inconsistenze-doc-vs-codice]].
- `dbt_project.yml` — presente, confermato `+transient: false`, `+contract.enforced: true` globali; `on-run-end` reale: `log_run_results(results)` + `pop_test_log_records(results)` (**non** `dbt_artifacts.upload_results` come da docx); `on-run-start`: `drop_snapshots_on_full_refresh()`. Snapshot config centralizzata con `+strategy: timestamp` e mapping custom delle colonne SCD2.
- `packages.yml` **non presente** in questo snapshot — solo `package-lock.yml` (dbt_utils 1.3.3).
- Script di supporto in root: `generate_models.ps1`, `generate_jobs.ps1`, `fetch_dbt_jobs.py`, `fetch_dbt_dependencies.py`, `load-env.ps1`, `sync-from-dwh-x-dbt.ps1`.

## Collegamenti

- [[macro-catalogo-dbt]]
- [[layer-l0]], [[layer-l1]], [[layer-l2]], [[layer-l3]]
- [[inconsistenze-doc-vs-codice]]
