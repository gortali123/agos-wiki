---
title: Data Masking / Classification
type: concept
tags: [layer/L1, layer/L2, security]
updated: 2026-07-07
---

Basato sul tagging colonne nativo di Snowflake. La documentazione ufficiale afferma che, poiché [[layer-l0]] è inaccessibile agli utenti finali, il masking viene applicato **solo a partire da** [[layer-l1]] e propagato automaticamente a L2/L3 tramite **tag propagation nativa** di Snowflake: qualsiasi DDL che deriva una colonna da una sorgente già taggata trasferisce automaticamente il tag, senza intervento manuale.

**Il codice reale contraddice questa affermazione**: esiste una seconda macro, `apply_privacy_to_l0_from_matrix()`, che applica tag e masking policy **direttamente su L0** (schema `L0`, database `AGOS_DEV_16000`) a partire da una matrice passata come dbt var (`l0_privacy_matrix`). Vedi sotto e [[incoerenze-codice-vs-documentazione]] (punto 9). **Stato (2026-07-08)**: non è ancora chiaro se sia un meccanismo voluto o un errore di implementazione — da verificare col team infra/sicurezza, vedi [[todo-allineamento-documentazione]] (sezione security/masking). Non prendere questa pagina come normativa finché non c'è un riscontro.

## Componenti

- Catalogo [[cfg-l1-datamask]] (`TECH.CFG_L1_DATAMASK`) — censisce per archivio le colonne soggette a masking.
- Oggetti Snowflake: **Tag** + **Masking policy** associata al tag.
- Le colonne sensibili sono identificate nei modelli DBT tramite un campo metadato dichiarato nello yml dei modelli L1.

## Macro

- `add_datamask()` — (in `raw/dwh-code/macros/add_datamask.sql`) legge `meta.masking` dalla config di ogni colonna del modello compilato e, se valorizzato, esegue `ALTER TABLE ... MODIFY COLUMN ... SET TAG AGOS_DEV_16000.TAGS.sensitivity = '<valore>'`. Pensata per L1 (ma agisce su `this`, quindi qualunque modello la richiami in post-hook, non necessariamente solo L1). **Nota**: non legge affatto [[cfg-l1-datamask]] (`TECH.CFG_L1_DATAMASK`) — la fonte del valore è solo il metadato `meta.masking` nello yml del modello, non la tabella di catalogo. Il documento ufficiale descrive invece `CFG_L1_DATAMASK` come il catalogo che "censisce le colonne soggette a masking", suggerendo che dovrebbe essere la fonte — da chiarire se la tabella è usata altrove (es. per generare i metadata yml) o se è un artefatto di design non più allineato all'implementazione.
- `apply_privacy_to_l0_from_matrix(results)` — (in `raw/dwh-code/macros/apply_privacy_to_l0_from_matrix.sql`) **applica il masking direttamente su L0**: crea/aggiorna uno schema `TAGS`, un tag `sensitivity` con valori ammessi `DOLLAR`/`SPACES`/`ZEROS`, e una masking policy `policy_mask_by_sensitivity` che sostituisce ogni carattere del valore con `$`/spazio/`0` a seconda del tag (bypass per il ruolo `DEVELOPER`). Poi itera una matrice `l0_privacy_matrix` (var dbt: `{tabella: {colonna: valore_tag}}`) e applica il tag a ogni colonna elencata, su tabelle **L0**. Meccanismo completamente separato da `add_datamask()` (tag omonimo `sensitivity`, ma valori ammessi e semantica diversi: qui sono stili di mascheramento, non un flag generico).
- `remove_datamask()` — descritta nella guida sviluppo ma **non presente** nel codice sincronizzato in `raw/dwh-code` (nessun file `remove_datamask.sql`). Potrebbe non essere ancora stata implementata, oppure vivere altrove nel repo non ancora copiato. **Stato (2026-07-08)**: da verificare col team infra/sicurezza, vedi [[todo-allineamento-documentazione]].

## Collegato da
[[layer-l0]], [[layer-l1]], [[layer-l2]], [[cfg-l1-datamask]], [[agosx-caricamento-l2]], [[incoerenze-codice-vs-documentazione]]
