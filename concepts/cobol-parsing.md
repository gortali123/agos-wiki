---
title: "Parsing COBOL (copybook, overpunch)"
type: concept
tags: [layer/L1, cobol]
updated: 2026-07-14
---

Soluzione per interpretare record COBOL a lunghezza fissa provenienti da sistemi legacy, descritta in [[caricamento-layer-l0-l1]].

- Tabella di mapping `COBOL_COPYBOOK_MAPPING` (verificato nel codice: `AGOS_DEV_16000.TECH.CFG_COBOL_COPYBOOK_MAPPING`, nome leggermente diverso da quello citato nel docx che omette il prefisso `CFG_`): una riga per campo per copybook/tipo record, con `SOURCE_TABLE`, `COPYBOOK_NAME`, `RECORD_NAME`, `TYPE_ANAGRAP`, `TYPE_RECORD`, `FIELD_NAME`, `LEVEL`, `PIC_CLAUSE`, `USAGE_CLAUSE`, `FILTER_CONDITION`, `START_POSITION`, `FIELD_LENGTH`, `DECIMAL_SCALE`, `SIGN`, `SF_COLUMN_NAME`, `SF_DATA_TYPE`, `CREATED_AT`.
- Macro `cobol_parse_columns(source_table)` (`macros/generate_models/cobol.sql`): genera dinamicamente, per ogni campo mappato, un'espressione `CASE WHEN <FILTER_CONDITION> THEN CAST(SUBSTR(<content_column>, <start>, <length>) AS <tipo>) ELSE NULL END AS <nome_campo>`. Per campi `FLOAT` (numerici con overpunch), invece di CAST diretto chiama la UDF Snowflake `AGOS_DEV_16000.L0.DECODE_OVERPUNCH(SUBSTR(...), decimal_scale)`.
- **Overpunch**: codifica dello standard COBOL per campi `PIC S9(n)` con `SIGN TRAILING` (segno + ultima cifra in un solo carattere). Decodificata da `decode_overpunch(val, scale)`.

## Inconsistenza verificata (2026-07-14)

Il docx presenta `decode_overpunch` come se fosse una macro DBT alla pari delle altre (accanto a `cobol_parse_columns`). **Non è una macro dbt**: è una **UDF Snowflake** (`AGOS_DEV_16000.L0.DECODE_OVERPUNCH`), invocata da dentro `cobol_parse_columns` ma la cui implementazione non è vendorizzata in `raw/dwh-code/macros/` (vive come oggetto Snowflake, probabilmente definito altrove, non in questo snapshot). Non è un errore funzionale ma una imprecisione di modellazione nella documentazione — chi legge il docx si aspetterebbe di trovarla come file `.sql` tra le macro. Vedi [[inconsistenze]].

## Collegamenti

- [[caricamento-layer-l0-l1]]
- [[macro-catalogo-dbt]]
- [[inconsistenze]]
