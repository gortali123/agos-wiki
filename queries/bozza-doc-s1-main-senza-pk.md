---
title: Bozza doc — S1 con tabella main L1 priva di PK (PK = ROWID) [APPLICATA]
type: query
tags: [layer/L2, storicizzazione, guida-sviluppo]
updated: 2026-07-08
---

**Stato: applicata.** Questo blocco è stato incollato dall'utente in [[guida-sviluppo]] §5.1 (subito dopo "S1 — SCD2") il 2026-07-08 — verificato per intero contro il testo reale del documento, nessuna discrepanza. Pagina mantenuta come riferimento storico del testo esatto proposto/inserito. Vedi [[storicizzazione-l2-s1-s4]] per la sintesi wiki aggiornata.

Generalizza il pattern usato in `models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql` (`raw/dwh-code`), **al netto della parte `PROGRESSIVO_CONTROPARTE`** che è specifica solo di quell'entità.

---

## S1 — Variante: tabella main L1 senza PK propria (PK = ROWID)

**Quando si applica**: la tabella main L1 dell'entità non ha una chiave primaria funzionale univoca — l'unica PK certa è il campo tecnico `ROWID` valorizzato in fase di caricamento. Questo significa che, a parità di chiave funzionale (es. `CD_CONTROPARTE`) **e** di timestamp di modifica (`TS_INIZIO_VALIDITA`), possono esistere più record fisici distinti in L1 (duplicati non discriminabili dalla sola chiave + timestamp).

Il pattern standard S1 ([[storicizzazione-l2-s1-s4]]) assume `unique_key = [<PK_funzionale>, TS_INIZIO_VALIDITA]`. Se la main non garantisce questa unicità, il merge fallirebbe o produrrebbe risultati indeterministici. Serve quindi introdurre un **campo tecnico di disambiguazione**, `PROGRESSIVO_PK`.

### Modifiche rispetto al pattern S1 standard

**1. CTE base — calcolo di `PROGRESSIVO_PK`**

Si aggiunge un progressivo che disambigua i record a parità di chiave funzionale e timestamp di modifica, ordinando in modo deterministico sul `ROWID` di L1:

```sql
ROW_NUMBER() OVER (
    PARTITION BY <chiave_funzionale>, <campo_data_modifica>, <campo_ora_modifica>
    ORDER BY <ROWID_L1>
)::NUMBER(38, 0) AS PROGRESSIVO_PK
```

**2. Unique key / PK del modello**

`unique_key` e il `constraints.primary_key` nel file yml si estendono con `PROGRESSIVO_PK`:

```yaml
config:
  materialized: incremental
  incremental_strategy: merge
  unique_key: [<PK_funzionale>, TS_INIZIO_VALIDITA, PROGRESSIVO_PK]
constraints:
  - type: primary_key
    warn_unenforced: false
    columns: [<PK_funzionale>, TS_INIZIO_VALIDITA, PROGRESSIVO_PK]
```

**3. CTE dedup — dedup S1 con tie-breaker su `PROGRESSIVO_PK`**

La macro `is_incremental_S1()` va richiamata passando `PROGRESSIVO_PK` come `order_extra`, in modo che il confronto incrementale (`LAG(HASHED_COLS)`) sia ordinato in modo stabile anche tra record con lo stesso `TS_INIZIO_VALIDITA`:

```sql
FROM base
{{ is_incremental_S1('<PK_funzionale>', order_extra='PROGRESSIVO_PK') }}
```

**4. SELECT finale — chiusura della finestra di validità**

`TS_FINE_VALIDITA` va ricalcolato con `ts_fine_validita()` sulla sola chiave + `TS_INIZIO_VALIDITA` (non su `PROGRESSIVO_PK`), e poi propagato con una window function a **tutti** i record che condividono lo stesso `TS_INIZIO_VALIDITA`, così che la finestra si chiuda al prossimo `TS_INIZIO_VALIDITA` distinto e non tra record duplicati dello stesso istante:

```sql
DEDUP_FV AS (
    SELECT
        *,
        {{ ts_fine_validita('<PK_funzionale>', 'TS_INIZIO_VALIDITA') }} AS TS_FV_NEXT
    FROM DEDUP
)

SELECT
    H.<PK_funzionale>,
    H.TS_INIZIO_VALIDITA,
    MAX(H.TS_FV_NEXT) OVER (
        PARTITION BY H.<PK_funzionale>, H.TS_INIZIO_VALIDITA
    ) AS TS_FINE_VALIDITA,
    H.PROGRESSIVO_PK,
    -- ... resto dei campi
FROM DEDUP_FV AS H
```

### Nota

Questa variante non cambia nient'altro del pattern S1: pre-hook cancellazioni (`delete_l2`), macro di conversione dtype, e logica di lookup/join restano invariati. Il campo `PROGRESSIVO_PK` è puramente tecnico e non fa parte della chiave funzionale di business — serve solo a rendere deterministico il merge quando la sorgente L1 non garantisce unicità naturale.

Un ulteriore campo progressivo specifico dell'entità (`PROGRESSIVO_CONTROPARTE`, usato solo in `VARIAZIONI_ANAGRAFICHE` per numerare le versioni di una controparte) **non fa parte di questo pattern generale** e va documentato separatamente, solo per quell'entità.

---

## Collegato da
[[guida-sviluppo]], [[storicizzazione-l2-s1-s4]], [[incoerenze-codice-vs-documentazione]]
