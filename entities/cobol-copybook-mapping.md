---
title: COBOL_COPYBOOK_MAPPING
type: entity
tags: [layer/L1, config-table, cobol]
updated: 2026-07-07
---

Tabella di mapping metadata-driven che descrive, per ciascuna tabella sorgente L1 e ciascuna COPYBOOK associata, la definizione completa di ogni campo COBOL da estrarre da una colonna flat. Letta a runtime dalla macro DBT `cobol_parse_columns`, vedi [[parsing-cobol]].

## Colonne principali

`SOURCE_TABLE`, `COPYBOOK_NAME`, `RECORD_NAME`, `TYPE_ANAGRAP`, `TYPE_RECORD`, `FIELD_NAME`, `LEVEL` (01-49, 66, 77, 88), `PIC_CLAUSE` (tipo/lunghezza/decimali/segno in notazione COBOL, es. `S9(9)V99`), `USAGE_CLAUSE` (`DISPLAY`, `COMP`, `COMP-3`, `COMP-1/2`), `FILTER_CONDITION` (discriminator), `START_POSITION`, `FIELD_LENGTH`, `DECIMAL_SCALE`, `SIGN` (`LEADING`/`TRAILING`/`NULL`), `SF_COLUMN_NAME`, `SF_DATA_TYPE`, `CREATED_AT`.

## Uso

Deve essere popolata correttamente prima di eseguire qualunque modello DBT che usi `cobol_parse_columns`. Aggiungere un nuovo tipo anagrafica richiede solo un insert in questa tabella, nessuna modifica a macro o modelli esistenti.

## Collegato da
[[parsing-cobol]], [[layer-l1]], [[agosx-caricamento-l0-l1]]
