---
title: "CFG_L1_SCHEMA e CFG_L1_CLUSTER_STO (export tabelle tecniche)"
type: source
tags: [layer/L1, source/csv, storicizzazione, ocs]
updated: 2026-07-17
---

Export CSV delle due tabelle tecniche già citate in [[caricamento-layer-l0-l1]] (`TECH.CFG_L1_SCHEMA`, `TECH.CFG_L1_CLUSTER_STO`). Non ingeriti riga per riga (troppo voluminosi): questa pagina ne riassume la struttura e le statistiche chiave, da usare come riferimento per query puntuali su singoli archivi/moduli.

## `raw/cfg_l1_schema.csv`

Catalogo colonne di tutti gli archivi L1, 139.495 righe. Colonne: `CD_MODULO, DS_ARCHIVIO, DS_COLUMN_NAME, DS_DATA_TYPE, DS_LENGTH_COL, FL_IS_NULLABLE, FL_IS_PRIMARY_KEY, DS_SORGENTE, NM_CAMPO (ordinale), TS_RIFERIMENTO`. Copre 1.737 archivi distinti su 50 `CD_MODULO`. Nota: alcuni valori di `DS_SORGENTE` nel file grezzo sono sporchi (`N`, `N `, `S`, `S `) — probabile disallineamento/parsing su righe con virgole nei valori (es. `DS_LENGTH_COL` tipo `"6,0"`); da trattare con cautela se si fa query diretta sul CSV, verificare riga per riga in caso di dubbio.

## `raw/cfg_l1_cluster_sto.csv`

Mappatura archivio → cluster di storicizzazione → sorgente, 1.737 righe. Colonne: `DS_ARCHIVIO, CD_MODULO, CD_CLUSTER, DS_SORGENTE`.

**Distribuzione sorgenti** (conferma quantitativa di quanto discusso in [[null-vs-placeholder-ocs]]: OCS è la sorgente enormemente dominante, non un caso limitato ad AIN):

| Sorgente | Archivi | % |
|---|---|---|
| OCS | 1613 | 92.9% |
| FEA | 55 | 3.2% |
| BSN | 19 | 1.1% |
| ADOBE | 16 | 0.9% |
| SFC | 8 | 0.5% |
| SAP | 7 | 0.4% |
| PRIMEWEB | 6 | 0.3% |
| DIL | 5 | 0.3% |
| CRIF, XEROX, SWORD, Microdata, IDM, CTC, BANCO | 1 ciascuno | — |

**Mapping CD_MODULO → DS_SORGENTE** (autoritativo, sostituisce l'euristica "nessuna cartella L1 dedicata = OCS" usata finora): tutti gli archivi con `CD_MODULO` non vuoto sono OCS — 36 moduli osservati: `AIN, ANA, ANT, BAN, CAR, CH1, CH2, CHM, CMN, CNF, CNT, CON, CQS, CRE, CRM, EFF, FMP, IAS, INC, INT, ITF, MIG, MSF, PAG, POS, PRV, REC, RIS, RVD, SDS, SER, SRV, SVC, TRS, VIG, WFL`. Solo `AIN` e (parzialmente) `WFL`/`SER` risultano vendorizzati in `raw/dwh-code/models/L1/OCS/`. Gli archivi con `CD_MODULO` vuoto appartengono alle 14 sorgenti NO-OCS già elencate in [[null-vs-placeholder-ocs]].

**Distribuzione cluster**: C=783, A2=563, A1=211, B1=85, TBD=55, D=26, B2=14. Nota per [[storicizzazione-l1-cluster-a-b-c]]: il cluster B risulta effettivamente diviso in **B1/B2** (come A1/A2), non documentato nella pagina concetto attuale — da aggiornare. Esiste anche uno stato **TBD** (55 archivi, non ancora classificato) concentrato su BSN, SAP, PRIMEWEB, DIL, SWORD, BANCO — nessun archivio OCS risulta TBD.

## Uso previsto

Riferimento per verificare rapidamente, dato un nome di archivio/modulo: (a) se è OCS (quindi soggetto al placeholder `' '`, vedi [[null-vs-placeholder-ocs]]), (b) il suo cluster di storicizzazione, (c) tipo/nullability/PK delle sue colonne — senza dover risalire al codice dbt quando non vendorizzato in `raw/dwh-code/`.

## Collegamenti

- [[caricamento-layer-l0-l1]]
- [[storicizzazione-l1-cluster-a-b-c]]
- [[null-vs-placeholder-ocs]]
