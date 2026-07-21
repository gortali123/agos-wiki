---
name: develop-l2
description: Genera SQL dbt e YML delle entita' L2 da un data model Excel. Usare quando l'utente chiede di generare/scrivere il modello dbt di un'entita' L2 (es. "genera il modello per ANAGRAFICA_CONTROPARTE", "genera SQL L2 di ...").
---

# DEVELOP L2 — code generator

Genera SQL dbt e YML del layer L2 da un data model Excel **caricato
dall'utente o presente nel progetto corrente**.

## Principi fondamentali

La REGOLA TECNICA e' la specifica autoritativa. Non interpretare, non semplificare, non ristrutturare.

- **Trascrivi** la regola tecnica esattamente come scritta - CTE se CTE, subquery se subquery
- **Puoi correggere** solo typo ovvi e sintassi SQL palese. Documenta sempre: `-- FIX: data model had '<originale>'`
- **Non puoi** semplificare/accorpare logica, aggiungere/rimuovere filtri o JOIN, cambiare struttura
- **Segnala senza correggere** regole ambigue, tabelle/colonne dubbie: `-- WARN: <CAMPO> - <motivo>`
- **Piu' entita'** -> genera una per volta, sequenziale

## Workflow

Output per entita': `{subject_area_upper}/{entity_lower}.sql` e `.yml`.

0. I file output esistono gia' (generati in sessione o modelli esistenti indicati dall'utente)? -> chiedi conferma sovrascrittura; se non confermata, stop.
1. Leggi il data model via dm-reader (Step 1): dal **catalog** subject area, storicizzazione (S1/S2/S3/S4), sorgenti L1 + cluster; dallo **sheet** campi, PK, tipi, TAB/COL/RT per procedura.
2. Genera SQL (Step 2) e YML (Step 3) direttamente, una riga di riepilogo per entita'.
3. A fine generazione presenta i file.

## Step 1: lettura del data model (skill dm-reader)

