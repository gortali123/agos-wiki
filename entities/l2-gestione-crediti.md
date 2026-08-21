---
title: "L2 GESTIONE_CREDITI"
type: entity
tags: [layer/L2, area/GESTIONE_CREDITI]
updated: 2026-08-19
---

Modelli (`raw/dwh-code/models/L2/GESTIONE_CREDITI/`): `azioni_recupero`, `cessioni`, `conteggi_estintivi`, `estinzioni_anticipate_tot`, `passaggi_a_perdita`, `perdite_minime_abb`, `pratica_a_recupero`.

- **`cessioni`** — S4, `UNION ALL` di più sorgenti procedura.
- **`pratica_a_recupero`** — S4, PK `[CD_PRATICA, TP_PROVENIENZA]`.

**Aggiornamento 2026-08-19**: tutti e 7 i modelli dell'area hanno `query_tag` (verificato con grep diretto) — la nota precedente ("nessun modello ha query_tag") era stale, risalente a prima del resync 2026-07-24 che ha corretto `query_tag` su gran parte di L2. `pre_hook delete_l2` non ricontrollato modello per modello in questo giro, tranne `passaggi_a_perdita` (S4/union, cancellazioni non applicabili per design).

**Bug reale in `passaggi_a_perdita.sql` righe 8 e 32 (verificato 2026-08-19)**: `COALESCE(nullif('B.TABTPP_CONCORDATA', ' '), 'N')` passa il nome colonna come stringa letterale tra apici invece che come identificatore SQL — il `NULLIF` non ha mai effetto reale (confronta sempre la costante `'B.TABTPP_CONCORDATA'` con `' '`, mai vero), quindi il placeholder OCS su questo campo non viene mai normalizzato. Vedi [[inconsistenze]] (voce 6), [[null-vs-placeholder-ocs]].

## Collegamenti

- [[layer-l2]]
- [[null-vs-placeholder-ocs]]
- [[inconsistenze]]
