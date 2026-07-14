---
title: "L2 RISCHI_ADEMPIMENTI"
type: entity
tags: [layer/L2, area/RISCHI_ADEMPIMENTI]
updated: 2026-07-14
---

Area più estesa e più spec-compliant per `query_tag` (schema = nome cartella corretto in quasi tutti i modelli). Modelli (`raw/dwh-code/models/L2/RISCHI_ADEMPIMENTI/`): `cartolarizzazioni_m`, `consolidamenti`, `elenco_conti_sval_o`, `flessibilita_m`, `forbearance_m`, `giorni_scaduto`, `indice_rischio_m`, `legame_cartolarizzazioni`, `moratorie_m`, `performing_m`, `ristrutturazioni_o`, `stato_creditizio_m`, `svalutazioni_m`.

- **`giorni_scaduto`** — S2, `pre_hook: delete_l2` + `FL_DELETED='N'` (entrambi gli step di cancellazione presenti, correttamente).
- **`indice_rischio_m`** — `query_tag.entita = "INDICE_RISCHIO"` (manca il suffisso `_M` rispetto al nome modello — mismatch minore).
- **`ristrutturazioni_o`** — **bug nel nome file**: `ristrutturazioni_o_sql` / `ristrutturazioni_o_yml` (mancano i punti prima dell'estensione). Come nominati, dbt non li riconoscerebbe come file modello validi. Il contenuto yml interno è comunque corretto (`query_tag` allineato all'area). Vedi [[inconsistenze-doc-vs-codice]].

## Collegamenti

- [[layer-l2]]
- [[inconsistenze-doc-vs-codice]]
