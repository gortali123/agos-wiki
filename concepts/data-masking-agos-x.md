---
title: "Data masking / classification Agos X"
type: concept
tags: [data-classification, snowflake, layer/L1]
updated: 2026-07-14
---

Meccanismo di data classification descritto in [[caricamento-layer-l2]], basato su tagging Snowflake nativo con propagazione automatica ai layer successivi.

- Tabella di catalogo `TECH.CFG_L1_DATAMASK`: censisce per ogni archivio le colonne soggette a masking (colonne `ds_masking_rule`, `fl_active`).
- Il masking si applica a partire da **L1** (L0 non è accessibile agli utenti finali) e si propaga a L2/L3 tramite **tag propagation nativa di Snowflake** (nessun intervento manuale richiesto sulle DDL derivate).
- Macro `add_datamask()`: post-hook alla prima esecuzione del modello, legge `model.columns[*].meta.masking` (valorizzato dal generatore `generate_yaml.sql` a partire da `CFG_L1_DATAMASK`) ed esegue `ALTER TABLE ... SET TAG AGOS_DEV_16000.TAGS.sensitivity = '<valore>'`.
- Macro `apply_privacy_to_l0_from_matrix(results)`: setup one-time — crea lo schema `TAGS`, il tag `sensitivity`, la masking policy `policy_mask_by_sensitivity` (valori ammessi `DOLLAR`/`SPACES`/`ZEROS`, bypass per ruolo `DEVELOPER`), e applica una matrice `var('l0_privacy_matrix')` direttamente su tabelle L0.

## Inconsistenza verificata (2026-07-14)

I docx documentano anche una macro **`remove_datamask()`** per rimuovere puntualmente un tag da una colonna. **Questa macro non esiste nel codice** (`raw/dwh-code/macros/`): esiste solo `add_datamask()` (set). L'unica cosa vagamente simile è uno statement `UNSET MASKING POLICY` dentro `apply_privacy_to_l0_from_matrix.sql`, ma è parte del setup one-time della policy stessa, non una macro riusabile per rimuovere il masking da una colonna specifica. Vedi [[inconsistenze]].

## Collegamenti

- [[caricamento-layer-l2]]
- [[macro-catalogo-dbt]]
- [[inconsistenze]]
