---
title: "Storicizzazione L1: cluster A, B, C"
type: concept
tags: [layer/L1, storicizzazione]
updated: 2026-07-14
---

Classificazione degli archivi L1 secondo la modalità di storicizzazione, definita nella tabella tecnica `TECH.CFG_L1_CLUSTER_STO` e descritta in [[caricamento-layer-l0-l1]].

- **Cluster A**: delta giornaliero, quasi solo insert (rari update puntuali per bonifiche) → materializzazione incrementale `merge`. Sotto-varianti osservate nel codice: **A1**, **A2** (es. `meta.cluster` nei modelli L1 OCS). A2 aggiunge `fl_deleted`/`ts_deleted` via post-hook `logic_delete_merge()`.
- **Cluster B**: fotografia completa ogni giorno → `TRUNCATE/INSERT`, materializzazione incrementale `insert_overwrite`. Nessuna storicizzazione necessaria per natura del caricamento.
- **Cluster C**: richiede vera storicizzazione SCD2. Implementato con **snapshot DBT strategy `timestamp`** più un modello `ephemeral` intermedio di tipizzazione (`stg_<modello>.sql`) a monte dello snapshot. Post-hook `logic_delete_scd2()` per le cancellazioni.
- **Cluster D**: non descritto nei tre documenti raw, ma presente nel codice (`generate_yaml.sql` genera per D: incremental+append con pre_hook `delete_month(get_dt_osservazione('ts_riferimento'))`, aggiunge colonna `dt_osservazione`) — corrisponde ad archivi con fotografie mensili aggiuntive. Vedi [[inconsistenze-doc-vs-codice]].

## Campi tecnici L1 per cluster

- Sempre: `ts_riferimento`, `ts_caricamento`.
- Cluster A (specialmente A2)/C: `fl_deleted`, `ts_deleted`.
- Cluster C — solo a livello di **snapshot** (non nel modello ephemeral `stg_`): `ts_inizio_validita`, `ts_fine_validita`, `id_scd`, `ts_update_at`. Il mapping esatto è centralizzato in `dbt_project.yml` (`snapshot_meta_column_names`): `dbt_valid_from→ts_inizio_validita`, `dbt_valid_to→ts_fine_validita`, `dbt_scd_id→id_scd`, `dbt_updated_at→ts_updated_at` (verificato 2026-07-14, vedi [[inconsistenze-doc-vs-codice]] per la nota su `ts_update_at` vs `ts_updated_at`).
- OCS: `sys_change_operation`, `lastmodifieddata` (nessun prefisso, deviazione sistemica dalla naming convention CD_/DT_/TS_/FL_).

## Naming L1→L0

Confermato 1:1 tra tabella L0 e modello L1 per tabelle non storicizzate (`<archivio>_source.yml` → `<archivio>.sql`/`.yml`). Per cluster C, il nome L1 diventa `stg_<archivio>` (ephemeral), e lo snapshot successivo riprende il nome originale `<archivio>`.

## Collegamenti

- [[caricamento-layer-l0-l1]]
- [[cancellazioni-fl-deleted]]
- [[storicizzazione-l2-s1-s4]]
- [[macro-catalogo-dbt]]
- [[inconsistenze-doc-vs-codice]]
