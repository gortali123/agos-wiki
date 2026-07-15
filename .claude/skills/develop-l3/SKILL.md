---
name: develop-l3
description: Genera SQL dbt e YML dei DataMart L3 da un data model Excel. Usare quando l'utente chiede di generare/scrivere il modello dbt di un DataMart L3 (es. "genera il modello per DM_X", "scrivi l'L3 di ...").
---

# DEVELOP L3 — code generator

Genera SQL dbt e YML dei DataMart L3 da un data model Excel **caricato
dall'utente o presente nel progetto corrente**. Un DataMart combina N tabelle
sorgenti (mix di L1 e L2) in un'unica tabella L3, tipicamente con molti campi
calcolati a formule complesse (correlation, capital requirement, RWA, UDF) e
una struttura multi-CTE. Per L3 si usano le storicizzazioni S2, S3, S4
(nomenclatura allineata con L2).

## Principi fondamentali

La REGOLA TECNICA e' la specifica autoritativa. Non interpretare, non
semplificare la logica, non inventare.

- **Trascrivi** la logica della regola tecnica fedelmente: stessi CASE, stesse
  formule, stessi filtri e JOIN
- **Puoi correggere** solo typo ovvi e sintassi SQL palese (es. `AS AS`, alias
  duplicati tipo `PVKCO_PVKCO_`, colonne con nome storpiato rispetto al resto
  del foglio, `**` non supportato da Snowflake → `POWER(base, esp)`).
  Documenta sempre: `-- FIX: data model had '<originale>'`
- **Devi consolidare la struttura**: in L3 ogni campo calcolato ha una RT
  scritta come query standalone e le RT di campi diversi ripetono le stesse
  CTE/subquery (es. `CTE_MA`, calcolo `CORR_CALC`). Nel modello finale ogni
  blocco comune va scritto **una sola volta** come CTE condivisa; le
  espressioni dei singoli campi restano fedeli all'originale. Questo
  consolidamento e' l'unico rimaneggiamento strutturale permesso.
- **Segnala senza correggere** regole ambigue, tabelle/colonne dubbie:
  `-- WARN: <CAMPO> - <motivo>`
- **Piu' DataMart** -> genera uno per volta, sequenziale

## Workflow

Output per DM: `{dm_lower}.sql` e `.yml`.

0. I file output esistono gia' (generati in sessione o modelli esistenti
   indicati dall'utente)? -> chiedi conferma sovrascrittura; se non
   confermata, stop.
1. Leggi il data model via **dm-reader** (Step 1 sotto): dal **catalog**
   entita' main, sorgenti L1 e L2 in input, regola tecnica perimetro,
   frequenza; dallo **sheet** campi, PK, tipi, TAB/COL/RT/CHIAVI.
2. Genera SQL (Step 2) e YML (Step 3) direttamente, una riga di riepilogo
   per DM.
3. A fine generazione presenta i file.

## Step 1: lettura del data model (skill dm-reader)

La lettura e' delegata alla skill **`dm-reader`** (formato L3 auto-rilevato),
fonte autoritativa per ricerca del file, comandi e formato output: leggi
prima `.claude/skills/dm-reader/SKILL.md`. Lo script si esegue **in place**,
senza copie, e auto-rileva l'Excel L3 piu' recente in `raw/` (o usa
`--file` per un file specifico).

Fallback - in tutti i casi fermati, non inventare contenuti:

- **Nessun Excel trovato** in `raw/` -> chiedi all'utente di aggiungere il
  data model L3 li'.
- **Il file piu' recente e' il data model L2** (il catalog esce in formato
  L2) -> passa `--file` al file L3 corretto, o chiedi all'utente di
  confermare quale file usare.
- **dm-reader non disponibile o non supporta il catalogo L3** -> segnalalo
  all'utente. Non riscrivere il parser a mano.

```bash
# Catalogo DataMart (formato L3 auto-rilevato)
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py catalog [X NOME_DM]

# Foglio del DataMart: campi, PK, tipi, TAB/COL/RT/CHIAVI
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py sheet NOME_DM
```

