---
title: TECH.CFG_L0_SORGENTE
type: entity
tags: [layer/L0, config-table]
updated: 2026-07-07
---

Tabella di configurazione che mappa ogni sorgente/archivio ai dettagli necessari per i controlli tecnici e il caricamento in [[layer-l0]] (percorso, formato, estensione, ecc.).

## Struttura (dal documento ufficiale)

3 colonne: `Sorgente`, `Defaults` (VARIANT), `Eccezioni` (VARIANT, override per archivi specifici rispetto ai default della sorgente).

## Dettaglio implementativo: CFG.json

La guida sviluppo descrive la controparte applicativa di questa tabella: un file `CFG.json` (nella repo `dwh-x-glue-library`) con struttura `<SORGENTE> → defaults / eccezioni → <ARCHIVIO>`, poi caricato in Snowflake come sopra. Parametri principali per sorgente/archivio:

| Parametro | Descrizione |
|---|---|
| Estensione | `.csv`, `.csv.gz`, `.txt`, `.txt.gz`, `.xlsx`, `.tsv`, `.xml`, `.json`, `.json.gz`, `.COMPLETED` |
| Dimensione | MB massimi (compressi) |
| FileFormat / Stage | oggetti Snowflake associati |
| Encoding | `utf-8` (default), `utf-8-sig`, `cp1252`, `latin-1`, `ascii`, `utf-16`... |
| Separatore | `\|`, `;`, `,`, `\t` |
| HeaderIndex | riga header 0-based |
| Bucket | bucket S3 sorgente |
| Modulo | `true` se organizzata a moduli (es. OCS) |
| LoadProcedure | `Standard` / `Custom` / `Main` (solo OCS) |
| FileCheck / HeaderCheck | `Standard` / `Skip` (HeaderCheck anche `NumeroColonne`) |
| InfoInCivetta | `Standard` (richiede `RegexCivetta`) / `FileTrigger` |
| RegexNamingLoad / RegexNamingDeleted / RegexCivetta / RegexSchema | regex Python con gruppi nominati (`archivio` obbligatorio in RegexNamingLoad, `unit` obbligatorio in RegexCivetta) |

Il merge dei parametri in `eccezioni` è **totale per override**: solo i parametri specificati sostituiscono l'omonimo in `defaults`, il resto è ereditato. La chiave del blocco eccezione deve combaciare esattamente col valore del gruppo `archivio` estratto dalla regex.

## Caricamento/aggiornamento in Snowflake

Tre modalità operative documentate in [[guida-sviluppo]]: truncate+reload completo, insert via query diretta, o MERGE incrementale da file S3 — tutte tramite tabella di appoggio `TECH.TEMP_JSON` (VARIANT) + `LATERAL FLATTEN`.

## Collegato da
[[layer-l0]], [[agosx-caricamento-l0-l1]], [[guida-sviluppo]]
