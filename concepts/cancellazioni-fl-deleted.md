---
title: "Cancellazioni logiche e FL_DELETED"
type: concept
tags: [layer/L1, layer/L2, cancellazioni]
updated: 2026-07-14
---

Meccanismo di gestione delle cancellazioni lungo la pipeline L0→L1→L2, descritto in [[caricamento-layer-l0-l1]] e [[caricamento-layer-l2]].

## L0/L1

- OCS invia un file dedicato con le sole chiavi fisiche (`ROWID`) da considerare cancellate, in parallelo al file dati, innescato dallo stesso file civetta.
- In L1, post-hook (vedi [[macro-catalogo-dbt]]): `logic_delete_merge()` (cluster A) o `logic_delete_scd2()` (cluster C) valorizzano `FL_DELETED = 'Y'` + `TS_DELETED` = `lastmodifieddata` del feed cancellazioni, joinando su `rowid` contro la source companion `<archivio>_deleted`.
- `logic_delete_scd2()` inoltre chiude la finestra di validità aperta (`ts_fine_validita = ts_deleted`) per il record attivo.

## L2

Due step teorici (da [[caricamento-layer-l2]]): filtro in lettura (`FL_DELETED = 'Y'` escluso) + cancellazione fisica via pre_hook `delete_l2('ARCHIVIO', [PK_L2...], [PK_L1...])` (vedi [[macro-catalogo-dbt]]) che confronta `TS_DELETED` del sorgente col max `LASTMODIFIEDDATA` del target (vedi [[lastmodifieddata]]).

**Verificato nel codice reale (2026-07-14)**: i due step non sono sempre entrambi presenti. Modelli come `ANTIFRODE.archivio_tessere` filtrano solo `FL_DELETED = 'N'` nel SELECT, senza alcun `pre_hook: delete_l2(...)` — quindi righe già caricate e successivamente cancellate **restano stale nel target L2** per questi modelli, a differenza di `VARIAZIONI_ANAGRAFICHE` o `CARTE_UTILIZZI` che hanno entrambi gli step. Non è chiaro se sia una scelta consapevole (entità dove le cancellazioni fisiche non contano) o un gap di implementazione — vedi [[inconsistenze]].

## Valore del flag: Y/N vs S/N

I tre documenti raw usano sistematicamente `FL_DELETED = 'Y'`/`'N'`. La convenzione di naming campi nella xlsx (`Nomenclatura Campi`, foglio "Indicatore Flag") prescrive però che i campi con prefisso `FL_` abbiano **rigorosamente due valori: "S" o "N"** (non "Y"). Questo è un disallineamento sistemico tra la convenzione documentata nel data model e l'uso reale in tutta la codebase (`FL_DELETED`, e probabilmente altri flag) — vedi [[naming-convention-agos-x]] e [[inconsistenze]] per il dettaglio.

## Collegamenti

- [[caricamento-layer-l0-l1]], [[caricamento-layer-l2]]
- [[storicizzazione-l1-cluster-a-b-c]], [[storicizzazione-l2-s1-s4]]
- [[naming-convention-agos-x]]
- [[macro-catalogo-dbt]]
- [[inconsistenze]]
