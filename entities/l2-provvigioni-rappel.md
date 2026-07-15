---
title: "L2 PROVVIGIONI_RAPPEL"
type: entity
tags: [layer/L2, area/PROVVIGIONI_RAPPEL]
updated: 2026-07-14
---

Modelli (`raw/dwh-code/models/L2/PROVVIGIONI_RAPPEL/`): `proforma_prv_rap`, `provvigioni_e_rappel`.

**`provvigioni_e_rappel`** — S4, PK composta a 14 colonne (la più lunga del progetto).

**Inconsistenza verificata (2026-07-14)**: entrambi i modelli hanno un `query_tag` con `"schema": "L2_MAIN"` (né `L2_PROVVIGIONI_RAPPEL` né una sigla xlsx nota) **commentato con `#`** — quindi la config è sia semanticamente sbagliata sia disattiva. `proforma_prv_rap` ha `pre_hook: delete_l2('ccfatprv', [...])` in forma a lista YAML (unica in questa forma nell'area). Vedi [[query-tag-monitoring]] e [[inconsistenze]].

## Collegamenti

- [[layer-l2]]
- [[inconsistenze]]
