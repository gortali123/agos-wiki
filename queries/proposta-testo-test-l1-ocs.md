---
title: "Proposta correzione testo: L1 - Controlli data quality (processo OCS)"
type: query
tags: [layer/L1, source/docx, data-quality, ocs]
updated: 2026-07-27
---

Proposta di correzione al capitolo "L1: Controlli data quality" in `raw/Agos X - Caricamento layer L0-L1.docx`: i nomi dei test generici custom citati nel documento (`primary_key_table`, `try_cast_table`) non corrispondono ai nomi reali nel codice (vedi [[inconsistenze]] voce 7). Corretto solo per il processo **OCS**; il resto del capitolo (store failures, `TEST_LOG_RECORDS`, `pop_test_log_records`) resta confermato e non toccato in questa proposta.

`raw/` è immutabile: questa pagina è la proposta da incollare a mano nel `.docx`, non un'edit diretta del file.

## Testo proposto

> Questi controlli sono applicati attraverso due test generici custom: **`primary_key`** (verifica che i dati presenti in L0 siano univoci rispetto alla chiave primaria dichiarata) e **`try_cast`** (verifica che i data type presenti in L0 siano conformi a quelli dichiarati).
>
> Questi test vengono indicati nel file yml source e vengono eseguiti prima del caricamento del dato in L1. Per gli archivi OCS il livello di severity è impostato a `warn` per `try_cast` e a `fail` per `primary_key`, salvo eccezioni configurate per singolo archivio.

## Basi di questa proposta

- Nel codice vendorizzato (`raw/dwh-code/`) i test generici si chiamano `primary_key`, `primary_key_positional`, `try_cast`, `try_cast_from_sql`, `try_cast_positional` — nessuno con suffisso `_table`.
- Il suffisso `_table` citato nel docx sopravvive solo nel template scaffold `templates/models/L0/table_source.yml`, non nei test effettivamente applicati.
- Non ancora verificato: se per sorgenti non-OCS la severity o la scelta tra `try_cast`/`try_cast_from_sql`/`try_cast_positional` differisca — fuori perimetro di questa proposta, limitata al processo OCS come richiesto dall'utente.

## Collegamenti

- [[caricamento-layer-l0-l1]]
- [[inconsistenze]]
