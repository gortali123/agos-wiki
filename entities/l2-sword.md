---
title: "L2 SWORD"
type: entity
tags: [layer/L2, area/SWORD]
updated: 2026-07-14
---

Modelli (`raw/dwh-code/models/L2/SWORD/`): `creditline`, `credlinasset`, `credlinfacil`, `loan`, `loan_arrears`, `loan_asset`, `loan_chargeprof`, `loan_transac`, `org_contact`, `org_transact`, `organisation`, `plan`, `plan_chargeprof`, `plan_paysch`.

**Architetturalmente unica nel progetto**: a differenza di tutte le altre aree (sorgenti relazionali), SWORD legge da un **campo XML** (`GN_VALUE`, un blob dentro una tabella wrapper `master_data`), parsato con `PARSE_XML` e navigato con le macro `{{ get_xml_path(...) }}` / `{{ flatten_xml(...) }}` (vedi [[macro-catalogo-dbt]]). Nessun `query_tag`, nessun `pre_hook delete_l2` in tutta l'area.

## Collegamenti

- [[layer-l2]]
- [[macro-catalogo-dbt]]
