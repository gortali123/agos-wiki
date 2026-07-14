---
title: "L2 GESTIONE_CREDITI"
type: entity
tags: [layer/L2, area/GESTIONE_CREDITI]
updated: 2026-07-14
---

Modelli (`raw/dwh-code/models/L2/GESTIONE_CREDITI/`): `azioni_recupero`, `cessioni`, `conteggi_estintivi`, `estinzioni_anticipate_tot`, `passaggi_a_perdita`, `perdite_minime_abb`, `pratica_a_recupero`.

- **`cessioni`** — S4, `UNION ALL` di più sorgenti procedura.
- **`pratica_a_recupero`** — S4, PK `[CD_PRATICA, TP_PROVENIENZA]`.

Nessun modello dell'area ha `query_tag` né `pre_hook delete_l2`.

## Collegamenti

- [[layer-l2]]
