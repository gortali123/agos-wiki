---
title: Parsing campi COBOL (gestione eccezioni L1)
type: concept
tags: [layer/L1, cobol]
updated: 2026-07-07
---

Soluzione per interpretare colonne "flat" contenenti record COBOL a lunghezza fissa (descritti da COPYBOOK), integrata come macro DBT metadata-driven.

## Principio

Il contenuto della colonna flat è strutturato secondo una COPYBOOK specifica, variabile in base al tipo di record. La tabella di output unisce tutti i campi delle sezioni DATI di **tutte** le COPYBOOK associate alla sorgente: poiché un record appartiene a una sola COPYBOOK alla volta, i campi delle altre COPYBOOK sono valorizzati a `NULL` per quel record → schema di output fisso e prevedibile.

## Macro `cobol_parse_columns(source_table)`

Legge [[cobol-copybook-mapping]] a runtime e genera dinamicamente, per ogni campo mappato, un'espressione:

```sql
CASE
    WHEN <discriminator_condition> = '<valore_copybook>' THEN
        CAST(SUBSTR(<content_column>, <start>, <length>) AS <tipo>)
    ELSE NULL
END AS <nome_campo>
```

Uso tipico in un modello dedicato:
```sql
SELECT {{ cobol_parse_columns('<source_table>') }}
FROM {{ ref('<sorgente>', '<modello_sorgente>') }}
```

Per omettere la definizione colonne nello yml occorre disabilitare il contract del modello (`{{ config( contract = {"enforced": false} ) }}` come prima riga del modello sql).

Aggiungere un nuovo tipo anagrafica richiede solo un insert nella tabella di mapping, nessuna modifica a macro o modelli.

## Overpunch

Codifica standard COBOL per campi `PIC S9(n) SIGN TRAILING`: il segno e l'ultima cifra sono rappresentati da un singolo carattere. Decodificata dalla funzione `decode_overpunch(val STRING, scale FLOAT) → FLOAT`, integrata nella logica di `cobol_parse_columns`. Ritorna `NULL` senza errore per input `NULL`/vuoto/solo spazi; divide il valore grezzo per `10^scale`.

## Collegato da
[[layer-l1]], [[cobol-copybook-mapping]], [[agosx-caricamento-l0-l1]]
