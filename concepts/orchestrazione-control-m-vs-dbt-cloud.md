---
title: Orchestrazione — Control-M vs dbt Cloud
type: concept
tags: [orchestrazione]
updated: 2026-07-07
---

Entrambi i documenti di framework ([[agosx-caricamento-l0-l1]] e [[agosx-caricamento-l2]]) sono chiari e concordi: **Control-M** è l'orchestratore di tutta la pipeline, da L0 a L3 — riceve le notifiche SNS, lancia i job Glue, esegue i comandi `dbt build` per ciascun modello, gestisce i vincoli anti-doppia-esecuzione.

La [[guida-sviluppo]] descrive però, in parallelo, un flusso di **gestione job via dbt Cloud** (§4.2): sviluppo modelli → `generate_jobs.ps1` → `jobs.yml` → sincronizzazione con `dbt-jobs-as-code sync` verso dbt Cloud → estrazione job ID (`fetch_dbt_jobs.py`) e dipendenze (`fetch_dbt_dependencies.py`). Il setup ambiente (§1.3) prevede anche l'installazione della dbt Cloud CLI con relative credenziali (`DBT_API_KEY`, `DBT_ACCOUNT_ID`, ecc.).

**Chiarito dall'utente (2026-07-07)**: non è un'incoerenza, sono due responsabilità distinte e complementari. Control-M orchestra l'**esecuzione** della pipeline. Il flusso jobs-as-code/dbt Cloud (`generate_jobs.ps1` → `jobs.yml` → `dbt-jobs-as-code sync`) serve alla **creazione/gestione dei job dbt stessi**, compito a carico del team di sviluppo. Il documento di framework va aggiornato per includere questa seconda parte, oggi assente — vedi [[todo-allineamento-documentazione]].

## Collegato da
[[layer-l1]], [[layer-l2]], [[guida-sviluppo]], [[incoerenze-doc-framework-vs-guida-sviluppo]]
