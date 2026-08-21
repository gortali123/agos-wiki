---
title: "L2 CARTE"
type: entity
tags: [layer/L2, area/CARTE]
updated: 2026-08-19
---

Modelli (`raw/dwh-code/models/L2/CARTE/`): `carte_autorizzativo`, `carte_blocchi`, `carte_estratto_conto_m`, `carte_limitazioni_operativita`, `carte_mov_estratto_conto_m`, `carte_utilizzi`.

**`carte_utilizzi`** è il modello più ricco: S1 con `hash_cols()` + `is_incremental_S1(...)` (macro condivisa, non bespoke — vedi [[storicizzazione-l2-s1-s4]]), `pre_hook: delete_l2('crvouf', [...])`, `FL_DELETED='N'` su molti alias joinati.

**Inconsistenza sistematica, riconfermata 2026-08-19**: tutti e 6 i modelli dell'area hanno `query_tag` valorizzato ma con `"schema": "L2_PRODOTTO"` invece di `L2_CARTE` — un mismatch a livello di intera cartella, non un typo isolato. Vedi [[query-tag-monitoring]] e [[inconsistenze]] (voce 1).

**Bug reale in `carte_utilizzi.sql:148` (verificato 2026-08-19)**: `FL_CONTRIBUTI_PROMO` è derivato con `CASE WHEN (f.CRVOC_CONTR_DEALER <> 0 OR f.CRVOC_CONTR_DEALER IS NOT NULL) THEN 'S' ELSE 'N' END` — condizione sempre vera per qualunque valore non-NULL incluso `0`, quindi il placeholder NUMBER OCS (`0` = assente) non viene mai discriminato, a differenza dei campi gemelli nello stesso file che usano correttamente `NULLIF(campo, 0)`. Vedi [[inconsistenze]] (voce 7), [[null-vs-placeholder-ocs]].

## Collegamenti

- [[layer-l2]]
- [[storicizzazione-l2-s1-s4]]
- [[inconsistenze]]
