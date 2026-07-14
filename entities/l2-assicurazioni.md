---
title: "L2 ASSICURAZIONI"
type: entity
tags: [layer/L2, area/ASSICURAZIONI]
updated: 2026-07-14
---

Modelli (`raw/dwh-code/models/L2/ASSICURAZIONI/`): `anagrafica_prodotto_assic`, `polizze_standalone`, `premi_assicurativi`, `provvigioni_assicurative`, `questionari_assicurativi`, `servizi_assicurativi`, `servizi_assicurativi_m`.

- **`anagrafica_prodotto_assic`** — S4, PK `[CD_SORGENTE, CD_SERVIZIO]`.
- **`premi_assicurativi`** — S4 con `unique_key` esplicito (insolito per insert_overwrite), current-row filtering su più dimensioni SCD2 joinate (`TS_INIZIO/FINE_VALIDITA` + `FL_DELETED='N'`).

Nessun modello dell'area ha `query_tag`.

## Collegamenti

- [[layer-l2]]
