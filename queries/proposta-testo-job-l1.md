---
title: "Proposta testo: L1 - nuovo capitolo breve sulla gestione dei job dbt Cloud"
type: query
tags: [layer/L1, source/docx, jobs]
updated: 2026-07-28
---

Proposta di un capitolo breve per `raw/Agos X - Caricamento layer L0-L1.docx`, che dia visibilità al fatto che i job dbt Cloud sono gestiti tramite un set di utility dedicate — senza duplicare il dettaglio operativo già in **4.2 Gestione Job dbt Cloud** di `raw/guida_sviluppo.docx`, che resta il riferimento e non viene toccata da questa proposta.

`raw/` è immutabile: questa pagina è la proposta da incollare a mano nel `.docx`, non un'edit del file stesso.

## Testo proposto — nuovo capitolo "L1: Gestione dei job dbt Cloud"

> Ogni modello L1 generato deve essere anche schedulato su dbt Cloud. La configurazione dei job non viene creata a mano da interfaccia, ma generata e mantenuta come file `jobs.yml` versionato nel progetto, poi sincronizzato con dbt Cloud.
>
> Il flusso si compone di un set di utility dedicate:
>
> - **`generate_jobs.ps1`**: genera la configurazione dei job a partire dai modelli presenti in una cartella.
> - **`dbt-jobs-as-code`**: sincronizza quella configurazione con dbt Cloud (aggiunge, aggiorna o rimuove i job di conseguenza).
> - **`fetch_dbt_jobs.py`** / **`fetch_dbt_dependencies.py`**: esportano rispettivamente gli identificativi e le dipendenze dei job per consultazione.
>
> Il dettaglio operativo di ciascuna utility è descritto nella Guida Sviluppo.

## Note

- Va inserito subito dopo il capitolo "L1: Generazione dei modelli DBT" — vedi [[proposta-testo-generazione-modelli-l1]] per la proposta di quel capitolo.

## Collegamenti

- [[caricamento-layer-l0-l1]]
- [[guida-sviluppo]]
- [[proposta-testo-generazione-modelli-l1]]
