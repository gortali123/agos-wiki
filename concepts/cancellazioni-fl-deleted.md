---
title: "Cancellazioni logiche e FL_DELETED"
type: concept
tags: [layer/L1, layer/L2, cancellazioni]
updated: 2026-08-19
---

Meccanismo di gestione delle cancellazioni lungo la pipeline L0→L1→L2, descritto in [[caricamento-layer-l0-l1]] e [[caricamento-layer-l2]].

## L0/L1

- OCS invia un file dedicato con le sole chiavi fisiche (`ROWID`) da considerare cancellate, in parallelo al file dati, innescato dallo stesso file civetta.
- In L1, post-hook (vedi [[macro-catalogo-dbt]]): `logic_delete_merge()` (cluster A) o `logic_delete_scd2()` (cluster C) valorizzano `FL_DELETED = 'Y'` + `TS_DELETED` = `lastmodifieddata` del feed cancellazioni, joinando su `rowid` contro la source companion `<archivio>_deleted`.
- `logic_delete_scd2()` inoltre chiude la finestra di validità aperta (`ts_fine_validita = ts_deleted`) per il record attivo.

## L2

Due step teorici (da [[caricamento-layer-l2]]): filtro in lettura (`FL_DELETED = 'Y'` escluso) + cancellazione fisica via pre_hook `delete_l2('ARCHIVIO', [PK_L2...], [PK_L1...])` (vedi [[macro-catalogo-dbt]]) che confronta `TS_DELETED` del sorgente col max `LASTMODIFIEDDATA` del target (vedi [[lastmodifieddata]]).

**Riverificato 2026-08-19**: il gap resta confermato su 6 modelli — `ANTIFRODE.archivio_tessere`, `ANTIFRODE.gestione_truffe`, `PAGAMENTI_CONTABILITA.pagamenti_vidaut`, `PRODOTTO.tabelle_finanziarie`, `PRODOTTO.variazioni_stato_prat`, `PROVVIGIONI_RAPPEL.proforma_prv_rap` filtrano solo `FL_DELETED` nel SELECT, senza alcun `pre_hook: delete_l2(...)` — quindi righe già caricate e successivamente cancellate **restano stale nel target L2** per questi modelli, a differenza di `VARIAZIONI_ANAGRAFICHE` o `CARTE_UTILIZZI` che hanno entrambi gli step. Non è chiaro se sia una scelta consapevole o un gap di implementazione — vedi [[inconsistenze]] (voce 2).

**Anomalia inversa** (rischio basso): `ANAGR_CONTROPARTE.legame_ditte_individuali`, `ANAGR_CONTROPARTE.variazioni_anagrafiche_day` e `CARTE.carte_autorizzativo` hanno il `pre_hook delete_l2(...)` ma nessun filtro `FL_DELETED` nel SELECT — vedi [[inconsistenze]] (voce 3).

## Valore del flag: Y/N

I tre documenti raw e il codice usano sistematicamente `FL_DELETED = 'Y'`/`'N'` (confermato in `raw/dwh-code/macros/logic_delete/delete_l2.sql`: `src.FL_DELETED = 'Y'`). La vecchia divergenza rispetto alla convenzione `S/N` del foglio "Nomenclatura Campi" di `raw/Agos X - Layer L2.xlsx` non è più verificabile: quel file è stato rimosso da `raw/` — vedi [[inconsistenze]] (sezione "Voci non più verificabili").

## Collegamenti

- [[caricamento-layer-l0-l1]], [[caricamento-layer-l2]]
- [[storicizzazione-l1-cluster-a-b-c]], [[storicizzazione-l2-s1-s4]]
- [[naming-convention-agos-x]]
- [[macro-catalogo-dbt]]
- [[inconsistenze]]
