---
title: Storicizzazione L2 (S1-S4)
type: concept
tags: [layer/L2, storicizzazione]
updated: 2026-07-08
---

Tipologie di storicizzazione per [[layer-l2]], mappate su materializzazioni DBT. Regole di dettaglio derivate da `Agos X - Linee_Guida_Layer_L2_Storicizzazione_20260304.pptx` (non ancora presente in `raw/` — fonte primaria non ingerita) più il dettaglio implementativo della [[guida-sviluppo]].

| Tipo | Materializzazione | Unique key | Campi tecnici |
|---|---|---|---|
| **S1** (SCD2) | incremental / merge | PK funzionale + `TS_INIZIO_VALIDITA` | `TS_INIZIO_VALIDITA`, `TS_FINE_VALIDITA`, `LASTMODIFIEDDATA` |
| **S2** (append giornaliero) | incremental / append | — | `TS_INSERIMENTO`, `LASTMODIFIEDDATA` |
| **S3** (append mensile) | incremental / append | — | `DT_OSSERVAZIONE`, `LASTMODIFIEDDATA` |
| **S4** (attualizzati) | incremental / insert_overwrite | — | — |

Regola generale: campi di storicizzazione subito dopo la PK funzionale; `LASTMODIFIEDDATA` (se presente) sempre in coda a tutte le colonne.

## S1 — SCD2

Due sottocasi:
- Main L1 già SCD2 (Cluster C): `TS_INIZIO_VALIDITA`/`TS_FINE_VALIDITA` ereditati direttamente dalla sorgente.
- Main L1 non storicizzata: `TS_INIZIO_VALIDITA` derivato dal campo timestamp funzionale (analisi tecnica), `TS_FINE_VALIDITA` calcolato a partire da esso.

SQL a 3 blocchi: CTE base (dataset + validità) → CTE dedup (colonne + hash colonne di business, esclusi `LASTMODIFIEDDATA`/validità, + logica incrementale) → SELECT finale (ricalcolo `TS_FINE_VALIDITA`, LEFT JOIN ai lookup). Il modello accorpa intervalli di validità consecutivi senza variazioni nei campi di business, evitando proliferazione di versioni ridondanti. Bonifiche a record passati sempre via **nuovo record**, mai update di intervalli vecchi.

### Variante: main L1 senza PK propria (PK = ROWID)

Quando la tabella main L1 non ha una chiave funzionale univoca (solo `ROWID` tecnico), a parità di chiave + `TS_INIZIO_VALIDITA` possono esserci più record fisici duplicati. Pattern reale in `models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql` (`raw/dwh-code`): si introduce un campo tecnico `PROGRESSIVO_PK` (`ROW_NUMBER()` su chiave+timestamp modifica, ordinato per `ROWID`), che estende `unique_key`/PK del modello e viene passato come `order_extra` a `is_incremental_S1()`. `TS_FINE_VALIDITA` viene poi propagato con una window function a tutti i record con lo stesso `TS_INIZIO_VALIDITA`. **Aggiunto formalmente alla guida sviluppo il 2026-07-08** (§5.1, subito dopo "S1 — SCD2"). La bozza di lavoro è stata rimossa da `queries/` una volta applicata al documento.

## S2 — Append giornalieri

`TS_INSERIMENTO` valorizzato dal campo timestamp funzionale (se assente: `CURRENT_TIMESTAMP()` + segnalazione WARN, "andrà valorizzato"). Blocco incrementale filtra su `LASTMODIFIEDDATA > MAX(LASTMODIFIEDDATA)` esistente.

## S3 — Append mensili

`DT_OSSERVAZIONE` dal campo data funzionale. Ad ogni run il **mese corrente viene cancellato e ricaricato interamente** (idempotenza), via `pre_hook: delete_month()`. Nessuna gestione cancellazioni per questo tipo. Supporta esecuzione per mese specifico via `--vars '{"dt_osservazione": "..."}'`.

## S4 — Attualizzati

Full overwrite ad ogni run, `incremental_strategy: insert_overwrite`.

## Macro di conversione dtype L1→L2

| Macro | Uso |
|---|---|
| `custom_to_timestamp_ntz(data, ora)` | → `TIMESTAMP_NTZ` |
| `custom_to_date(data)` | → `DATE` |
| `custom_to_time(ora)` | → `TIME` |
| `custom_to_decimal(col, precision, decimal)` | Importi: divide per 10^decimal. OCS sempre `decimal=2` |
| `ole_to_timestamp(data, ora=none)` | Data OLE (+ ora opz.) → `TIMESTAMP` |
| `timestamp_to_ole(col)` | → `ole_date` (INTEGER) + `ole_time` (HHMMSS) |
| `ole_to_date(col)` / `date_to_ole(col)` | conversioni OLE ↔ `DATE` |

No-OCS: verificare se serve dividere per 100.0, altrimenti cast diretto a `NUMBER(x,2)` (replicare anche nello yml).

## Vedi anche

[[storicizzazione-l1-cluster]] (L1), [[storicizzazione-l3-s5]] (L3, incluso S5 non presente qui).

## Collegato da
[[layer-l2]], [[agosx-caricamento-l2]], [[guida-sviluppo]]
