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

Nome tabella/colonne corretto il 2026-08-25 per seguire la convenzione reale delle tabelle tecniche `TECH.CFG_*` (vedi `raw/dwh-code/macros/generate_models/generate_yaml.sql`, che legge da `TECH.CFG_L1_SCHEMA`/`CFG_L1_CLUSTER_STO`/`CFG_L1_DATAMASK`/`CFG_L0_L1_MODULO_LOOKUP`): schema `TECH`, tabella `CFG_` + maiuscolo, colonne con prefisso per tipo (`DS_` stringa, `FL_` flag Y/N, `GN_` per VARIANT — come `gn_failure_info` in `try_cast.sql`).

```sql
CREATE TABLE TECH.CFG_DQ_TEST_CONFIG (
    DS_MODELLO     VARCHAR,     -- nome modello dbt, es. 'L2_ANAGR_CONTROPARTE'
    DS_COLONNA     VARCHAR,     -- null per test a livello tabella
    DS_TEST_TYPE   VARCHAR,     -- nome del generic test custom, es. 'dq_not_null', 'dq_custom_sql'
    GN_PARAMS      VARIANT,     -- parametri specifici del test type, in json
    DS_SEVERITY    VARCHAR,     -- 'warn' | 'error' (letterale dbt config.severity)
    FL_ACTIVE      VARCHAR(1) DEFAULT 'Y'  -- Y/N, non booleano (coerente con FL_DELETED e gli altri FL_ del progetto)
);
```

## Generic test custom

Uno per `TEST_TYPE`, in `tests/generic/` (convenzione reale del repo — vedi i generic test esistenti in `raw/dwh-code/tests/generic/`, es. `try_cast.sql`, `primary_key.sql` — non `macros/generic_tests/` come scritto nella prima bozza di questa pagina).

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
    "select ds_colonna, ds_test_type, gn_params, ds_severity from tech.cfg_dq_test_config where ds_modello = 'L2_ANAGR_CONTROPARTE' and fl_active = 'Y'"
) %}

models:
  - name: L2_ANAGR_CONTROPARTE
    columns:
    {% for i in range(cfg['DS_COLONNA']|length) %}
      - name: {{ cfg['DS_COLONNA'][i] }}
        tests:
          - {{ cfg['DS_TEST_TYPE'][i] }}:
              {% set p = fromjson(cfg['GN_PARAMS'][i]) %}
              {% for k, v in p.items() %}
              {{ k }}: "{{ v }}"
              {% endfor %}
              config:
                severity: {{ cfg['DS_SEVERITY'][i] }}
    {% endfor %}
```

Nel pilota effettivo (vedi sotto) la query è fattorizzata in una macro dedicata (`dq_cfg_by_col`, in `develop/macros/data_quality/dq_tests_block.sql`) invece di essere inline nello schema.yml, per poter essere riusata su più modelli.

`dbt build` esegue questi test sempre dopo il modello; `dbt test` li rilancia isolatamente quando serve — nessun runner o hook aggiuntivo.

## Punto aperto / da verificare in fase di implementazione

`get_query_results_as_dict` gira a **compile time**: serve una connessione al warehouse attiva durante il parse. Non è un problema nel normale flusso CLI/Cloud (ogni invocazione fa comunque il parse), ma va tenuto a mente: se la config cambia, il nuovo test compare solo al prossimo parse/compile, non a runtime su un artifact già compilato.

## Pilota: check formato email su ANAGRAFICA_CONTROPARTE.DS_EMAIL (2026-08-25)

Primo test reale, in `develop/`, non ancora portato upstream:

- `develop/tests/generic/is_valid_email.sql` — generic test custom (`regexp_like` su pattern email base), in `tests/generic/` come da convenzione reale del repo.
- `develop/macros/data_quality/dq_tests_block.sql` — `dq_cfg_by_col(model_name)` (una query su `TECH.CFG_DQ_TEST_CONFIG` per modello, risultato raggruppato per colonna) + `dq_tests_block(cfg_by_col, col_name)` (puro lookup/render, nessuna query aggiuntiva).
- `develop/models/L2/ANAGR_CONTROPARTE/anagrafica_controparte.yml` — copia completa dello schema.yml reale (tutte le colonne/data_type/constraints), con `{{ dq_tests_block(cfg_by_col, '<NOME_COLONNA>') }}` dopo ogni `data_type:`. Nessuna colonna è hardcoded per un test specifico: la chiamata è identica per tutte le ~230 colonne, è la riga di config a decidere quali producono un test.
- `develop/setup/dq_test_config.sql` — `CREATE TABLE TECH.CFG_DQ_TEST_CONFIG` (schema da questa pagina, nomi colonna con prefissi `DS_`/`FL_`/`GN_` coerenti col resto del progetto) + riga pilota: `('L2_ANAGR_CONTROPARTE', 'DS_EMAIL', 'is_valid_email', null, 'warn', 'Y')`.

Non ancora verificato: una compilazione/run dbt reale (serve l'ambiente Snowflake collegato, non disponibile da qui) — quindi il pattern è verificato solo a livello di lettura/design, non eseguito.

## Stato

Design confermato 2026-08-20; primo pilota implementato in `develop/` il 2026-08-25 (vedi sopra). Da formalizzare ulteriormente (altri test_type, altri modelli) solo dopo validazione del pilota.
