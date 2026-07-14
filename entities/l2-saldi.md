---
title: "L2 SALDI"
type: entity
tags: [layer/L2, area/SALDI]
updated: 2026-07-14
---

Modelli (`raw/dwh-code/models/L2/SALDI/`): `saldo_contabile_m`, `saldo_gestionale_m`, `saldo_off_m`. Tutti con `query_tag` corretto (`schema: "L2_SALDI"`, coerente col nome cartella).

**`saldo_contabile_m`** — S3, `pre_hook: delete_month()`, e **contiene un commento nel codice che si auto-dichiara `-- Storicizzazione: S3 (incremental / append) - chiave tecnica DT_OSSERVAZIONE`** — conferma diretta che gli sviluppatori conoscono e usano consapevolmente la tassonomia S1-S4 documentata.

## Collegamenti

- [[layer-l2]]
- [[storicizzazione-l2-s1-s4]]
