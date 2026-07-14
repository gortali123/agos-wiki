---
title: "L2 PRODOTTO"
type: entity
tags: [layer/L2, area/PRODOTTO]
updated: 2026-07-14
---

Modelli (`raw/dwh-code/models/L2/PRODOTTO/`): `azioni_postvendita`, `carta`, `catene_intermediazione_agg`, `consumo`, `cqs`, `pratica`, `tabelle_finanziarie`, `variazioni_stato_prat`.

**`pratica`** — S4, PK `[CD_PRATICA, TP_PROCEDURA]`, union concettuale di CONSUMO/CARTA/CQS (per xlsx Catalogo Entità: `UNION` di `L1.PLPRAT`, `L1.CRCAR`, `L1.QSPRA`), con numerosi JOIN a lookup current-row (`TS_FINE_VALIDITA=9999-12-31 AND FL_DELETED='N'`).

Nessun `query_tag` nell'area. Vedi anche [[l2-prodotto-m]] per le versioni mensili consolidate.

## Collegamenti

- [[layer-l2]]
- [[l2-prodotto-m]]
