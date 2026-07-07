---
title: Data Masking / Classification
type: concept
tags: [layer/L1, layer/L2, security]
updated: 2026-07-07
---

Basato sul tagging colonne nativo di Snowflake. Poiché [[layer-l0]] è inaccessibile agli utenti finali, il masking viene applicato a partire da [[layer-l1]] e propagato automaticamente a L2/L3 tramite **tag propagation nativa** di Snowflake: qualsiasi DDL che deriva una colonna da una sorgente già taggata trasferisce automaticamente il tag, senza intervento manuale.

## Componenti

- Catalogo [[cfg-l1-datamask]] (`TECH.CFG_L1_DATAMASK`) — censisce per archivio le colonne soggette a masking.
- Oggetti Snowflake: **Tag** + **Masking policy** associata al tag.
- Le colonne sensibili sono identificate nei modelli DBT tramite un campo metadato dichiarato nello yml dei modelli L1.

## Macro

- `add_datamask()` — esegue `ALTER TABLE` su L1 per assegnare il tag alle colonne interessate (a cui è associata la masking policy). Eseguita automaticamente in post-hook alla **prima esecuzione** del modello (non ai run successivi), o in modo estemporaneo per allineare i tag dopo un aggiornamento di `CFG_L1_DATAMASK`.
- `remove_datamask()` — rimuove un tag da una colonna specifica in qualunque layer; in questo caso va rimosso manualmente anche il metadato corrispondente nello yml del modello.

## Collegato da
[[layer-l1]], [[layer-l2]], [[cfg-l1-datamask]], [[agosx-caricamento-l2]]