(`sheets` lista i fogli, utile per il nome esatto.)

Dal **catalog L3** ricavi per il DM:

```
NOME_DM | DM_ID | SOTTO_PROCESSO | MAIN: ... | L1: ... | L2: ... | FREQ: ... | PROFONDITA: ... | PERIMETRO: <SQL>
```

- `MAIN` = entita' principale (la FROM di base del modello)
- `L1` / `L2` = sorgenti in input per layer: ti dice da che layer arriva ogni
  tabella (serve per decidere se applicare le macro di conversione, vedi sotto)
- `PERIMETRO` = la Regola Tecnica Perimetro: definisce FROM + filtro di base
  del modello (es. `SELECT * FROM IFBLFPVKCO`)

Dallo **sheet** una riga per campo:

```
CAMPO | PK | TIPO | PROC | TAB | COL | RT | CHIAVI
```

- **TAB/COL** possono elencare piu' sorgenti con prefisso layer, separate da
  ` ; ` (es. `[L1] IFBLFPVKCO ; [L2] MANUAL_ADJUSTMENT_O`). Una COL senza
  prefisso che coincide col nome di un altro CAMPO del DM e' una dipendenza da
  campo calcolato, non una colonna sorgente.
- **RT** = regola tecnica (query standalone da integrare nel modello)
- **CHIAVI** = chiavi di aggancio: snippet FROM/JOIN che dice come agganciare
  le sorgenti non-main (es. `FROM IFBLFPVKCO AS CC LEFT JOIN PRATICA_M AS PM
  ON ...`). Usale come specifica dei JOIN.

## Step 2: genera SQL

### Priorita' per ogni campo

1. **RT presente** -> integra la logica nel modello (vedi consolidamento CTE)
2. **TAB + COL presenti, senza RT** -> `alias.<col> AS NOME_CAMPO`
3. **TAB e COL vuoti, senza RT** -> `NULL AS NOME_CAMPO` con `-- WARN`

### Struttura del modello (multi-CTE)

Ordine consigliato delle CTE:

1. **CTE perimetro/base** (es. `base`): la FROM deriva dalla Regola Tecnica
   Perimetro sull'entita' main, piu' il filtro incremental della classe di
   storicizzazione (vedi Storicizzazione). Tutte le colonne main usate a
   valle passano da qui.
2. **CTE di lookup/adjustment** (es. `cte_ma`): le RT che selezionano un valore
   scalare di servizio (es. `SELECT NM_MANUAL_ADJ FROM MANUAL_ADJUSTMENT_O
   WHERE ... LIMIT 1`) diventano una CTE a riga singola agganciata con
   **CROSS JOIN** nel SELECT che la usa. Sostituisci le scalar subquery
   ripetute `(SELECT X FROM CTE_MA)` con `MA.X` dal CROSS JOIN.
3. **CTE di calcolo intermedie**: i campi calcolati che dipendono da altri
   campi calcolati (es. correlation -> capital requirement -> RWA;
   anzianita' -> classificazione anzianita' -> status default) si
   costruiscono in catena: ogni livello e' una CTE che arricchisce la
   precedente. I blocchi identici ripetuti in piu' RT (es. il calcolo di
   `CORR_CALC`) compaiono una sola volta.
4. **JOIN alle sorgenti non-main**: come da colonna CHIAVI (tipicamente LEFT
   JOIN su L2 tipo `PRATICA_M`; rispetta le chiavi di aggancio indicate).
5. **SELECT finale**: tutti i campi del DM, nell'ordine del data model, mai
   `SELECT *` nel SELECT finale.

Se una RT marca un campo intermedio non presente nel data model (es.
`CORR_CALC` usato solo per il capital requirement ma esposto anche come campo
`EU_CORRELATION`), esponi il campo se e solo se esiste nel data model.

### Sorgenti: sempre ref()

