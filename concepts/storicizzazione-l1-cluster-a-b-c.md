---
title: "Storicizzazione L1: cluster A, B, C"
type: concept
tags: [layer/L1, storicizzazione]
updated: 2026-07-14
---

Classificazione degli archivi L1 secondo la modalità di storicizzazione, definita nella tabella tecnica `TECH.CFG_L1_CLUSTER_STO` e descritta in [[caricamento-layer-l0-l1]].

- **Cluster A**: delta giornaliero, quasi solo insert (rari update puntuali per bonifiche) → materializzazione incrementale `merge`. Sotto-varianti osservate nel codice: **A1**, **A2** (es. `meta.cluster` nei modelli L1 OCS). A2 aggiunge `fl_deleted`/`ts_deleted` via post-hook `logic_delete_merge()`.
- **Cluster B**: fotografia completa ogni giorno → `TRUNCATE/INSERT`, materializzazione incrementale `insert_overwrite`. Nessuna storicizzazione necessaria per natura del caricamento. Confermato in `TECH.CFG_L1_CLUSTER_STO` (vedi [[cfg-l1-schema-e-cluster-sto]]) che esiste una sotto-variante **B1/B2** analoga ad A1/A2 (85+14 archivi), non ulteriormente dettagliata nei tre documenti raw.
- **Cluster C**: richiede vera storicizzazione SCD2. Implementato con **snapshot DBT strategy `timestamp`** più un modello `ephemeral` intermedio di tipizzazione (`stg_<modello>.sql`) a monte dello snapshot. Post-hook `logic_delete_scd2()` per le cancellazioni.
- **Cluster D**: non descritto nei tre documenti raw, ma presente nel codice (`generate_yaml.sql` genera per D: incremental+append con pre_hook `delete_month(get_dt_osservazione('ts_riferimento'))`, aggiunge colonna `dt_osservazione`) — corrisponde ad archivi con fotografie mensili aggiuntive. Vedi [[inconsistenze]].
- **TBD**: stato osservato in `TECH.CFG_L1_CLUSTER_STO` (55 archivi, vedi [[cfg-l1-schema-e-cluster-sto]]) per archivi non ancora classificati in un cluster — concentrato su BSN, SAP, PRIMEWEB, DIL, SWORD, BANCO; nessun archivio OCS risulta TBD.

## Campi tecnici L1 per cluster

- Sempre: `ts_riferimento`, `ts_caricamento`.
- Cluster A (specialmente A2)/C: `fl_deleted`, `ts_deleted`.
- Cluster C — solo a livello di **snapshot** (non nel modello ephemeral `stg_`): `ts_inizio_validita`, `ts_fine_validita`, `id_scd`, `ts_update_at`. Il mapping esatto è centralizzato in `dbt_project.yml` (`snapshot_meta_column_names`): `dbt_valid_from→ts_inizio_validita`, `dbt_valid_to→ts_fine_validita`, `dbt_scd_id→id_scd`, `dbt_updated_at→ts_updated_at` (verificato 2026-07-14, vedi [[inconsistenze]] per la nota su `ts_update_at` vs `ts_updated_at`).
- OCS: `sys_change_operation`, `lastmodifieddata` (nessun prefisso, deviazione sistemica dalla naming convention CD_/DT_/TS_/FL_).

## Normalizzazione varchar vuoti OCS in L1 (placeholder `' '`)

I 14 modelli L1 `OCS/AIN` (`raw/dwh-code/models/L1/OCS/AIN/*.sql`: `aiecfpare.sql`, `aictfpt.sql`, `aiecfpart.sql`, `aiecfpartl.sql`, `aiecfparel.sql`, `aiecfpardl.sql`, `aiecfpard.sql`, `aiecfparcl.sql`, `aiecfparc.sql`, `aictfstl.sql`, `aictfpdpl.sql`, `aictfpdp.sql`, `stg_aitbfsta.sql`, `stg_aitbfatt.sql`) applicano sistematicamente, per ogni campo varchar, il pattern:

```
TRY_CAST(IFF(RTRIM(<campo>) = '', ' ', RTRIM(<campo>)) AS VARCHAR(n)) AS <campo>
```

es. `aiecfpare.sql` righe 8, 10, 12, 15-16, 18-19, 22-24, 28-29; `aictfpt.sql` righe 10-16, 18, 22.

Questa non è passthrough puro: è logica L1 esplicita che **forza a `' '` (placeholder) ogni valore che dopo `RTRIM` risulta stringa vuota `''`**, garantendo che il placeholder OCS sia sempre rappresentato in modo canonico (un singolo spazio), mai come `''` vuota o come NULL vero. Va nella direzione opposta a quella discussa in [[null-vs-placeholder-ocs]] (che tratta come L2/L3 devono *interpretare* `' '` come NULL semantico): qui in L1 il placeholder viene *prodotto/normalizzato*, non convertito.

Non è un pattern generato dal template (`raw/dwh-code/templates/models/L1/C/stg_table.sql`, verificato 2026-07-20, contiene solo `TRY_CAST(<col> AS <dtype>)` senza `IFF`) — è scritto a mano modello per modello, solo per gli archivi OCS/AIN campionati in questo snapshot. Non è stato trovato lo stesso pattern altrove in `raw/dwh-code/models/L1/` né macro dedicate in `raw/dwh-code/macros/` per questa normalizzazione: resta da verificare se altri archivi OCS non vendorizzati (fuori campione) replicano la stessa logica.

## Naming L1→L0

Confermato 1:1 tra tabella L0 e modello L1 per tabelle non storicizzate (`<archivio>_source.yml` → `<archivio>.sql`/`.yml`). Per cluster C, il nome L1 diventa `stg_<archivio>` (ephemeral), e lo snapshot successivo riprende il nome originale `<archivio>`.

## Collegamenti

- [[caricamento-layer-l0-l1]]
- [[cancellazioni-fl-deleted]]
- [[storicizzazione-l2-s1-s4]]
- [[macro-catalogo-dbt]]
- [[inconsistenze]]
- [[cfg-l1-schema-e-cluster-sto]]
- [[null-vs-placeholder-ocs]]
