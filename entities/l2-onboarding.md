---
title: "L2 ONBOARDING"
type: entity
tags: [layer/L2, area/ONBOARDING]
updated: 2026-07-14
---

Modelli (`raw/dwh-code/models/L2/ONBOARDING/`): `doc_istruttoria`, `wfl_attivita`, `wfl_fase`, `wfl_istanza`, `wfl_sottofase`.

**`wfl_istanza`** è notevole: è l'**unico modello S1 di tutto il progetto che usa la macro condivisa** `{{ is_incremental_S1('CD_ISTANZA') }}` + `{{ ts_fine_validita(...) }}` invece di ricalcolare a mano dedup-hash e finestre come fa [[l2-anagr-controparte]] (`variazioni_anagrafiche`). Vedi [[storicizzazione-l2-s1-s4]] per la discussione su questa doppia implementazione.

Nessun `query_tag` nell'area.

## Collegamenti

- [[layer-l2]]
- [[storicizzazione-l2-s1-s4]]
