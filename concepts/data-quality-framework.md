---
title: Data Quality Framework (proposta, config-driven)
type: concept
tags: [layer/L2, layer/L3, dbt, data-quality, proposta]
updated: 2026-08-20
---

Proposta (non ancora implementata, solo design) per gestire i test di data quality su L2/L3 in modo dichiarativo, tramite una tabella di configurazione Snowflake, restando dentro il meccanismo nativo dei test dbt — nessuna tabella di risultati custom, nessun runner parallelo.

## Requisiti stabiliti con l'utente (2026-08-20)

1. I test devono girare **sempre tramite dbt** (`dbt build` quando il test deve girare a ogni run dopo il modello, `dbt test` quando gira a cadenza separata/più rada).
2. I risultati **non** vanno in una tabella dedicata: devono confluire nella stessa event table dei test dbt "classici" (vedi [[cancellazioni-fl-deleted]]/log_run_results già in uso nel progetto — meccanismo esistente, non toccato da questa proposta). Non interessano gli `store_failures`, solo l'esito pass/fail.
3. I test devono essere **custom** (non solo i tipi standard tipo `not_null`/`unique` di dbt/dbt_utils).
4. Ogni riga di configurazione può avere una **severity** propria (`warn`/`error`), mappata sul `config.severity` nativo di dbt.

## Idea chiave

Gli `schema.yml` di dbt sono **Jinja-rendered prima del parsing YAML**. Questo permette di interrogare la tabella di config a compile-time (via `run_query` / `dbt_utils.get_query_results_as_dict`) e generare dinamicamente i blocchi `tests:` per ogni colonna/modello, invece di scriverli a mano. I test generati sono a tutti gli effetti nodi dbt normali → finiscono in `run_results.json` come qualsiasi altro test, quindi il meccanismo di logging verso l'event table esistente li intercetta senza modifiche.

## Schema di configurazione

```sql
CREATE TABLE CFG.DQ_TEST_CONFIG (
    MODELLO     VARCHAR,     -- nome modello dbt, es. 'L2_ANAGR_CONTROPARTE'
    COLONNA     VARCHAR,     -- null per test a livello tabella
    TEST_TYPE   VARCHAR,     -- nome del generic test custom, es. 'dq_not_null', 'dq_custom_sql'
    PARAMS      VARIANT,     -- parametri specifici del test type, in json
    SEVERITY    VARCHAR,     -- 'warn' | 'error' (letterale dbt config.severity)
    ACTIVE      BOOLEAN DEFAULT TRUE
);
```

## Generic test custom

Uno per `TEST_TYPE`, in `macros/generic_tests/` (segue la convenzione dei generic test dbt: la query restituisce le righe che *falliscono*).

```sql
-- macros/generic_tests/dq_not_null.sql
{% test dq_not_null(model, column_name) %}
    select * from {{ model }} where {{ column_name }} is null
{% endtest %}
```

```sql
-- macros/generic_tests/dq_custom_sql.sql
{% test dq_custom_sql(model, column_name=none, condition_sql=none) %}
    select *
    from {{ model }}
    where not ({{ condition_sql }})
{% endtest %}
```

## Generazione dinamica dei test da config

```yaml
{% set cfg = dbt_utils.get_query_results_as_dict(
    "select colonna, test_type, params, severity from cfg.dq_test_config where modello = 'L2_ANAGR_CONTROPARTE' and active"
) %}

models:
  - name: L2_ANAGR_CONTROPARTE
    columns:
    {% for i in range(cfg['COLONNA']|length) %}
      - name: {{ cfg['COLONNA'][i] }}
        tests:
          - {{ cfg['TEST_TYPE'][i] }}:
              {% set p = fromjson(cfg['PARAMS'][i]) %}
              {% for k, v in p.items() %}
              {{ k }}: "{{ v }}"
              {% endfor %}
              config:
                severity: {{ cfg['SEVERITY'][i] }}
    {% endfor %}
```

`dbt build` esegue questi test sempre dopo il modello; `dbt test` li rilancia isolatamente quando serve — nessun runner o hook aggiuntivo.

## Punto aperto / da verificare in fase di implementazione

`get_query_results_as_dict` gira a **compile time**: serve una connessione al warehouse attiva durante il parse. Non è un problema nel normale flusso CLI/Cloud (ogni invocazione fa comunque il parse), ma va tenuto a mente: se la config cambia, il nuovo test compare solo al prossimo parse/compile, non a runtime su un artifact già compilato.

## Stato

Solo design, discusso in chat il 2026-08-20. Nessun file scritto in `develop/` — da formalizzare come `develop/macros/generic_tests/*` e come modifica agli `schema.yml` quando si passa all'implementazione reale.
