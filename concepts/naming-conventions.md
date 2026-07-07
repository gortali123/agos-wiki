---
title: Naming convention Snowflake/DBT
type: concept
tags: [naming, glossary]
updated: 2026-07-07
---

Convenzioni di naming per oggetti Snowflake e file DBT nel progetto AGOS-X, come da [[agosx-caricamento-l2]] (fonte principale) e [[agosx-caricamento-l0-l1]].

## Schemi

- `L2_<area_funzionale>` — 16 aree funzionali definite nel documento ufficiale: ANAGR_CONTROPARTE, ANAGR_COMMERCIALE, ANTIFRODE, ANTIRICICLAGGIO, ASSICURAZIONI, BUDGET, CONTATTI, DIGITAL, GESTIONE_CREDITI, HR, ONBOARDING, PRODOTTO, PRODOTTO_M, PAGAMENTI_CONTABILITA, PROVVIGIONI_RAPPEL, RISCHI_ADEMPIMENTI, SCORE_BANCHE_DATI.
- `L3_<processo>`.
- L0/L1: schema per modulo (OCS) o sorgente.

**Attenzione — tre tassonomie diverse coesistono per le aree L2**, non ancora riconciliate:
1. L'elenco sopra, dal documento ufficiale L2.
2. I nomi cartella reali in `dbt_project.yml` ([[incoerenze-codice-vs-documentazione]] punto 4): `ANAGR_CONTROPARTE`, `ANTIFRODE`, `ASSICURAZIONI`, `CARTE`, `ONBOARDING`, `PRODOTTO`, `PRODOTTO_M`, `RISCHI_ADEMPIMENTI`, `SALDI`, `SWORD`, `GESTIONE_CREDITI`.
3. I codici Subject Area nel foglio `Nomenclatura SubjectArea Tabell[e]` del data model L2 ([[agosx-layer-l2-datamodel]]): `ANA_CNT`, `ANA_COM`, `HR`, `CNT_VOC`, `CNT`, `DGT_ARI`, `DGT_FRP`, `DGT_TRC`, `GNS_PRV`, `GNS_RCV`, `PRD_CQS`, `PRD_PGM`, `PRD_ASS`, `PRD_CNS`, ecc.

Da chiarire con l'utente quale sia la tassonomia corrente/di riferimento.

## Tabelle

- L2: `<nome>_<frequenza>`
- L3: `<tipo_oggetto>_<nome_tabella>_<frequenza>`
- Frequenza: `_W` settimanale, `_M` mensile, `_T` trimestrale, `_Q` quadrimestrale, `_S` semestrale, `_Y` annuale, `_O` on demand; nessun suffisso per giornaliere.

## Tipo oggetto (prefisso)

| Prefisso | Oggetto |
|---|---|
| `V_` | Vista |
| `VM_` | Vista materializzata |
| `DM_` | Datamart |
| `FL_OUT_` | Flusso di output |
| `PRC_` | Tabella di processo |
| `FN_` | Function |
| `PR_` | Stored procedure |

## Prefisso campo

| Prefisso | Significato |
|---|---|
| `CD_` | Codice |
| `ID_` | Identificativo |
| `DS_` | Descrizione |
| `NM_` | Misure, KPI |
| `DT_` | Data |
| `TS_` | Timestamp |
| `FL_` | Flag |
| `TP_` | Tipo |
| `EU_` | Importo in euro |
| `PC_` | Percentuale |
| `SK_` | Smart key |
| `GN_` | Prefisso generico |

## File DBT

- Configurazione: `<nome_tabella>.yml`
- Modello: `<nome_tabella>.sql` o `stg_<nome_tabella>.sql` (ephemeral)
- Snapshot: `<nome_tabella>.sql`
- Source L0: `<nome_tabella>_source.yml`

## Alberatura progetto

Progetto DBT unico per tutti i layer (`AGOSX/models/L0|L1|L2|L3/...`), primo livello = layer, secondo livello = sorgente (L0/L1) o area funzionale/processo (L2/L3). Possibile evoluzione futura verso split multi-progetto con **dbt mesh** (menzionato come opzione, non ancora deciso).

## Collegato da
[[layer-l2]], [[layer-l3]], [[agosx-caricamento-l2]], [[agosx-caricamento-l0-l1]], [[agosx-layer-l2-datamodel]]