La lettura e' delegata alla skill **`dm-reader`**, fonte autoritativa per
ricerca del file, comandi e formato output: leggi prima
`.claude/skills/dm-reader/SKILL.md`. Lo script si esegue **in place** (non
scrive nulla), niente cache: l'Excel viene letto a ogni esecuzione.
Auto-rileva l'Excel piu' recente in `raw/` (o usa `--file` per un file
specifico se in `raw/` convivono piu' data model).

Fallback - in entrambi i casi fermati, non inventare contenuti:

- **Nessun Excel trovato** in `raw/` -> chiedi all'utente di aggiungere il data model li'.
- **dm-reader non disponibile** -> segnala che questa skill richiede `dm-reader`. Non riscrivere il parser a mano.

```bash
# Catalogo: tutte le entita', per subject area, o singola entita'
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py catalog [SUBJECT_AREA [ENTITA]]

# Foglio entita': campi, PK, tipi, TAB/COL/RT per procedura
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py sheet NOME_ENTITA
```

(`sheets` lista i fogli, utile per il nome esatto dell'entita'.)

Lo **sheet** restituisce una riga per campo per procedura (campo con 2 procedure -> 2 righe con stesso CAMPO):

| CAMPO | PK | TIPO | PROC | TAB | COL | RT | CHIAVI |
|---|---|---|---|---|---|---|---|

- **TAB** = sorgente tabella (es. `CCANAGR`), **COL** = sorgente campo nella tabella (es. `AC_CODICE`), **RT** = regola tecnica (espressione SQL completa, se presente), **CHIAVI** = chiavi di aggancio (in genere vuote in L2, usate soprattutto in L3)

Per i dettagli su come viene interpretato l'Excel, fa fede la SKILL.md di dm-reader.

## Step 2: genera SQL

### Priorita' per ogni campo

1. **RT presente** -> trascrivi esattamente (CTE se CTE, subquery se subquery)
2. **TAB + COL presenti, senza RT** -> `alias.<col> AS NOME_CAMPO`
3. **TAB e COL vuoti, senza RT** -> `NULL AS NOME_CAMPO`

### Integrare regole tecniche complesse

Se la RT contiene una CTE (WITH) o richiede JOIN aggiuntivi, **valuta se ha senso**:

- **CTE riusata in piu' campi, o complessa e migliora leggibilita'?** -> nel blocco CTE principale (prima del SELECT finale). Ricicla il nome originale se c'e', altrimenti inventane uno descrittivo.
- **CTE usata una sola volta e semplice?** -> estrai il CASE/espressione e mettila inline nel SELECT. Non farla come CTE se non serve.
- **Solo CASE/espressione SQL** -> direttamente nel SELECT come colonna calcolata.
- **JOIN** -> aggiungi al SELECT principale (LEFT JOIN per lookup, INNER JOIN se la logica lo richiede).
- **WHERE clause** -> integra nel WHERE finale (con `AND` se ci sono gia' filtri).

Regole speciali (si applicano anche quando la sorgente e' diretta):

- **Campi EU_** -> `{{ custom_to_decimal('alias.<col>', x, 2) }} AS EU_xxx` - macro parametrica `custom_to_decimal(column, precision, decimal)` che divide per `10^decimal` e casta a `NUMBER(precision, decimal)`; per L2 la convenzione e' sempre `decimal=2`, `x` e' la precisione totale dal data model
- **Campi DT_** -> `{{ custom_to_date('alias.<col>') }} AS DT_xxx`
- **Campi TS_** -> `{{ custom_to_timestamp_ntz('alias.<col_data>', 'alias.<col_ora>') }} AS TS_xxx` (se due colonne data/ora); `{{ custom_to_timestamp_ntz('alias.<col>') }} AS TS_xxx` (se una sola); escluso LASTMODIFIEDDATA
- Tabelle: `{{ ref('tabella_lower') }}`
- Literal timestamp -> `TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')`
- Doppio underscore: `AS X__Y` -> `AS X_Y`
- **Multiprocedure (P > 1):** un SELECT per procedura uniti con `UNION ALL`. Campi assenti in una procedura -> `NULL AS NOME_CAMPO`

### Campi tecnici - regola assoluta

- **LASTMODIFIEDDATA**: sempre da sorgente principale (`T.LASTMODIFIEDDATA AS LASTMODIFIEDDATA`), sempre ULTIMO campo nel SELECT - nessun campo dopo
- **Ordine campi nel SELECT (non negoziabile):**
  1. Campi PK
  2. TS_INIZIO_VALIDITA, TS_FINE_VALIDITA, TS_INSERIMENTO, DT_OSSERVAZIONE (se presenti, in quest'ordine)
  3. Altri campi business
  4. LASTMODIFIEDDATA (sempre ultimo)
- Mai `CURRENT_TIMESTAMP()`, mai `T.data_modifica`

### Storicizzazione

**S1** (incremental/merge):

**Tutta la logica business** (pre-aggregazioni, filtri, join intermedi, ecc.) va in CTE prima di `base`, o dentro `base` stessa. Da `base` in poi e' meccanica di storicizzazione.

**Step fissi di storicizzazione:**

1. CTE `base`: produce il dataset completo (da sorgente main, left join successivamente) gia' mappato con alias. Contiene TS_INIZIO_VALIDITA e TS_FINE_VALIDITA (vedi casi cluster C vs non-C sotto).
2. CTE `dedup`: elenca esplicitamente tutte le colonne di `base` piu' `{{ hash_cols([...]) }} AS HASHED_COLS`, poi `FROM base {{ is_incremental_S1('PK') }}`. `hash_cols` riceve tutti i campi di `base` esclusi `TS_INIZIO_VALIDITA`, `TS_FINE_VALIDITA` e `LASTMODIFIEDDATA`. `is_incremental_S1` usa quell'hash per filtrare le sole righe nuove/cambiate nei run incrementali.
3. SELECT finale da `dedup`: elenca tutte le colonne esplicitamente. Ricalcola TS_FINE_VALIDITA con `{{ ts_fine_validita('PK_alias', 'H.TS_INIZIO_VALIDITA') }}`. I LEFT JOIN ai lookup di decodifica stanno qui, dopo il dedup.

**Differenza C vs non-C - solo nel contenuto della CTE `base`:**

- **Cluster C** (TS gia' in L1): porta TS_INIZIO_VALIDITA e TS_FINE_VALIDITA direttamente dalla sorgente.
- **Cluster non-C** (SCD2 costruito in L2): TS_INIZIO_VALIDITA calcolato con `{{ custom_to_timestamp_ntz() }}`, TS_FINE_VALIDITA calcolato con `{{ ts_fine_validita(pk_source_expr, ts_inizio_expr) }}`.

**S2/S3/S4 - niente CTE `base`**: SELECT diretto dalla sorgente, con eventuali LEFT JOIN inline. In piu', per ciascuna:

**S2** (incremental/append):

- TS_INSERIMENTO e' campo tecnico di storicizzazione: va in PK nel YML. Valorizzazione dal data model; se assente -> `CURRENT_TIMESTAMP()` con warning
- Blocco incremental nel WHERE:
```sql
{% if is_incremental() %}
WHERE LASTMODIFIEDDATA > (SELECT COALESCE(MAX(LASTMODIFIEDDATA),'1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
{% endif %}
```

**S3** (incremental/append) - nessun LASTMODIFIEDDATA:

- DT_OSSERVAZIONE e' campo tecnico: va in PK nel YML
- Pre-hook nel YML: `pre_hook: "{{ delete_month() }}"`
- Blocco incremental nel WHERE:
```sql
{% if is_incremental() %}
WHERE DT_OSSERVAZIONE = {{ get_dt_osservazione() }}
{% endif %}
```

**S4** (incremental/insert_overwrite) - nessun blocco incremental, nessun LASTMODIFIEDDATA.

### Regole SQL

- Solo query, mai `{{ config(...) }}`
- Mai `BETWEEN` -> usa `>= AND <`
- Virgola sempre a fine riga, mai a inizio
- Alias corti, no parole riservate SQL
- **Non usare SELECT \*** - elencare sempre tutte le colonne esplicitamente
- **Nessun padding prima di `AS`**: `alias.COLONNA AS NOME_CAMPO`

#### Placeholder OCS (varchar vuoti ' ')

Le sorgenti OCS non prevedono NULL sui campi varchar: un valore "bianco" arriva gia' da L1 come placeholder a singolo spazio `' '` (normalizzato canonicamente in L1). Quando la RT o il mapping diretto testano un campo OCS varchar:

- **IS NULL / IS NOT NULL** su campo OCS -> usa `{{ custom_is_null('alias.<col>') }}` / `{{ custom_is_not_null('alias.<col>') }}` (coprono sia NULL vero sia `' '`), non il solo `IS NULL`.
- **COALESCE** con un campo OCS come primo input -> aggiungi `NULLIF(alias.<col>, ' ')` prima del COALESCE, cosi' il placeholder non "vince" sul fallback.
- **Eccezione nota**: `BACCPTES` dove `' '` ha significato applicativo proprio ("Poste Italiane") - non applicare la macro li'.
- In caso di dubbio se un campo e' OCS o la provenienza non e' chiara, segnala `-- WARN` invece di applicare la macro alla cieca.

#### Cluster FL_DELETED (cancellazioni logiche)

Le tabelle L1 dei cluster **A1, A2, C** (solo questi) hanno FL_DELETED; B1 e altri cluster no. Per le tabelle A1/A2/C:

- **Main table**: aggiungere `AND FL_DELETED = 'N'` nel WHERE
- **LEFT JOIN lookup**: aggiungere `AND T.FL_DELETED = 'N'` nel JOIN ON
- **Cluster B1 e altri**: niente filtro FL_DELETED

## Step 3: genera YML

```yaml
version: 2
models:
  - name: {entity_lower}
    config:
      materialized: {materialization}
      incremental_strategy: {strategy}
      unique_key: [COL1, COL2]          # solo S1
      query_tag: '{"app": "DBT", "schema": "L2_<AREA_FUNZIONALE>", "entita": "<ENTITY_NAME>"}'
      pre_hook:
        - "{{ delete_l2('{source_name}', ['PK1', 'PK2'], ['SRC_PK1', 'SRC_PK2']) }}"
    constraints:
      - type: primary_key
        warn_unenforced: false
        columns: [COL1, COL2]
    columns:
      - name: NOME_CAMPO
        data_type: TIPO
```

**Pre-hook delete_l2**: obbligatorio SOLO se la tabella main e' un cluster FL_DELETED (C o A1/A2, vedi Step 2). Escluso modelli che leggono da altre L2/L3 o dove la main e' cluster B1. Per S3 il pre-hook non e' `delete_l2` ma `delete_month()` (vedi Storicizzazione); per S4 nessun pre-hook.

**Primary key:** colonne con FLAG_PK, piu' il campo tecnico di storicizzazione: S1 -> TS_INIZIO_VALIDITA, S2 -> TS_INSERIMENTO, S3 -> DT_OSSERVAZIONE.

**Unique key:** SOLO S1, = primary key (vedi tabella).

**Data types:** FORMATO -> tecnici (LASTMODIFIEDDATA/TS_*->TIMESTAMP_NTZ, DT_OSSERVAZIONE->DATE) -> fallback naming (FL_*->VARCHAR(1), DT_*->DATE, EU_*/NM_*->NUMBER, DS_*/CD_*->VARCHAR)

**Campi EU_:** data type DEVE essere `NUMBER(x,2)`. Se il datamodel dice `NUMBER(13,0)` -> metti `NUMBER(13,2)`

**query_tag:** obbligatorio in tutti i modelli generati (S1-S4), a prescindere da eventuali modelli esistenti che non lo hanno.

| S | materialized | incremental_strategy | unique_key | pre_hook | query_tag |
|---|---|---|---|---|---|
| S1 | incremental | merge | si' = PK + TS_INIZIO_VALIDITA | `delete_l2(...)` se FL_DELETED | si' |
| S2 | incremental | append | no | `delete_l2(...)` se FL_DELETED | si' |
| S3 | incremental | append | no | `delete_month()` | si' |
| S4 | incremental | insert_overwrite | no | nessuno | si' |
