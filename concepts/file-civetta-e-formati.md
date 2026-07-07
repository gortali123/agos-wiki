---
title: File civetta e formati sorgente (L0)
type: concept
tags: [layer/L0, glossary]
updated: 2026-07-07
---

## Alberatura bucket S3

Per ogni modulo/archivio: `dati/` (file csv inviati dal sorgente), `archived/` (file caricati correttamente, dopo retention), `schema/` (file di schema, se previsti), `error_dwh/` (+ `fixed/`, `NO_fixed/` — file in errore), `logs/` (file civetta).

## File civetta

File trigger in formato txt, uno per modulo OCS o per archivio/gruppo per le altre sorgenti. Segnala che l'invio di tutti i file di un modulo (o archivio) è completo, scatenando il processo di loading. Contenuto, separato da `|`: nome archivio, nome file inviati, numero di record per archivio, inizio/fine elaborazione, status.

Naming: `<modulo o archivio>_<YYYYMMDDHHMISS>_flag.txt` (es. `ana_20250801102350_flag.txt`).

Per sorgenti configurate come `InfoInCivetta = FileTrigger` (vedi [[cfg-l0-sorgente]]) non c'è file civetta: il file dati stesso è il trigger.

## File dati e cancellazione

- Dati: `<archivio>_<F/D>_<timestamp_invio>_<progressivo>.csv.gz` (F=Full, D=Delta).
- Cancellazione (solo OCS): `<archivio>_deleted_<timestamp_invio>_<progressivo>.csv.gz` — vedi [[gestione-cancellazioni]].
- Schema: `<archivio>_schema` (es. `ccanag_schema.csv`).
- Dimensione massima 250MB compressi (se il sorgente lo consente); file più grandi vanno spezzati.
- Per OCS e Salesforce: se non ci sono record in un dato giorno va comunque inviato un file vuoto. Per le altre sorgenti l'invio non è garantito in assenza di aggiornamenti.

Nota: per le sorgenti no-OCS la naming convention "standard" sopra descritta **potrebbe non essere rispettata** — il documento ufficiale lo segnala esplicitamente con un asterisco.

## File di schema

CSV con delimitatore `|`, fornito da OCS/Salesforce/Fea. Contiene: nome campo, formato/datatype, lunghezza, flag PK, flag nullability. Alimenta [[cfg-l1-schema]].

## Formato Excel (eccezione)

File Excel ammessi solo se: estensione `.xlsx` (non `.xls`), nome con data di riferimento, nessuna macro/formula/link esterno, un solo foglio, nome sheet senza caratteri speciali (tranne underscore) né spazi iniziali/finali, nessuna colonna vuota di comodo, nessun commento/nota/firma/grafico fuori dalle colonne dati, nessuna riga/colonna accorpata o cella unita, valori assenti rappresentati con cella vuota (mai `N/A`, `-`, `NULL` come testo). Conversione automatica a CSV dal job Glue, scritta nel prefix `/dati_conv`.

## Collegato da
[[layer-l0]], [[cfg-l0-sorgente]], [[agosx-caricamento-l0-l1]], [[guida-sviluppo]]
