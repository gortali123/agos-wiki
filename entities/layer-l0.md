---
title: "Layer L0"
type: entity
tags: [layer/L0]
updated: 2026-07-14
---

Primo layer Snowflake: ingestione grezza da sorgenti esterne (OCS, Salesforce, CDE, ADOBE, CTC, ...). Tabelle **TRANSIENT**, tutti i campi VARCHAR/VARIANT, ricreate ad ogni run (`CREATE OR REPLACE`). Popolato da job AWS Glue + procedure Snowflake, orchestrati da Control-M via trigger SNS sul file civetta.

Nello snapshot vendorizzato (`raw/dwh-code/models/L0/`) contiene solo file `*_source.yml` (dichiarazioni source, nessun modello SQL) per le sorgenti ADOBE, CTC, OCS.

Dettagli completi: [[caricamento-layer-l0-l1]], [[guida-sviluppo]].

## Collegamenti

- [[layer-l1]]
- [[repo-dwh-x-dbt]]
