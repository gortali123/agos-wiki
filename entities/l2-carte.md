---
title: "L2 CARTE"
type: entity
tags: [layer/L2, area/CARTE]
updated: 2026-07-14
---

Modelli (`raw/dwh-code/models/L2/CARTE/`): `carte_autorizzativo`, `carte_blocchi`, `carte_estratto_conto_m`, `carte_limitazioni_operativita`, `carte_mov_estratto_conto_m`, `carte_utilizzi`.

**`carte_utilizzi`** è il modello più ricco: S1, `pre_hook: delete_l2('crvouf', [...])`, `FL_DELETED='N'` su molti alias joinati.

**Inconsistenza sistematica verificata (2026-07-14)**: tutti e 6 i modelli dell'area hanno `query_tag` valorizzato ma con `"schema": "L2_PRODOTTO"` invece di `L2_CARTE` — un mismatch a livello di intera cartella, non un typo isolato. Vedi [[query-tag-monitoring]] e [[inconsistenze]].

## Collegamenti

- [[layer-l2]]
- [[storicizzazione-l2-s1-s4]]
- [[inconsistenze]]
