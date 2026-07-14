---
title: "Naming convention Agos X (schemi, tabelle, campi)"
type: concept
tags: [naming-convention, layer/L2, glossario]
updated: 2026-07-14
---

Convenzioni di naming per il DWH Agos X, raccolte da tre fonti che si sovrappongono solo parzialmente: [[caricamento-layer-l2]], [[guida-sviluppo]], e la xlsx [[layer-l2-xlsx-reference]] (foglio "Nomenclatura Campi"). Le divergenze tra fonti sono segnalate esplicitamente qui e riportate in [[inconsistenze-doc-vs-codice]].

## Schemi e tabelle

- Schema: `L2_<area_funzionale>` / `L3_<processo>`.
- Tabelle: `L2: <nome>_<frequenza>`, `L3: <tipo_oggetto>_<nome_tabella>_<frequenza>`.
- Frequenze: nessun suffisso = giornaliera, `_W` settimanale, `_M` mensile, `_T` trimestrale, `_Q` quadrimestrale, `_S` semestrale, `_Y` annuale, `_O` on demand.
- Tipo oggetto: Vista `V_`, Vista materializzata `VM_`, Datamart `DM_`, Flusso di output `FL_OUT_`, Tabella di processo `PRC_`, Function `FN_`, Stored procedure `PR_`.

## Prefissi campo: due liste non identiche

| Fonte | Prefissi elencati |
|---|---|
| docx (`caricamento-layer-l2`, `guida-sviluppo`) | `CD_`, `ID_`, `DS_`, `NM_`, `DT_`, `TS_`, `FL_`, `TP_`, `EU_`, `PC_`, `SK_`, `GN_` |
| xlsx "Nomenclatura Campi" | `CD`, `DS`, `TP`, `DT`, `TS`, `EU`, `FL`, `NM`, `PC`, `PR` (Progressivo), `GN_` |

Differenze:
- **`ID_`** (Identificativo) e **`SK_`** (Smart key) compaiono solo nei docx, non nella xlsx.
- **`PR_`** (Progressivo) compare solo nella xlsx, non nei docx — nonostante il concetto di "progressivo" sia usato concretamente nel codice (`PROGRESSIVO_PK`, `PROGRESSIVO_CONTROPARTE` — che però non usano il prefisso `PR_`, sono scritti per esteso, vedi [[progressivo-pk-e-progressivo-controparte]]).

Non è chiaro se le due liste siano state scritte in momenti diversi (una supersede l'altra) o se semplicemente nessuno le ha mai riconciliate. Da chiedere al team.

## Valori dei flag (FL_): S/N vs Y/N

La xlsx è esplicita: "Rigorosamente a 2 valori. **'S' o 'N'**". Nel codice reale e nei tre docx, il flag più usato in assoluto (`FL_DELETED`) usa sistematicamente **'Y'/'N'**, non 'S'/'N'. Vedi [[cancellazioni-fl-deleted]] e [[inconsistenze-doc-vs-codice]].

## Colonne tecniche fuori convenzione

Osservate nel codice reale, sistematicamente senza prefisso standard:
- `LASTMODIFIEDDATA` — timestamp CDC, usato ovunque senza prefisso `TS_`.
- `ROWID` — chiave tecnica L1.
- `PROGRESSIVO_PK`, `PROGRESSIVO_CONTROPARTE` — campi tecnici di disambiguazione, senza prefisso.
- `NM_ORA_INSERIMENTO_RECORD` (in `SEGNALAZIONI_ANAGRAFICHE`) — usa `NM_` (quantità numerica) per un valore orario, che semanticamente sarebbe più vicino a `TS_`.

Questi sono probabilmente accettati come "colonne tecniche di framework" più che violazioni vere e proprie, ma vale la pena tenerne traccia.

## Subject Area: due tassonomie diverse

- Nei docx, le aree funzionali L2 sono nomi estesi: `ANAGR_CONTROPARTE`, `ANAGR_COMMERCIALE`, `ANTIFRODE`, `ANTIRICICLAGGIO`, `ASSICURAZIONI`, `BUDGET`, `CONTATTI`, `DIGITAL`, `GESTIONE_CREDITI`, `HR`, `ONBOARDING`, `PRODOTTO`, `PRODOTTO_M`, `PAGAMENTI_CONTABILITA`, `PROVVIGIONI_RAPPEL`, `RISCHI_ADEMPIMENTI`, `SCORE_BANCHE_DATI` — e corrispondono 1:1 alle cartelle in `raw/dwh-code/models/L2/`.
- Nella xlsx (foglio "Nomenclatura SubjectArea Tabell"), le subject area hanno sigle a 3+3 lettere diverse: `ANA_CNT` (Anagrafica Controparte), `PRD_CRT` (Carte), `ADP_SLD` (Saldi), `SDE_ANT` (Antifrode), ecc., con schema risultante tipo `L2_ANA_CNT` — **diverso** dallo schema realmente usato nel codice (es. `L2_ANAGR_CONTROPARTE` per cartella `ANAGR_CONTROPARTE`, quando il `query_tag` è popolato correttamente).

Sembrano due tassonomie di naming per lo stesso concetto, non riconciliate. Vedi [[inconsistenze-doc-vs-codice]].

## Collegamenti

- [[layer-l2-xlsx-reference]]
- [[caricamento-layer-l2]], [[guida-sviluppo]]
- [[cancellazioni-fl-deleted]]
- [[progressivo-pk-e-progressivo-controparte]]
- [[inconsistenze-doc-vs-codice]]
