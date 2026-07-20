---
title: "L2 ONBOARDING"
type: entity
tags: [layer/L2, area/ONBOARDING]
updated: 2026-07-16
---

Modelli (`raw/dwh-code/models/L2/ONBOARDING/`): `doc_istruttoria`, `wfl_attivita`, `wfl_fase`, `wfl_istanza`, `wfl_sottofase`.

**`wfl_istanza`, `wfl_attivita`, `wfl_fase`, `wfl_sottofase`** sono tutti S1 basati sulla macro condivisa `{{ hash_cols([...]) }}` + `{{ is_incremental_S1(...) }}` + `{{ ts_fine_validita(...) }}` (riverificato 2026-07-16 dopo resync `raw/dwh-code/`). **Correzione**: la nota precedente ("`wfl_istanza` unico modello S1 del progetto a usare la macro condivisa") è superata — l'adozione della macro è oggi ampia anche fuori da ONBOARDING (es. `indirizzi_postalizzazione`, `carte_utilizzi`, `tabelle_finanziarie`, `variazioni_stato_prat`); l'eccezione bespoke residua è solo [[l2-anagr-controparte]] (`variazioni_anagrafiche`). Vedi [[storicizzazione-l2-s1-s4]] per il dettaglio aggiornato.

Nessun `query_tag` nell'area.

## Collegamenti

- [[layer-l2]]
- [[storicizzazione-l2-s1-s4]]