**Tutte le tabelle sorgenti, sia L1 sia L2, si referenziano con
`{{ ref('tabella_lower') }}`** (es. `{{ ref('ifblfpvkco') }}`,
`{{ ref('manual_adjustment_o') }}`, `{{ ref('pratica_m') }}`). Mai `source()`,
mai schemi hard-coded.

### Macro di conversione: solo su sorgenti L1

Le macro valgono **solo quando la colonna sorgente arriva da una tabella L1**
(layer indicato dal catalogo e/o dal prefisso `[L1]` nello sheet). Se la
sorgente e' L2 (o un altro DM L3) il dato e' gia' convertito: mappa diretto.

Su **mapping diretti** (senza RT) da sorgente L1:
- **Campi EU_** -> `{{ custom_to_decimal('alias.<col>', x, y) }}` dove `x,y`
  sono precisione e scala dal data model (la scala NON si forza a 2: usa
  quella del FORMATO/DECIMAL, es. `NUMBER(13,11)` resta `13,11`)
- **Campi DT_** -> `{{ custom_to_date('alias.<col>') }}`
- **Campi TS_** -> `{{ custom_to_timestamp_ntz('alias.<col_data>', 'alias.<col_ora>') }}`
  (se due colonne data/ora); `{{ custom_to_timestamp_ntz('alias.<col>') }}`
  (se una sola)

Nelle **RT** invece le colonne sorgente si usano come scritte nella regola
(trascrivi, niente macro dentro le formule). Se la stessa colonna importo L1
e' usata sia in un mapping diretto (convertito) sia dentro una formula (raw),
segnala la possibile incoerenza di unita' con `-- WARN`.

### Placeholder temporali nelle RT

Le RT contengono placeholder tipo
`WHERE <col_data> = TO_DATE('AAAA-MM-DD') -- ultima mensilita'`: NON vanno
trascritti letteralmente. Sono il filtro temporale di carico e si traducono
nel blocco incremental del caso di storicizzazione applicabile (vedi sotto,
inclusa la regola "una sola volta nella CTE perimetro/base").

### Storicizzazione

Le storicizzazioni L3 seguono la stessa nomenclatura di L2 (S2, S3, S4).
Determina la classe da catalogo (`FREQ`) e indicazioni dell'utente; in caso
ambiguo chiedi.

In ogni caso il filtro temporale/incremental si applica **una sola volta**
nella CTE perimetro/base — non ripetuto per campo; se il perimetro ha gia' un
WHERE funzionale, combinalo con `AND`.

**S2 - Append giornalieri** (`FREQ = Giornaliera`):
`incremental` + `append` puro, niente pre-hook di delete, niente filtro di
riprocesso: ogni run accoda i record del giorno.

- Campi tecnici (data/timestamp di caricamento, ecc.): DA DEFINIRE. Per ora
  non aggiungere campi tecnici non presenti nel data model; se il data model
  ne prevede, mappali e segnala `-- WARN` se la valorizzazione e' ambigua.

**S3 - Append mensili** (`FREQ = Mensile`):
`incremental` + `append` con riprocesso dell'ultima mensilita' — foto di fine
mese estratta dagli intervalli di validita' SCD2 della main.

- Il campo data di partizione mensile e' il campo `DT_` in PK del DM
  (es. `DT_ESTRAZIONE`), valorizzato `{{ get_dt_osservazione() }}`.
  Se non c'e' un `DT_` in PK -> `-- WARN` e chiedi.
- Pre-hook nel YML: `pre_hook: "{{ delete_month('<DT_PARTIZIONE>') }}"`
  (come in develop-l2, caso S3).
- Blocco incremental nel WHERE della CTE perimetro/base dipende dalla main L2:

  - **Se main L2 ha S3** (DT_OSSERVAZIONE): filtra sulla data di osservazione
    del mese precedente:
  ```sql
  {% if is_incremental() %}
  WHERE DT_OSSERVAZIONE = {{ get_dt_osservazione() }}
  {% endif %}
  ```

  - **Se main L2 ha S1** (TS_INIZIO_VALIDITA/TS_FINE_VALIDITA): seleziona il 
    record il cui intervallo copre il mese di interesse:
  ```sql
  {% if is_incremental() %}
  WHERE TS_INIZIO_VALIDITA <= {{ get_dt_osservazione() }}
    AND TS_FINE_VALIDITA > {{ get_dt_osservazione() }}
  {% endif %}
  ```

  (Verso/inclusivita' delle disuguaglianze da confermare caso per caso sul
  data model; in dubbio `-- WARN`.)
