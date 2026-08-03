---
name: datagen-l1
description: Genera CREATE + INSERT di dati di test per le sorgenti L1 di uno o piu' modelli L2, deducendo colonne/tipi dalle trasformazioni usate nel modello L2. Usare quando l'utente chiede dati di test/popolamento per un modello L2 (es. "generami i dati di test per ana_versioni_form", "fammi il datagen per i modelli di AREA_RISERVATA").
---

# DATAGEN L1 — generatore dati di test per sorgenti L1

Data uno o piu' modelli L2, genera uno script `.sql` con `CREATE TABLE` +
`INSERT INTO` per **ogni sorgente L1** referenziata (via `{{ ref(...) }}`),
con righe di test costruite per esercitare tutti i rami delle
trasformazioni applicate in L2 (macro, `CASE WHEN`, cast, placeholder OCS).

**Non genera** l'INSERT sulla tabella L2 di destinazione: l'obiettivo e'
solo popolare le sorgenti L1 cosi' che il modello L2 sia eseguibile e
testabile con `dbt run`/`dbt test` reali.

## Convenzioni di naming

- Tabella generata: `AGOS_DEV_16000.L1_TEST.<NOME_TABELLA_SORGENTE>_TEST`
  (nome sorgente = nome del `ref()`, uppercase).
- Output: un file per modello L2, in
  `develop/datagen/L2/{AREA}/{entity_lower}.sql` (mirror del path del
  modello in `raw/dwh-code/models/L2/`).
- Piu' modelli richiesti insieme (es. un'intera cartella) -> un file per
  modello, generati in sequenza.

## Workflow

1. **Leggi il modello L2 per intero** (`.sql`, e il relativo `.yml` se
   presente per i data type delle colonne L2).
2. **Individua ogni `{{ ref('...') }}`** nel modello: quella e' una
   sorgente L1 da mockare. Se un `ref()` punta a un altro modello L2/L3
   (non una sorgente L1 diretta), segnalalo e chiedi/salta — questa skill
   copre solo sorgenti L1 dirette.
3. **Determina schema della sorgente L1 sempre per deduzione**: non
   cercare/leggere il modello L1 nel repo. Deduci colonne e tipi solo
   dall'uso nel modello L2: nome colonna dal riferimento (`F.FORMID` ->
   colonna `FORMID`), tipo dalla funzione/macro che la avvolge (vedi
   tabella sotto). Segnala sempre con un commento in testa alla CREATE:
   `-- WARN: schema dedotto dall'uso in <modello>.sql, non verificato contro il modello L1 reale`
4. **Genera CREATE TABLE** con le colonne dedotte/lette, nome
   `AGOS_DEV_16000.L1_TEST.<SORGENTE>_TEST`.
5. **Genera INSERT INTO** con righe di test, una riga per ogni caso
   rilevante (vedi "Copertura test data" sotto). Aggiungi un commento breve
   sopra ogni riga o gruppo di righe che spiega quale caso copre.
6. Se il modello ha **piu' sorgenti** (JOIN multipli), genera CREATE+INSERT
   per ciascuna, con dati coerenti tra loro dove servono chiavi di join
   (stessi valori di chiave presenti in entrambe le mock table, piu'
   qualche riga "orfana" per testare il comportamento di LEFT JOIN/INNER
   JOIN).
7. Presenta un riepilogo breve (una riga per modello: sorgenti trovate,
   vendorizzate o dedotte, numero righe generate).

## Deduzione tipo per funzione/macro

| Espressione nel modello L2 | Tipo dedotto colonna sorgente |
|---|---|
| `custom_to_date(col)` | `NUMBER(8)` (YYYYMMDD) |
| `custom_to_timestamp_ntz(col)` | `TIMESTAMP_NTZ` o `NUMBER`/`VARCHAR` se il pattern e' YYYYMMDDHH24MISS — guarda la macro se vendorizzata, altrimenti assumi `TIMESTAMP_NTZ` |
| `custom_to_decimal(col, x, d)` | `NUMBER(x,0)` (valore intero scalato, la macro divide per 10^d) |
| `custom_is_null`/`custom_is_not_null` (OCS) | `VARCHAR` con placeholder `' '` |
| confronto `= 0` / `NULLIF(col,0)` (OCS NUMBER) | `NUMBER`, con placeholder `0` |
| `TRY_CAST(col AS NUMBER(n))` | `VARCHAR` (sorgente stringa castata) |
| `col::NUMBER(n)` | `NUMBER(n)` |
| confronto con stringhe `'True'/'False'` o `'S'/'N'` | `VARCHAR` |
| nessuna trasformazione, solo alias | dedotto dal prefisso del nome campo L2 di destinazione (`FL_*`->`VARCHAR(1)`, `DT_*`->`DATE`/`NUMBER(8)` sorgente, `EU_*`/`NM_*`->`NUMBER`, `CD_*`/`DS_*`->`VARCHAR`) |

Se il tipo resta ambiguo, usa `VARCHAR` e lascia un `-- WARN`.

## Copertura test data

Per ogni colonna sorgente coinvolta in una trasformazione, includi righe
che esercitano:

- **Ogni ramo di `CASE WHEN`** presente nel modello L2 (incluso l'`ELSE`).
- **Ogni placeholder OCS** noto (`' '` per varchar, `0` per number) quando
  la colonna e' su una tabella OCS (verifica cluster/sorgente in
  `sources/cfg-l1-schema-e-cluster-sto.md` se serve) — sia il caso
  placeholder sia il caso valorizzato.
- **Casi limite delle macro standard**: `custom_to_date`/
  `custom_to_timestamp_ntz` -> valore `99999999`/equivalente (data max),
  valore `0` (NULL), formato YYYYMM troncato, formato pieno normale.
- **NULL vs valore presente**, per ogni colonna nullable non OCS.
- **Almeno 1-2 righe "business normali"** con valori plausibili, oltre ai
  casi limite, cosi' l'output e' anche leggibile come esempio.
- **FL_DELETED**: se la sorgente e' cluster A1/A2/C, includi sia
  `FL_DELETED = 'N'` che `'S'` per verificare il filtro.

Non generare piu' di ~10-15 righe per sorgente salvo che il modello abbia
molte piu' combinazioni rilevanti da coprire — in quel caso segnalalo
invece di troncare silenziosamente.

## Cosa NON fare

- Non generare `INSERT INTO` sulla tabella L2 di destinazione.
- Non scrivere il modello L2 stesso (quello e' compito di `develop-l2`).
- Non inventare colonne non riferite nel modello L2 (a meno che il .yml
  del modello L1 vendorizzato le elenchi comunque).
- Non troncare silenziosamente la copertura dei casi — se ne salti,
  dillo.
