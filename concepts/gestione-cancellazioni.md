---
title: Gestione cancellazioni (OCS e L2)
type: concept
tags: [cancellazioni, layer/L0, layer/L1, layer/L2]
updated: 2026-07-07
---

## Cancellazioni OCS (L0→L1)

La sorgente OCS mette a disposizione un file dedicato contenente solo le chiavi fisiche (`ROWID`) dei record da considerare cancellati (`<archivio>_deleted_<timestamp>_<progressivo>.csv.gz`, nel prefix `dati/` dello stesso archivio). Caratteristiche standard: CSV gzip, separatore `|`, escape backslash, encoding UTF-8 senza BOM.

Il caricamento delle cancellazioni è **parallelo** al caricamento dati standard, scatenato dallo stesso file civetta, e popola tabelle L0 dedicate parallele a quelle dati. Il caricamento in [[layer-l1]] parte solo se **entrambi** gli archivi (dati e cancellazioni) sono terminati OK.

Applicazione in L1: post-hook DBT che richiama una macro di cancellazione logica, diversa per cluster di storicizzazione (vedi [[storicizzazione-l1-cluster]]):
- `logical_delete_merge` — Cluster A
- `logical_delete_scd2()` — Cluster C

Effetto: `FL_DELETED = 'Y'` sui record con chiave da cancellare + `TS_DELETED` valorizzato con la data di cancellazione.

**Propagazione**: in L2/L3 (derivati da L1) le trasformazioni devono escludere sistematicamente `FL_DELETED = 'Y'`, per non reintrodurre record cancellati in dataset/metriche/aggregazioni.

## Cancellazioni in L2

Due step:
1. **Filtro in lettura** dalla tabella master L1: esclude i record con `FL_DELETED = 'Y'` (nota: il documento ufficiale L2 scrive in un punto `FL_DELETE = Y`, senza la `D` finale — quasi certamente un refuso, dato che ovunque altrove il campo è `FL_DELETED`).
2. **Cancellazione fisica post-esecuzione**: macro nel post-hook del modello DBT che recupera le chiavi cancellate logicamente in L1 (non ancora processate) ed esegue la `DELETE` fisica in L2 — per tutta la storia delle variazioni nel caso di tabelle storicizzate S1.

Implementazione pratica (guida sviluppo): pre-hook `delete_l2('NOME_ARCHIVIO', ['PK_L2_1', ...], ['PK_L1_1', ...])` da aggiungere sui modelli S1/S2 quando la tabella main è Cluster A1/A2 o C. Conversioni automatiche per chiavi `DT_`/`TS_` in L2. Filtro `FL_DELETED = 'N'` da applicare sia sulla tabella main (WHERE) sia sulle tabelle in join (condizione di JOIN). Nota: la guida sviluppo lascia esplicitamente aperto il caso di funzioni più complesse nel passaggio chiave da L1 a L2 staging.

## Collegato da
[[layer-l0]], [[layer-l1]], [[layer-l2]], [[agosx-caricamento-l0-l1]], [[agosx-caricamento-l2]], [[guida-sviluppo]]