- **Main senza timestamp/data funzionale**: comportamento DA DEFINIRE. 
  Genera comunque il modello, lascia il blocco incremental con 
  `-- TODO: main senza campi temporali, filtro mensile da definire` 
  e segnalalo all'utente.

**S4 - Insert_overwrite attualizzati**:
`incremental` + `insert_overwrite`, niente pre-hook. Solo se esplicitamente
indicato in data model.

I DM L3 non espongono LASTMODIFIEDDATA ne' TS_INIZIO/FINE_VALIDITA come campi
di output (in S3 gli intervalli di validita' delle sorgenti si
usano solo come filtro), e non gestiscono cancellazioni (no `delete_l2`, no
filtri FL_DELETED).

### UDF

`PROBNORM()` e `PROBIT()` sono UDF Python (scipy) gia' deployate in Snowflake:
**usale as-is** nelle espressioni, senza definirle ne' wrapparle. Lo stesso
vale per eventuali altre UDF citate nelle RT: trascrivile e, se non note,
aggiungi `-- WARN: UDF <nome> assunta esistente`.

### Regole SQL

- Solo query, mai `{{ config(...) }}`
- Mai `BETWEEN` -> usa `>= AND <`
- Virgola sempre a fine riga, mai a inizio
- Alias corti, no parole riservate SQL; ricicla gli alias delle RT/CHIAVI se
  presenti (es. `CC`, `PM`, `MA`)
- **Niente `SELECT *` nel SELECT finale** - elencare sempre tutte le colonne.
  Nelle CTE intermedie preferisci comunque colonne esplicite; se una RT usa
  `SELECT CC.*` su decine di colonne, e' accettabile mantenerlo nelle CTE
  interne per leggibilita'.
- **Nessun padding prima di `AS`**: `alias.COLONNA AS NOME_CAMPO`
- `**` (potenza) non e' Snowflake: riscrivi con `POWER()` e commenta
  `-- FIX: data model had '**'`
- Literal timestamp -> `TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')`;
  literal date -> `TO_DATE('9999-12-31')`
- Doppio underscore: `AS X__Y` -> `AS X_Y`

## Step 3: genera YML

```yaml
version: 2
models:
  - name: {dm_lower}
    config:
      materialized: incremental
      incremental_strategy: {append | merge}
      unique_key: [COL1, COL2]            # solo caso merge
      pre_hook:
        - "{{ delete_month('<DT_PARTIZIONE>') }}"   # solo S3
    constraints:
      - type: primary_key
        warn_unenforced: false
        columns: [DT_ESTRAZIONE, CD_PRATICA]
    columns:
      - name: NOME_CAMPO
        data_type: TIPO
```

| S | Classe | incremental_strategy | pre_hook delete_month | unique_key |
|---|---|---|---|---|
| S2 | Append giornaliero | append | no | no |
| S3 | Foto mensile | append | si' | no |
| S4 | Insert_overwrite attualizzati | insert_overwrite | no | no |

- **materialized**: sempre `incremental`
- Niente post-hook di cancellazione
- **Primary key**: colonne con FLAG_PK = Y, nell'ordine del data model
- **Data types**: dal FORMATO/LENGTH/DECIMAL del data model
  (`NUMBER(12,0)`, `VARCHAR(2)`, `DATE`, ...). Per i campi EU_ rispetta
  precisione e scala del data model, senza forzare la scala a 2
  (es. `EU_EL NUMBER(13,11)`). Fallback naming solo se FORMATO assente:
  FL_*->VARCHAR(1), DT_*->DATE, EU_*/NM_*/PC_*->NUMBER, DS_*/CD_*->VARCHAR
